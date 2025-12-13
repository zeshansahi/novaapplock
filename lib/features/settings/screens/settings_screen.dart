import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth_pin/providers/pin_providers.dart';
import '../../auth_pin/widgets/pin_input_widget.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isChangingPin = false;
  String? _errorMessage;

  Future<void> _changePin() async {
    setState(() {
      _isChangingPin = true;
      _errorMessage = null;
    });

    final oldPin = await _showPinDialog('Enter old PIN');
    if (oldPin == null) {
      setState(() {
        _isChangingPin = false;
      });
      return;
    }

    final pinNotifier = ref.read(pinStateProvider.notifier);
    final isValid = await pinNotifier.verifyPin(oldPin);

    if (!isValid) {
      setState(() {
        _errorMessage = 'Incorrect old PIN';
        _isChangingPin = false;
      });
      HapticFeedback.vibrate();
      return;
    }

    final newPin = await _showPinDialog('Enter new PIN');
    if (newPin == null) {
      setState(() {
        _isChangingPin = false;
      });
      return;
    }

    final confirmPin = await _showPinDialog('Confirm new PIN');
    if (confirmPin == null || confirmPin != newPin) {
      setState(() {
        _errorMessage = 'PINs do not match';
        _isChangingPin = false;
      });
      HapticFeedback.vibrate();
      return;
    }

    final success = await pinNotifier.changePin(oldPin, newPin);

    if (!mounted) return;

    setState(() {
      _isChangingPin = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN changed successfully')),
      );
    } else {
      setState(() {
        _errorMessage = 'Failed to change PIN';
      });
    }
  }

  Future<String?> _showPinDialog(String title) async {
    String? pin;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: StatefulBuilder(
          builder: (context, setState) {
            return PinInputWidget(
              pinLength: AppConstants.pinLength,
              onPinComplete: (enteredPin) {
                pin = enteredPin;
                Navigator.of(context).pop();
              },
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    return pin;
  }

  Future<void> _resetAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Data'),
        content: const Text(
          'This will delete all app data including your PIN and settings. You will need to set up the app again.',
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
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppConstants.pinSetupRoute,
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change PIN'),
            subtitle: const Text('Update your security PIN'),
            trailing: _isChangingPin
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isChangingPin ? null : _changePin,
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Reset All Data',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            subtitle: const Text('Delete all app data and settings'),
            onTap: _resetAllData,
          ),
        ],
      ),
    );
  }
}

