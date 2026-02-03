import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../data/services/subscription_service.dart';

/// Provider for the subscription service singleton
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});

/// Provider for the current subscription state
final subscriptionStateProvider = StateNotifierProvider<SubscriptionStateNotifier, SubscriptionState>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  return SubscriptionStateNotifier(service);
});

/// Notifier for subscription state
class SubscriptionStateNotifier extends StateNotifier<SubscriptionState> {
  final SubscriptionService _service;

  SubscriptionStateNotifier(this._service) : super(const SubscriptionState()) {
    _init();
  }

  Future<void> _init() async {
    // Listen to customer info updates
    _service.addCustomerInfoUpdateListener((customerInfo) {
      _updateFromCustomerInfo(customerInfo);
    });
    // Load initial state
    await refresh();
  }

  void _updateFromCustomerInfo(CustomerInfo customerInfo) {
    final entitlements = customerInfo.entitlements.active;

    SubscriptionTier tier = SubscriptionTier.free;
    String? expirationDateString;

    if (entitlements.containsKey('unlimited')) {
      tier = SubscriptionTier.unlimited;
      expirationDateString = entitlements['unlimited']?.expirationDate;
    } else if (entitlements.containsKey('pro')) {
      tier = SubscriptionTier.pro;
      expirationDateString = entitlements['pro']?.expirationDate;
    } else if (entitlements.containsKey('basic')) {
      tier = SubscriptionTier.basic;
      expirationDateString = entitlements['basic']?.expirationDate;
    }

    state = SubscriptionState(
      tier: tier,
      isActive: tier != SubscriptionTier.free,
      expirationDateString: expirationDateString,
      customerInfo: customerInfo,
    );
  }

  /// Refresh subscription state
  Future<void> refresh() async {
    state = await _service.getSubscriptionState();
  }

  /// Show paywall and update state
  Future<bool> showPaywall() async {
    final success = await _service.showPaywall();
    if (success) {
      await refresh();
    }
    return success;
  }

  /// Restore purchases
  Future<void> restorePurchases() async {
    state = await _service.restorePurchases();
  }

  /// Identify user after login
  Future<void> identifyUser(String userId) async {
    await _service.identifyUser(userId);
    await refresh();
  }

  /// Log out
  Future<void> logOut() async {
    await _service.logOut();
    state = const SubscriptionState();
  }
}

/// Provider to check if user can add more equipment
final canAddEquipmentProvider = Provider.family<bool, int>((ref, currentCount) {
  final subscriptionState = ref.watch(subscriptionStateProvider);
  return subscriptionState.canAddEquipment(currentCount);
});

/// Provider for equipment limit
final equipmentLimitProvider = Provider<int>((ref) {
  final subscriptionState = ref.watch(subscriptionStateProvider);
  return subscriptionState.tier.equipmentLimit;
});
