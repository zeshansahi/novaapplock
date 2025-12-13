import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'secure_storage_service.dart';
import 'preferences_service.dart';
import 'installed_apps_service.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final preferencesProvider = Provider<PreferencesService>((ref) {
  return PreferencesService();
});

final installedAppsProvider = Provider<InstalledAppsService>((ref) {
  return InstalledAppsService();
});

