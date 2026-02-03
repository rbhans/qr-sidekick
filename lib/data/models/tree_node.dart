import 'package:freezed_annotation/freezed_annotation.dart';
import 'point.dart';

part 'tree_node.freezed.dart';
part 'tree_node.g.dart';

/// Tree node model for station hierarchy (ported from NSK station.ts)
@freezed
class TreeNode with _$TreeNode {
  const TreeNode._();

  const factory TreeNode({
    required String name,
    String? path,
    @Default([]) List<TreeNode> children,
    @Default(false) bool isPoint,
    @Default([]) List<Point> points,
    @Default(false) bool isEquipment,
    @Default(false) bool hasEquipment,
    @Default(false) bool isDirectDevice,
  }) = _TreeNode;

  factory TreeNode.fromJson(Map<String, dynamic> json) =>
      _$TreeNodeFromJson(json);

  /// Check if node has children
  bool get hasChildren => children.isNotEmpty;

  /// Check if this is a leaf node (no children)
  bool get isLeaf => children.isEmpty;

  /// Get all equipment nodes in subtree
  List<TreeNode> get equipmentNodes {
    final result = <TreeNode>[];
    if (isDirectDevice) {
      result.add(this);
    }
    for (final child in children) {
      result.addAll(child.equipmentNodes);
    }
    return result;
  }

  /// Find node by path
  TreeNode? findByPath(String targetPath) {
    if (path == targetPath) return this;
    for (final child in children) {
      final found = child.findByPath(targetPath);
      if (found != null) return found;
    }
    return null;
  }
}

/// Processed station data from CSV
@freezed
class ProcessedStationData with _$ProcessedStationData {
  const factory ProcessedStationData({
    required List<Equipment> devices,
    required Map<String, Point> points,
    required TreeNode tree,
    required List<String> paths,
    @Default({}) Map<String, String> facetsMap,
    @Default({}) Map<String, String> pointTypesMap,
  }) = _ProcessedStationData;
}
