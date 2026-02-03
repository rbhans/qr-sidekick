import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'equipment_config.freezed.dart';
part 'equipment_config.g.dart';

/// Individual note entry with date
@freezed
class NoteEntry with _$NoteEntry {
  const factory NoteEntry({
    required String id,
    required DateTime createdAt,
    required String content,
    String? createdBy,
  }) = _NoteEntry;

  factory NoteEntry.fromJson(Map<String, dynamic> json) =>
      _$NoteEntryFromJson(json);

  factory NoteEntry.create({required String content, String? createdBy}) {
    return NoteEntry(
      id: const Uuid().v4(),
      createdAt: DateTime.now(),
      content: content,
      createdBy: createdBy,
    );
  }
}

/// Helper to parse notes from various formats
List<NoteEntry>? _parseNotes(dynamic value) {
  if (value == null) return null;

  // Already a list (JSONB column)
  if (value is List) {
    return value.map((e) => NoteEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  // String value - could be JSON array string or plain text
  if (value is String && value.isNotEmpty) {
    // Try to parse as JSON array first
    if (value.startsWith('[')) {
      try {
        final List<dynamic> parsed = jsonDecode(value) as List<dynamic>;
        return parsed.map((e) => NoteEntry.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        // Fall through to legacy handling
      }
    }
    // Handle legacy plain text format
    return [
      NoteEntry(
        id: 'legacy',
        createdAt: DateTime.now(),
        content: value,
      ),
    ];
  }
  return null;
}

/// Equipment configuration model (stored in Supabase)
@freezed
class EquipmentConfig with _$EquipmentConfig {
  const factory EquipmentConfig({
    /// The QR code ID (UUID) - this IS the QR code value
    @JsonKey(name: 'qr_id') required String qrId,
    @JsonKey(name: 'station_id') required String stationId,
    @JsonKey(name: 'equipment_name') required String equipmentName,
    @JsonKey(name: 'equipment_path') required String equipmentPath,
    @JsonKey(name: 'bql_query') required String bqlQuery,
    @JsonKey(name: 'point_paths') required List<String> pointPaths,
    @JsonKey(name: 'created_by') required String createdBy,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    /// Location description (e.g., "Building A, Floor 2, Room 201")
    String? location,
    /// Notes log entries (stored as JSONB array)
    @JsonKey(name: 'notes', fromJson: _parseNotes) List<NoteEntry>? noteEntries,
  }) = _EquipmentConfig;

  factory EquipmentConfig.fromJson(Map<String, dynamic> json) =>
      _$EquipmentConfigFromJson(json);
}

/// Equipment data retrieved from live query
@freezed
class EquipmentLiveData with _$EquipmentLiveData {
  const factory EquipmentLiveData({
    required EquipmentConfig config,
    required List<PointValue> points,
    required DateTime queriedAt,
  }) = _EquipmentLiveData;
}

/// Single point value from live query
@freezed
class PointValue with _$PointValue {
  const factory PointValue({
    required String path,
    required String name,
    required String value,
    String? status,
    String? type,
  }) = _PointValue;
}
