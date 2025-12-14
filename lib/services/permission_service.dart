import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class PermissionService {
  static const MethodChannel _channel = MethodChannel('com.example.novaapplock/usage_stats');

  /// Check if overlay permission is granted
  static Future<bool> isOverlayPermissionGranted() async {
    return await Permission.systemAlertWindow.isGranted;
  }

  /// Request overlay permission
  static Future<bool> requestOverlayPermission() async {
    if (await isOverlayPermissionGranted()) {
      return true;
    }
    return await Permission.systemAlertWindow.request().isGranted;
  }

  /// Check if usage stats permission is granted
  static Future<bool> isUsageStatsPermissionGranted() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkUsageStatsPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Request usage stats permission
  static Future<void> requestUsageStatsPermission() async {
    try {
      await _channel.invokeMethod('requestUsageStatsPermission');
    } catch (e) {
      // Handle error
    }
  }

  /// Open usage stats settings
  static Future<void> openUsageStatsSettings() async {
    try {
      await _channel.invokeMethod('openUsageStatsSettings');
    } catch (e) {
      // Handle error
    }
  }

  /// Open overlay settings
  static Future<void> openOverlaySettings() async {
    await openAppSettings();
  }

  /// Check all required permissions
  static Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'overlay': await isOverlayPermissionGranted(),
      'usageStats': await isUsageStatsPermissionGranted(),
    };
  }

  /// Request all required permissions
  static Future<Map<String, bool>> requestAllPermissions() async {
    final overlayGranted = await requestOverlayPermission();
    await requestUsageStatsPermission();
    
    // Wait a bit for user to grant usage stats permission
    await Future.delayed(const Duration(seconds: 1));
    final usageStatsGranted = await isUsageStatsPermissionGranted();
    
    return {
      'overlay': overlayGranted,
      'usageStats': usageStatsGranted,
    };
  }
}

