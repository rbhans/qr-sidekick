// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'station.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Station _$StationFromJson(Map<String, dynamic> json) {
  return _Station.fromJson(json);
}

/// @nodoc
mixin _$Station {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'organization_id')
  String? get organizationId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get host => throw _privateConstructorUsedError;
  int get port => throw _privateConstructorUsedError;
  StationProtocol get protocol => throw _privateConstructorUsedError;
  String? get fingerprint => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_by')
  String get createdBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Station to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Station
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StationCopyWith<Station> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StationCopyWith<$Res> {
  factory $StationCopyWith(Station value, $Res Function(Station) then) =
      _$StationCopyWithImpl<$Res, Station>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'organization_id') String? organizationId,
    String name,
    String host,
    int port,
    StationProtocol protocol,
    String? fingerprint,
    @JsonKey(name: 'created_by') String createdBy,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
  });
}

/// @nodoc
class _$StationCopyWithImpl<$Res, $Val extends Station>
    implements $StationCopyWith<$Res> {
  _$StationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Station
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? organizationId = freezed,
    Object? name = null,
    Object? host = null,
    Object? port = null,
    Object? protocol = null,
    Object? fingerprint = freezed,
    Object? createdBy = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            organizationId: freezed == organizationId
                ? _value.organizationId
                : organizationId // ignore: cast_nullable_to_non_nullable
                      as String?,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            host: null == host
                ? _value.host
                : host // ignore: cast_nullable_to_non_nullable
                      as String,
            port: null == port
                ? _value.port
                : port // ignore: cast_nullable_to_non_nullable
                      as int,
            protocol: null == protocol
                ? _value.protocol
                : protocol // ignore: cast_nullable_to_non_nullable
                      as StationProtocol,
            fingerprint: freezed == fingerprint
                ? _value.fingerprint
                : fingerprint // ignore: cast_nullable_to_non_nullable
                      as String?,
            createdBy: null == createdBy
                ? _value.createdBy
                : createdBy // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$StationImplCopyWith<$Res> implements $StationCopyWith<$Res> {
  factory _$$StationImplCopyWith(
    _$StationImpl value,
    $Res Function(_$StationImpl) then,
  ) = __$$StationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'organization_id') String? organizationId,
    String name,
    String host,
    int port,
    StationProtocol protocol,
    String? fingerprint,
    @JsonKey(name: 'created_by') String createdBy,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
  });
}

/// @nodoc
class __$$StationImplCopyWithImpl<$Res>
    extends _$StationCopyWithImpl<$Res, _$StationImpl>
    implements _$$StationImplCopyWith<$Res> {
  __$$StationImplCopyWithImpl(
    _$StationImpl _value,
    $Res Function(_$StationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Station
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? organizationId = freezed,
    Object? name = null,
    Object? host = null,
    Object? port = null,
    Object? protocol = null,
    Object? fingerprint = freezed,
    Object? createdBy = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$StationImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        organizationId: freezed == organizationId
            ? _value.organizationId
            : organizationId // ignore: cast_nullable_to_non_nullable
                  as String?,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        host: null == host
            ? _value.host
            : host // ignore: cast_nullable_to_non_nullable
                  as String,
        port: null == port
            ? _value.port
            : port // ignore: cast_nullable_to_non_nullable
                  as int,
        protocol: null == protocol
            ? _value.protocol
            : protocol // ignore: cast_nullable_to_non_nullable
                  as StationProtocol,
        fingerprint: freezed == fingerprint
            ? _value.fingerprint
            : fingerprint // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdBy: null == createdBy
            ? _value.createdBy
            : createdBy // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$StationImpl extends _Station {
  const _$StationImpl({
    required this.id,
    @JsonKey(name: 'organization_id') this.organizationId,
    required this.name,
    required this.host,
    this.port = 443,
    this.protocol = StationProtocol.https,
    this.fingerprint,
    @JsonKey(name: 'created_by') required this.createdBy,
    @JsonKey(name: 'created_at') required this.createdAt,
    @JsonKey(name: 'updated_at') required this.updatedAt,
  }) : super._();

  factory _$StationImpl.fromJson(Map<String, dynamic> json) =>
      _$$StationImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'organization_id')
  final String? organizationId;
  @override
  final String name;
  @override
  final String host;
  @override
  @JsonKey()
  final int port;
  @override
  @JsonKey()
  final StationProtocol protocol;
  @override
  final String? fingerprint;
  @override
  @JsonKey(name: 'created_by')
  final String createdBy;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Station(id: $id, organizationId: $organizationId, name: $name, host: $host, port: $port, protocol: $protocol, fingerprint: $fingerprint, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.organizationId, organizationId) ||
                other.organizationId == organizationId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.host, host) || other.host == host) &&
            (identical(other.port, port) || other.port == port) &&
            (identical(other.protocol, protocol) ||
                other.protocol == protocol) &&
            (identical(other.fingerprint, fingerprint) ||
                other.fingerprint == fingerprint) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    organizationId,
    name,
    host,
    port,
    protocol,
    fingerprint,
    createdBy,
    createdAt,
    updatedAt,
  );

  /// Create a copy of Station
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StationImplCopyWith<_$StationImpl> get copyWith =>
      __$$StationImplCopyWithImpl<_$StationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StationImplToJson(this);
  }
}

