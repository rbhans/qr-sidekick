import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/equipment_config.dart';

/// Repository for equipment config data operations
class EquipmentConfigRepository {
  final SupabaseClient _client;

  EquipmentConfigRepository(this._client);

  /// Get all equipment configs for a station
  Future<List<EquipmentConfig>> getEquipmentConfigs(String stationId) async {
    final response = await _client
        .from('qsk_equipment_configs')
        .select()
        .eq('station_id', stationId)
        .order('equipment_name', ascending: true);

    return (response as List)
        .map((json) => EquipmentConfig.fromJson(json))
        .toList();
  }

  /// Get all equipment configs for current user's organizations
  Future<List<EquipmentConfig>> getAllEquipmentConfigs() async {
    final response = await _client
        .from('qsk_equipment_configs')
        .select()
        .order('equipment_name', ascending: true);

    return (response as List)
        .map((json) => EquipmentConfig.fromJson(json))
        .toList();
  }

  /// Get a single equipment config by QR ID
  Future<EquipmentConfig?> getByQrId(String qrId) async {
    final response = await _client
        .from('qsk_equipment_configs')
        .select()
        .eq('qr_id', qrId)
        .maybeSingle();

    if (response == null) return null;
    return EquipmentConfig.fromJson(response);
  }

  /// Create a new equipment config
  Future<EquipmentConfig> createEquipmentConfig({
    required String stationId,
    required String equipmentName,
    required String equipmentPath,
    required String bqlQuery,
    required List<String> pointPaths,
  }) async {
    final userId = _client.auth.currentUser!.id;

    final response = await _client
        .from('qsk_equipment_configs')
        .insert({
          'station_id': stationId,
          'equipment_name': equipmentName,
          'equipment_path': equipmentPath,
          'bql_query': bqlQuery,
          'point_paths': pointPaths,
          'created_by': userId,
        })
        .select()
        .single();

    return EquipmentConfig.fromJson(response);
  }

  /// Update an existing equipment config
  Future<EquipmentConfig> updateEquipmentConfig({
    required String qrId,
    String? equipmentName,
    String? equipmentPath,
    String? bqlQuery,
    List<String>? pointPaths,
  }) async {
    final updates = <String, dynamic>{};
    if (equipmentName != null) updates['equipment_name'] = equipmentName;
    if (equipmentPath != null) updates['equipment_path'] = equipmentPath;
    if (bqlQuery != null) updates['bql_query'] = bqlQuery;
    if (pointPaths != null) updates['point_paths'] = pointPaths;

    final response = await _client
        .from('qsk_equipment_configs')
        .update(updates)
        .eq('qr_id', qrId)
        .select()
        .single();

    return EquipmentConfig.fromJson(response);
  }

  /// Delete an equipment config
  Future<void> deleteEquipmentConfig(String qrId) async {
    await _client.from('qsk_equipment_configs').delete().eq('qr_id', qrId);
  }

  /// Add a note entry to equipment config
  Future<List<NoteEntry>> addNote(String qrId, NoteEntry note) async {
    // Get current notes
    final config = await getByQrId(qrId);
    final currentNotes = config?.noteEntries ?? [];

    // Add new note at the beginning (newest first)
    final updatedNotes = [note, ...currentNotes];

    // Encode as JSON string (column is TEXT, not JSONB)
    final notesJson = jsonEncode(updatedNotes.map((n) => n.toJson()).toList());

    // Update in database
    await _client.from('qsk_equipment_configs').update({
      'notes': notesJson,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('qr_id', qrId);

    return updatedNotes;
  }

  /// Delete a note entry from equipment config
  Future<List<NoteEntry>> deleteNote(String qrId, String noteId) async {
    // Get current notes
    final config = await getByQrId(qrId);
    final currentNotes = config?.noteEntries ?? [];

    // Remove the note with matching id
    final updatedNotes = currentNotes.where((n) => n.id != noteId).toList();

    // Encode as JSON string (column is TEXT, not JSONB)
    final notesJson = jsonEncode(updatedNotes.map((n) => n.toJson()).toList());

    // Update in database
    await _client.from('qsk_equipment_configs').update({
      'notes': notesJson,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('qr_id', qrId);

    return updatedNotes;
  }

  /// Update location for an equipment config
  Future<void> updateLocation(String qrId, String? location) async {
    await _client
        .from('qsk_equipment_configs')
        .update({'location': location, 'updated_at': DateTime.now().toIso8601String()})
        .eq('qr_id', qrId);
  }
}
