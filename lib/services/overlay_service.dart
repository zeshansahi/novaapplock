import 'package:overlay_support/overlay_support.dart';
import 'package:flutter/material.dart';
import '../features/auth_pin/screens/lock_overlay_screen.dart';

class OverlayService {
  static bool _isOverlayShowing = false;
  static OverlaySupportEntry? _currentOverlay;

  /// Show the lock screen overlay
  static void showLockOverlay({
    required String packageName,
    required String appName,
    required VoidCallback onUnlock,
  }) {
    if (_isOverlayShowing) return;

    _isOverlayShowing = true;
    
    _currentOverlay = showOverlay(
      (context, t) => LockOverlayScreen(
        packageName: packageName,
        appName: appName,
        onUnlock: () {
          _isOverlayShowing = false;
          onUnlock();
          _currentOverlay?.dismiss();
          _currentOverlay = null;
        },
      ),
      duration: Duration.zero, // Show until dismissed
    );
  }

  /// Hide the lock screen overlay
  static void hideLockOverlay() {
    if (!_isOverlayShowing) return;
    _isOverlayShowing = false;
    _currentOverlay?.dismiss();
    _currentOverlay = null;
  }

  static bool get isOverlayShowing => _isOverlayShowing;
}

