// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organization_member.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$OrganizationMemberImpl _$$OrganizationMemberImplFromJson(
  Map<String, dynamic> json,
) => _$OrganizationMemberImpl(
  id: json['id'] as String,
  organizationId: json['organization_id'] as String,
  userId: json['user_id'] as String,
  role: $enumDecode(_$MemberRoleEnumMap, json['role']),
  invitedBy: json['invited_by'] as String?,
  joinedAt: DateTime.parse(json['joined_at'] as String),
);

Map<String, dynamic> _$$OrganizationMemberImplToJson(
  _$OrganizationMemberImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'organization_id': instance.organizationId,
  'user_id': instance.userId,
  'role': _$MemberRoleEnumMap[instance.role]!,
  'invited_by': instance.invitedBy,
  'joined_at': instance.joinedAt.toIso8601String(),
};

const _$MemberRoleEnumMap = {
  MemberRole.admin: 'admin',
  MemberRole.tech: 'tech',
};
