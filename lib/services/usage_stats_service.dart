import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'permission_service.dart';

class UsageStatsService {
  static const String _lockedAppsKey = 'locked_apps_list';
  static const MethodChannel _channel = MethodChannel('com.example.novaapplock/usage_stats');
  static Timer? _monitoringTimer;
  static String? _lastForegroundApp;
  static String? _lastLockedAppTriggered; // Track last locked app we triggered overlay for
  static String? _lastUnlockedPackage;
  static DateTime? _lastUnlockTime;
  static const Duration _unlockCooldown = Duration(minutes: 5);
  static bool _overlayActive = false;
  static String? _currentUnlockedForeground;
  static Function(String packageName, String appName)? onLockedAppDetected;

  /// Check if usage stats permission is granted
  static Future<bool> isPermissionGranted() async {
    return await PermissionService.isUsageStatsPermissionGranted();
  }

  /// Request usage stats permission
  static Future<void> requestPermission() async {
    await PermissionService.requestUsageStatsPermission();
  }

  /// Get the current foreground app
  static Future<String?> getForegroundApp() async {
    try {
      final result = await _channel.invokeMethod<String>('getForegroundApp');
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Get app name from package name
  static Future<String> getAppName(String packageName) async {
    try {
      final result = await _channel.invokeMethod<String>('getAppName', {'packageName': packageName});
      return result ?? packageName;
    } catch (e) {
      return packageName;
    }
  }

  /// Get list of locked apps
  static Future<List<String>> getLockedApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lockedAppsJson = prefs.getStringList(_lockedAppsKey) ?? [];
      // Trim and filter out any empty strings
      final cleanedList = lockedAppsJson
          .map((app) => app.trim())
          .where((app) => app.isNotEmpty)
          .toList();
      print('🔐 getLockedApps: Retrieved ${cleanedList.length} apps: ${cleanedList.join(", ")}');
      return cleanedList;
    } catch (e) {
      print('❌ Error getting locked apps: $e');
      return [];
    }
  }

  /// Add app to locked list
  static Future<bool> addLockedApp(String packageName) async {
    try {
      final trimmedPackageName = packageName.trim();
      final lockedApps = await getLockedApps();
      
      // Check if already exists (case-insensitive and trimmed)
      final alreadyExists = lockedApps.any((app) => app.trim().toLowerCase() == trimmedPackageName.toLowerCase());
      
      if (!alreadyExists) {
        lockedApps.add(trimmedPackageName);
        final prefs = await SharedPreferences.getInstance();
        final success = await prefs.setStringList(_lockedAppsKey, lockedApps);
        print('🔐 addLockedApp: Added $trimmedPackageName, success: $success');
        return success;
      } else {
        print('🔐 addLockedApp: $trimmedPackageName already exists');
        return true;
      }
    } catch (e) {
      print('❌ Error adding locked app: $e');
      return false;
    }
  }

  /// Remove app from locked list
  static Future<bool> removeLockedApp(String packageName) async {
    try {
      final trimmedPackageName = packageName.trim();
      final lockedApps = await getLockedApps()??[];
      
      // Remove using case-insensitive comparison
      lockedApps.removeWhere((app) => app.trim().toLowerCase() == trimmedPackageName.toLowerCase());
      
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setStringList(_lockedAppsKey, lockedApps);
      print('🔐 removeLockedApp: Removed $trimmedPackageName, success: $success');
      return success;
    } catch (e) {
      print('❌ Error removing locked app: $e');
      return false;
    }
  }

  /// Check if app is locked
  static Future<bool> isAppLocked(String packageName) async {
    try {
      final trimmedPackageName = packageName.trim();
      final lockedApps = await getLockedApps();
      
      // Use case-insensitive comparison with trimming
      final isLocked = lockedApps.any((app) => app.trim().toLowerCase() == trimmedPackageName.toLowerCase());
      
      print('🔐 isAppLocked check: "$trimmedPackageName" -> $isLocked (locked apps: ${lockedApps.length})');
      if (lockedApps.isNotEmpty) {
        print('🔐 Locked apps list: ${lockedApps.join(", ")}');
        // Debug: Show exact comparison
        for (var app in lockedApps) {
          final matches = app.trim().toLowerCase() == trimmedPackageName.toLowerCase();
          print('🔐   Comparing: "$app" == "$trimmedPackageName" -> $matches');
        }
      }
      return isLocked;
    } catch (e) {
      print('❌ Error checking if app is locked: $e');
      return false;
    }
  }

  static void markUnlocked(String packageName) {
    _lastUnlockedPackage = packageName;
    _lastUnlockTime = DateTime.now();
    _lastLockedAppTriggered = null; // Clear trigger so app can be used freely
    _overlayActive = false;
    _currentUnlockedForeground = packageName;
    
    // Notify native side to set cooldown in MonitoringService
    const overlayChannel = MethodChannel('com.example.novaapplock/overlay');
    overlayChannel.invokeMethod('markUnlocked', {'packageName': packageName}).catchError((e) {
      print('Error marking unlocked on native side: $e');
    });
    
    print('🔓 Marked $packageName as unlocked');
  }

