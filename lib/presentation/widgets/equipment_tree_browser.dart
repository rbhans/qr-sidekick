import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/station.dart';
import '../../data/services/niagara_client.dart';
import '../providers/niagara_provider.dart';

/// Result returned when equipment is selected from the tree
class EquipmentSelection {
  final String equipmentName;
  final String equipmentPath;
  final List<String> pointPaths;
  final int pointCount;

  EquipmentSelection({
    required this.equipmentName,
    required this.equipmentPath,
    required this.pointPaths,
    required this.pointCount,
  });
}

/// Result for bulk selection
class BulkEquipmentSelection {
  final List<EquipmentSelection> selections;
  final String stationId;

  BulkEquipmentSelection({
    required this.selections,
    required this.stationId,
  });
}

/// Provider for fetching station tree with credentials
final stationTreeProvider = FutureProvider.family<NiagaraTreeResult, Station>((ref, station) async {
  final client = ref.watch(niagaraClientProvider);

  // Get credentials (local or shared)
  final creds = await ref.watch(stationCredentialsProvider(station.id).future);
  if (creds == null) {
    return NiagaraTreeResult.error('No credentials available for this station');
  }

  return client.fetchStationTree(
    station: station,
    username: creds.username,
    password: creds.password,
  );
});

/// Equipment tree browser dialog for selecting equipment from a Niagara station
class EquipmentTreeBrowser extends ConsumerStatefulWidget {
  final Station station;
  final String? initialPath;
  final bool bulkSelectMode;

  const EquipmentTreeBrowser({
    super.key,
    required this.station,
    this.initialPath,
    this.bulkSelectMode = false,
  });

  /// Show the tree browser as a modal dialog for single selection
  static Future<EquipmentSelection?> show(
    BuildContext context, {
    required Station station,
    String? initialPath,
  }) async {
    return showDialog<EquipmentSelection>(
      context: context,
      builder: (context) => EquipmentTreeBrowser(
        station: station,
        initialPath: initialPath,
        bulkSelectMode: false,
      ),
    );
  }

  /// Show the tree browser for bulk selection (multiple equipment)
  static Future<BulkEquipmentSelection?> showBulkSelect(
    BuildContext context, {
    required Station station,
  }) async {
    return showDialog<BulkEquipmentSelection>(
      context: context,
      builder: (context) => EquipmentTreeBrowser(
        station: station,
        bulkSelectMode: true,
      ),
    );
  }

  @override
  ConsumerState<EquipmentTreeBrowser> createState() => _EquipmentTreeBrowserState();
}

class _EquipmentTreeBrowserState extends ConsumerState<EquipmentTreeBrowser> {
  final _expandedNodes = <String>{};
  NiagaraEquipment? _selectedEquipment;
  TreeNode? _selectedNode;
  StationTree? _stationTree;

  // For bulk select mode
  final _selectedForBulk = <String, (NiagaraEquipment, TreeNode)>{};

  @override
  void initState() {
    super.initState();
    // Expand root nodes by default
    _expandedNodes.add('/');
  }

  void _toggleExpanded(String path) {
    setState(() {
      if (_expandedNodes.contains(path)) {
        _expandedNodes.remove(path);
      } else {
        _expandedNodes.add(path);
      }
    });
  }

  void _selectEquipment(NiagaraEquipment equipment, TreeNode node) {
    if (widget.bulkSelectMode) {
      _toggleBulkSelection(equipment, node);
    } else {
      setState(() {
        _selectedEquipment = equipment;
        _selectedNode = node;
      });
    }
  }

  void _toggleBulkSelection(NiagaraEquipment equipment, TreeNode node) {
    setState(() {
      if (_selectedForBulk.containsKey(equipment.path)) {
        _selectedForBulk.remove(equipment.path);
      } else {
        _selectedForBulk[equipment.path] = (equipment, node);
      }
    });
  }

  void _selectAllEquipment() {
    if (_stationTree == null) return;
    setState(() {
      for (final equip in _stationTree!.equipment) {
        final node = _findNodeForEquipment(equip, _stationTree!.root);
        if (node != null) {
          _selectedForBulk[equip.path] = (equip, node);
        }
      }
    });
  }

  void _deselectAllEquipment() {
    setState(() {
      _selectedForBulk.clear();
    });
  }

