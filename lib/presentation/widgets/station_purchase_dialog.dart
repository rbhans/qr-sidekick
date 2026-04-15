import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../providers/station_purchase_provider.dart';

/// Dialog shown when user needs to purchase a station slot
class StationPurchaseDialog extends ConsumerWidget {
  const StationPurchaseDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const StationPurchaseDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchaseState = ref.watch(stationPurchaseStateProvider);
    final price = purchaseState.formattedPrice;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Row(
        children: [
          Icon(Icons.dns, color: AppColors.primary),
          SizedBox(width: 12),
          Text('Station Slot Required'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Purchase a station slot to add a new Niagara station.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.dns, size: 20, color: AppColors.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Station Slot',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        'One-time purchase per station',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (price != null)
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () async {
                final count = await ref
                    .read(stationPurchaseStateProvider.notifier)
                    .restorePurchases();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(count > 0
                          ? 'Restored $count station slot${count > 1 ? 's' : ''}'
                          : 'No purchases to restore'),
                    ),
                  );
                  if (count > 0) {
                    Navigator.pop(context, true);
                  }
                }
              },
              child: const Text(
                'Restore Purchases',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final notifier = ref.read(stationPurchaseStateProvider.notifier);
            final success = await notifier.purchaseStationSlot();
            if (context.mounted) {
              Navigator.pop(context, success);
            }
          },
          child: Text(price != null ? 'Purchase for $price' : 'Purchase'),
        ),
      ],
    );
  }
}
