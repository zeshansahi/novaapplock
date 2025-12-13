import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/pin_providers.dart';
import '../widgets/pin_input_widget.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _pin = '';
  bool _isConfirming = false;
  String? _errorMessage;

  void _onPinEntered(String pin) {
    setState(() {
      _errorMessage = null;
    });

    if (!_isConfirming) {
      setState(() {
        _pin = pin;
        _isConfirming = true;
      });
    } else {
      if (pin == _pin) {
        _savePin(pin);
      } else {
        setState(() {
          _errorMessage = 'PINs do not match. Please try again.';
          _pin = '';
          _isConfirming = false;
        });
        HapticFeedback.vibrate();
      }
    }
  }

  Future<void> _savePin(String pin) async {
    final pinNotifier = ref.read(pinStateProvider.notifier);
    final success = await pinNotifier.setPin(pin);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacementNamed(AppConstants.homeRoute);
    } else {
      setState(() {
        _errorMessage = 'Failed to save PIN. Please try again.';
        _pin = '';
        _isConfirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup PIN'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 32),
              Text(
                _isConfirming ? 'Confirm PIN' : 'Create PIN',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming
                    ? 'Enter your PIN again to confirm'
                    : 'Enter a 4-digit PIN to secure your app',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                textAlign: TextAlign.center,
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
            ],
          ),
        ),
      ),
    );
  }
}