  static void setOverlayActive(bool active) {
    _overlayActive = active;
    if (!active) {
      _lastLockedAppTriggered = null;
    }
  }

  static void clearLockStateForPackage(String packageName) {
    if (_lastLockedAppTriggered == packageName) {
      _lastLockedAppTriggered = null;
    }
    if (_currentUnlockedForeground == packageName) {
      _currentUnlockedForeground = null;
    }
    if (_lastUnlockedPackage == packageName) {
      _lastUnlockedPackage = null;
      _lastUnlockTime = null;
    }
  }

  static Future<void> clearPendingLockForPackage(String packageName) async {
    if (packageName.isEmpty) return;
    const overlayChannel = MethodChannel('com.example.novaapplock/overlay');
    try {
      await overlayChannel.invokeMethod('clearPendingLockForPackage', {
        'packageName': packageName,
      });
    } catch (e) {
      print('Error clearing pending lock for $packageName: $e');
    }
  }

  /// Start monitoring foreground app
  static void startMonitoring() {
    if (_monitoringTimer != null && _monitoringTimer!.isActive) {
      print('⚠️ Monitoring already active, skipping');
      return;
    }

    print('✅ Starting UsageStats monitoring...');
    // Keep process alive with native foreground service
    _channel.invokeMethod('startMonitoringService').catchError((e) {
      print('❌ Error starting monitoring service: $e');
    });
    _lastForegroundApp = null; // Reset to ensure first check triggers
    
    _monitoringTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) async {
      try {
        final foregroundApp = await getForegroundApp();
        
        // Don't monitor our own app or null
        if (foregroundApp == null) {
          _lastForegroundApp = null;
          _lastLockedAppTriggered = null;
          return;
        }
        
        if (foregroundApp == 'com.example.novaapplock') {
          _lastForegroundApp = null;
          _lastLockedAppTriggered = null;
          return;
        }
        
        // Check if app changed
        final appChanged = foregroundApp != _lastForegroundApp;
        
        if (appChanged) {
          print('📱 Foreground app changed: $_lastForegroundApp -> $foregroundApp');
          _lastForegroundApp = foregroundApp;
        }

        // If overlay already showing, skip
        if (_overlayActive) {
          return;
        }

        // If this app was just unlocked, skip re-locking while it stays in foreground.
        if (_currentUnlockedForeground != null) {
          if (foregroundApp == _currentUnlockedForeground) {
            print('⏸️ Skipping lock for recently unlocked app still in foreground: $foregroundApp');
            return;
          } else {
            // Foreground changed, clear unlock flag
            _currentUnlockedForeground = null;
            _lastUnlockedPackage = null;
            _lastUnlockTime = null;
          }
        }
        
        // Always check if current app is locked (not just on change)
        // This ensures we catch locked apps even if detection was missed
        final isLocked = await isAppLocked(foregroundApp);
        print('🔍 Checking app: $foregroundApp -> Locked: $isLocked');
        
        if (isLocked) {
          // Only trigger if app changed OR if we haven't triggered for this app yet
          // This prevents repeated triggers but allows re-trigger if user switches away
          final shouldTrigger = appChanged || _lastLockedAppTriggered != foregroundApp;
          
          if (shouldTrigger) {
            print('🔍 Locked app detected: $foregroundApp (changed: $appChanged)');
            print('🔍 Callback status: ${onLockedAppDetected != null ? "SET" : "NULL"}');
            
            if (onLockedAppDetected != null) {
              final appName = await getAppName(foregroundApp);
              print('🚨 LOCKED APP DETECTED: $foregroundApp ($appName)');
              print('🚨 Calling callback immediately...');
              
              // Mark that we've triggered for this app
              _lastLockedAppTriggered = foregroundApp;
              
              // Call the callback immediately when locked app is detected
              try {
                onLockedAppDetected!(foregroundApp, appName);
                print('✅ Callback executed successfully');
              } catch (e, stackTrace) {
                print('❌ Error in callback: $e');
                print('❌ Stack trace: $stackTrace');
                // Reset trigger flag on error so we can retry
                _lastLockedAppTriggered = null;
              }
            } else {
              print('⚠️ Callback is null! Cannot trigger lock overlay');
              print('⚠️ Make sure monitoring callback is set in main.dart or home_screen.dart');
            }
          }
        } else {
          // Current app isn't locked, so reset trigger state
          _lastLockedAppTriggered = null;
        }
      } catch (e) {
        // Log error for debugging
        print('❌ UsageStats monitoring error: $e');
      }
    });
    print('✅ UsageStats monitoring started successfully');
  }

  /// Stop monitoring foreground app
  static void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _lastForegroundApp = null;
    _lastLockedAppTriggered = null;
    _channel.invokeMethod('stopMonitoringService').catchError((e) {
      print('❌ Error stopping monitoring service: $e');
    });
  }
}
