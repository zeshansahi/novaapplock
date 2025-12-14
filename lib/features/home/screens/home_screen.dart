import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/lock_providers.dart';
import '../providers/locked_apps_provider.dart';
import '../../auth_pin/providers/pin_providers.dart';
import '../../../services/providers.dart';
import 'package:device_apps/device_apps.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLockState();
    });
  }

  Future<List<Application>> _getLockedAppsDetails(List<String> packageNames) async {
    final installedAppsService = ref.read(installedAppsProvider);
    final allApps = await installedAppsService.getInstalledApps();
    return allApps.where((app) => packageNames.contains(app.packageName)).toList();
  }

  void _checkLockState() {
    final lockState = ref.read(lockStateProvider);
    final pinNotifier = ref.read(pinStateProvider.notifier);
    
    // Check if lock is enabled and we need to show lock screen
    if (lockState.isLockEnabled && lockState.isLocked) {
      pinNotifier.hasPin().then((hasPin) {
        if (hasPin) {
          final navigator = Navigator.of(context);
          if (mounted) {
            navigator.pushReplacementNamed(AppConstants.lockRoute);
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(lockStateProvider);
    final lockNotifier = ref.read(lockStateProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).pushNamed(AppConstants.settingsRoute);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'App Lock',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                lockState.isLockEnabled
                                    ? 'Your app is protected'
                                    : 'App lock is disabled',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                              ),
                            ],
                          ),
                          Switch(
                            value: lockState.isLockEnabled,
                            onChanged: (value) async {
                              await lockNotifier.setLockEnabled(value);
                              if (value && mounted) {
                                // Lock immediately if enabling
                                lockNotifier.lock();
                                Navigator.of(context).pushReplacementNamed(AppConstants.lockRoute);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Locked Apps',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushNamed(AppConstants.installedAppsRoute);
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Apps'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Consumer(
                        builder: (context, ref, child) {
                          final lockedAppsState = ref.watch(lockedAppsProvider);
                          
                          if (lockedAppsState.isLoading) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          
                          if (lockedAppsState.lockedApps.isEmpty) {
                            return Text(
                              'No apps locked. Tap "Add Apps" to select apps to lock.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                            );
                          }
                          
                          if (lockedAppsState.error != null) {
                            return Text(
                              lockedAppsState.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                          
                          return FutureBuilder<List<Application>>(
                            future: _getLockedAppsDetails(lockedAppsState.lockedApps),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              
                              final apps = snapshot.data!;
                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: apps.length,
                                itemBuilder: (context, index) {
                                  final app = apps[index];
                                  return ListTile(
                                    leading: app is ApplicationWithIcon
                                        ? Image.memory(
                                            (app as ApplicationWithIcon).icon,
                                            width: 40,
                                            height: 40,
                                          )
                                        : const Icon(Icons.android),
                                    title: Text(app.appName),
                                    subtitle: Text(app.packageName),
                                    trailing: Switch(
                                      value: true,
                                      onChanged: (value) async {
                                        final notifier = ref.read(lockedAppsProvider.notifier);
                                        await notifier.removeLockedApp(app.packageName);
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(AppConstants.installedAppsRoute);
                },
                icon: const Icon(Icons.apps),
                label: const Text('Installed Apps'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

