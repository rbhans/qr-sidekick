import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/station.dart';
import '../../providers/equipment_config_provider.dart';
import '../../providers/station_provider.dart';
import '../../providers/niagara_provider.dart';
import '../../widgets/equipment_tree_browser.dart';

/// Add/Edit equipment config screen
class EquipmentFormScreen extends ConsumerStatefulWidget {
  final String? qrId;

  const EquipmentFormScreen({super.key, this.qrId});

  bool get isEditing => qrId != null;

  @override
  ConsumerState<EquipmentFormScreen> createState() => _EquipmentFormScreenState();
}

class _EquipmentFormScreenState extends ConsumerState<EquipmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pathController = TextEditingController();
  final _bqlController = TextEditingController();
  final _pointPathsController = TextEditingController();

  String? _selectedStationId;
  bool _isLoading = false;
  bool _isInitialized = false;
  EquipmentSelection? _selectedEquipment;

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    _bqlController.dispose();
    _pointPathsController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStationId == null && !widget.isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a station'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(equipmentConfigNotifierProvider.notifier);

      // Parse point paths (one per line)
      final pointPaths = _pointPathsController.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (widget.isEditing) {
        await notifier.updateConfig(
          qrId: widget.qrId!,
          equipmentName: _nameController.text.trim(),
          equipmentPath: _pathController.text.trim(),
          bqlQuery: _bqlController.text.trim(),
          pointPaths: pointPaths,
        );
      } else {
        final config = await notifier.createConfig(
          stationId: _selectedStationId!,
          equipmentName: _nameController.text.trim(),
          equipmentPath: _pathController.text.trim(),
          bqlQuery: _bqlController.text.trim(),
          pointPaths: pointPaths,
        );

        if (mounted) {
          // Navigate to QR code view after creation
          context.go('/admin/equipment/${config.qrId}/qr');
          return;
        }
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing ? 'Equipment updated' : 'Equipment created'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _browseEquipment(Station station) async {
    // Check if credentials are available
    final credStatus = await ref.read(stationCredentialStatusProvider(station.id).future);
    if (credStatus == CredentialSource.none) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No credentials configured for ${station.name}. Please configure station credentials first.'),
            backgroundColor: AppColors.warning,
            action: SnackBarAction(
              label: 'Configure',
              onPressed: () => context.push('/admin/stations/${station.id}'),
            ),
          ),
        );
      }
      return;
    }

    // Open tree browser
    final selection = await EquipmentTreeBrowser.show(
      context,
      station: station,
      initialPath: _pathController.text.isNotEmpty ? _pathController.text : null,
    );

    if (selection != null && mounted) {
      setState(() {
        _selectedEquipment = selection;
        _nameController.text = selection.equipmentName;
        _pathController.text = selection.equipmentPath;
        _pointPathsController.text = selection.pointPaths.join('\n');
        // Auto-generate BQL query for the selected equipment
        _bqlController.text = "bql:select slotPath, out.value as 'Value', status as 'Status' from control:ControlPoint";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stationsAsync = ref.watch(stationNotifierProvider);

    // Load existing config data if editing
    if (widget.isEditing && !_isInitialized) {
      final configAsync = ref.watch(equipmentConfigByQrIdProvider(widget.qrId!));
      configAsync.whenData((config) {
        if (config != null && !_isInitialized) {
          _nameController.text = config.equipmentName;
          _pathController.text = config.equipmentPath;
          _bqlController.text = config.bqlQuery;
          _pointPathsController.text = config.pointPaths.join('\n');
          _selectedStationId = config.stationId;
          _isInitialized = true;
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.isEditing ? '[ EDIT EQUIPMENT ]' : '[ ADD EQUIPMENT ]',
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Station selector (only for new equipment)
              if (!widget.isEditing) ...[
                const Text(
                  '[ STATION ]',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                stationsAsync.when(
                  loading: () => const LinearProgressIndicator(color: AppColors.primary),
                  error: (e, _) => Text('Error loading stations: $e'),
                  data: (stations) {
                    if (stations.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text(
                                'No stations configured',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => context.push('/admin/stations/add'),
                                child: const Text('Add Station First'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return _StationSelector(
                      stations: stations,
                      selectedId: _selectedStationId,
                      onChanged: (id) => setState(() => _selectedStationId = id),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Browse equipment button
                if (_selectedStationId != null)
                  stationsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (stations) {
                      final station = stations.firstWhere(
                        (s) => s.id == _selectedStationId,
                        orElse: () => stations.first,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _browseEquipment(station),
                            icon: const Icon(Icons.account_tree, size: 18),
                            label: Text(_selectedEquipment != null
                                ? 'Change Selection'
                                : 'Browse Equipment from Station'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.secondary,
                              side: const BorderSide(color: AppColors.secondary),
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                          if (_selectedEquipment != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Equipment selected from station',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.success,
                                          ),
                                        ),
                                        Text(
                                          '${_selectedEquipment!.pointCount} points configured',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),

                const SizedBox(height: 24),
              ],

              // Equipment name
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Equipment Name',
                  hintText: 'e.g., AHU-01',
                  prefixIcon: Icon(Icons.label_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an equipment name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Equipment path
              TextFormField(
                controller: _pathController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Equipment Path',
                  hintText: 'e.g., /Drivers/NiagaraNetwork/Building1/AHU01',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the equipment path';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // BQL Query
              TextFormField(
                controller: _bqlController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'BQL Query',
                  hintText: 'bql:select * from control:ControlPoint...',
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a BQL query';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Point paths
              TextFormField(
                controller: _pointPathsController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Point Paths (one per line)',
                  hintText: '/points/SpaceTemp\n/points/SupplyAirTemp\n/points/DamperCmd',
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
              ),
              const SizedBox(height: 32),

              // Submit button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(widget.isEditing ? 'Update Equipment' : 'Create & Generate QR'),
              ),

              if (widget.isEditing) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push('/admin/equipment/${widget.qrId}/qr'),
                  icon: const Icon(Icons.qr_code),
                  label: const Text('View QR Code'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isLoading ? null : () => _showDeleteDialog(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Text('Delete Equipment'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Equipment?'),
        content: const Text(
          'This will delete the equipment config and invalidate its QR code. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await ref
                    .read(equipmentConfigNotifierProvider.notifier)
                    .deleteConfig(widget.qrId!);
                if (mounted) {
                  context.go('/admin/equipment');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Equipment deleted'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _StationSelector extends StatelessWidget {
  final List<Station> stations;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _StationSelector({
    required this.stations,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: stations.map((station) {
        final isSelected = station.id == selectedId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => onChanged(station.id),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? AppColors.primary : AppColors.textTertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${station.host}:${station.port}',
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
