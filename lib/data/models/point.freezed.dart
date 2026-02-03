// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'point.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Point _$PointFromJson(Map<String, dynamic> json) {
  return _Point.fromJson(json);
}

/// @nodoc
mixin _$Point {
  String get name => throw _privateConstructorUsedError;
  String get path => throw _privateConstructorUsedError;
  PointType get type => throw _privateConstructorUsedError;
  bool get hasPointsFolder => throw _privateConstructorUsedError;
  String? get equipmentPath => throw _privateConstructorUsedError;
  String? get facets => throw _privateConstructorUsedError;

  /// Serializes this Point to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Point
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PointCopyWith<Point> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PointCopyWith<$Res> {
  factory $PointCopyWith(Point value, $Res Function(Point) then) =
      _$PointCopyWithImpl<$Res, Point>;
  @useResult
  $Res call({
    String name,
    String path,
    PointType type,
    bool hasPointsFolder,
    String? equipmentPath,
    String? facets,
  });
}

/// @nodoc
class _$PointCopyWithImpl<$Res, $Val extends Point>
    implements $PointCopyWith<$Res> {
  _$PointCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Point
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? path = null,
    Object? type = null,
    Object? hasPointsFolder = null,
    Object? equipmentPath = freezed,
    Object? facets = freezed,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            path: null == path
                ? _value.path
                : path // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as PointType,
            hasPointsFolder: null == hasPointsFolder
                ? _value.hasPointsFolder
                : hasPointsFolder // ignore: cast_nullable_to_non_nullable
                      as bool,
            equipmentPath: freezed == equipmentPath
                ? _value.equipmentPath
                : equipmentPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            facets: freezed == facets
                ? _value.facets
                : facets // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PointImplCopyWith<$Res> implements $PointCopyWith<$Res> {
  factory _$$PointImplCopyWith(
    _$PointImpl value,
    $Res Function(_$PointImpl) then,
  ) = __$$PointImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String name,
    String path,
    PointType type,
    bool hasPointsFolder,
    String? equipmentPath,
    String? facets,
  });
}

/// @nodoc
class __$$PointImplCopyWithImpl<$Res>
    extends _$PointCopyWithImpl<$Res, _$PointImpl>
    implements _$$PointImplCopyWith<$Res> {
  __$$PointImplCopyWithImpl(
    _$PointImpl _value,
    $Res Function(_$PointImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Point
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? path = null,
    Object? type = null,
    Object? hasPointsFolder = null,
    Object? equipmentPath = freezed,
    Object? facets = freezed,
  }) {
    return _then(
      _$PointImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        path: null == path
            ? _value.path
            : path // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as PointType,
        hasPointsFolder: null == hasPointsFolder
            ? _value.hasPointsFolder
            : hasPointsFolder // ignore: cast_nullable_to_non_nullable
                  as bool,
        equipmentPath: freezed == equipmentPath
            ? _value.equipmentPath
            : equipmentPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        facets: freezed == facets
            ? _value.facets
            : facets // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PointImpl extends _Point {
  const _$PointImpl({
    required this.name,
    required this.path,
    this.type = PointType.unknown,
    this.hasPointsFolder = false,
    this.equipmentPath,
    this.facets,
  }) : super._();

  factory _$PointImpl.fromJson(Map<String, dynamic> json) =>
      _$$PointImplFromJson(json);

  @override
  final String name;
  @override
  final String path;
  @override
  @JsonKey()
  final PointType type;
  @override
  @JsonKey()
  final bool hasPointsFolder;
  @override
  final String? equipmentPath;
  @override
  final String? facets;

  @override
  String toString() {
    return 'Point(name: $name, path: $path, type: $type, hasPointsFolder: $hasPointsFolder, equipmentPath: $equipmentPath, facets: $facets)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PointImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.path, path) || other.path == path) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.hasPointsFolder, hasPointsFolder) ||
                other.hasPointsFolder == hasPointsFolder) &&
            (identical(other.equipmentPath, equipmentPath) ||
                other.equipmentPath == equipmentPath) &&
            (identical(other.facets, facets) || other.facets == facets));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    name,
    path,
    type,
    hasPointsFolder,
    equipmentPath,
    facets,
  );

  /// Create a copy of Point
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PointImplCopyWith<_$PointImpl> get copyWith =>
      __$$PointImplCopyWithImpl<_$PointImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PointImplToJson(this);
  }
}

abstract class _Point extends Point {
  const factory _Point({
    required final String name,
    required final String path,
    final PointType type,
    final bool hasPointsFolder,
    final String? equipmentPath,
    final String? facets,
  }) = _$PointImpl;
  const _Point._() : super._();

  factory _Point.fromJson(Map<String, dynamic> json) = _$PointImpl.fromJson;

