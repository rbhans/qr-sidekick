// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tree_node.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TreeNode _$TreeNodeFromJson(Map<String, dynamic> json) {
  return _TreeNode.fromJson(json);
}

/// @nodoc
mixin _$TreeNode {
  String get name => throw _privateConstructorUsedError;
  String? get path => throw _privateConstructorUsedError;
  List<TreeNode> get children => throw _privateConstructorUsedError;
  bool get isPoint => throw _privateConstructorUsedError;
  List<Point> get points => throw _privateConstructorUsedError;
  bool get isEquipment => throw _privateConstructorUsedError;
  bool get hasEquipment => throw _privateConstructorUsedError;
  bool get isDirectDevice => throw _privateConstructorUsedError;

  /// Serializes this TreeNode to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TreeNode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TreeNodeCopyWith<TreeNode> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TreeNodeCopyWith<$Res> {
  factory $TreeNodeCopyWith(TreeNode value, $Res Function(TreeNode) then) =
      _$TreeNodeCopyWithImpl<$Res, TreeNode>;
  @useResult
  $Res call({
    String name,
    String? path,
    List<TreeNode> children,
    bool isPoint,
    List<Point> points,
    bool isEquipment,
    bool hasEquipment,
    bool isDirectDevice,
  });
}

/// @nodoc
class _$TreeNodeCopyWithImpl<$Res, $Val extends TreeNode>
    implements $TreeNodeCopyWith<$Res> {
  _$TreeNodeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TreeNode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? path = freezed,
    Object? children = null,
    Object? isPoint = null,
    Object? points = null,
    Object? isEquipment = null,
    Object? hasEquipment = null,
    Object? isDirectDevice = null,
  }) {
    return _then(
      _value.copyWith(
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            path: freezed == path
                ? _value.path
                : path // ignore: cast_nullable_to_non_nullable
                      as String?,
            children: null == children
                ? _value.children
                : children // ignore: cast_nullable_to_non_nullable
                      as List<TreeNode>,
            isPoint: null == isPoint
                ? _value.isPoint
                : isPoint // ignore: cast_nullable_to_non_nullable
                      as bool,
            points: null == points
                ? _value.points
                : points // ignore: cast_nullable_to_non_nullable
                      as List<Point>,
            isEquipment: null == isEquipment
                ? _value.isEquipment
                : isEquipment // ignore: cast_nullable_to_non_nullable
                      as bool,
            hasEquipment: null == hasEquipment
                ? _value.hasEquipment
                : hasEquipment // ignore: cast_nullable_to_non_nullable
                      as bool,
            isDirectDevice: null == isDirectDevice
                ? _value.isDirectDevice
                : isDirectDevice // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TreeNodeImplCopyWith<$Res>
    implements $TreeNodeCopyWith<$Res> {
  factory _$$TreeNodeImplCopyWith(
    _$TreeNodeImpl value,
    $Res Function(_$TreeNodeImpl) then,
  ) = __$$TreeNodeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String name,
    String? path,
    List<TreeNode> children,
    bool isPoint,
    List<Point> points,
    bool isEquipment,
    bool hasEquipment,
    bool isDirectDevice,
  });
}

/// @nodoc
class __$$TreeNodeImplCopyWithImpl<$Res>
    extends _$TreeNodeCopyWithImpl<$Res, _$TreeNodeImpl>
    implements _$$TreeNodeImplCopyWith<$Res> {
  __$$TreeNodeImplCopyWithImpl(
    _$TreeNodeImpl _value,
    $Res Function(_$TreeNodeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TreeNode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? path = freezed,
    Object? children = null,
    Object? isPoint = null,
    Object? points = null,
    Object? isEquipment = null,
    Object? hasEquipment = null,
    Object? isDirectDevice = null,
  }) {
    return _then(
      _$TreeNodeImpl(
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        path: freezed == path
            ? _value.path
            : path // ignore: cast_nullable_to_non_nullable
                  as String?,
        children: null == children
            ? _value._children
            : children // ignore: cast_nullable_to_non_nullable
                  as List<TreeNode>,
        isPoint: null == isPoint
            ? _value.isPoint
            : isPoint // ignore: cast_nullable_to_non_nullable
                  as bool,
        points: null == points
            ? _value._points
            : points // ignore: cast_nullable_to_non_nullable
                  as List<Point>,
        isEquipment: null == isEquipment
            ? _value.isEquipment
            : isEquipment // ignore: cast_nullable_to_non_nullable
                  as bool,
        hasEquipment: null == hasEquipment
            ? _value.hasEquipment
            : hasEquipment // ignore: cast_nullable_to_non_nullable
                  as bool,
        isDirectDevice: null == isDirectDevice
            ? _value.isDirectDevice
            : isDirectDevice // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TreeNodeImpl extends _TreeNode {
  const _$TreeNodeImpl({
    required this.name,
    this.path,
    final List<TreeNode> children = const [],
    this.isPoint = false,
    final List<Point> points = const [],
    this.isEquipment = false,
    this.hasEquipment = false,
    this.isDirectDevice = false,
  }) : _children = children,
       _points = points,
       super._();

  factory _$TreeNodeImpl.fromJson(Map<String, dynamic> json) =>
      _$$TreeNodeImplFromJson(json);

  @override
  final String name;
  @override
  final String? path;
  final List<TreeNode> _children;
  @override
  @JsonKey()
  List<TreeNode> get children {
    if (_children is EqualUnmodifiableListView) return _children;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_children);
  }

  @override
  @JsonKey()
  final bool isPoint;
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
  final bool isEquipment;
  @override
  @JsonKey()
  final bool hasEquipment;
  @override
  @JsonKey()
  final bool isDirectDevice;

  @override
  String toString() {
    return 'TreeNode(name: $name, path: $path, children: $children, isPoint: $isPoint, points: $points, isEquipment: $isEquipment, hasEquipment: $hasEquipment, isDirectDevice: $isDirectDevice)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TreeNodeImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.path, path) || other.path == path) &&
            const DeepCollectionEquality().equals(other._children, _children) &&
            (identical(other.isPoint, isPoint) || other.isPoint == isPoint) &&
            const DeepCollectionEquality().equals(other._points, _points) &&
            (identical(other.isEquipment, isEquipment) ||
                other.isEquipment == isEquipment) &&
            (identical(other.hasEquipment, hasEquipment) ||
                other.hasEquipment == hasEquipment) &&
            (identical(other.isDirectDevice, isDirectDevice) ||
                other.isDirectDevice == isDirectDevice));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    name,
    path,
    const DeepCollectionEquality().hash(_children),
    isPoint,
    const DeepCollectionEquality().hash(_points),
    isEquipment,
    hasEquipment,
    isDirectDevice,
  );

  /// Create a copy of TreeNode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TreeNodeImplCopyWith<_$TreeNodeImpl> get copyWith =>
      __$$TreeNodeImplCopyWithImpl<_$TreeNodeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TreeNodeImplToJson(this);
  }
}

abstract class _TreeNode extends TreeNode {
  const factory _TreeNode({
    required final String name,
    final String? path,
    final List<TreeNode> children,
    final bool isPoint,
    final List<Point> points,
    final bool isEquipment,
    final bool hasEquipment,
    final bool isDirectDevice,
  }) = _$TreeNodeImpl;
  const _TreeNode._() : super._();

  factory _TreeNode.fromJson(Map<String, dynamic> json) =
      _$TreeNodeImpl.fromJson;

  @override
  String get name;
  @override
  String? get path;
  @override
  List<TreeNode> get children;
  @override
  bool get isPoint;
  @override
  List<Point> get points;
  @override
  bool get isEquipment;
  @override
  bool get hasEquipment;
  @override
  bool get isDirectDevice;

  /// Create a copy of TreeNode
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TreeNodeImplCopyWith<_$TreeNodeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ProcessedStationData {
  List<Equipment> get devices => throw _privateConstructorUsedError;
  Map<String, Point> get points => throw _privateConstructorUsedError;
  TreeNode get tree => throw _privateConstructorUsedError;
  List<String> get paths => throw _privateConstructorUsedError;
  Map<String, String> get facetsMap => throw _privateConstructorUsedError;
  Map<String, String> get pointTypesMap => throw _privateConstructorUsedError;

  /// Create a copy of ProcessedStationData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProcessedStationDataCopyWith<ProcessedStationData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProcessedStationDataCopyWith<$Res> {
  factory $ProcessedStationDataCopyWith(
    ProcessedStationData value,
    $Res Function(ProcessedStationData) then,
  ) = _$ProcessedStationDataCopyWithImpl<$Res, ProcessedStationData>;
  @useResult
  $Res call({
    List<Equipment> devices,
    Map<String, Point> points,
    TreeNode tree,
    List<String> paths,
    Map<String, String> facetsMap,
    Map<String, String> pointTypesMap,
  });

  $TreeNodeCopyWith<$Res> get tree;
}

/// @nodoc
class _$ProcessedStationDataCopyWithImpl<
  $Res,
  $Val extends ProcessedStationData
>
    implements $ProcessedStationDataCopyWith<$Res> {
  _$ProcessedStationDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProcessedStationData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? devices = null,
    Object? points = null,
    Object? tree = null,
    Object? paths = null,
    Object? facetsMap = null,
    Object? pointTypesMap = null,
  }) {
    return _then(
      _value.copyWith(
            devices: null == devices
                ? _value.devices
                : devices // ignore: cast_nullable_to_non_nullable
                      as List<Equipment>,
            points: null == points
                ? _value.points
                : points // ignore: cast_nullable_to_non_nullable
                      as Map<String, Point>,
            tree: null == tree
                ? _value.tree
                : tree // ignore: cast_nullable_to_non_nullable
                      as TreeNode,
            paths: null == paths
                ? _value.paths
                : paths // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            facetsMap: null == facetsMap
                ? _value.facetsMap
                : facetsMap // ignore: cast_nullable_to_non_nullable
                      as Map<String, String>,
            pointTypesMap: null == pointTypesMap
                ? _value.pointTypesMap
                : pointTypesMap // ignore: cast_nullable_to_non_nullable
                      as Map<String, String>,
          )
          as $Val,
    );
  }

  /// Create a copy of ProcessedStationData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TreeNodeCopyWith<$Res> get tree {
    return $TreeNodeCopyWith<$Res>(_value.tree, (value) {
      return _then(_value.copyWith(tree: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ProcessedStationDataImplCopyWith<$Res>
    implements $ProcessedStationDataCopyWith<$Res> {
  factory _$$ProcessedStationDataImplCopyWith(
    _$ProcessedStationDataImpl value,
    $Res Function(_$ProcessedStationDataImpl) then,
  ) = __$$ProcessedStationDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<Equipment> devices,
    Map<String, Point> points,
    TreeNode tree,
    List<String> paths,
    Map<String, String> facetsMap,
    Map<String, String> pointTypesMap,
  });

  @override
  $TreeNodeCopyWith<$Res> get tree;
}

/// @nodoc
class __$$ProcessedStationDataImplCopyWithImpl<$Res>
    extends _$ProcessedStationDataCopyWithImpl<$Res, _$ProcessedStationDataImpl>
    implements _$$ProcessedStationDataImplCopyWith<$Res> {
  __$$ProcessedStationDataImplCopyWithImpl(
    _$ProcessedStationDataImpl _value,
    $Res Function(_$ProcessedStationDataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProcessedStationData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? devices = null,
    Object? points = null,
    Object? tree = null,
    Object? paths = null,
    Object? facetsMap = null,
    Object? pointTypesMap = null,
  }) {
    return _then(
      _$ProcessedStationDataImpl(
        devices: null == devices
            ? _value._devices
            : devices // ignore: cast_nullable_to_non_nullable
                  as List<Equipment>,
        points: null == points
            ? _value._points
            : points // ignore: cast_nullable_to_non_nullable
                  as Map<String, Point>,
        tree: null == tree
            ? _value.tree
            : tree // ignore: cast_nullable_to_non_nullable
                  as TreeNode,
        paths: null == paths
            ? _value._paths
            : paths // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        facetsMap: null == facetsMap
            ? _value._facetsMap
            : facetsMap // ignore: cast_nullable_to_non_nullable
                  as Map<String, String>,
        pointTypesMap: null == pointTypesMap
            ? _value._pointTypesMap
            : pointTypesMap // ignore: cast_nullable_to_non_nullable
                  as Map<String, String>,
      ),
    );
  }
}

/// @nodoc

class _$ProcessedStationDataImpl implements _ProcessedStationData {
  const _$ProcessedStationDataImpl({
    required final List<Equipment> devices,
    required final Map<String, Point> points,
    required this.tree,
    required final List<String> paths,
    final Map<String, String> facetsMap = const {},
    final Map<String, String> pointTypesMap = const {},
  }) : _devices = devices,
       _points = points,
       _paths = paths,
       _facetsMap = facetsMap,
       _pointTypesMap = pointTypesMap;

  final List<Equipment> _devices;
  @override
  List<Equipment> get devices {
    if (_devices is EqualUnmodifiableListView) return _devices;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_devices);
  }

  final Map<String, Point> _points;
  @override
  Map<String, Point> get points {
    if (_points is EqualUnmodifiableMapView) return _points;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_points);
  }

  @override
  final TreeNode tree;
  final List<String> _paths;
  @override
  List<String> get paths {
    if (_paths is EqualUnmodifiableListView) return _paths;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_paths);
  }

  final Map<String, String> _facetsMap;
  @override
  @JsonKey()
  Map<String, String> get facetsMap {
    if (_facetsMap is EqualUnmodifiableMapView) return _facetsMap;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_facetsMap);
  }

  final Map<String, String> _pointTypesMap;
  @override
  @JsonKey()
  Map<String, String> get pointTypesMap {
    if (_pointTypesMap is EqualUnmodifiableMapView) return _pointTypesMap;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_pointTypesMap);
  }

  @override
  String toString() {
    return 'ProcessedStationData(devices: $devices, points: $points, tree: $tree, paths: $paths, facetsMap: $facetsMap, pointTypesMap: $pointTypesMap)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProcessedStationDataImpl &&
            const DeepCollectionEquality().equals(other._devices, _devices) &&
            const DeepCollectionEquality().equals(other._points, _points) &&
            (identical(other.tree, tree) || other.tree == tree) &&
            const DeepCollectionEquality().equals(other._paths, _paths) &&
            const DeepCollectionEquality().equals(
              other._facetsMap,
              _facetsMap,
            ) &&
            const DeepCollectionEquality().equals(
              other._pointTypesMap,
              _pointTypesMap,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_devices),
    const DeepCollectionEquality().hash(_points),
    tree,
    const DeepCollectionEquality().hash(_paths),
    const DeepCollectionEquality().hash(_facetsMap),
    const DeepCollectionEquality().hash(_pointTypesMap),
  );

  /// Create a copy of ProcessedStationData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProcessedStationDataImplCopyWith<_$ProcessedStationDataImpl>
  get copyWith =>
      __$$ProcessedStationDataImplCopyWithImpl<_$ProcessedStationDataImpl>(
        this,
        _$identity,
      );
}

abstract class _ProcessedStationData implements ProcessedStationData {
  const factory _ProcessedStationData({
    required final List<Equipment> devices,
    required final Map<String, Point> points,
    required final TreeNode tree,
    required final List<String> paths,
    final Map<String, String> facetsMap,
    final Map<String, String> pointTypesMap,
  }) = _$ProcessedStationDataImpl;

  @override
  List<Equipment> get devices;
  @override
  Map<String, Point> get points;
  @override
  TreeNode get tree;
  @override
  List<String> get paths;
  @override
  Map<String, String> get facetsMap;
  @override
  Map<String, String> get pointTypesMap;

  /// Create a copy of ProcessedStationData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProcessedStationDataImplCopyWith<_$ProcessedStationDataImpl>
  get copyWith => throw _privateConstructorUsedError;
}
