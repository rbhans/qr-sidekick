import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/equipment_config.dart';
import '../../data/repositories/equipment_config_repository.dart';

/// Equipment config repository provider
final equipmentConfigRepositoryProvider = Provider<EquipmentConfigRepository>((ref) {
  return EquipmentConfigRepository(Supabase.instance.client);
});

/// All equipment configs provider
final equipmentConfigsProvider = FutureProvider<List<EquipmentConfig>>((ref) async {
  final repository = ref.watch(equipmentConfigRepositoryProvider);
  return repository.getAllEquipmentConfigs();
});

/// Equipment configs by station provider
final equipmentConfigsByStationProvider =
    FutureProvider.family<List<EquipmentConfig>, String>((ref, stationId) async {
  final repository = ref.watch(equipmentConfigRepositoryProvider);
  return repository.getEquipmentConfigs(stationId);
});

/// Single equipment config by QR ID provider
final equipmentConfigByQrIdProvider =
    FutureProvider.family<EquipmentConfig?, String>((ref, qrId) async {
  final repository = ref.watch(equipmentConfigRepositoryProvider);
  return repository.getByQrId(qrId);
});

/// Equipment config management notifier
class EquipmentConfigNotifier extends StateNotifier<AsyncValue<List<EquipmentConfig>>> {
  final EquipmentConfigRepository _repository;

  EquipmentConfigNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadConfigs();
  }

  Future<void> loadConfigs() async {
    state = const AsyncValue.loading();
    try {
      final configs = await _repository.getAllEquipmentConfigs();
      state = AsyncValue.data(configs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<EquipmentConfig> createConfig({
    required String stationId,
    required String equipmentName,
    required String equipmentPath,
    required String bqlQuery,
    required List<String> pointPaths,
  }) async {
    final config = await _repository.createEquipmentConfig(
      stationId: stationId,
      equipmentName: equipmentName,
      equipmentPath: equipmentPath,
      bqlQuery: bqlQuery,
      pointPaths: pointPaths,
    );
    await loadConfigs();
    return config;
  }

  /// Create multiple equipment configs in batch
  Future<List<EquipmentConfig>> createBatchConfigs({
    required String stationId,
    required List<({String name, String path, List<String> pointPaths})> equipmentList,
  }) async {
    final configs = <EquipmentConfig>[];
    final defaultBql = "bql:select slotPath, out.value as 'Value', status as 'Status' from control:ControlPoint";

    for (final equipment in equipmentList) {
      final config = await _repository.createEquipmentConfig(
        stationId: stationId,
        equipmentName: equipment.name,
        equipmentPath: equipment.path,
        bqlQuery: defaultBql,
        pointPaths: equipment.pointPaths,
      );
      configs.add(config);
    }

    await loadConfigs();
    return configs;
  }

  Future<void> updateConfig({
    required String qrId,
    String? equipmentName,
    String? equipmentPath,
    String? bqlQuery,
    List<String>? pointPaths,
  }) async {
    await _repository.updateEquipmentConfig(
      qrId: qrId,
      equipmentName: equipmentName,
      equipmentPath: equipmentPath,
      bqlQuery: bqlQuery,
      pointPaths: pointPaths,
    );
    await loadConfigs();
  }

  Future<void> deleteConfig(String qrId) async {
    await _repository.deleteEquipmentConfig(qrId);
    await loadConfigs();
  }
}

final equipmentConfigNotifierProvider =
    StateNotifierProvider<EquipmentConfigNotifier, AsyncValue<List<EquipmentConfig>>>((ref) {
  final repository = ref.watch(equipmentConfigRepositoryProvider);
  return EquipmentConfigNotifier(repository);
});

