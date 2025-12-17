import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:overlay_support/overlay_support.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'features/auth_pin/screens/lock_overlay_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth_pin/screens/pin_setup_screen.dart';
import 'features/auth_pin/screens/lock_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/installed_apps/screens/installed_apps_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/premium/screens/premium_screen.dart';
import 'features/auth_pin/providers/lock_providers.dart' as lock;
import 'services/providers.dart';
import 'services/usage_stats_service.dart';
import 'services/overlay_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(
    const ProviderScope(
      child: NovaAppLockApp(),
    ),
  );
}

class NovaAppLockApp extends ConsumerStatefulWidget {
  const NovaAppLockApp({super.key});

  @override
  ConsumerState<NovaAppLockApp> createState() => _NovaAppLockAppState();
}

class _NovaAppLockAppState extends ConsumerState<NovaAppLockApp>
    with WidgetsBindingObserver {
  ProviderSubscription<lock.LockState>? _lockStateSubscription;
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  bool _pendingLockChecked = false;
  bool _showingPendingLock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _lockStateSubscription = ref.listenManual<lock.LockState>(
      lock.lockStateProvider,
      (previous, next) {
        final wasEnabled = previous?.isLockEnabled ?? false;
        final isEnabled = next.isLockEnabled;
        final wasLoading = previous?.isLoading ?? true;
        final isLoading = next.isLoading;

        // When lock state finishes loading, check for pending lock
        if (wasLoading && !isLoading && !_pendingLockChecked) {
          _pendingLockChecked = true;
          _checkPendingLockViaChannel();
        }

        if (!wasEnabled && isEnabled) {
          _startMonitoringIfPermitted();
        } else if (wasEnabled && !isEnabled) {
          UsageStatsService.stopMonitoring();
        }
      },
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUsageStats();
      // Also try checking pending lock after first frame
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_pendingLockChecked) {
          _pendingLockChecked = true;
          _checkPendingLockViaChannel();
        }
      });
    });
  }

  @override
  void dispose() {
    OverlayService.hideLockOverlay();
    _lockStateSubscription?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _startMonitoringIfPermitted();
      _checkPendingLockViaChannel();
    }
  }

  void _initializeUsageStats() {
    print('Initializing usage stats monitoring');
    
    UsageStatsService.onLockedAppDetected = (packageName, appName) {
      print('Locked app detected callback: $packageName');
      
      if (packageName == 'com.example.novaapplock') {
        return;
      }
      
      final lockState = ref.read(lock.lockStateProvider);
      if (lockState.isLockEnabled) {
        UsageStatsService.setOverlayActive(true);
        OverlayService.showLockOverlay(
          packageName: packageName,
          appName: appName,
          onUnlock: () {
            OverlayService.hideLockOverlay();
            UsageStatsService.setOverlayActive(false);
          },
        );
      }
    };
    
    _startMonitoringIfPermitted();
  }

  Future<void> _startMonitoringIfPermitted() async {
    final hasPermission = await UsageStatsService.isPermissionGranted();
    if (hasPermission) {
      final lockState = ref.read(lock.lockStateProvider);
      if (lockState.isLockEnabled) {
        UsageStatsService.startMonitoring();
      }
    }
  }
  
  Future<void> _checkPendingLockViaChannel() async {
    if (_showingPendingLock) return;
    
    try {
      const channel = MethodChannel('com.example.novaapplock/overlay');
      final result = await channel.invokeMethod<dynamic>('getPendingLock');
      
      if (result != null && result is Map) {
        final packageName = result['packageName'] as String?;
        final appName = (result['appName'] as String?) ?? 'App';
        
        if (packageName != null && packageName.isNotEmpty) {
          print('🔒 Pending lock found via channel: $packageName');
          
          final lockState = ref.read(lock.lockStateProvider);
          if (lockState.isLockEnabled || !lockState.isLoading) {
            _showingPendingLock = true;
            // DON'T call lock() here - that's for internal app lock only
            // External app locks use overlay without affecting internal state
            
            // Wait for navigator to be ready
            await Future.delayed(const Duration(milliseconds: 200));
            
            if (mounted && _navKey.currentState != null) {
              _navKey.currentState!.push(
                MaterialPageRoute(
                  builder: (context) => LockOverlayScreen(
                    packageName: packageName,
                    appName: appName,
                    onUnlock: () {
                      // SystemNavigator.pop() minimizes app to reveal locked app
                      // SystemNavigator.pop() minimizes app to reveal locked app
                      SystemNavigator.pop();
                      _showingPendingLock = false;
                    },
                  ),
                  fullscreenDialog: true,
                ),
              );
            } else {
              // Fallback to overlay
              OverlayService.showLockOverlay(
                packageName: packageName,
                appName: appName,
                onUnlock: () {
                  OverlayService.hideLockOverlay();
                  _showingPendingLock = false;
                },
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error checking pending lock via channel: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return OverlaySupport.global(
      child: MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        navigatorKey: _navKey,
        debugShowCheckedModeBanner: false,
        initialRoute: AppConstants.splashRoute,
        routes: {
          AppConstants.splashRoute: (context) => const SplashScreen(),
          AppConstants.pinSetupRoute: (context) => const PinSetupScreen(),
          AppConstants.lockRoute: (context) => const LockScreen(),
          AppConstants.homeRoute: (context) => const HomeScreen(),
          AppConstants.installedAppsRoute: (context) => const InstalledAppsScreen(),
          AppConstants.settingsRoute: (context) => const SettingsScreen(),
          AppConstants.premiumRoute: (context) => const PremiumScreen(),
        },
      ),
    );
  }
}
