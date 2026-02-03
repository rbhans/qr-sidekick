import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/station.dart';

/// Repository for station data operations
class StationRepository {
  final SupabaseClient _client;

  StationRepository(this._client);

  /// Get all stations for the current user's organizations
  Future<List<Station>> getStations() async {
    final response = await _client
        .from('qsk_stations')
        .select()
        .order('name', ascending: true);

    return (response as List)
        .map((json) => Station.fromJson(json))
        .toList();
  }

  /// Get a single station by ID
  Future<Station?> getStation(String id) async {
    final response = await _client
        .from('qsk_stations')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Station.fromJson(response);
  }

  /// Create a new station
  Future<Station> createStation({
    required String organizationId,
    required String name,
    required String host,
    int port = 443,
    StationProtocol protocol = StationProtocol.https,
    String? fingerprint,
  }) async {
    final userId = _client.auth.currentUser!.id;

    final response = await _client
        .from('qsk_stations')
        .insert({
          'organization_id': organizationId,
          'name': name,
          'host': host,
          'port': port,
          'protocol': protocol.name,
          'fingerprint': fingerprint,
          'created_by': userId,
        })
        .select()
        .single();

    return Station.fromJson(response);
  }

  /// Update an existing station
  Future<Station> updateStation({
    required String id,
    String? name,
    String? host,
    int? port,
    StationProtocol? protocol,
    String? fingerprint,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (host != null) updates['host'] = host;
    if (port != null) updates['port'] = port;
    if (protocol != null) updates['protocol'] = protocol.name;
    if (fingerprint != null) updates['fingerprint'] = fingerprint;

    final response = await _client
        .from('qsk_stations')
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    return Station.fromJson(response);
  }

  /// Delete a station
  Future<void> deleteStation(String id) async {
    await _client.from('qsk_stations').delete().eq('id', id);
  }
}
