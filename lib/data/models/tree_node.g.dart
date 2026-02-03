// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tree_node.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TreeNodeImpl _$$TreeNodeImplFromJson(Map<String, dynamic> json) =>
    _$TreeNodeImpl(
      name: json['name'] as String,
      path: json['path'] as String?,
      children:
          (json['children'] as List<dynamic>?)
              ?.map((e) => TreeNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isPoint: json['isPoint'] as bool? ?? false,
      points:
          (json['points'] as List<dynamic>?)
              ?.map((e) => Point.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isEquipment: json['isEquipment'] as bool? ?? false,
      hasEquipment: json['hasEquipment'] as bool? ?? false,
      isDirectDevice: json['isDirectDevice'] as bool? ?? false,
    );

Map<String, dynamic> _$$TreeNodeImplToJson(_$TreeNodeImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'path': instance.path,
      'children': instance.children,
      'isPoint': instance.isPoint,
      'points': instance.points,
      'isEquipment': instance.isEquipment,
      'hasEquipment': instance.hasEquipment,
      'isDirectDevice': instance.isDirectDevice,
    };
