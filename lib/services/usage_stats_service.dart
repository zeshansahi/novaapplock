import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UsageStatsService {
  static const String _lockedAppsKey = 'locked_apps_list';
  static const MethodChannel _channel = MethodChannel('com.example.novaapplock/usage_stats');
  static Timer? _monitoringTimer;
  static String? _lastForegroundApp;
  static Function(String packageName, String appName)? onLockedAppDetected;

  /// Check if usage stats permission is granted
  static Future<bool> isPermissionGranted() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkUsageStatsPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Request usage stats permission
  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestUsageStatsPermission');
    } catch (e) {
      // Handle error
    }
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
      return lockedAppsJson;
    } catch (e) {
      return [];
    }
  }

  /// Add app to locked list
  static Future<bool> addLockedApp(String packageName) async {
    try {
      final lockedApps = await getLockedApps();
      if (!lockedApps.contains(packageName)) {
        lockedApps.add(packageName);
        final prefs = await SharedPreferences.getInstance();
        return await prefs.setStringList(_lockedAppsKey, lockedApps);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Remove app from locked list
  static Future<bool> removeLockedApp(String packageName) async {
    try {
      final lockedApps = await getLockedApps();
      lockedApps.remove(packageName);
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setStringList(_lockedAppsKey, lockedApps);
    } catch (e) {
      return false;
    }
  }

  /// Check if app is locked
  static Future<bool> isAppLocked(String packageName) async {
    final lockedApps = await getLockedApps();
    return lockedApps.contains(packageName);
  }

  /// Start monitoring foreground app
  static void startMonitoring() {
    if (_monitoringTimer != null && _monitoringTimer!.isActive) {
      return;
    }

    _monitoringTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final foregroundApp = await getForegroundApp();
        
        if (foregroundApp != null && foregroundApp != _lastForegroundApp) {
          _lastForegroundApp = foregroundApp;
          
          final isLocked = await isAppLocked(foregroundApp);
          if (isLocked && onLockedAppDetected != null) {
            final appName = await getAppName(foregroundApp);
            onLockedAppDetected!(foregroundApp, appName);
          }
        }
      } catch (e) {
        // Handle error silently
      }
    });
  }

  /// Stop monitoring foreground app
  static void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _lastForegroundApp = null;
  }
}
