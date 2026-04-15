import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/config/env_config.dart';
import 'data/datasources/supabase_datasource.dart';
import 'data/services/station_purchase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment configuration from .env file
  await EnvConfig.load();

  // Initialize Supabase
  await initializeSupabase();

  // Initialize RevenueCat
  final stationPurchaseService = StationPurchaseService();
  await stationPurchaseService.initialize();

  runApp(
    const ProviderScope(
      child: QRSidekickApp(),
    ),
  );
}