  TreeNode? _findNodeForEquipment(NiagaraEquipment equip, TreeNode root) {
    if (root.path == equip.path || root.path == equip.path.replaceAll('/points', '')) {
      return root;
    }
    for (final child in root.children) {
      final found = _findNodeForEquipment(equip, child);
      if (found != null) return found;
    }
    return null;
  }

  /// Collect all points from this equipment AND all descendant equipment
  List<String> _collectAllPointPaths(TreeNode node, List<NiagaraEquipment> allEquipment) {
    final pointPaths = <String>[];

    // Find equipment for this node
    final equip = allEquipment.where((e) =>
        e.path == node.path ||
        e.path.replaceAll('/points', '') == node.path
    ).firstOrNull;

    if (equip != null) {
      pointPaths.addAll(equip.points.map((p) => p.path));
    }

    // Recursively collect from children
    for (final child in node.children) {
      pointPaths.addAll(_collectAllPointPaths(child, allEquipment));
    }

    return pointPaths;
  }

  /// Count total points including descendants
  int _countAllPoints(TreeNode node, List<NiagaraEquipment> allEquipment) {
    return _collectAllPointPaths(node, allEquipment).length;
  }

  void _confirmSelection() {
    if (widget.bulkSelectMode) {
      _confirmBulkSelection();
    } else {
      _confirmSingleSelection();
    }
  }

  void _confirmSingleSelection() {
    if (_selectedEquipment == null || _selectedNode == null || _stationTree == null) return;

    // Collect points from selected node AND all descendant equipment
    final allPointPaths = _collectAllPointPaths(_selectedNode!, _stationTree!.equipment);

    Navigator.of(context).pop(EquipmentSelection(
      equipmentName: _selectedEquipment!.name,
      equipmentPath: _selectedEquipment!.path,
      pointPaths: allPointPaths,
      pointCount: allPointPaths.length,
    ));
  }

