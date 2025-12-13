import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/lock_providers.dart';
import '../../auth_pin/providers/pin_providers.dart';

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
                      Text(
                        'Locked Apps',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Coming soon',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                      ),
                      const SizedBox(height: 8),
                      // TODO: Integrate real app lock engine here
                      // This will show the list of locked apps when implemented
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

