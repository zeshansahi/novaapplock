import 'package:device_apps/device_apps.dart';

class InstalledAppsService {
  Future<List<Application>> getInstalledApps({
    bool includeSystemApps = false,
    bool onlyAppsWithLaunchIntent = true,
  }) async {
    try {
      final apps = await DeviceApps.getInstalledApplications(
        includeSystemApps: includeSystemApps,
        onlyAppsWithLaunchIntent: onlyAppsWithLaunchIntent,
        includeAppIcons: true,
      );
      return apps;
    } catch (e) {
      throw Exception('Failed to get installed apps: $e');
    }
  }

  Future<Application?> getApp(String packageName) async {
    try {
      return await DeviceApps.getApp(packageName, true);
    } catch (e) {
      return null;
    }
  }
}

