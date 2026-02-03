import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/scan_history_service.dart';

/// Provider for SharedPreferences
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

/// Provider for ScanHistoryService
final scanHistoryServiceProvider = Provider<ScanHistoryService?>((ref) {
  final prefsAsync = ref.watch(sharedPreferencesProvider);
  return prefsAsync.maybeWhen(
    data: (prefs) => ScanHistoryService(prefs),
    orElse: () => null,
  );
});

/// Notifier for managing scan history state
class ScanHistoryNotifier extends StateNotifier<List<ScanHistoryItem>> {
  final ScanHistoryService? _service;

  ScanHistoryNotifier(this._service) : super([]) {
    _loadHistory();
  }

  void _loadHistory() {
    if (_service != null) {
      state = _service.getHistory();
    }
  }

  Future<void> addScan({
    required String qrId,
    required String equipmentName,
  }) async {
    if (_service == null) return;

    await _service.addScan(qrId: qrId, equipmentName: equipmentName);
    state = _service.getHistory();
  }

  Future<void> removeFromHistory(String qrId) async {
    if (_service == null) return;

    await _service.removeFromHistory(qrId);
    state = _service.getHistory();
  }

  Future<void> clearHistory() async {
    if (_service == null) return;

    await _service.clearHistory();
    state = [];
  }

  void refresh() {
    _loadHistory();
  }
}

/// Provider for scan history notifier
final scanHistoryNotifierProvider =
    StateNotifierProvider<ScanHistoryNotifier, List<ScanHistoryItem>>((ref) {
  final service = ref.watch(scanHistoryServiceProvider);
  return ScanHistoryNotifier(service);
});
