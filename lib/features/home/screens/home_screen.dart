import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/lock_providers.dart';
import '../providers/locked_apps_provider.dart';
import '../../auth_pin/providers/pin_providers.dart';
import '../../../services/providers.dart';
import '../../../services/permission_service.dart';
import '../../../services/usage_stats_service.dart';
import '../../../services/overlay_service.dart';
import '../../../widgets/permission_request_dialog.dart';
import '../widgets/debug_info_widget.dart';
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
    // Set up monitoring callback immediately
    _setupMonitoringCallback();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLockState();
      // Start monitoring if lock is already enabled
      _startMonitoringIfEnabled();
      // Delay permission check to ensure layout is complete
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkPermissions();
        }
      });
    });
  }

  Future<void> _startMonitoringIfEnabled() async {
    final lockState = ref.read(lockStateProvider);
    if (lockState.isLockEnabled) {
      final hasPermission = await PermissionService.isUsageStatsPermissionGranted();
      if (hasPermission) {
        print('🔄 Starting monitoring (lock already enabled)');
        UsageStatsService.startMonitoring();
      } else {
        print('⚠️ Cannot start monitoring - usage stats permission not granted');
      }
    }
  }

  Future<void> _checkPermissions() async {
    if (!mounted) return;
    
    // Wait for the widget tree to be fully built
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    
    final permissions = await PermissionService.checkAllPermissions();
    
    // Only show overlay permission dialog if not granted
    if (!permissions['overlay']! && mounted) {
      PermissionRequestDialog.show(
        context: context,
        permissionType: 'overlay',
        title: 'Overlay Permission Required',
        message: 'Nova App Lock needs permission to display over other apps to show the lock screen when a locked app is opened.',
        onGranted: () {
          // After overlay permission, check usage stats
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              _checkUsageStatsPermission();
            }
          });
        },
        onDenied: () {
          // Even if denied, check usage stats
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              _checkUsageStatsPermission();
            }
          });
        },
      );
    } else {
      // If overlay is granted, check usage stats
      _checkUsageStatsPermission();
    }
  }

  Future<void> _checkUsageStatsPermission() async {
    if (!mounted) return;
    
    final permissions = await PermissionService.checkAllPermissions();
    if (!permissions['usageStats']! && mounted) {
      PermissionRequestDialog.show(
        context: context,
        permissionType: 'usageStats',
        title: 'Usage Access Permission Required',
        message: 'Nova App Lock needs usage access permission to detect when locked apps are opened.',
        onGranted: () {
          // After usage stats, show auto start dialog
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) _showAutoStartDialog();
          });
        },
        onDenied: () {
          // Even if denied, show auto start dialog
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) _showAutoStartDialog();
          });
        },
      );
    } else {
      // If usage stats already granted, show auto start dialog
      _showAutoStartDialog();
    }
  }
  
  Future<void> _showAutoStartDialog() async {
    if (!mounted) return;
    
    // Show dialog for auto start
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Background Running Required'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'For app lock to work when the app is closed, please enable:',
            ),
            SizedBox(height: 12),
            Text('• Auto Start permission'),
            Text('• Disable Battery Optimization'),
            SizedBox(height: 12),
            Text(
              'This ensures the app stays active in background to protect your locked apps.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                const channel = MethodChannel('com.example.novaapplock/overlay');
                await channel.invokeMethod('openAutoStartSettings');
              } catch (e) {
                debugPrint('Error opening auto-start settings: $e');
              }
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _setupMonitoringCallback() {
    // Set up the callback for locked app detection
    UsageStatsService.onLockedAppDetected = (packageName, appName) {
      print('🔒 Locked app detected from home screen: $packageName');
      
      // Don't lock our own app
      if (packageName == 'com.example.novaapplock') {
        return;
      }
      
      final lockState = ref.read(lockStateProvider);
      if (lockState.isLockEnabled) {
        print('🔒 Showing overlay for: $packageName');
        // DON'T call lock() here - avoids triggering internal app lock
        OverlayService.showLockOverlay(
          packageName: packageName,
          appName: appName,
          onUnlock: () {
            print('🔓 Overlay unlocked');
            OverlayService.hideLockOverlay();
          },
        );
      }
    };
  }

  Future<List<Application>> _getLockedAppsDetails(List<String> packageNames) async {
    final installedAppsService = ref.read(installedAppsProvider);
    final allApps = await installedAppsService.getInstalledApps();
    return allApps.where((app) => packageNames.contains(app.packageName)).toList();
  }

  void _checkLockState() {
    final lockState = ref.read(lockStateProvider);
    final pinNotifier = ref.read(pinStateProvider.notifier);
    
    // Don't navigate to internal lock screen if overlay is already showing
    // This prevents conflict when lock_overlay_screen is displayed for locked apps
    if (OverlayService.isOverlayShowing) {
      print('⚠️ Overlay is showing, skipping internal lock navigation');
      return;
    }
    
    // Check if lock is enabled and we need to show lock screen
    if (lockState.isLockEnabled && lockState.isLocked) {
      pinNotifier.hasPin().then((hasPin) {
        if (hasPin) {
          // Double-check overlay isn't showing now
          if (!OverlayService.isOverlayShowing) {
            final navigator = Navigator.of(context);
            if (mounted) {
              navigator.pushReplacementNamed(AppConstants.lockRoute);
            }
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
                              if (value) {
                                // Check permissions before enabling
                                final permissions = await PermissionService.checkAllPermissions();
                                if (!permissions['overlay']! || !permissions['usageStats']!) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please grant all required permissions to enable app locking'),
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                    await _checkPermissions();
                                  }
                                  return;
                                }
                              }
                              
                              await lockNotifier.setLockEnabled(value);
                              
                              // Start monitoring when enabling
                              if (value) {
                                // Ensure callback is set up
                                _setupMonitoringCallback();
                                
                                final hasPermission = await PermissionService.isUsageStatsPermissionGranted();
                                if (hasPermission) {
                                  print('Starting monitoring from home screen toggle');
                                  UsageStatsService.startMonitoring();
                                } else {
                                  print('Usage stats permission not granted, cannot start monitoring');
                                }
                                
                                if (mounted) {
                                  // Lock immediately if enabling
                                  lockNotifier.lock();
                                  Navigator.of(context).pushReplacementNamed(AppConstants.lockRoute);
                                }
                              } else {
                                // Stop monitoring when disabling
                                print('Stopping monitoring - app lock disabled');
                                UsageStatsService.stopMonitoring();
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              'Locked Apps',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Flexible(
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    if (mounted) {
                                      Navigator.of(context).pushNamed(AppConstants.installedAppsRoute);
                                    }
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Apps'),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    if (mounted) {
                                      Navigator.of(context).pushNamed(AppConstants.premiumRoute);
                                    }
                                  },
                                  icon: const Icon(Icons.star),
                                  label: const Text('Premium'),
                                ),
                              ],
                            ),
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
                                        : const Icon(Icons.android, size: 40),
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
              const SizedBox(height: 16),
              // Debug widget - remove in production
              const DebugInfoWidget(),
            ],
          ),
        ),
      ),
    );
  }
}
