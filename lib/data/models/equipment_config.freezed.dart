// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'equipment_config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

NoteEntry _$NoteEntryFromJson(Map<String, dynamic> json) {
  return _NoteEntry.fromJson(json);
}

/// @nodoc
mixin _$NoteEntry {
  String get id => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  String? get createdBy => throw _privateConstructorUsedError;

  /// Serializes this NoteEntry to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NoteEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NoteEntryCopyWith<NoteEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NoteEntryCopyWith<$Res> {
  factory $NoteEntryCopyWith(NoteEntry value, $Res Function(NoteEntry) then) =
      _$NoteEntryCopyWithImpl<$Res, NoteEntry>;
  @useResult
  $Res call({String id, DateTime createdAt, String content, String? createdBy});
}

/// @nodoc
class _$NoteEntryCopyWithImpl<$Res, $Val extends NoteEntry>
    implements $NoteEntryCopyWith<$Res> {
  _$NoteEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NoteEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? content = null,
    Object? createdBy = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            content: null == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as String,
            createdBy: freezed == createdBy
                ? _value.createdBy
                : createdBy // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$NoteEntryImplCopyWith<$Res>
    implements $NoteEntryCopyWith<$Res> {
  factory _$$NoteEntryImplCopyWith(
    _$NoteEntryImpl value,
    $Res Function(_$NoteEntryImpl) then,
  ) = __$$NoteEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, DateTime createdAt, String content, String? createdBy});
}

