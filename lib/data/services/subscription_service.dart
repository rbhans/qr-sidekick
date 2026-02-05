import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../../core/config/env_config.dart';

void _log(String message) {
  if (kDebugMode) {
    debugPrint('SubscriptionService: $message');
  }
}

/// Subscription tier based on equipment limits
enum SubscriptionTier {
  free,      // 1 equipment max
  basic,     // 50 equipment, $3/mo
  pro,       // 100 equipment, $5/mo
  unlimited, // Unlimited, $10/mo
}

/// Extension to get equipment limits for each tier
extension SubscriptionTierLimits on SubscriptionTier {
  int get equipmentLimit {
    switch (this) {
      case SubscriptionTier.free:
        return 1;
      case SubscriptionTier.basic:
        return 50;
      case SubscriptionTier.pro:
        return 100;
      case SubscriptionTier.unlimited:
        return -1; // Unlimited
    }
  }

  String get displayName {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.basic:
        return 'Basic';
      case SubscriptionTier.pro:
        return 'Pro';
      case SubscriptionTier.unlimited:
        return 'Unlimited';
    }
  }

  String get description {
    switch (this) {
      case SubscriptionTier.free:
        return '1 equipment max';
      case SubscriptionTier.basic:
        return '50 equipment • \$3/mo';
      case SubscriptionTier.pro:
        return '100 equipment • \$5/mo';
      case SubscriptionTier.unlimited:
        return 'Unlimited • \$10/mo';
    }
  }
}

/// Subscription state
class SubscriptionState {
  final SubscriptionTier tier;
  final bool isActive;
  final String? expirationDateString;
  final CustomerInfo? customerInfo;

  const SubscriptionState({
    this.tier = SubscriptionTier.free,
    this.isActive = false,
    this.expirationDateString,
    this.customerInfo,
  });

  bool canAddEquipment(int currentCount) {
    if (tier == SubscriptionTier.unlimited) return true;
    return currentCount < tier.equipmentLimit;
  }

  int get remainingSlots {
    if (tier == SubscriptionTier.unlimited) return -1;
    return tier.equipmentLimit;
  }
}

/// Service for managing RevenueCat subscriptions
class SubscriptionService {
  // Entitlement IDs from RevenueCat dashboard
  static const String _basicEntitlement = 'basic';
  static const String _proEntitlement = 'pro';
  static const String _unlimitedEntitlement = 'unlimited';

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
      // Avoid crashing the app if RevenueCat isn't configured correctly.
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

  /// Get current subscription state
  Future<SubscriptionState> getSubscriptionState() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return _parseCustomerInfo(customerInfo);
    } catch (e) {
      _log('Error getting subscription state: $e');
      return const SubscriptionState();
    }
  }

  /// Parse customer info to determine tier
  SubscriptionState _parseCustomerInfo(CustomerInfo customerInfo) {
    final entitlements = customerInfo.entitlements.active;

    SubscriptionTier tier = SubscriptionTier.free;
    String? expirationDateString;

    // Check entitlements in order of highest tier
    if (entitlements.containsKey(_unlimitedEntitlement)) {
      tier = SubscriptionTier.unlimited;
      expirationDateString = entitlements[_unlimitedEntitlement]?.expirationDate;
    } else if (entitlements.containsKey(_proEntitlement)) {
      tier = SubscriptionTier.pro;
      expirationDateString = entitlements[_proEntitlement]?.expirationDate;
    } else if (entitlements.containsKey(_basicEntitlement)) {
      tier = SubscriptionTier.basic;
      expirationDateString = entitlements[_basicEntitlement]?.expirationDate;
    }

    return SubscriptionState(
      tier: tier,
      isActive: tier != SubscriptionTier.free,
      expirationDateString: expirationDateString,
      customerInfo: customerInfo,
    );
  }

  /// Show the RevenueCat paywall
  Future<bool> showPaywall() async {
    try {
      final paywallResult = await RevenueCatUI.presentPaywallIfNeeded(_basicEntitlement);
      return paywallResult == PaywallResult.purchased ||
             paywallResult == PaywallResult.restored;
    } catch (e) {
      _log('Error showing paywall: $e');
      return false;
    }
  }

  /// Restore purchases
  Future<SubscriptionState> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      return _parseCustomerInfo(customerInfo);
    } catch (e) {
      _log('Error restoring purchases: $e');
      return const SubscriptionState();
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
