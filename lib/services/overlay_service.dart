import 'package:overlay_support/overlay_support.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../features/auth_pin/screens/lock_overlay_screen.dart';
import 'usage_stats_service.dart';

class OverlayService {
  static const MethodChannel _channel = MethodChannel('com.example.novaapplock/overlay');
  static bool _isOverlayShowing = false;
  static OverlaySupportEntry? _currentOverlay;
  static VoidCallback? _currentOnUnlock;
  static String? _currentPackage;

  /// Show the lock screen overlay
  static void showLockOverlay({
    required String packageName,
    required String appName,
    required VoidCallback onUnlock,
  }) {
    if (_isOverlayShowing) {
      print('⚠️ Overlay already showing, skipping');
      return;
    }

    print('🔒 Showing lock overlay for: $packageName ($appName)');
    _isOverlayShowing = true;
    _currentOnUnlock = onUnlock;
    _currentPackage = packageName;
    UsageStatsService.setOverlayActive(true);
    
    // Bring our app to foreground, then show Flutter overlay with PIN
    _bringAppToFront().then((_) {
      // Add a small delay to ensure app is in foreground
      return Future.delayed(const Duration(milliseconds: 200));
    }).then((_) {
      _showFlutterOverlay(packageName, appName, onUnlock);
    }).catchError((error) {
      print('❌ Error in showLockOverlay: $error');
      _isOverlayShowing = false;
      _currentOnUnlock = null;
      // Retry once after delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_isOverlayShowing) {
          print('🔄 Retrying lock overlay...');
          _isOverlayShowing = true;
          _currentOnUnlock = onUnlock;
          _showFlutterOverlay(packageName, appName, onUnlock);
        }
      });
    });
  }

  static void _showFlutterOverlay(String packageName, String appName, VoidCallback onUnlock) {
    try {
      print('📱 Creating Flutter overlay widget...');
      _currentOverlay = showOverlay(
        (context, t) => LockOverlayScreen(
          packageName: packageName,
          appName: appName,
          onUnlock: () {
            print('✅ Overlay unlocked for: $packageName');
            _isOverlayShowing = false;
            _currentPackage = null;
            UsageStatsService.setOverlayActive(false);
            onUnlock();
            _currentOverlay?.dismiss();
            _currentOverlay = null;
            _currentOnUnlock = null;
          },
        ),
        duration: Duration.zero, // Show until dismissed
      );
      print('✅ Flutter overlay shown successfully');
    } catch (e, stackTrace) {
      print('❌ Error showing Flutter overlay: $e');
      print('Stack trace: $stackTrace');
      _isOverlayShowing = false;
      _currentOnUnlock = null;
      _currentOverlay = null;
      _currentPackage = null;
    }
  }

  static void _handleUnlock() {
    if (_currentOnUnlock != null) {
      _currentOnUnlock!();
      _currentOnUnlock = null;
    }
    _isOverlayShowing = false;
  }

  /// Hide the lock screen overlay
  static void hideLockOverlay() {
    if (!_isOverlayShowing) {
      print('ℹ️ No overlay to hide');
      return;
    }
    
    print('🔓 Hiding lock overlay');
    _isOverlayShowing = false;
    UsageStatsService.setOverlayActive(false);
    _currentPackage = null;
    
    // Hide native overlay
    try {
      _channel.invokeMethod('hideOverlay').catchError((e) {
        print('⚠️ Error hiding native overlay: $e');
      });
    } catch (e) {
      print('⚠️ Exception hiding native overlay: $e');
    }
    
    // Hide Flutter overlay
    try {
      _currentOverlay?.dismiss();
      _currentOverlay = null;
      _currentOnUnlock = null;
      _currentPackage = null;
    } catch (e) {
      print('⚠️ Error dismissing Flutter overlay: $e');
    }
  }

  static bool get isOverlayShowing => _isOverlayShowing;

  static void hideIfShowingFor(String packageName) {
    if (_currentPackage == packageName) {
      hideLockOverlay();
    }
  }

  static Future<void> _bringAppToFront() async {
    try {
      await _channel.invokeMethod('bringToFront');
      print('Requested bringToFront via platform channel');
    } catch (e) {
      print('Error bringing app to front: $e');
    }
  }
}
