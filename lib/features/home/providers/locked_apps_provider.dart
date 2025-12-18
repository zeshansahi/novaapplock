import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/providers.dart';
import '../../../services/usage_stats_service.dart';
import '../../../services/purchase_service.dart';
import '../../../services/overlay_service.dart';

final lockedAppsProvider = StateNotifierProvider<LockedAppsNotifier, LockedAppsState>((ref) {
  return LockedAppsNotifier(
    ref.read(purchaseServiceProvider),
  );
});

class LockedAppsState {
  final List<String> lockedApps;
  final bool isLoading;
  final String? error;

  LockedAppsState({
    this.lockedApps = const [],
    this.isLoading = false,
    this.error,
  });

  LockedAppsState copyWith({
    List<String>? lockedApps,
    bool? isLoading,
    String? error,
  }) {
    return LockedAppsState(
      lockedApps: lockedApps ?? this.lockedApps,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class LockedAppsNotifier extends StateNotifier<LockedAppsState> {
  final PurchaseService _purchaseService;

  LockedAppsNotifier(this._purchaseService)
      : super(LockedAppsState()) {
    _loadLockedApps();
  }

  Future<void> _loadLockedApps() async {
    state = state.copyWith(isLoading: true);
    try {
      final apps = await UsageStatsService.getLockedApps();
      state = state.copyWith(lockedApps: apps, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<bool> addLockedApp(String packageName) async {
    try {
      final limit = await _purchaseService.getLockedAppsLimit();
      final currentCount = state.lockedApps.length;
      
      if (currentCount >= limit && !await _purchaseService.isPremium()) {
        state = state.copyWith(
          error: 'Free version allows up to $limit apps. Upgrade to Premium for unlimited.',
        );
        return false;
      }

      final success = await UsageStatsService.addLockedApp(packageName);
      if (success) {
        await _loadLockedApps();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> removeLockedApp(String packageName) async {
    try {
      final success = await UsageStatsService.removeLockedApp(packageName);
      if (success) {
        OverlayService.hideIfShowingFor(packageName);
        UsageStatsService.clearLockStateForPackage(packageName);
        await UsageStatsService.clearPendingLockForPackage(packageName);
        await _loadLockedApps();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> isAppLocked(String packageName) async {
    return await UsageStatsService.isAppLocked(packageName);
  }

  Future<void> refresh() async {
    await _loadLockedApps();
  }
}
