import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_apps/device_apps.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/usage_stats_service.dart';
import '../providers/pin_providers.dart';
import '../providers/lock_providers.dart';
import '../../../services/biometric_service.dart';
import '../../../services/providers.dart';
import '../widgets/pin_input_widget.dart';

class LockOverlayScreen extends ConsumerStatefulWidget {
  final String packageName;
  final String appName;
  final VoidCallback onUnlock;

  const LockOverlayScreen({
    super.key,
    required this.packageName,
    required this.appName,
    required this.onUnlock,
  });

  @override
  ConsumerState<LockOverlayScreen> createState() => _LockOverlayScreenState();
}

class _LockOverlayScreenState extends ConsumerState<LockOverlayScreen> {
  String? _errorMessage;
  int _failedAttempts = 0;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _tryBiometricAuth();
  }

  Future<void> _tryBiometricAuth() async {
    final biometricService = ref.read(biometricServiceProvider);
    final isEnabled = await biometricService.isBiometricEnabled();
    
    if (!isEnabled || _isAuthenticating) return;
    
    setState(() {
      _isAuthenticating = true;
    });

    final success = await biometricService.authenticate(
      reason: 'Unlock ${widget.appName}',
    );

    if (!mounted) return;

    setState(() {
      _isAuthenticating = false;
    });

    if (success) {
      _unlock();
    }
  }

  Future<void> _onPinEntered(String pin) async {
    setState(() {
      _errorMessage = null;
    });

    final pinNotifier = ref.read(pinStateProvider.notifier);
    final isValid = await pinNotifier.verifyPin(pin);

    if (!mounted) return;

    if (isValid) {
      setState(() {
        _failedAttempts = 0;
        _errorMessage = null;
      });
      _unlock();
    } else {
      setState(() {
        _failedAttempts++;
        _errorMessage = 'Incorrect PIN. Please try again.';
      });
      HapticFeedback.vibrate();
      
      // Check for fake crash after 3 failed attempts
      if (_failedAttempts >= 3) {
        _handleFakeCrash();
      }
    }
  }

  void _unlock() {
    ref.read(lockStateProvider.notifier).unlock();
    UsageStatsService.markUnlocked(widget.packageName);
    // Launch the originally locked app after successful unlock
    if (widget.packageName.isNotEmpty) {
      Future.microtask(() async {
        bool launched = false;
        // Prefer native launch via platform channel for reliability
        try {
          launched = await const MethodChannel('com.example.novaapplock/overlay')
                  .invokeMethod<bool>('openApp', {'packageName': widget.packageName}) ??
              false;
        } catch (_) {}

        // Fallback to device_apps if native launch fails
        if (!launched) {
          launched = await DeviceApps.openApp(widget.packageName);
        }

        // Small delay then push Nova to background to avoid black screen
        Future.delayed(const Duration(milliseconds: 200), () {
          const MethodChannel('com.example.novaapplock/overlay')
              .invokeMethod<bool>('moveToBackground')
              .catchError((_) {});
          Navigator.of(context, rootNavigator: true).maybePop();
        });
      });
    }
    widget.onUnlock();
  }

  Future<void> _handleFakeCrash() async {
    final purchaseService = ref.read(purchaseServiceProvider);
    final isPremium = await purchaseService.isPremium();
    
    if (isPremium) {
      // Take intruder selfie
      // TODO: Implement intruder selfie feature
    }
    
    // Show fake crash screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => FakeCrashScreen(
            onRestart: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back button
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 32),
                Text(
                  widget.appName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This app is locked',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 48),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                PinInputWidget(
                  pinLength: AppConstants.pinLength,
                  onPinComplete: _onPinEntered,
                ),
                const SizedBox(height: 32),
                if (!_isAuthenticating)
                  TextButton.icon(
                    onPressed: _tryBiometricAuth,
                    icon: const Icon(Icons.fingerprint, color: Colors.white),
                    label: const Text(
                      'Use Biometric',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                if (_isAuthenticating)
                  const CircularProgressIndicator(
                    color: Colors.white,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FakeCrashScreen extends StatelessWidget {
  final VoidCallback onRestart;

  const FakeCrashScreen({
    super.key,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 32),
            const Text(
              'App Crashed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'The application has encountered an unexpected error and needs to restart.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: onRestart,
              child: const Text('Restart App'),
            ),
          ],
        ),
      ),
    );
  }
}
