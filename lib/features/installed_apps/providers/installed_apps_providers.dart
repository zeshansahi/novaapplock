import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_apps/device_apps.dart';
import '../../../services/providers.dart';

final installedAppsListProvider = FutureProvider<List<Application>>((ref) async {
  final service = ref.read(installedAppsProvider);
  return await service.getInstalledApps(
    includeSystemApps: false,
    onlyAppsWithLaunchIntent: true,
  );
});

// Filtered apps provider
final filteredAppsProvider = Provider.family<AsyncValue<List<Application>>, String>((ref, query) {
  final appsAsync = ref.watch(installedAppsListProvider);
  
  return appsAsync.when(
    data: (apps) {
      if (query.isEmpty) {
        return AsyncValue.data(apps);
      }
      final lowerQuery = query.toLowerCase();
      final filtered = apps.where((app) {
        return app.appName.toLowerCase().contains(lowerQuery) ||
            app.packageName.toLowerCase().contains(lowerQuery);
      }).toList()
        ..sort((a, b) => a.appName.compareTo(b.appName));
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

