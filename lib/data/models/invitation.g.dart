// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invitation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$InvitationImpl _$$InvitationImplFromJson(Map<String, dynamic> json) =>
    _$InvitationImpl(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      email: json['email'] as String,
      role: $enumDecode(_$MemberRoleEnumMap, json['role']),
      invitedBy: json['invited_by'] as String,
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      acceptedAt: json['accepted_at'] == null
          ? null
          : DateTime.parse(json['accepted_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$InvitationImplToJson(_$InvitationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'organization_id': instance.organizationId,
      'email': instance.email,
      'role': _$MemberRoleEnumMap[instance.role]!,
      'invited_by': instance.invitedBy,
      'token': instance.token,
      'expires_at': instance.expiresAt.toIso8601String(),
      'accepted_at': instance.acceptedAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$MemberRoleEnumMap = {
  MemberRole.admin: 'admin',
  MemberRole.tech: 'tech',
};
