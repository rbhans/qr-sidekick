// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'point.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PointImpl _$$PointImplFromJson(Map<String, dynamic> json) => _$PointImpl(
  name: json['name'] as String,
  path: json['path'] as String,
  type:
      $enumDecodeNullable(_$PointTypeEnumMap, json['type']) ??
      PointType.unknown,
  hasPointsFolder: json['hasPointsFolder'] as bool? ?? false,
  equipmentPath: json['equipmentPath'] as String?,
  facets: json['facets'] as String?,
);

Map<String, dynamic> _$$PointImplToJson(_$PointImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'path': instance.path,
      'type': _$PointTypeEnumMap[instance.type]!,
      'hasPointsFolder': instance.hasPointsFolder,
      'equipmentPath': instance.equipmentPath,
      'facets': instance.facets,
    };

const _$PointTypeEnumMap = {
  PointType.boolean: 'boolean',
  PointType.numeric: 'numeric',
  PointType.enumType: 'enumType',
  PointType.string: 'string',
  PointType.unknown: 'unknown',
};

_$EquipmentImpl _$$EquipmentImplFromJson(Map<String, dynamic> json) =>
    _$EquipmentImpl(
      name: json['name'] as String,
      path: json['path'] as String,
      points:
          (json['points'] as List<dynamic>?)
              ?.map((e) => Point.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      hasPointsFolder: json['hasPointsFolder'] as bool? ?? false,
    );

Map<String, dynamic> _$$EquipmentImplToJson(_$EquipmentImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'path': instance.path,
      'points': instance.points,
      'hasPointsFolder': instance.hasPointsFolder,
    };