abstract class _Station extends Station {
  const factory _Station({
    required final String id,
    @JsonKey(name: 'organization_id') final String? organizationId,
    required final String name,
    required final String host,
    final int port,
    final StationProtocol protocol,
    final String? fingerprint,
    @JsonKey(name: 'created_by') required final String createdBy,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
    @JsonKey(name: 'updated_at') required final DateTime updatedAt,
  }) = _$StationImpl;
  const _Station._() : super._();

  factory _Station.fromJson(Map<String, dynamic> json) = _$StationImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'organization_id')
  String? get organizationId;
  @override
  String get name;
  @override
  String get host;
  @override
  int get port;
  @override
  StationProtocol get protocol;
  @override
  String? get fingerprint;
  @override
  @JsonKey(name: 'created_by')
  String get createdBy;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;

  /// Create a copy of Station
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StationImplCopyWith<_$StationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$StationConnectionConfig {
  String get host => throw _privateConstructorUsedError;
  int get port => throw _privateConstructorUsedError;
  StationProtocol get protocol => throw _privateConstructorUsedError;
  String get username => throw _privateConstructorUsedError;
  String get password => throw _privateConstructorUsedError;
  bool get allowSelfSignedCerts => throw _privateConstructorUsedError;

  /// Create a copy of StationConnectionConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StationConnectionConfigCopyWith<StationConnectionConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StationConnectionConfigCopyWith<$Res> {
  factory $StationConnectionConfigCopyWith(
    StationConnectionConfig value,
    $Res Function(StationConnectionConfig) then,
  ) = _$StationConnectionConfigCopyWithImpl<$Res, StationConnectionConfig>;
  @useResult
  $Res call({
    String host,
    int port,
    StationProtocol protocol,
    String username,
    String password,
    bool allowSelfSignedCerts,
  });
}

/// @nodoc
class _$StationConnectionConfigCopyWithImpl<
  $Res,
  $Val extends StationConnectionConfig
