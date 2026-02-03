import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/organization.dart';
import '../../data/repositories/organization_repository.dart';

/// Organization repository provider
final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  return OrganizationRepository(Supabase.instance.client);
});

/// User's organizations provider
final userOrganizationsProvider = FutureProvider<List<Organization>>((ref) async {
  final repository = ref.watch(organizationRepositoryProvider);
  return repository.getUserOrganizations();
});

/// Current organization ID provider
final currentOrganizationIdProvider = FutureProvider<String?>((ref) async {
  final repository = ref.watch(organizationRepositoryProvider);
  return repository.getCurrentOrganizationId();
});

/// Organization members provider
final organizationMembersProvider = FutureProvider<List<OrganizationMember>>((ref) async {
  final repository = ref.watch(organizationRepositoryProvider);
  return repository.getOrganizationMembers();
});
