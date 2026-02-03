import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

/// User profile model (from profiles table)
@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    @JsonKey(name: 'display_name') String? displayName,
    String? company,
    @JsonKey(name: 'subscription_tier') @Default('free') String subscriptionTier,
    @Default({}) Map<String, dynamic> entitlements,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}

/// App user combining Supabase auth user and profile
@freezed
class AppUser with _$AppUser {
  const AppUser._();

  const factory AppUser({
    required String id,
    required String email,
    UserProfile? profile,
  }) = _AppUser;

  /// Display name (fallback to email if no profile name)
  String get displayName => profile?.displayName ?? email.split('@').first;

  /// Check if profile is complete
  bool get hasProfile => profile != null;
}