/// @nodoc
class __$$NoteEntryImplCopyWithImpl<$Res>
    extends _$NoteEntryCopyWithImpl<$Res, _$NoteEntryImpl>
    implements _$$NoteEntryImplCopyWith<$Res> {
  __$$NoteEntryImplCopyWithImpl(
    _$NoteEntryImpl _value,
    $Res Function(_$NoteEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of NoteEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? content = null,
    Object? createdBy = freezed,
  }) {
    return _then(
      _$NoteEntryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        content: null == content
            ? _value.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String,
        createdBy: freezed == createdBy
            ? _value.createdBy
            : createdBy // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$NoteEntryImpl implements _NoteEntry {
  const _$NoteEntryImpl({
    required this.id,
    required this.createdAt,
    required this.content,
    this.createdBy,
  });

  factory _$NoteEntryImpl.fromJson(Map<String, dynamic> json) =>
      _$$NoteEntryImplFromJson(json);

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final String content;
  @override
  final String? createdBy;

  @override
  String toString() {
    return 'NoteEntry(id: $id, createdAt: $createdAt, content: $content, createdBy: $createdBy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NoteEntryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, createdAt, content, createdBy);

  /// Create a copy of NoteEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NoteEntryImplCopyWith<_$NoteEntryImpl> get copyWith =>
      __$$NoteEntryImplCopyWithImpl<_$NoteEntryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NoteEntryImplToJson(this);
  }
}

abstract class _NoteEntry implements NoteEntry {
  const factory _NoteEntry({
    required final String id,
    required final DateTime createdAt,
    required final String content,
    final String? createdBy,
  }) = _$NoteEntryImpl;

  factory _NoteEntry.fromJson(Map<String, dynamic> json) =
      _$NoteEntryImpl.fromJson;

  @override
  String get id;
  @override
  DateTime get createdAt;
  @override
  String get content;
  @override
  String? get createdBy;

  /// Create a copy of NoteEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NoteEntryImplCopyWith<_$NoteEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

EquipmentConfig _$EquipmentConfigFromJson(Map<String, dynamic> json) {
  return _EquipmentConfig.fromJson(json);
}

/// @nodoc
mixin _$EquipmentConfig {
  /// The QR code ID (UUID) - this IS the QR code value
  @JsonKey(name: 'qr_id')
  String get qrId => throw _privateConstructorUsedError;
  @JsonKey(name: 'station_id')
  String get stationId => throw _privateConstructorUsedError;
  @JsonKey(name: 'equipment_name')
  String get equipmentName => throw _privateConstructorUsedError;
  @JsonKey(name: 'equipment_path')
  String get equipmentPath => throw _privateConstructorUsedError;
  @JsonKey(name: 'bql_query')
  String get bqlQuery => throw _privateConstructorUsedError;
  @JsonKey(name: 'point_paths')
  List<String> get pointPaths => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_by')
  String get createdBy => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Location description (e.g., "Building A, Floor 2, Room 201")
  String? get location => throw _privateConstructorUsedError;

  /// Notes log entries (stored as JSONB array)
  @JsonKey(name: 'notes', fromJson: _parseNotes)
  List<NoteEntry>? get noteEntries => throw _privateConstructorUsedError;

  /// Serializes this EquipmentConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EquipmentConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EquipmentConfigCopyWith<EquipmentConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EquipmentConfigCopyWith<$Res> {
  factory $EquipmentConfigCopyWith(
    EquipmentConfig value,
    $Res Function(EquipmentConfig) then,
  ) = _$EquipmentConfigCopyWithImpl<$Res, EquipmentConfig>;
  @useResult
  $Res call({
    @JsonKey(name: 'qr_id') String qrId,
    @JsonKey(name: 'station_id') String stationId,
    @JsonKey(name: 'equipment_name') String equipmentName,
    @JsonKey(name: 'equipment_path') String equipmentPath,
    @JsonKey(name: 'bql_query') String bqlQuery,
    @JsonKey(name: 'point_paths') List<String> pointPaths,
    @JsonKey(name: 'created_by') String createdBy,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
    String? location,
    @JsonKey(name: 'notes', fromJson: _parseNotes) List<NoteEntry>? noteEntries,
  });
}

/// @nodoc
class _$EquipmentConfigCopyWithImpl<$Res, $Val extends EquipmentConfig>
    implements $EquipmentConfigCopyWith<$Res> {
  _$EquipmentConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EquipmentConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? qrId = null,
    Object? stationId = null,
    Object? equipmentName = null,
    Object? equipmentPath = null,
    Object? bqlQuery = null,
    Object? pointPaths = null,
    Object? createdBy = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? location = freezed,
    Object? noteEntries = freezed,
  }) {
    return _then(
      _value.copyWith(
            qrId: null == qrId
                ? _value.qrId
                : qrId // ignore: cast_nullable_to_non_nullable
                      as String,
            stationId: null == stationId
                ? _value.stationId
                : stationId // ignore: cast_nullable_to_non_nullable
                      as String,
            equipmentName: null == equipmentName
                ? _value.equipmentName
                : equipmentName // ignore: cast_nullable_to_non_nullable
                      as String,
            equipmentPath: null == equipmentPath
                ? _value.equipmentPath
                : equipmentPath // ignore: cast_nullable_to_non_nullable
                      as String,
            bqlQuery: null == bqlQuery
                ? _value.bqlQuery
                : bqlQuery // ignore: cast_nullable_to_non_nullable
                      as String,
            pointPaths: null == pointPaths
                ? _value.pointPaths
                : pointPaths // ignore: cast_nullable_to_non_nullable
                      as List<String>,
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
            location: freezed == location
                ? _value.location
                : location // ignore: cast_nullable_to_non_nullable
                      as String?,
            noteEntries: freezed == noteEntries
                ? _value.noteEntries
                : noteEntries // ignore: cast_nullable_to_non_nullable
                      as List<NoteEntry>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EquipmentConfigImplCopyWith<$Res>
    implements $EquipmentConfigCopyWith<$Res> {
  factory _$$EquipmentConfigImplCopyWith(
    _$EquipmentConfigImpl value,
    $Res Function(_$EquipmentConfigImpl) then,
  ) = __$$EquipmentConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'qr_id') String qrId,
    @JsonKey(name: 'station_id') String stationId,
    @JsonKey(name: 'equipment_name') String equipmentName,
    @JsonKey(name: 'equipment_path') String equipmentPath,
    @JsonKey(name: 'bql_query') String bqlQuery,
    @JsonKey(name: 'point_paths') List<String> pointPaths,
    @JsonKey(name: 'created_by') String createdBy,
    @JsonKey(name: 'created_at') DateTime createdAt,
    @JsonKey(name: 'updated_at') DateTime updatedAt,
    String? location,
    @JsonKey(name: 'notes', fromJson: _parseNotes) List<NoteEntry>? noteEntries,
  });
}

/// @nodoc
class __$$EquipmentConfigImplCopyWithImpl<$Res>
    extends _$EquipmentConfigCopyWithImpl<$Res, _$EquipmentConfigImpl>
    implements _$$EquipmentConfigImplCopyWith<$Res> {
  __$$EquipmentConfigImplCopyWithImpl(
    _$EquipmentConfigImpl _value,
    $Res Function(_$EquipmentConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EquipmentConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? qrId = null,
    Object? stationId = null,
    Object? equipmentName = null,
    Object? equipmentPath = null,
    Object? bqlQuery = null,
    Object? pointPaths = null,
    Object? createdBy = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? location = freezed,
    Object? noteEntries = freezed,
  }) {
    return _then(
      _$EquipmentConfigImpl(
        qrId: null == qrId
            ? _value.qrId
            : qrId // ignore: cast_nullable_to_non_nullable
                  as String,
        stationId: null == stationId
            ? _value.stationId
            : stationId // ignore: cast_nullable_to_non_nullable
                  as String,
        equipmentName: null == equipmentName
            ? _value.equipmentName
            : equipmentName // ignore: cast_nullable_to_non_nullable
                  as String,
        equipmentPath: null == equipmentPath
            ? _value.equipmentPath
            : equipmentPath // ignore: cast_nullable_to_non_nullable
                  as String,
        bqlQuery: null == bqlQuery
            ? _value.bqlQuery
            : bqlQuery // ignore: cast_nullable_to_non_nullable
                  as String,
        pointPaths: null == pointPaths
            ? _value._pointPaths
            : pointPaths // ignore: cast_nullable_to_non_nullable
                  as List<String>,
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
        location: freezed == location
            ? _value.location
            : location // ignore: cast_nullable_to_non_nullable
                  as String?,
        noteEntries: freezed == noteEntries
            ? _value._noteEntries
            : noteEntries // ignore: cast_nullable_to_non_nullable
                  as List<NoteEntry>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$EquipmentConfigImpl implements _EquipmentConfig {
  const _$EquipmentConfigImpl({
    @JsonKey(name: 'qr_id') required this.qrId,
    @JsonKey(name: 'station_id') required this.stationId,
    @JsonKey(name: 'equipment_name') required this.equipmentName,
    @JsonKey(name: 'equipment_path') required this.equipmentPath,
    @JsonKey(name: 'bql_query') required this.bqlQuery,
    @JsonKey(name: 'point_paths') required final List<String> pointPaths,
    @JsonKey(name: 'created_by') required this.createdBy,
    @JsonKey(name: 'created_at') required this.createdAt,
    @JsonKey(name: 'updated_at') required this.updatedAt,
    this.location,
    @JsonKey(name: 'notes', fromJson: _parseNotes)
    final List<NoteEntry>? noteEntries,
  }) : _pointPaths = pointPaths,
       _noteEntries = noteEntries;

  factory _$EquipmentConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$EquipmentConfigImplFromJson(json);

  /// The QR code ID (UUID) - this IS the QR code value
  @override
  @JsonKey(name: 'qr_id')
  final String qrId;
  @override
  @JsonKey(name: 'station_id')
  final String stationId;
  @override
  @JsonKey(name: 'equipment_name')
  final String equipmentName;
  @override
  @JsonKey(name: 'equipment_path')
  final String equipmentPath;
  @override
  @JsonKey(name: 'bql_query')
  final String bqlQuery;
  final List<String> _pointPaths;
  @override
  @JsonKey(name: 'point_paths')
  List<String> get pointPaths {
    if (_pointPaths is EqualUnmodifiableListView) return _pointPaths;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pointPaths);
  }

  @override
  @JsonKey(name: 'created_by')
  final String createdBy;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @override
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  /// Location description (e.g., "Building A, Floor 2, Room 201")
  @override
  final String? location;

  /// Notes log entries (stored as JSONB array)
  final List<NoteEntry>? _noteEntries;

  /// Notes log entries (stored as JSONB array)
  @override
  @JsonKey(name: 'notes', fromJson: _parseNotes)
  List<NoteEntry>? get noteEntries {
    final value = _noteEntries;
    if (value == null) return null;
    if (_noteEntries is EqualUnmodifiableListView) return _noteEntries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'EquipmentConfig(qrId: $qrId, stationId: $stationId, equipmentName: $equipmentName, equipmentPath: $equipmentPath, bqlQuery: $bqlQuery, pointPaths: $pointPaths, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt, location: $location, noteEntries: $noteEntries)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EquipmentConfigImpl &&
            (identical(other.qrId, qrId) || other.qrId == qrId) &&
            (identical(other.stationId, stationId) ||
                other.stationId == stationId) &&
            (identical(other.equipmentName, equipmentName) ||
                other.equipmentName == equipmentName) &&
            (identical(other.equipmentPath, equipmentPath) ||
                other.equipmentPath == equipmentPath) &&
            (identical(other.bqlQuery, bqlQuery) ||
                other.bqlQuery == bqlQuery) &&
            const DeepCollectionEquality().equals(
              other._pointPaths,
              _pointPaths,
            ) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.location, location) ||
                other.location == location) &&
            const DeepCollectionEquality().equals(
              other._noteEntries,
              _noteEntries,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    qrId,
    stationId,
    equipmentName,
    equipmentPath,
    bqlQuery,
    const DeepCollectionEquality().hash(_pointPaths),
    createdBy,
    createdAt,
    updatedAt,
    location,
    const DeepCollectionEquality().hash(_noteEntries),
  );

  /// Create a copy of EquipmentConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EquipmentConfigImplCopyWith<_$EquipmentConfigImpl> get copyWith =>
      __$$EquipmentConfigImplCopyWithImpl<_$EquipmentConfigImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$EquipmentConfigImplToJson(this);
  }
}

abstract class _EquipmentConfig implements EquipmentConfig {
  const factory _EquipmentConfig({
    @JsonKey(name: 'qr_id') required final String qrId,
    @JsonKey(name: 'station_id') required final String stationId,
    @JsonKey(name: 'equipment_name') required final String equipmentName,
    @JsonKey(name: 'equipment_path') required final String equipmentPath,
    @JsonKey(name: 'bql_query') required final String bqlQuery,
    @JsonKey(name: 'point_paths') required final List<String> pointPaths,
    @JsonKey(name: 'created_by') required final String createdBy,
    @JsonKey(name: 'created_at') required final DateTime createdAt,
    @JsonKey(name: 'updated_at') required final DateTime updatedAt,
    final String? location,
    @JsonKey(name: 'notes', fromJson: _parseNotes)
    final List<NoteEntry>? noteEntries,
  }) = _$EquipmentConfigImpl;

  factory _EquipmentConfig.fromJson(Map<String, dynamic> json) =
      _$EquipmentConfigImpl.fromJson;

  /// The QR code ID (UUID) - this IS the QR code value
  @override
  @JsonKey(name: 'qr_id')
  String get qrId;
  @override
  @JsonKey(name: 'station_id')
  String get stationId;
  @override
  @JsonKey(name: 'equipment_name')
  String get equipmentName;
  @override
  @JsonKey(name: 'equipment_path')
  String get equipmentPath;
  @override
  @JsonKey(name: 'bql_query')
  String get bqlQuery;
  @override
  @JsonKey(name: 'point_paths')
  List<String> get pointPaths;
  @override
  @JsonKey(name: 'created_by')
  String get createdBy;
  @override
  @JsonKey(name: 'created_at')
  DateTime get createdAt;
  @override
  @JsonKey(name: 'updated_at')
  DateTime get updatedAt;

  /// Location description (e.g., "Building A, Floor 2, Room 201")
  @override
  String? get location;

  /// Notes log entries (stored as JSONB array)
  @override
  @JsonKey(name: 'notes', fromJson: _parseNotes)
  List<NoteEntry>? get noteEntries;

  /// Create a copy of EquipmentConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EquipmentConfigImplCopyWith<_$EquipmentConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$EquipmentLiveData {
  EquipmentConfig get config => throw _privateConstructorUsedError;
  List<PointValue> get points => throw _privateConstructorUsedError;
  DateTime get queriedAt => throw _privateConstructorUsedError;

  /// Create a copy of EquipmentLiveData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EquipmentLiveDataCopyWith<EquipmentLiveData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EquipmentLiveDataCopyWith<$Res> {
  factory $EquipmentLiveDataCopyWith(
    EquipmentLiveData value,
    $Res Function(EquipmentLiveData) then,
  ) = _$EquipmentLiveDataCopyWithImpl<$Res, EquipmentLiveData>;
  @useResult
  $Res call({
    EquipmentConfig config,
    List<PointValue> points,
    DateTime queriedAt,
  });

  $EquipmentConfigCopyWith<$Res> get config;
}

/// @nodoc
class _$EquipmentLiveDataCopyWithImpl<$Res, $Val extends EquipmentLiveData>
    implements $EquipmentLiveDataCopyWith<$Res> {
  _$EquipmentLiveDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EquipmentLiveData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? config = null,
    Object? points = null,
    Object? queriedAt = null,
  }) {
    return _then(
      _value.copyWith(
            config: null == config
                ? _value.config
                : config // ignore: cast_nullable_to_non_nullable
                      as EquipmentConfig,
            points: null == points
                ? _value.points
                : points // ignore: cast_nullable_to_non_nullable
                      as List<PointValue>,
            queriedAt: null == queriedAt
                ? _value.queriedAt
                : queriedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }

  /// Create a copy of EquipmentLiveData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $EquipmentConfigCopyWith<$Res> get config {
    return $EquipmentConfigCopyWith<$Res>(_value.config, (value) {
      return _then(_value.copyWith(config: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$EquipmentLiveDataImplCopyWith<$Res>
    implements $EquipmentLiveDataCopyWith<$Res> {
  factory _$$EquipmentLiveDataImplCopyWith(
    _$EquipmentLiveDataImpl value,
    $Res Function(_$EquipmentLiveDataImpl) then,
  ) = __$$EquipmentLiveDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    EquipmentConfig config,
    List<PointValue> points,
    DateTime queriedAt,
  });

  @override
  $EquipmentConfigCopyWith<$Res> get config;
}

/// @nodoc
class __$$EquipmentLiveDataImplCopyWithImpl<$Res>
    extends _$EquipmentLiveDataCopyWithImpl<$Res, _$EquipmentLiveDataImpl>
    implements _$$EquipmentLiveDataImplCopyWith<$Res> {
  __$$EquipmentLiveDataImplCopyWithImpl(
    _$EquipmentLiveDataImpl _value,
    $Res Function(_$EquipmentLiveDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EquipmentLiveData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? config = null,
    Object? points = null,
    Object? queriedAt = null,
  }) {
    return _then(
      _$EquipmentLiveDataImpl(
        config: null == config
            ? _value.config
            : config // ignore: cast_nullable_to_non_nullable
                  as EquipmentConfig,
        points: null == points
            ? _value._points
            : points // ignore: cast_nullable_to_non_nullable
                  as List<PointValue>,
        queriedAt: null == queriedAt
            ? _value.queriedAt
            : queriedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$EquipmentLiveDataImpl implements _EquipmentLiveData {
  const _$EquipmentLiveDataImpl({
    required this.config,
    required final List<PointValue> points,
    required this.queriedAt,
  }) : _points = points;

  @override
  final EquipmentConfig config;
  final List<PointValue> _points;
  @override
  List<PointValue> get points {
    if (_points is EqualUnmodifiableListView) return _points;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_points);
  }

  @override
  final DateTime queriedAt;

  @override
  String toString() {
    return 'EquipmentLiveData(config: $config, points: $points, queriedAt: $queriedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EquipmentLiveDataImpl &&
            (identical(other.config, config) || other.config == config) &&
            const DeepCollectionEquality().equals(other._points, _points) &&
            (identical(other.queriedAt, queriedAt) ||
                other.queriedAt == queriedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    config,
    const DeepCollectionEquality().hash(_points),
    queriedAt,
  );

  /// Create a copy of EquipmentLiveData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EquipmentLiveDataImplCopyWith<_$EquipmentLiveDataImpl> get copyWith =>
      __$$EquipmentLiveDataImplCopyWithImpl<_$EquipmentLiveDataImpl>(
        this,
        _$identity,
      );
}

abstract class _EquipmentLiveData implements EquipmentLiveData {
  const factory _EquipmentLiveData({
    required final EquipmentConfig config,
    required final List<PointValue> points,
    required final DateTime queriedAt,
  }) = _$EquipmentLiveDataImpl;

  @override
  EquipmentConfig get config;
  @override
  List<PointValue> get points;
  @override
  DateTime get queriedAt;

  /// Create a copy of EquipmentLiveData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EquipmentLiveDataImplCopyWith<_$EquipmentLiveDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PointValue {
  String get path => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get value => throw _privateConstructorUsedError;
  String? get status => throw _privateConstructorUsedError;
  String? get type => throw _privateConstructorUsedError;

  /// Create a copy of PointValue
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PointValueCopyWith<PointValue> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PointValueCopyWith<$Res> {
  factory $PointValueCopyWith(
    PointValue value,
    $Res Function(PointValue) then,
  ) = _$PointValueCopyWithImpl<$Res, PointValue>;
  @useResult
  $Res call({
    String path,
    String name,
    String value,
    String? status,
    String? type,
  });
}

/// @nodoc
class _$PointValueCopyWithImpl<$Res, $Val extends PointValue>
    implements $PointValueCopyWith<$Res> {
  _$PointValueCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PointValue
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? path = null,
    Object? name = null,
    Object? value = null,
    Object? status = freezed,
    Object? type = freezed,
  }) {
    return _then(
      _value.copyWith(
            path: null == path
                ? _value.path
                : path // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            value: null == value
                ? _value.value
                : value // ignore: cast_nullable_to_non_nullable
                      as String,
            status: freezed == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String?,
            type: freezed == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PointValueImplCopyWith<$Res>
    implements $PointValueCopyWith<$Res> {
  factory _$$PointValueImplCopyWith(
    _$PointValueImpl value,
    $Res Function(_$PointValueImpl) then,
  ) = __$$PointValueImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String path,
    String name,
    String value,
    String? status,
    String? type,
  });
}

/// @nodoc
class __$$PointValueImplCopyWithImpl<$Res>
    extends _$PointValueCopyWithImpl<$Res, _$PointValueImpl>
    implements _$$PointValueImplCopyWith<$Res> {
  __$$PointValueImplCopyWithImpl(
    _$PointValueImpl _value,
    $Res Function(_$PointValueImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PointValue
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? path = null,
    Object? name = null,
    Object? value = null,
    Object? status = freezed,
    Object? type = freezed,
  }) {
    return _then(
      _$PointValueImpl(
        path: null == path
            ? _value.path
            : path // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        value: null == value
            ? _value.value
            : value // ignore: cast_nullable_to_non_nullable
                  as String,
        status: freezed == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String?,
        type: freezed == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$PointValueImpl implements _PointValue {
  const _$PointValueImpl({
    required this.path,
    required this.name,
    required this.value,
    this.status,
    this.type,
  });

  @override
  final String path;
  @override
  final String name;
  @override
  final String value;
  @override
  final String? status;
  @override
  final String? type;

  @override
  String toString() {
    return 'PointValue(path: $path, name: $name, value: $value, status: $status, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PointValueImpl &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.type, type) || other.type == type));
  }

  @override
  int get hashCode => Object.hash(runtimeType, path, name, value, status, type);

  /// Create a copy of PointValue
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PointValueImplCopyWith<_$PointValueImpl> get copyWith =>
      __$$PointValueImplCopyWithImpl<_$PointValueImpl>(this, _$identity);
}

abstract class _PointValue implements PointValue {
  const factory _PointValue({
    required final String path,
    required final String name,
    required final String value,
    final String? status,
    final String? type,
  }) = _$PointValueImpl;

  @override
  String get path;
  @override
  String get name;
  @override
  String get value;
  @override
  String? get status;
  @override
  String? get type;

  /// Create a copy of PointValue
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PointValueImplCopyWith<_$PointValueImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
