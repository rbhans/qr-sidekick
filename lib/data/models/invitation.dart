import 'package:freezed_annotation/freezed_annotation.dart';
import 'organization_member.dart';

part 'invitation.freezed.dart';
part 'invitation.g.dart';

/// Invitation model
@freezed
class Invitation with _$Invitation {
  const Invitation._();

  const factory Invitation({
    required String id,
    @JsonKey(name: 'organization_id') required String organizationId,
    required String email,
    required MemberRole role,
    @JsonKey(name: 'invited_by') required String invitedBy,
    required String token,
    @JsonKey(name: 'expires_at') required DateTime expiresAt,
    @JsonKey(name: 'accepted_at') DateTime? acceptedAt,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _Invitation;

  factory Invitation.fromJson(Map<String, dynamic> json) =>
      _$InvitationFromJson(json);

  /// Check if invitation is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if invitation is accepted
  bool get isAccepted => acceptedAt != null;

  /// Check if invitation is pending (not expired and not accepted)
  bool get isPending => !isExpired && !isAccepted;
}
