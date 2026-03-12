import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/station.dart';
import '../../providers/equipment_config_provider.dart';
import '../../providers/station_provider.dart';
import '../../providers/niagara_provider.dart';
import '../../widgets/equipment_tree_browser.dart';

/// Equipment configs management screen
class EquipmentConfigsScreen extends ConsumerWidget {
  const EquipmentConfigsScreen({super.key});

  Future<void> _handleBulkAdd(BuildContext context, WidgetRef ref) async {
    // First, select a station
    final stations = await ref.read(stationsProvider.future);
    if (stations.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No stations configured. Add a station first.'),
            backgroundColor: AppColors.warning,
            action: SnackBarAction(
              label: 'Add Station',
              onPressed: () => context.push('/admin/stations/add'),
            ),
          ),
        );
      }
      return;
    }

    // Show station picker if multiple stations, or use the only one
    final Station? station = stations.length == 1
        ? stations.first
        : await showDialog<Station>(
            context: context,
            builder: (context) => _StationPickerDialog(stations: stations),
          );

    if (station == null || !context.mounted) return;

    // Check if credentials are available
    final credStatus = await ref.read(stationCredentialStatusProvider(station.id).future);
    if (credStatus == CredentialSource.none) {
      if (context.mounted) {
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

    // Open bulk select tree browser
    final selection = await EquipmentTreeBrowser.showBulkSelect(
      context,
      station: station,
    );

    if (selection == null || selection.selections.isEmpty || !context.mounted) return;

    // Show progress dialog and create configs
    if (context.mounted) {
      await _createBulkConfigs(context, ref, selection);
    }
  }

  Future<void> _createBulkConfigs(
    BuildContext context,
    WidgetRef ref,
    BulkEquipmentSelection selection,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Creating ${selection.selections.length} equipment configs...',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );

    try {
      final equipmentList = selection.selections.map((s) => (
        name: s.equipmentName,
        path: s.equipmentPath,
        pointPaths: s.pointPaths,
      )).toList();

      await ref.read(equipmentConfigNotifierProvider.notifier).createBatchConfigs(
        stationId: selection.stationId,
        equipmentList: equipmentList,
      );

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Created ${selection.selections.length} equipment configs'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync = ref.watch(equipmentConfigNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin');
            }
          },
        ),
        title: const Text(
          '[ EQUIPMENT ]',
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Bulk Add',
            onPressed: () => _handleBulkAdd(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(equipmentConfigNotifierProvider.notifier).loadConfigs(),
          ),
        ],
      ),
      body: configsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                error.toString(),
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(equipmentConfigNotifierProvider.notifier).loadConfigs(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (configs) {
          if (configs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.qr_code_2,
                    size: 64,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No equipment configured',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add equipment to generate QR codes',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/admin/equipment/add'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Equipment'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: configs.length,
            itemBuilder: (context, index) {
              final config = configs[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => context.push('/admin/equipment/${config.qrId}'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                          ),
                          child: const Icon(
                            Icons.hvac,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                config.equipmentName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                config.equipmentPath,
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.visibility, color: AppColors.secondary),
                          tooltip: 'Preview as Tech',
                          onPressed: () => context.push('/equipment/${config.qrId}'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.qr_code, color: AppColors.primary),
                          tooltip: 'View QR Code',
                          onPressed: () => context.push('/admin/equipment/${config.qrId}/qr'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/equipment/add'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.background),
      ),
    );
  }
}

/// Dialog for picking a station for bulk add
class _StationPickerDialog extends StatelessWidget {
  final List<Station> stations;

  const _StationPickerDialog({required this.stations});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        '[ SELECT STATION ]',
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: stations.length,
          itemBuilder: (context, index) {
            final station = stations[index];
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.dns, color: AppColors.secondary, size: 20),
              ),
              title: Text(station.name),
              subtitle: Text(
                '${station.host}:${station.port}',
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              onTap: () => Navigator.of(context).pop(station),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
