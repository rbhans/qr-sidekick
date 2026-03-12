import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/env_config.dart';

void _log(String message) {
  if (kDebugMode) {
    debugPrint('StationPurchaseService: $message');
  }
}

/// State representing how many station slots the user has purchased
class StationPurchaseState {
  final int purchasedSlots;
  final Package? stationSlotPackage;

  const StationPurchaseState({
    this.purchasedSlots = 0,
    this.stationSlotPackage,
  });

  bool canAddStation(int activeStationCount) {
    return activeStationCount < purchasedSlots;
  }

  String? get formattedPrice => stationSlotPackage?.storeProduct.priceString;
}

/// Service for managing per-station purchases via RevenueCat
class StationPurchaseService {
  static const String _productId = 'station_slot';
  static const String _offeringId = 'default';

  bool _isInitialized = false;

  /// Initialize RevenueCat SDK
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Purchases.setLogLevel(LogLevel.debug);

      final apiKey = _apiKeyForPlatform();
      if (apiKey.isEmpty) {
        _log('RevenueCat API key missing for this platform.');
        return;
      }

      await Purchases.configure(PurchasesConfiguration(apiKey));
      _isInitialized = true;
    } catch (e) {
      _log('RevenueCat initialization failed: $e');
    }
  }

  String _apiKeyForPlatform() {
    if (Platform.isIOS) {
      return EnvConfig.revenueCatIosApiKey;
    }
    if (Platform.isAndroid) {
      return EnvConfig.revenueCatAndroidApiKey;
    }
    return '';
  }

  /// Get current purchase state from Supabase profile
  Future<StationPurchaseState> getState() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return const StationPurchaseState();

      final response = await client
          .from('profiles')
          .select('purchased_station_slots')
          .eq('id', userId)
          .maybeSingle();

      final slots = (response?['purchased_station_slots'] as int?) ?? 0;

      // Also fetch the package for price display
      final package = await _getStationSlotPackage();

      return StationPurchaseState(
        purchasedSlots: slots,
        stationSlotPackage: package,
      );
    } catch (e) {
      _log('Error getting purchase state: $e');
      return const StationPurchaseState();
    }
  }

  /// Get the station slot package from RevenueCat offerings
  Future<Package?> _getStationSlotPackage() async {
    try {
      final offerings = await Purchases.getOfferings();
      final offering = offerings.getOffering(_offeringId) ?? offerings.current;
      if (offering == null) return null;

      // Find the station_slot package
      for (final package in offering.availablePackages) {
        if (package.storeProduct.identifier == _productId) {
          return package;
        }
      }
      // Fallback: return the first available package
      return offering.availablePackages.isNotEmpty
          ? offering.availablePackages.first
          : null;
    } catch (e) {
      _log('Error fetching offerings: $e');
      return null;
    }
  }

  /// Purchase a station slot. Returns true if purchase succeeded.
  Future<bool> purchaseStationSlot() async {
    try {
      final package = await _getStationSlotPackage();
      if (package == null) {
        _log('No station_slot package found in offerings');
        return false;
      }

      await Purchases.purchase(PurchaseParams.package(package));

      // Increment purchased_station_slots in Supabase
      await _incrementSlots();

      return true;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        _log('Purchase cancelled by user');
      } else {
        _log('Purchase error: $e');
      }
      return false;
    } catch (e) {
      _log('Error purchasing station slot: $e');
      return false;
    }
  }

  /// Increment purchased_station_slots in Supabase
  Future<void> _incrementSlots({int count = 1}) async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      // Use RPC or read-modify-write
      final response = await client
          .from('profiles')
          .select('purchased_station_slots')
          .eq('id', userId)
          .single();

      final currentSlots = (response['purchased_station_slots'] as int?) ?? 0;

      await client.from('profiles').update({
        'purchased_station_slots': currentSlots + count,
      }).eq('id', userId);
    } catch (e) {
      _log('Error incrementing slots: $e');
      rethrow;
    }
  }

  /// Restore purchases and sync slot count from RevenueCat transaction history
  Future<int> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();

      // Count station_slot transactions
      final slotCount = customerInfo.nonSubscriptionTransactions
          .where((t) => t.productIdentifier == _productId)
          .length;

      // Sync to Supabase
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId != null && slotCount > 0) {
        await client.from('profiles').update({
          'purchased_station_slots': slotCount,
        }).eq('id', userId);
      }

      return slotCount;
    } catch (e) {
      _log('Error restoring purchases: $e');
      return 0;
    }
  }

  /// Identify user (call after login)
  Future<void> identifyUser(String userId) async {
    try {
      await Purchases.logIn(userId);
    } catch (e) {
      _log('Error identifying user: $e');
    }
  }

  /// Log out user
  Future<void> logOut() async {
    try {
      await Purchases.logOut();
    } catch (e) {
      _log('Error logging out from RevenueCat: $e');
    }
  }

  /// Add listener for customer info updates
  void addCustomerInfoUpdateListener(void Function(CustomerInfo) listener) {
    Purchases.addCustomerInfoUpdateListener(listener);
  }
}
