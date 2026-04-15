import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/station_purchase_service.dart';

/// Provider for the station purchase service singleton
final stationPurchaseServiceProvider = Provider<StationPurchaseService>((ref) {
  return StationPurchaseService();
});

/// Provider for the current station purchase state
final stationPurchaseStateProvider =
    StateNotifierProvider<StationPurchaseStateNotifier, StationPurchaseState>((ref) {
  final service = ref.watch(stationPurchaseServiceProvider);
  return StationPurchaseStateNotifier(service);
});

/// Notifier for station purchase state
class StationPurchaseStateNotifier extends StateNotifier<StationPurchaseState> {
  final StationPurchaseService _service;

  StationPurchaseStateNotifier(this._service) : super(const StationPurchaseState()) {
    _init();
  }

  Future<void> _init() async {
    await refresh();
  }

  /// Refresh purchase state from Supabase
  Future<void> refresh() async {
    state = await _service.getState();
  }

  /// Purchase a station slot and update state
  Future<bool> purchaseStationSlot() async {
    final success = await _service.purchaseStationSlot();
    if (success) {
      await refresh();
    }
    return success;
  }

  /// Restore purchases and update state
  Future<int> restorePurchases() async {
    final count = await _service.restorePurchases();
    await refresh();
    return count;
  }

  /// Identify user after login
  Future<void> identifyUser(String userId) async {
    await _service.identifyUser(userId);
    await refresh();
  }

  /// Log out
  Future<void> logOut() async {
    await _service.logOut();
    state = const StationPurchaseState();
  }
}

/// Provider to check if user can add more stations
/// Returns false while loading to prevent premature access
final canAddStationProvider = Provider.family<bool, int>((ref, activeStationCount) {
  final purchaseState = ref.watch(stationPurchaseStateProvider);
  if (purchaseState.isLoading) return false;
  return purchaseState.canAddStation(activeStationCount);
});