  void _confirmBulkSelection() {
    if (_selectedForBulk.isEmpty || _stationTree == null) return;

    final selections = <EquipmentSelection>[];
    for (final entry in _selectedForBulk.entries) {
      final (equipment, node) = entry.value;
      final allPointPaths = _collectAllPointPaths(node, _stationTree!.equipment);
      selections.add(EquipmentSelection(
        equipmentName: equipment.name,
        equipmentPath: equipment.path,
        pointPaths: allPointPaths,
        pointCount: allPointPaths.length,
      ));
    }

    Navigator.of(context).pop(BulkEquipmentSelection(
      selections: selections,
      stationId: widget.station.id,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final treeAsync = ref.watch(stationTreeProvider(widget.station));

    return Dialog(
      backgroundColor: AppColors.background,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.account_tree, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.bulkSelectMode ? '[ BULK SELECT ]' : '[ SELECT EQUIPMENT ]',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        widget.station.name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            // Bulk select actions
            if (widget.bulkSelectMode && _stationTree != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _selectAllEquipment,
                    icon: const Icon(Icons.select_all, size: 16),
                    label: const Text('Select All'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _selectedForBulk.isNotEmpty ? _deselectAllEquipment : null,
                    icon: const Icon(Icons.deselect, size: 16),
                    label: const Text('Deselect All'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _selectedForBulk.isNotEmpty
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedForBulk.length} selected',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _selectedForBulk.isNotEmpty
                            ? AppColors.primary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 24),

            // Tree content
            Expanded(
              child: treeAsync.when(
                loading: () => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text(
                        'Loading station tree...',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading tree',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        e.toString(),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => ref.refresh(stationTreeProvider(widget.station)),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (result) {
                  if (result is NiagaraTreeSuccess) {
                    // Store tree reference for point collection
                    _stationTree = result.tree;

                    if (result.tree.equipment.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_outlined, color: AppColors.textTertiary, size: 48),
                            SizedBox(height: 16),
                            Text(
                              'No equipment found',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'The station has no control points configured',
                              style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }
                    return _buildTreeView(result.tree);
                  } else {
                    // Error cases
                    final message = switch (result) {
                      NiagaraTreeAuthFailed(message: final m) => 'Authentication failed: $m',
                      NiagaraTreeConnectionFailed(message: final m) => 'Connection failed: $m',
                      NiagaraTreeError(message: final m) => m,
                      _ => 'Unknown error',
                    };
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                          const SizedBox(height: 16),
                          Text(message, textAlign: TextAlign.center),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),

            // Selection info and actions (single select mode)
            if (!widget.bulkSelectMode && _selectedEquipment != null && _selectedNode != null && _stationTree != null) ...[
              const Divider(height: 24),
              Builder(builder: (context) {
                final totalPoints = _countAllPoints(_selectedNode!, _stationTree!.equipment);
                final directPoints = _selectedEquipment!.points.length;
                final hasChildPoints = totalPoints > directPoints;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedEquipment!.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$totalPoints points',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedEquipment!.path,
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (hasChildPoints) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Includes ${totalPoints - directPoints} points from child equipment',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],

            // Bulk selection summary
            if (widget.bulkSelectMode && _selectedForBulk.isNotEmpty && _stationTree != null) ...[
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.playlist_add_check, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_selectedForBulk.length} equipment selected',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _selectedForBulk.values.take(5).map((entry) {
                        final (equipment, _) = entry;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            equipment.name,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_selectedForBulk.length > 5) ...[
                      const SizedBox(height: 4),
                      Text(
                        '+${_selectedForBulk.length - 5} more',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: widget.bulkSelectMode
                      ? (_selectedForBulk.isNotEmpty ? _confirmSelection : null)
                      : (_selectedEquipment != null ? _confirmSelection : null),
                  icon: Icon(widget.bulkSelectMode ? Icons.playlist_add : Icons.check, size: 18),
                  label: Text(widget.bulkSelectMode
                      ? 'Add ${_selectedForBulk.length} Equipment'
                      : 'Select Equipment'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTreeView(StationTree tree) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stats bar
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.device_hub, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  '${tree.equipment.length} equipment groups',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${tree.equipment.fold<int>(0, (sum, e) => sum + e.points.length)} total points',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Tree nodes
          ...tree.root.children.map((node) => _buildTreeNode(node, tree.equipment, 0)),
        ],
      ),
    );
  }

  Widget _buildTreeNode(TreeNode node, List<NiagaraEquipment> equipment, int depth) {
    final isExpanded = _expandedNodes.contains(node.path);
    final hasChildren = node.children.isNotEmpty;

    // Find equipment for this node
    final equip = equipment.where((e) =>
        e.path == node.path ||
        e.path.replaceAll('/points', '') == node.path
    ).firstOrNull;

    final isSelected = widget.bulkSelectMode
        ? (equip != null && _selectedForBulk.containsKey(equip.path))
        : (equip != null && _selectedEquipment?.path == equip.path);
    final isEquipment = node.isEquipment || equip != null;

    // Calculate total points including children for display
    final totalPoints = isEquipment ? _countAllPoints(node, equipment) : 0;
    final directPoints = equip?.points.length ?? 0;
    final hasChildPoints = totalPoints > directPoints;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            if (isEquipment && equip != null) {
              _selectEquipment(equip, node);
            } else if (hasChildren) {
              _toggleExpanded(node.path);
            }
          },
          child: Container(
            padding: EdgeInsets.only(
              left: 12.0 + (depth * 16.0),
              right: 12,
              top: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              border: isSelected
                  ? const Border(left: BorderSide(color: AppColors.primary, width: 3))
                  : null,
            ),
            child: Row(
              children: [
                // Expand/collapse icon or spacer
                if (hasChildren)
                  GestureDetector(
                    onTap: () => _toggleExpanded(node.path),
                    child: Icon(
                      isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 4),

                // Checkbox for bulk mode, icon for single mode
                if (widget.bulkSelectMode && isEquipment && equip != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 20,
                      color: isSelected ? AppColors.primary : AppColors.textTertiary,
                    ),
                  )
                else ...[
                  // Node icon
                  Icon(
                    isEquipment
                        ? Icons.precision_manufacturing
                        : Icons.folder_outlined,
                    size: 18,
                    color: isEquipment
                        ? (isSelected ? AppColors.primary : AppColors.secondary)
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 8),
                ],

                // Node name
                Expanded(
                  child: Text(
                    node.name,
                    style: TextStyle(
                      fontWeight: isEquipment ? FontWeight.w500 : FontWeight.normal,
                      color: isSelected
                          ? AppColors.primary
                          : (isEquipment ? AppColors.textPrimary : AppColors.textSecondary),
                    ),
                  ),
                ),

                // Point count badge for equipment (shows total including children)
                if (isEquipment && equip != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      hasChildPoints ? '$totalPoints' : '$directPoints',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Children
        if (isExpanded && hasChildren)
          ...node.children.map((child) => _buildTreeNode(child, equipment, depth + 1)),
      ],
    );
  }
}

/// Compact inline tree browser for embedding in forms
class EquipmentTreeInline extends ConsumerStatefulWidget {
  final Station station;
  final ValueChanged<EquipmentSelection> onSelected;
  final String? initialPath;

  const EquipmentTreeInline({
    super.key,
    required this.station,
    required this.onSelected,
    this.initialPath,
  });

  @override
  ConsumerState<EquipmentTreeInline> createState() => _EquipmentTreeInlineState();
}

class _EquipmentTreeInlineState extends ConsumerState<EquipmentTreeInline> {
  final _expandedNodes = <String>{};
  String? _selectedPath;

  @override
  void initState() {
    super.initState();
    _expandedNodes.add('/');
    _selectedPath = widget.initialPath;
  }

  void _toggleExpanded(String path) {
    setState(() {
      if (_expandedNodes.contains(path)) {
        _expandedNodes.remove(path);
      } else {
        _expandedNodes.add(path);
      }
    });
  }

  void _selectEquipment(NiagaraEquipment equipment) {
    setState(() {
      _selectedPath = equipment.path;
    });

    widget.onSelected(EquipmentSelection(
      equipmentName: equipment.name,
      equipmentPath: equipment.path,
      pointPaths: equipment.points.map((p) => p.path).toList(),
      pointCount: equipment.points.length,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final treeAsync = ref.watch(stationTreeProvider(widget.station));

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(maxHeight: 300),
      child: treeAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
                SizedBox(height: 12),
                Text(
                  'Loading equipment...',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 32),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () => ref.refresh(stationTreeProvider(widget.station)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (result) {
          if (result is NiagaraTreeSuccess) {
            if (result.tree.equipment.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined, color: AppColors.textTertiary, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'No equipment found',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            }
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: result.tree.root.children
                    .map((node) => _buildNode(node, result.tree.equipment, 0))
                    .toList(),
              ),
            );
          } else {
            final message = switch (result) {
              NiagaraTreeAuthFailed(message: final m) => m,
              NiagaraTreeConnectionFailed(message: final m) => m,
              NiagaraTreeError(message: final m) => m,
              _ => 'Error',
            };
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(message, style: const TextStyle(color: AppColors.error)),
            );
          }
        },
      ),
    );
  }

  Widget _buildNode(TreeNode node, List<NiagaraEquipment> equipment, int depth) {
    final isExpanded = _expandedNodes.contains(node.path);
    final hasChildren = node.children.isNotEmpty;

    final equip = equipment.where((e) =>
        e.path == node.path ||
        e.path.replaceAll('/points', '') == node.path
    ).firstOrNull;

    final isSelected = equip != null && _selectedPath == equip.path;
    final isEquipment = node.isEquipment || equip != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            if (isEquipment && equip != null) {
              _selectEquipment(equip);
            } else if (hasChildren) {
              _toggleExpanded(node.path);
            }
          },
          child: Container(
            padding: EdgeInsets.only(
              left: 8.0 + (depth * 12.0),
              right: 8,
              top: 6,
              bottom: 6,
            ),
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : null,
            child: Row(
              children: [
                if (hasChildren)
                  GestureDetector(
                    onTap: () => _toggleExpanded(node.path),
                    child: Icon(
                      isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  const SizedBox(width: 16),
                Icon(
                  isEquipment ? Icons.precision_manufacturing : Icons.folder_outlined,
                  size: 14,
                  color: isEquipment ? AppColors.secondary : AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    node.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isEquipment ? FontWeight.w500 : FontWeight.normal,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (isEquipment && equip != null)
                  Text(
                    '${equip.points.length}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                  ),
              ],
            ),
          ),
        ),
        if (isExpanded && hasChildren)
          ...node.children.map((c) => _buildNode(c, equipment, depth + 1)),
      ],
    );
  }
}
