import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/env_config.dart';

part 'supabase_datasource.g.dart';

/// Provides the Supabase client instance
@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) {
  return Supabase.instance.client;
}

/// Initialize Supabase
Future<void> initializeSupabase() async {
  // Validate config before initializing
  EnvConfig.validate();

  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );
}

/// Extension on SupabaseClient for common operations
extension SupabaseClientExtension on SupabaseClient {
  /// Get current user ID or throw
  String get currentUserId {
    final userId = auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    return userId;
  }

  /// Check if user is authenticated
  bool get isAuthenticated => auth.currentUser != null;
}
