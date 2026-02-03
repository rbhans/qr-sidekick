import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A record of a scanned equipment item
class ScanHistoryItem {
  final String qrId;
  final String equipmentName;
  final DateTime scannedAt;

  ScanHistoryItem({
    required this.qrId,
    required this.equipmentName,
    required this.scannedAt,
  });

  Map<String, dynamic> toJson() => {
        'qrId': qrId,
        'equipmentName': equipmentName,
        'scannedAt': scannedAt.toIso8601String(),
      };

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) => ScanHistoryItem(
        qrId: json['qrId'] as String,
        equipmentName: json['equipmentName'] as String,
        scannedAt: DateTime.parse(json['scannedAt'] as String),
      );
}

/// Service for managing scan history in local storage
class ScanHistoryService {
  static const _historyKey = 'scan_history';
  static const _maxHistoryItems = 50;

  final SharedPreferences _prefs;

  ScanHistoryService(this._prefs);

  /// Get all scan history items, most recent first
  List<ScanHistoryItem> getHistory() {
    final historyJson = _prefs.getString(_historyKey);
    if (historyJson == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(historyJson);
      return decoded
          .map((item) => ScanHistoryItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Add a scan to history (or update if already exists)
  Future<void> addScan({
    required String qrId,
    required String equipmentName,
  }) async {
    final history = getHistory();

    // Remove existing entry for this qrId if present
    history.removeWhere((item) => item.qrId == qrId);

    // Add new entry at the beginning
    history.insert(
      0,
      ScanHistoryItem(
        qrId: qrId,
        equipmentName: equipmentName,
        scannedAt: DateTime.now(),
      ),
    );

    // Trim to max size
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }

    // Save to storage
    final historyJson = jsonEncode(history.map((item) => item.toJson()).toList());
    await _prefs.setString(_historyKey, historyJson);
  }

  /// Remove a specific item from history
  Future<void> removeFromHistory(String qrId) async {
    final history = getHistory();
    history.removeWhere((item) => item.qrId == qrId);

    final historyJson = jsonEncode(history.map((item) => item.toJson()).toList());
    await _prefs.setString(_historyKey, historyJson);
  }

  /// Clear all scan history
  Future<void> clearHistory() async {
    await _prefs.remove(_historyKey);
  }
}
