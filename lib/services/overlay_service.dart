import 'package:overlay_support/overlay_support.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../features/auth_pin/screens/lock_overlay_screen.dart';

class OverlayService {
  static const MethodChannel _channel = MethodChannel('com.example.novaapplock/overlay');
  static bool _isOverlayShowing = false;
  static OverlaySupportEntry? _currentOverlay;
  static VoidCallback? _currentOnUnlock;

  /// Show the lock screen overlay
  static void showLockOverlay({
    required String packageName,
    required String appName,
    required VoidCallback onUnlock,
  }) {
    if (_isOverlayShowing) {
      print('Overlay already showing, skipping');
      return;
    }

    print('Showing lock overlay for: $packageName ($appName)');
    _isOverlayShowing = true;
    _currentOnUnlock = onUnlock;
    
    // Try native overlay first (works over other apps)
    _showNativeOverlay(packageName, appName).catchError((e) {
      print('Native overlay failed: $e, trying Flutter overlay');
      // Fallback to Flutter overlay (only works in our app)
      _showFlutterOverlay(packageName, appName, onUnlock);
    });
  }

  static Future<void> _showNativeOverlay(String packageName, String appName) async {
    try {
      await _channel.invokeMethod('showOverlay', {
        'packageName': packageName,
        'appName': appName,
      });
      print('Native overlay shown successfully');
    } catch (e) {
      print('Error showing native overlay: $e');
      rethrow;
    }
  }

  static void _showFlutterOverlay(String packageName, String appName, VoidCallback onUnlock) {
    try {
      _currentOverlay = showOverlay(
        (context, t) => LockOverlayScreen(
          packageName: packageName,
          appName: appName,
          onUnlock: () {
            print('Overlay unlocked for: $packageName');
            _isOverlayShowing = false;
            onUnlock();
            _currentOverlay?.dismiss();
            _currentOverlay = null;
            _currentOnUnlock = null;
          },
        ),
        duration: Duration.zero, // Show until dismissed
      );
      print('Flutter overlay shown successfully');
    } catch (e) {
      print('Error showing Flutter overlay: $e');
      _isOverlayShowing = false;
      _currentOnUnlock = null;
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
    if (!_isOverlayShowing) return;
    _isOverlayShowing = false;
    
    // Hide native overlay
    _channel.invokeMethod('hideOverlay').catchError((e) {
      print('Error hiding native overlay: $e');
    });
    
    // Hide Flutter overlay
    _currentOverlay?.dismiss();
    _currentOverlay = null;
    _currentOnUnlock = null;
  }

  static bool get isOverlayShowing => _isOverlayShowing;
}

