import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for managing shared station credentials in Supabase
class StationCredentialsRepository {
  final SupabaseClient _client;

  StationCredentialsRepository(this._client);

  /// Check if shared credentials exist for a station
  Future<bool> hasSharedCredentials(String stationId) async {
    final response = await _client.rpc(
      'has_shared_credentials',
      params: {'p_station_id': stationId},
    );
    return response as bool? ?? false;
  }

  /// Get shared credentials for a station (decrypted server-side)
  Future<({String username, String password})?> getSharedCredentials(
    String stationId,
  ) async {
    final response = await _client.rpc(
      'get_shared_credentials',
      params: {'p_station_id': stationId},
    );

    if (response == null || (response as List).isEmpty) {
      return null;
    }

    final data = response[0] as Map<String, dynamic>;
    final username = data['username'] as String?;
    final password = data['password'] as String?;

    if (username == null || password == null) {
      return null;
    }

    return (username: username, password: password);
  }

  /// Save shared credentials for a station (encrypted server-side)
  Future<void> saveSharedCredentials({
    required String stationId,
    required String username,
    required String password,
  }) async {
    await _client.rpc(
      'save_shared_credentials',
      params: {
        'p_station_id': stationId,
        'p_username': username,
        'p_password': password,
      },
    );
  }

  /// Delete shared credentials for a station
  Future<void> deleteSharedCredentials(String stationId) async {
    await _client.rpc(
      'delete_shared_credentials',
      params: {'p_station_id': stationId},
    );
  }
}
