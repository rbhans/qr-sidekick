import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_exception.dart' as app_errors;
import '../../data/datasources/supabase_datasource.dart';
import '../../data/models/user_profile.dart';

part 'auth_provider.g.dart';

/// App auth state that includes user and profile
class AppAuthState {
  const AppAuthState({
    this.user,
    this.profile,
    this.isLoading = false,
    this.error,
  });

  final User? user;
  final UserProfile? profile;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null;
  bool get hasProfile => profile != null;

  AppAuthState copyWith({
    User? user,
    UserProfile? profile,
    bool? isLoading,
    String? error,
  }) {
    return AppAuthState(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Auth state notifier
@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  AppAuthState build() {
    // Listen to Supabase auth state changes
    final client = ref.watch(supabaseClientProvider);

    _authSubscription?.cancel();
    _authSubscription = client.auth.onAuthStateChange.listen((event) async {
      final user = event.session?.user;
      if (user != null) {
        // Fetch profile when user signs in
        final profile = await _fetchProfile(user.id);
        state = AppAuthState(user: user, profile: profile);
      } else {
        state = const AppAuthState();
      }
    });

    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    // Check current session
    final currentUser = client.auth.currentUser;
    if (currentUser != null) {
      // Async fetch profile
      _fetchProfile(currentUser.id).then((profile) {
        state = AppAuthState(user: currentUser, profile: profile);
      });
      return AppAuthState(user: currentUser, isLoading: true);
    }

    return const AppAuthState();
  }

  Future<UserProfile?> _fetchProfile(String userId) async {
    try {
      final client = ref.read(supabaseClientProvider);
      final response = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        return UserProfile.fromJson(response);
      }
      return null;
    } catch (e) {
      // Profile may not exist yet
      return null;
    }
  }

  /// Sign in with email and password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = ref.read(supabaseClientProvider);
      await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // Auth state change listener will update state
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
      rethrow;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
      rethrow;
    }
  }

  /// Sign up with email and password
  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = ref.read(supabaseClientProvider);
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          if (displayName != null) 'display_name': displayName,
        },
      );

      if (response.user != null) {
        // Create profile
        await client.from('profiles').upsert({
          'id': response.user!.id,
          'display_name': displayName,
        });
      }
      // Auth state change listener will update state
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
      rethrow;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = ref.read(supabaseClientProvider);
      await client.auth.signOut();
      state = const AppAuthState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to sign out',
      );
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = ref.read(supabaseClientProvider);
      await client.auth.resetPasswordForEmail(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to send reset email',
      );
      rethrow;
    }
  }

  /// Update profile
  Future<void> updateProfile({
    String? displayName,
    String? company,
  }) async {
    final user = state.user;
    if (user == null) {
      throw const app_errors.AuthException('Not authenticated');
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('profiles').upsert({
        'id': user.id,
        if (displayName != null) 'display_name': displayName,
        if (company != null) 'company': company,
      });

      final profile = await _fetchProfile(user.id);
      state = state.copyWith(isLoading: false, profile: profile);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update profile',
      );
      rethrow;
    }
  }
}

/// Convenience provider for checking if user is authenticated
@riverpod
bool isAuthenticated(Ref ref) {
  return ref.watch(authProvider).isAuthenticated;
}

/// Convenience provider for current user
@riverpod
User? currentUser(Ref ref) {
  return ref.watch(authProvider).user;
}

/// Convenience provider for current profile
@riverpod
UserProfile? currentProfile(Ref ref) {
  return ref.watch(authProvider).profile;
}