>
    implements $StationConnectionConfigCopyWith<$Res> {
  _$StationConnectionConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StationConnectionConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? host = null,
    Object? port = null,
    Object? protocol = null,
    Object? username = null,
    Object? password = null,
    Object? allowSelfSignedCerts = null,
  }) {
    return _then(
      _value.copyWith(
            host: null == host
                ? _value.host
                : host // ignore: cast_nullable_to_non_nullable
                      as String,
            port: null == port
                ? _value.port
                : port // ignore: cast_nullable_to_non_nullable
                      as int,
            protocol: null == protocol
                ? _value.protocol
                : protocol // ignore: cast_nullable_to_non_nullable
                      as StationProtocol,
            username: null == username
                ? _value.username
                : username // ignore: cast_nullable_to_non_nullable
                      as String,
            password: null == password
                ? _value.password
                : password // ignore: cast_nullable_to_non_nullable
                      as String,
            allowSelfSignedCerts: null == allowSelfSignedCerts
                ? _value.allowSelfSignedCerts
                : allowSelfSignedCerts // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$StationConnectionConfigImplCopyWith<$Res>
    implements $StationConnectionConfigCopyWith<$Res> {
  factory _$$StationConnectionConfigImplCopyWith(
    _$StationConnectionConfigImpl value,
    $Res Function(_$StationConnectionConfigImpl) then,
  ) = __$$StationConnectionConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String host,
    int port,
    StationProtocol protocol,
    String username,
    String password,
    bool allowSelfSignedCerts,
  });
}

/// @nodoc
class __$$StationConnectionConfigImplCopyWithImpl<$Res>
    extends
        _$StationConnectionConfigCopyWithImpl<
          $Res,
          _$StationConnectionConfigImpl
        >
    implements _$$StationConnectionConfigImplCopyWith<$Res> {
  __$$StationConnectionConfigImplCopyWithImpl(
    _$StationConnectionConfigImpl _value,
    $Res Function(_$StationConnectionConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of StationConnectionConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? host = null,
    Object? port = null,
    Object? protocol = null,
    Object? username = null,
    Object? password = null,
    Object? allowSelfSignedCerts = null,
  }) {
    return _then(
      _$StationConnectionConfigImpl(
        host: null == host
            ? _value.host
            : host // ignore: cast_nullable_to_non_nullable
                  as String,
        port: null == port
            ? _value.port
            : port // ignore: cast_nullable_to_non_nullable
                  as int,
        protocol: null == protocol
            ? _value.protocol
            : protocol // ignore: cast_nullable_to_non_nullable
                  as StationProtocol,
        username: null == username
            ? _value.username
            : username // ignore: cast_nullable_to_non_nullable
                  as String,
        password: null == password
            ? _value.password
            : password // ignore: cast_nullable_to_non_nullable
                  as String,
        allowSelfSignedCerts: null == allowSelfSignedCerts
            ? _value.allowSelfSignedCerts
            : allowSelfSignedCerts // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$StationConnectionConfigImpl implements _StationConnectionConfig {
  const _$StationConnectionConfigImpl({
    required this.host,
    this.port = 443,
    this.protocol = StationProtocol.https,
    required this.username,
    required this.password,
    this.allowSelfSignedCerts = false,
  });

  @override
  final String host;
  @override
  @JsonKey()
  final int port;
  @override
  @JsonKey()
  final StationProtocol protocol;
  @override
  final String username;
  @override
  final String password;
  @override
  @JsonKey()
  final bool allowSelfSignedCerts;

  @override
  String toString() {
    return 'StationConnectionConfig(host: $host, port: $port, protocol: $protocol, username: $username, password: $password, allowSelfSignedCerts: $allowSelfSignedCerts)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StationConnectionConfigImpl &&
            (identical(other.host, host) || other.host == host) &&
            (identical(other.port, port) || other.port == port) &&
            (identical(other.protocol, protocol) ||
                other.protocol == protocol) &&
            (identical(other.username, username) ||
                other.username == username) &&
            (identical(other.password, password) ||
                other.password == password) &&
            (identical(other.allowSelfSignedCerts, allowSelfSignedCerts) ||
                other.allowSelfSignedCerts == allowSelfSignedCerts));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    host,
    port,
    protocol,
    username,
    password,
    allowSelfSignedCerts,
  );

  /// Create a copy of StationConnectionConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StationConnectionConfigImplCopyWith<_$StationConnectionConfigImpl>
  get copyWith =>
      __$$StationConnectionConfigImplCopyWithImpl<
        _$StationConnectionConfigImpl
      >(this, _$identity);
}

abstract class _StationConnectionConfig implements StationConnectionConfig {
  const factory _StationConnectionConfig({
    required final String host,
    final int port,
    final StationProtocol protocol,
    required final String username,
    required final String password,
    final bool allowSelfSignedCerts,
  }) = _$StationConnectionConfigImpl;

  @override
  String get host;
  @override
  int get port;
  @override
  StationProtocol get protocol;
  @override
  String get username;
  @override
  String get password;
  @override
  bool get allowSelfSignedCerts;

  /// Create a copy of StationConnectionConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StationConnectionConfigImplCopyWith<_$StationConnectionConfigImpl>
  get copyWith => throw _privateConstructorUsedError;
}
