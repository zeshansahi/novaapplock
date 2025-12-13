import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth_pin/screens/pin_setup_screen.dart';
import 'features/auth_pin/screens/lock_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/installed_apps/screens/installed_apps_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/auth_pin/providers/lock_providers.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  void _onAppResumed() {
    // Check if lock is enabled and app should be locked
    final lockState = ref.read(lockStateProvider);
    if (lockState.isLockEnabled && !lockState.isLocked) {
      // Lock the app when returning from background
      ref.read(lockStateProvider.notifier).lock();
      
      // Navigate to lock screen if not already there
      final navigator = Navigator.of(context);
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      },
    );
  }
}
