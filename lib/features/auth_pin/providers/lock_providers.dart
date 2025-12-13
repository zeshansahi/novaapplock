import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/providers.dart';
import '../../../services/preferences_service.dart';

final lockStateProvider = StateNotifierProvider<LockNotifier, LockState>((ref) {
  return LockNotifier(ref.read(preferencesProvider));
});

class LockState {
  final bool isLockEnabled;
  final bool isLocked;
  final bool isLoading;

  LockState({
    this.isLockEnabled = false,
    this.isLocked = false,
    this.isLoading = false,
  });

  LockState copyWith({
    bool? isLockEnabled,
    bool? isLocked,
    bool? isLoading,
  }) {
    return LockState(
      isLockEnabled: isLockEnabled ?? this.isLockEnabled,
      isLocked: isLocked ?? this.isLocked,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class LockNotifier extends StateNotifier<LockState> {
  final PreferencesService _preferences;

  LockNotifier(this._preferences) : super(LockState()) {
    _loadLockState();
  }

  Future<void> _loadLockState() async {
    state = state.copyWith(isLoading: true);
    try {
      final enabled = await _preferences.isLockEnabled();
      state = state.copyWith(
        isLockEnabled: enabled,
        isLocked: enabled,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> setLockEnabled(bool enabled) async {
    try {
      await _preferences.setLockEnabled(enabled);
      state = state.copyWith(
        isLockEnabled: enabled,
        isLocked: enabled,
      );
    } catch (e) {
      // Handle error
    }
  }

  void unlock() {
    if (state.isLockEnabled) {
      state = state.copyWith(isLocked: false);
    }
  }

  void lock() {
    if (state.isLockEnabled) {
      state = state.copyWith(isLocked: true);
    }
  }
}

