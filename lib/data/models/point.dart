import 'package:freezed_annotation/freezed_annotation.dart';

part 'point.freezed.dart';
part 'point.g.dart';

/// Point type enum (from Niagara control types)
enum PointType {
  boolean,
  numeric,
  enumType,
  string,
  unknown,
}

/// Control point model (ported from NSK station.ts)
@freezed
class Point with _$Point {
  const Point._();

  const factory Point({
    required String name,
    required String path,
    @Default(PointType.unknown) PointType type,
    @Default(false) bool hasPointsFolder,
    String? equipmentPath,
    String? facets,
  }) = _Point;

  factory Point.fromJson(Map<String, dynamic> json) => _$PointFromJson(json);

  /// Get simple display name (last segment of path)
  String get displayName => name;

  /// Get parent path (equipment path)
  String get parentPath {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length > 1) {
      segments.removeLast();
      if (segments.isNotEmpty && segments.last == 'points') {
        segments.removeLast();
      }
      return '/${segments.join('/')}';
    }
    return '/';
  }
}

/// Equipment model (collection of points)
@freezed
class Equipment with _$Equipment {
  const Equipment._();

  const factory Equipment({
    required String name,
    required String path,
    @Default([]) List<Point> points,
    @Default(false) bool hasPointsFolder,
  }) = _Equipment;

  factory Equipment.fromJson(Map<String, dynamic> json) =>
      _$EquipmentFromJson(json);

  /// Get point count
  int get pointCount => points.length;

  /// Get display name (last segment of path)
  String get displayName => name;
}
