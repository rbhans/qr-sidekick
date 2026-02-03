import 'package:freezed_annotation/freezed_annotation.dart';

part 'organization_member.freezed.dart';
part 'organization_member.g.dart';

/// Member role enum
enum MemberRole {
  @JsonValue('admin')
  admin,
  @JsonValue('tech')
  tech,
}

/// Organization member model
@freezed
class OrganizationMember with _$OrganizationMember {
  const factory OrganizationMember({
    required String id,
    @JsonKey(name: 'organization_id') required String organizationId,
    @JsonKey(name: 'user_id') required String userId,
    required MemberRole role,
    @JsonKey(name: 'invited_by') String? invitedBy,
    @JsonKey(name: 'joined_at') required DateTime joinedAt,
  }) = _OrganizationMember;

  factory OrganizationMember.fromJson(Map<String, dynamic> json) =>
      _$OrganizationMemberFromJson(json);
}

/// Extension for role helpers
extension MemberRoleExtension on MemberRole {
  bool get isAdmin => this == MemberRole.admin;
  bool get isTech => this == MemberRole.tech;

  String get displayName {
    switch (this) {
      case MemberRole.admin:
        return 'Admin';
      case MemberRole.tech:
        return 'Technician';
    }
  }
}
