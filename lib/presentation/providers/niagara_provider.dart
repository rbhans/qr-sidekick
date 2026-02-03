import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/niagara_client.dart';
import '../../data/repositories/station_credentials_repository.dart';
import '../../data/models/station.dart';
import '../../data/models/equipment_config.dart';

/// Provider for the NiagaraClient singleton
final niagaraClientProvider = Provider<NiagaraClient>((ref) {
  return NiagaraClient();
});

/// Provider for the StationCredentialsRepository
final stationCredentialsRepositoryProvider = Provider<StationCredentialsRepository>((ref) {
  return StationCredentialsRepository(Supabase.instance.client);
});

/// Credential source enum
enum CredentialSource {
  local,   // Stored on device
  shared,  // Stored in Supabase (shared with team)
  none,    // No credentials available
}

/// Provider to check credential status for a station
/// Returns the source of credentials (local, shared, or none)
final stationCredentialStatusProvider = FutureProvider.family<CredentialSource, String>((ref, stationId) async {
  final client = ref.watch(niagaraClientProvider);
  final credentialsRepo = ref.watch(stationCredentialsRepositoryProvider);

  // Check local first (faster)
  final hasLocal = await client.hasCredentials(stationId);
  if (hasLocal) {
    return CredentialSource.local;
  }

  // Check shared credentials in Supabase
  final hasShared = await credentialsRepo.hasSharedCredentials(stationId);
  if (hasShared) {
    return CredentialSource.shared;
  }

  return CredentialSource.none;
});

/// Provider to get credentials for a station (checks local first, then shared)
final stationCredentialsProvider = FutureProvider.family<({String username, String password})?, String>((ref, stationId) async {
  final client = ref.watch(niagaraClientProvider);
  final credentialsRepo = ref.watch(stationCredentialsRepositoryProvider);

  // Check local first
  final localCreds = await client.getCredentials(stationId);
  if (localCreds.username != null && localCreds.password != null) {
    return (username: localCreds.username!, password: localCreds.password!);
  }

  // Check shared credentials
  final sharedCreds = await credentialsRepo.getSharedCredentials(stationId);
  return sharedCreds;
});

/// Provider to check if shared credentials exist for a station
final hasSharedCredentialsProvider = FutureProvider.family<bool, String>((ref, stationId) async {
  final credentialsRepo = ref.watch(stationCredentialsRepositoryProvider);
  return credentialsRepo.hasSharedCredentials(stationId);
});

/// Provider for live equipment data
/// Takes a tuple of (station, equipmentConfig) to fetch live point values
final liveEquipmentDataProvider = FutureProvider.family<EquipmentLiveData?, ({Station station, EquipmentConfig config})>(
  (ref, params) async {
    final client = ref.watch(niagaraClientProvider);
    final station = params.station;
    final config = params.config;

    // Get credentials (local or shared)
    final creds = await ref.watch(stationCredentialsProvider(station.id).future);
    if (creds == null) {
      return null;
    }

    // Read all points
    final results = await client.readPoints(
      station: station,
      pointPaths: config.pointPaths,
    );

    // Convert results to PointValues
    final points = <PointValue>[];
    for (final result in results) {
      if (result.isSuccess && result.point != null) {
        points.add(result.point!);
      } else {
        // Add placeholder for failed points
        final path = config.pointPaths[results.indexOf(result)];
        points.add(PointValue(
          path: path,
          name: path.split('/').last,
          value: '--',
          status: 'error',
        ));
      }
    }

    return EquipmentLiveData(
      config: config,
      points: points,
      queriedAt: DateTime.now(),
    );
  },
);

/// State notifier for managing connection testing
class ConnectionTestNotifier extends StateNotifier<AsyncValue<NiagaraConnectionResult?>> {
  final NiagaraClient _client;

  ConnectionTestNotifier(this._client) : super(const AsyncValue.data(null));

  Future<void> testConnection({
    required Station station,
    required String username,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _client.testConnection(
        station: station,
        username: username,
        password: password,
      );

      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

/// Provider for connection testing
final connectionTestProvider = StateNotifierProvider.autoDispose<ConnectionTestNotifier, AsyncValue<NiagaraConnectionResult?>>((ref) {
  final client = ref.watch(niagaraClientProvider);
  return ConnectionTestNotifier(client);
});

/// Notifier for saving credentials (handles both local and shared)
class CredentialSaveNotifier extends StateNotifier<AsyncValue<void>> {
  final NiagaraClient _client;
  final StationCredentialsRepository _credentialsRepo;

  CredentialSaveNotifier(this._client, this._credentialsRepo)
      : super(const AsyncValue.data(null));

  /// Save credentials locally only (on this device)
  Future<void> saveLocal({
    required String stationId,
    required String username,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _client.storeCredentials(
        stationId: stationId,
        username: username,
        password: password,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Save credentials to Supabase (shared with team)
  Future<void> saveShared({
    required String stationId,
    required String username,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _credentialsRepo.saveSharedCredentials(
        stationId: stationId,
        username: username,
        password: password,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Save credentials both locally and shared
  Future<void> saveBoth({
    required String stationId,
    required String username,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Save locally for faster access
      await _client.storeCredentials(
        stationId: stationId,
        username: username,
        password: password,
      );
      // Save shared for team access
      await _credentialsRepo.saveSharedCredentials(
        stationId: stationId,
        username: username,
        password: password,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Delete shared credentials
  Future<void> deleteShared(String stationId) async {
    state = const AsyncValue.loading();
    try {
      await _credentialsRepo.deleteSharedCredentials(stationId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Delete local credentials
  Future<void> deleteLocal(String stationId) async {
    state = const AsyncValue.loading();
    try {
      await _client.deleteCredentials(stationId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for credential saving
final credentialSaveProvider = StateNotifierProvider.autoDispose<CredentialSaveNotifier, AsyncValue<void>>((ref) {
  final client = ref.watch(niagaraClientProvider);
  final credentialsRepo = ref.watch(stationCredentialsRepositoryProvider);
  return CredentialSaveNotifier(client, credentialsRepo);
});
