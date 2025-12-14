import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:overlay_support/overlay_support.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth_pin/screens/pin_setup_screen.dart';
import 'features/auth_pin/screens/lock_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/installed_apps/screens/installed_apps_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/premium/screens/premium_screen.dart';
import 'features/auth_pin/providers/lock_providers.dart';
import 'services/providers.dart';
import 'services/usage_stats_service.dart';
import 'services/overlay_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
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
  StreamSubscription? _unlockSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize usage stats monitoring after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUsageStats();
      _setupUnlockListener();
    });
  }
  
  void _setupUnlockListener() {
    // Listen for unlock events from native overlay
    const platform = MethodChannel('com.example.novaapplock/overlay');
    // Note: This would need a proper event channel for real-time updates
    // For now, the unlock is handled in the native service
  }

  @override
  void dispose() {
    _unlockSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
      // Restart monitoring when app resumes
      _startMonitoringIfPermitted();
    } else if (state == AppLifecycleState.paused) {
      // Don't stop monitoring - we need it to work in background
      // _stopUsageStats();
    }
  }

  void _initializeUsageStats() {
    print('Initializing usage stats monitoring');
    
    // Set up callback for when locked app is detected
    UsageStatsService.onLockedAppDetected = (packageName, appName) {
      print('Locked app detected callback: $packageName');
      
      // Don't lock our own app
      if (packageName == 'com.example.novaapplock') {
        print('Skipping our own app');
        return;
      }
      
      final lockState = ref.read(lockStateProvider);
      print('Lock state - enabled: ${lockState.isLockEnabled}');
      
      if (lockState.isLockEnabled) {
        print('Showing overlay for locked app: $packageName');
        // Use a post-frame callback to ensure overlay can be shown
        WidgetsBinding.instance.addPostFrameCallback((_) {
          OverlayService.showLockOverlay(
            packageName: packageName,
            appName: appName,
            onUnlock: () {
              print('Overlay unlocked, hiding');
              // App unlocked - hide overlay
              OverlayService.hideLockOverlay();
            },
          );
        });
      } else {
        print('App lock is not enabled, skipping overlay');
      }
    };
    
    // Check permission and start monitoring
    _startMonitoringIfPermitted();
  }

  Future<void> _startMonitoringIfPermitted() async {
    final hasPermission = await UsageStatsService.isPermissionGranted();
    print('Usage stats permission granted: $hasPermission');
    
    if (hasPermission) {
      final lockState = ref.read(lockStateProvider);
      if (lockState.isLockEnabled) {
        print('Starting usage stats monitoring');
        UsageStatsService.startMonitoring();
      } else {
        print('App lock not enabled, not starting monitoring');
      }
    } else {
      print('Usage stats permission not granted, will retry');
      // Retry after a delay in case permission was just granted
      Future.delayed(const Duration(seconds: 2), () {
        _startMonitoringIfPermitted();
      });
    }
  }

  void _stopUsageStats() {
    UsageStatsService.stopMonitoring();
  }

  void _onAppResumed() {
    // Check if lock is enabled and app should be locked
    final lockState = ref.read(lockStateProvider);
    if (lockState.isLockEnabled && !lockState.isLocked) {
      // Lock the app when returning from background
      ref.read(lockStateProvider.notifier).lock();
      
      // Use a post-frame callback to ensure Navigator is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        
        final navigator = Navigator.maybeOf(context);
        if (navigator != null) {
          // Check current route
          final currentRoute = ModalRoute.of(context);
          if (currentRoute?.settings.name != AppConstants.lockRoute) {
            if (navigator.canPop()) {
              navigator.pushNamedAndRemoveUntil(
                AppConstants.lockRoute,
                (route) => route.settings.name == AppConstants.lockRoute,
              );
            } else {
              navigator.pushReplacementNamed(AppConstants.lockRoute);
            }
          }
        }
      });
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
