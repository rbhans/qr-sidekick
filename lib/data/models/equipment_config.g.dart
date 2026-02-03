// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'equipment_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NoteEntryImpl _$$NoteEntryImplFromJson(Map<String, dynamic> json) =>
    _$NoteEntryImpl(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      content: json['content'] as String,
      createdBy: json['createdBy'] as String?,
    );

Map<String, dynamic> _$$NoteEntryImplToJson(_$NoteEntryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'createdAt': instance.createdAt.toIso8601String(),
      'content': instance.content,
      'createdBy': instance.createdBy,
    };

_$EquipmentConfigImpl _$$EquipmentConfigImplFromJson(
  Map<String, dynamic> json,
) => _$EquipmentConfigImpl(
  qrId: json['qr_id'] as String,
  stationId: json['station_id'] as String,
  equipmentName: json['equipment_name'] as String,
  equipmentPath: json['equipment_path'] as String,
  bqlQuery: json['bql_query'] as String,
  pointPaths: (json['point_paths'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  createdBy: json['created_by'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
  location: json['location'] as String?,
  noteEntries: _parseNotes(json['notes']),
);

Map<String, dynamic> _$$EquipmentConfigImplToJson(
  _$EquipmentConfigImpl instance,
) => <String, dynamic>{
  'qr_id': instance.qrId,
  'station_id': instance.stationId,
  'equipment_name': instance.equipmentName,
  'equipment_path': instance.equipmentPath,
  'bql_query': instance.bqlQuery,
  'point_paths': instance.pointPaths,
  'created_by': instance.createdBy,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
  'location': instance.location,
  'notes': instance.noteEntries,
};