  @override
  String get name;
  @override
  String get path;
  @override
  PointType get type;
  @override
  bool get hasPointsFolder;
  @override
  String? get equipmentPath;
  @override
  String? get facets;

  /// Create a copy of Point
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PointImplCopyWith<_$PointImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Equipment _$EquipmentFromJson(Map<String, dynamic> json) {
  return _Equipment.fromJson(json);
}

/// @nodoc
mixin _$Equipment {
  String get name => throw _privateConstructorUsedError;
  String get path => throw _privateConstructorUsedError;
  List<Point> get points => throw _privateConstructorUsedError;
  bool get hasPointsFolder => throw _privateConstructorUsedError;

  /// Serializes this Equipment to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Equipment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EquipmentCopyWith<Equipment> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EquipmentCopyWith<$Res> {
  factory $EquipmentCopyWith(Equipment value, $Res Function(Equipment) then) =
      _$EquipmentCopyWithImpl<$Res, Equipment>;
  @useResult
  $Res call({
    String name,
    String path,
    List<Point> points,
    bool hasPointsFolder,
  });
}

/// @nodoc
class _$EquipmentCopyWithImpl<$Res, $Val extends Equipment>
    implements $EquipmentCopyWith<$Res> {
  _$EquipmentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Equipment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? path = null,
    Object? points = null,
    Object? hasPointsFolder = null,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            path: null == path
                ? _value.path
                : path // ignore: cast_nullable_to_non_nullable
                      as String,
            points: null == points
                ? _value.points
                : points // ignore: cast_nullable_to_non_nullable
                      as List<Point>,
            hasPointsFolder: null == hasPointsFolder
                ? _value.hasPointsFolder
                : hasPointsFolder // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EquipmentImplCopyWith<$Res>
    implements $EquipmentCopyWith<$Res> {
  factory _$$EquipmentImplCopyWith(
    _$EquipmentImpl value,
    $Res Function(_$EquipmentImpl) then,
  ) = __$$EquipmentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String name,
    String path,
    List<Point> points,
    bool hasPointsFolder,
  });
}

/// @nodoc
class __$$EquipmentImplCopyWithImpl<$Res>
    extends _$EquipmentCopyWithImpl<$Res, _$EquipmentImpl>
    implements _$$EquipmentImplCopyWith<$Res> {
  __$$EquipmentImplCopyWithImpl(
    _$EquipmentImpl _value,
    $Res Function(_$EquipmentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Equipment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? path = null,
    Object? points = null,
    Object? hasPointsFolder = null,
  }) {
    return _then(
      _$EquipmentImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        path: null == path
            ? _value.path
            : path // ignore: cast_nullable_to_non_nullable
                  as String,
        points: null == points
            ? _value._points
            : points // ignore: cast_nullable_to_non_nullable
                  as List<Point>,
        hasPointsFolder: null == hasPointsFolder
            ? _value.hasPointsFolder
            : hasPointsFolder // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$EquipmentImpl extends _Equipment {
  const _$EquipmentImpl({
    required this.name,
    required this.path,
    final List<Point> points = const [],
    this.hasPointsFolder = false,
  }) : _points = points,
       super._();

  factory _$EquipmentImpl.fromJson(Map<String, dynamic> json) =>
      _$$EquipmentImplFromJson(json);

  @override
  final String name;
  @override
  final String path;
  final List<Point> _points;
  @override
  @JsonKey()
  List<Point> get points {
    if (_points is EqualUnmodifiableListView) return _points;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_points);
  }

  @override
  @JsonKey()
  final bool hasPointsFolder;

  @override
  String toString() {
    return 'Equipment(name: $name, path: $path, points: $points, hasPointsFolder: $hasPointsFolder)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EquipmentImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.path, path) || other.path == path) &&
            const DeepCollectionEquality().equals(other._points, _points) &&
            (identical(other.hasPointsFolder, hasPointsFolder) ||
                other.hasPointsFolder == hasPointsFolder));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    name,
    path,
    const DeepCollectionEquality().hash(_points),
    hasPointsFolder,
  );

  /// Create a copy of Equipment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EquipmentImplCopyWith<_$EquipmentImpl> get copyWith =>
      __$$EquipmentImplCopyWithImpl<_$EquipmentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EquipmentImplToJson(this);
  }
}

abstract class _Equipment extends Equipment {
  const factory _Equipment({
    required final String name,
    required final String path,
    final List<Point> points,
    final bool hasPointsFolder,
  }) = _$EquipmentImpl;
  const _Equipment._() : super._();

  factory _Equipment.fromJson(Map<String, dynamic> json) =
      _$EquipmentImpl.fromJson;

  @override
  String get name;
  @override
  String get path;
  @override
  List<Point> get points;
  @override
  bool get hasPointsFolder;

  /// Create a copy of Equipment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EquipmentImplCopyWith<_$EquipmentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
