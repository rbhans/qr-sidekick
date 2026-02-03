import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/organization.dart';

/// Member info returned from the database
class OrganizationMember {
  final String id;
  final String? email;
  final String? displayName;
  final String role;
  final DateTime joinedAt;

  OrganizationMember({
    required this.id,
    this.email,
    this.displayName,
    required this.role,
    required this.joinedAt,
  });

  factory OrganizationMember.fromJson(Map<String, dynamic> json) {
    return OrganizationMember(
      id: json['user_id'] as String,
      email: json['profiles']?['email'] as String?,
      displayName: json['profiles']?['display_name'] as String?,
      role: json['role'] as String? ?? 'tech',
      joinedAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Repository for organization data operations
class OrganizationRepository {
  final SupabaseClient _client;

  OrganizationRepository(this._client);

  /// Get the current user's primary organization ID
  Future<String?> getCurrentOrganizationId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _client
        .from('qsk_organization_members')
        .select('organization_id')
        .eq('user_id', userId)
        .limit(1)
        .maybeSingle();

    return response?['organization_id'] as String?;
  }

  /// Get all organizations the current user is a member of
  Future<List<Organization>> getUserOrganizations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // Get organization IDs where user is a member
    final membershipResponse = await _client
        .from('qsk_organization_members')
        .select('organization_id')
        .eq('user_id', userId);

    final orgIds = (membershipResponse as List)
        .map((m) => m['organization_id'] as String)
        .toList();

    if (orgIds.isEmpty) return [];

    // Get the organizations
    final orgsResponse = await _client
        .from('qsk_organizations')
        .select()
        .inFilter('id', orgIds)
        .order('name', ascending: true);

    return (orgsResponse as List)
        .map((json) => Organization.fromJson(json))
        .toList();
  }

  /// Get a single organization by ID
  Future<Organization?> getOrganization(String id) async {
    final response = await _client
        .from('qsk_organizations')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Organization.fromJson(response);
  }

  /// Create a new organization and add current user as admin
  Future<Organization> createOrganization(String name) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Create the organization
    final orgResponse = await _client
        .from('qsk_organizations')
        .insert({'name': name})
        .select()
        .single();

    final org = Organization.fromJson(orgResponse);

    // Add current user as admin
    await _client.from('qsk_organization_members').insert({
      'organization_id': org.id,
      'user_id': userId,
      'role': 'admin',
    });

    return org;
  }

  /// Get members of the current user's organization
  Future<List<OrganizationMember>> getOrganizationMembers() async {
    final orgId = await getCurrentOrganizationId();
    if (orgId == null) return [];

    final response = await _client
        .from('qsk_organization_members')
        .select('*, profiles:user_id(email, display_name)')
        .eq('organization_id', orgId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((json) => OrganizationMember.fromJson(json))
        .toList();
  }

  /// Invite a member to the organization
  Future<void> inviteMember({required String email, required String role}) async {
    final orgId = await getCurrentOrganizationId();
    if (orgId == null) {
      throw Exception('No organization found');
    }

    // In a real app, you'd send an invitation email
    // For now, we'll create a pending invitation record
    await _client.from('qsk_invitations').insert({
      'organization_id': orgId,
      'email': email.toLowerCase(),
      'role': role,
      'invited_by': _client.auth.currentUser?.id,
    });
  }

  /// Remove a member from the organization
  Future<void> removeMember(String userId) async {
    final orgId = await getCurrentOrganizationId();
    if (orgId == null) {
      throw Exception('No organization found');
    }

    await _client
        .from('qsk_organization_members')
        .delete()
        .eq('organization_id', orgId)
        .eq('user_id', userId);
  }
}
