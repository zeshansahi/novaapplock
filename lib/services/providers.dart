import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'secure_storage_service.dart';
import 'preferences_service.dart';
import 'installed_apps_service.dart';
import 'overlay_service.dart';
import 'usage_stats_service.dart';
import 'purchase_service.dart';
import 'biometric_service.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final preferencesProvider = Provider<PreferencesService>((ref) {
  return PreferencesService();
});

final installedAppsProvider = Provider<InstalledAppsService>((ref) {
  return InstalledAppsService();
});

final overlayServiceProvider = Provider<OverlayService>((ref) {
  return OverlayService();
});

// UsageStatsService is a static class, no provider needed

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final service = PurchaseService();
  ref.onDispose(() => service.dispose());
  return service;
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

