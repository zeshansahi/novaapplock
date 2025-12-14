import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/providers.dart';
import '../../../services/secure_storage_service.dart';
import '../../../services/preferences_service.dart';

final pinStateProvider = StateNotifierProvider<PinNotifier, PinState>((ref) {
  return PinNotifier(
    ref.read(secureStorageProvider),
    ref.read(preferencesProvider),
  );
});

class PinState {
  final String? currentPin;
  final bool isLoading;
  final String? error;

  PinState({
    this.currentPin,
    this.isLoading = false,
    this.error,
  });

  PinState copyWith({
    String? currentPin,
    bool? isLoading,
    String? error,
  }) {
    return PinState(
      currentPin: currentPin ?? this.currentPin,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PinNotifier extends StateNotifier<PinState> {
  final SecureStorageService _secureStorage;
  final PreferencesService _preferences;

  PinNotifier(this._secureStorage, this._preferences) : super(PinState()) {
    _checkPin();
  }

  Future<void> _checkPin() async {
    state = state.copyWith(isLoading: true);
    try {
      final pin = await _secureStorage.getPin();
      state = state.copyWith(currentPin: pin, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<bool> hasPin() async {
    return await _secureStorage.hasPin();
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final storedPin = await _secureStorage.getPin();
      return storedPin == pin;
    } catch (e) {
      return false;
    }
  }

  Future<bool> setPin(String pin) async {
    try {
      await _secureStorage.savePin(pin);
      state = state.copyWith(currentPin: pin);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    try {
      final isValid = await verifyPin(oldPin);
      if (!isValid) {
        state = state.copyWith(error: 'Incorrect old PIN');
        return false;
      }
      await _secureStorage.savePin(newPin);
      state = state.copyWith(currentPin: newPin, error: null);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<void> deletePin() async {
    try {
      await _secureStorage.deletePin();
      await _preferences.resetAllData();
      state = state.copyWith(currentPin: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}



