import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_apps/device_apps.dart';
import '../providers/installed_apps_providers.dart';
import '../widgets/app_details_bottom_sheet.dart';
import '../../home/providers/locked_apps_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/providers.dart';
import '../../../services/purchase_service.dart';
import '../../../services/usage_stats_service.dart';

class InstalledAppsScreen extends ConsumerStatefulWidget {
  const InstalledAppsScreen({super.key});

  @override
  ConsumerState<InstalledAppsScreen> createState() => _InstalledAppsScreenState();
}

class _InstalledAppsScreenState extends ConsumerState<InstalledAppsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Future<bool> _canLockApp(WidgetRef ref, String packageName) async {
    final purchaseService = ref.read(purchaseServiceProvider);
    final lockedAppsState = ref.read(lockedAppsProvider);
    final isPremium = await purchaseService.isPremium();
    
    if (isPremium) return true;
    
    final limit = await purchaseService.getLockedAppsLimit();
    final currentCount = lockedAppsState.lockedApps.length;
    final isAlreadyLocked = lockedAppsState.lockedApps.contains(packageName);
    
    return isAlreadyLocked || currentCount < limit;
  }

  void _showPremiumDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upgrade to Premium'),
        content: const Text(
          'Free version allows locking up to 3 apps. Upgrade to Premium for unlimited app locking and additional features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed(AppConstants.premiumRoute);
                    },
                    child: const Text('Upgrade'),
                  ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(filteredAppsProvider(_searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Installed Apps'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search apps...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: appsAsync.when(
              data: (apps) {
                if (apps.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No apps found'
                          : 'No apps match your search',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    return ListTile(
                      leading: app is ApplicationWithIcon
                          ? Image.memory(
                              (app as ApplicationWithIcon).icon,
                              width: 48,
                              height: 48,
                            )
                          : const Icon(Icons.android, size: 48),
                      title: Text(app.appName),
                      subtitle: Text(
                        app.packageName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Consumer(
                        builder: (context, ref, child) {
                          final lockedAppsState = ref.watch(lockedAppsProvider);
                          final isLocked = lockedAppsState.lockedApps.contains(app.packageName);
                          
                          return FutureBuilder<bool>(
                            future: _canLockApp(ref, app.packageName),
                            builder: (context, snapshot) {
                              final canLock = snapshot.data ?? true;
                              
                              return Switch(
                                value: isLocked,
                                onChanged: canLock
                                    ? (value) async {
                                        final notifier = ref.read(lockedAppsProvider.notifier);
                                        if (value) {
                                          final success = await notifier.addLockedApp(app.packageName);
                                          if (!success && mounted) {
                                            _showPremiumDialog(context, ref);
                                          }
                                        } else {
                                          await notifier.removeLockedApp(app.packageName);
                                        }
                                      }
                                    : null,
                              );
                            },
                          );
                        },
                      ),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => AppDetailsBottomSheet(app: app),
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading apps',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(installedAppsListProvider);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

