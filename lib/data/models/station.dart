import 'package:freezed_annotation/freezed_annotation.dart';

part 'station.freezed.dart';
part 'station.g.dart';

/// Protocol enum for station connection
enum StationProtocol {
  @JsonValue('http')
  http,
  @JsonValue('https')
  https,
}

/// Station model (Niagara station connection)
@freezed
class Station with _$Station {
  const Station._();

  const factory Station({
    required String id,
    @JsonKey(name: 'organization_id') required String organizationId,
    required String name,
    required String host,
    @Default(443) int port,
    @Default(StationProtocol.https) StationProtocol protocol,
    String? fingerprint,
    @JsonKey(name: 'created_by') required String createdBy,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _Station;

  factory Station.fromJson(Map<String, dynamic> json) =>
      _$StationFromJson(json);

  /// Get the base URL for this station
  String get baseUrl => '${protocol.name}://$host:$port';
}

/// Station connection configuration (for testing connection)
/// This is used temporarily during connection setup, NOT stored in DB
@freezed
class StationConnectionConfig with _$StationConnectionConfig {
  const factory StationConnectionConfig({
    required String host,
    @Default(443) int port,
    @Default(StationProtocol.https) StationProtocol protocol,
    required String username,
    required String password,
    @Default(false) bool allowSelfSignedCerts,
  }) = _StationConnectionConfig;
}
