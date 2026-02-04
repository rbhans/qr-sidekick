import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/station.dart';
import '../../data/repositories/station_repository.dart';

/// Station repository provider
final stationRepositoryProvider = Provider<StationRepository>((ref) {
  return StationRepository(Supabase.instance.client);
});

/// Stations list provider
final stationsProvider = FutureProvider<List<Station>>((ref) async {
  final repository = ref.watch(stationRepositoryProvider);
  return repository.getStations();
});

/// Single station provider
final stationProvider = FutureProvider.family<Station?, String>((ref, id) async {
  final repository = ref.watch(stationRepositoryProvider);
  return repository.getStation(id);
});

/// Station management notifier
class StationNotifier extends StateNotifier<AsyncValue<List<Station>>> {
  final StationRepository _repository;
  final Ref _ref;

  StationNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadStations();
  }

  Future<void> loadStations() async {
    state = const AsyncValue.loading();
    try {
      final stations = await _repository.getStations();
      state = AsyncValue.data(stations);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Station> createStation({
    required String name,
    required String host,
    int port = 443,
    StationProtocol protocol = StationProtocol.https,
  }) async {
    final station = await _repository.createStation(
      name: name,
      host: host,
      port: port,
      protocol: protocol,
    );
    await loadStations();
    return station;
  }

  Future<void> updateStation({
    required String id,
    String? name,
    String? host,
    int? port,
    StationProtocol? protocol,
  }) async {
    await _repository.updateStation(
      id: id,
      name: name,
      host: host,
      port: port,
      protocol: protocol,
    );
    await loadStations();
  }

  Future<void> deleteStation(String id) async {
    await _repository.deleteStation(id);
    await loadStations();
  }
}

final stationNotifierProvider =
    StateNotifierProvider<StationNotifier, AsyncValue<List<Station>>>((ref) {
  final repository = ref.watch(stationRepositoryProvider);
  return StationNotifier(repository, ref);
});
