import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/pin_providers.dart';
import '../providers/lock_providers.dart';
import '../widgets/pin_input_widget.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String? _errorMessage;

  Future<void> _onPinEntered(String pin) async {
    setState(() {
      _errorMessage = null;
    });

    final pinNotifier = ref.read(pinStateProvider.notifier);
    final isValid = await pinNotifier.verifyPin(pin);

    if (!mounted) return;

    if (isValid) {
      setState(() {
        _errorMessage = null;
      });
      ref.read(lockStateProvider.notifier).unlock();
      Navigator.of(context).pushReplacementNamed(AppConstants.homeRoute);
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN. Please try again.';
      });
      HapticFeedback.vibrate();
    }
  }

  Future<void> _showForgotPinDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot PIN?'),
        content: const Text(
          'This will reset all app data including your PIN. You will need to set up a new PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final pinNotifier = ref.read(pinStateProvider.notifier);
      await pinNotifier.deletePin();

      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppConstants.pinSetupRoute, (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your PIN to continue',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 48),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              PinInputWidget(
                pinLength: AppConstants.pinLength,
                onPinComplete: _onPinEntered,
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: _showForgotPinDialog,
                child: const Text('Forgot PIN?'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
