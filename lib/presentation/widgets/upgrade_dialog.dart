import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/subscription_service.dart';
import '../providers/subscription_provider.dart';

/// Dialog shown when user hits their equipment limit
class UpgradeDialog extends ConsumerWidget {
  final int currentCount;
  final String? message;

  const UpgradeDialog({
    super.key,
    required this.currentCount,
    this.message,
  });

  static Future<bool> show(
    BuildContext context, {
    required int currentCount,
    String? message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => UpgradeDialog(
        currentCount: currentCount,
        message: message,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionState = ref.watch(subscriptionStateProvider);
    final tier = subscriptionState.tier;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.warning),
          const SizedBox(width: 12),
          const Text('Equipment Limit Reached'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message ?? 'You\'ve reached the limit of ${tier.equipmentLimit} equipment items on the ${tier.displayName} plan.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upgrade to get more:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                if (tier == SubscriptionTier.free) ...[
                  _buildTierOption('Basic', '50 equipment', '\$3/mo'),
                  _buildTierOption('Pro', '100 equipment', '\$5/mo'),
                  _buildTierOption('Unlimited', 'No limits', '\$10/mo'),
                ] else if (tier == SubscriptionTier.basic) ...[
                  _buildTierOption('Pro', '100 equipment', '\$5/mo'),
                  _buildTierOption('Unlimited', 'No limits', '\$10/mo'),
                ] else if (tier == SubscriptionTier.pro) ...[
                  _buildTierOption('Unlimited', 'No limits', '\$10/mo'),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Maybe Later'),
        ),
        ElevatedButton(
          onPressed: () async {
            final notifier = ref.read(subscriptionStateProvider.notifier);
            final success = await notifier.showPaywall();
            if (context.mounted) {
              Navigator.pop(context, success);
            }
          },
          child: const Text('View Plans'),
        ),
      ],
    );
  }

  Widget _buildTierOption(String name, String limit, String price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check, size: 16, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$name - $limit',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            price,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
