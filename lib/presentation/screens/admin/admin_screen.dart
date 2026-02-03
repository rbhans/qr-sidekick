import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/subscription_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';

/// Admin dashboard screen - manage stations, equipment, and settings
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final profile = authState.profile;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text(
          '[ ADMIN ]',
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // User info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                      ),
                      child: Center(
                        child: Text(
                          (profile?.displayName ?? user?.email ?? 'U')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.background,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.displayName ?? 'Admin',
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Subscription section
            const Text(
              '[ SUBSCRIPTION ]',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            _SubscriptionCard(),
            const SizedBox(height: 24),

            // Management section
            const Text(
              '[ MANAGEMENT ]',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),

            _AdminCard(
              icon: Icons.dns,
              title: 'Stations',
              subtitle: 'Connect to Niagara stations',
              color: AppColors.secondary,
              onTap: () => context.push('/admin/stations'),
            ),
            const SizedBox(height: 12),

            _AdminCard(
              icon: Icons.qr_code_2,
              title: 'Equipment & QR Codes',
              subtitle: 'Configure equipment and generate QR codes',
              color: AppColors.primary,
              onTap: () => context.push('/admin/equipment'),
            ),
            const SizedBox(height: 24),

            // Settings section
            const Text(
              '[ SETTINGS ]',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),

            _AdminCard(
              icon: Icons.person_outline,
              title: 'Account',
              subtitle: 'Manage your profile and password',
              color: AppColors.textSecondary,
              onTap: () => context.push('/account'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Subscription status card widget
class _SubscriptionCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionState = ref.watch(subscriptionStateProvider);
    final tier = subscriptionState.tier;

    final Color tierColor;
    final IconData tierIcon;

    switch (tier) {
      case SubscriptionTier.unlimited:
        tierColor = AppColors.primary;
        tierIcon = Icons.all_inclusive;
        break;
      case SubscriptionTier.pro:
        tierColor = AppColors.secondary;
        tierIcon = Icons.workspace_premium;
        break;
      case SubscriptionTier.basic:
        tierColor = AppColors.info;
        tierIcon = Icons.star;
        break;
      case SubscriptionTier.free:
      default:
        tierColor = AppColors.success;
        tierIcon = Icons.card_giftcard;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    tierIcon,
                    color: tierColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        tier.description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (tier == SubscriptionTier.free)
                  ElevatedButton(
                    onPressed: () async {
                      await ref.read(subscriptionStateProvider.notifier).showPaywall();
                    },
                    child: const Text('Upgrade'),
                  )
                else
                  TextButton(
                    onPressed: () async {
                      await ref.read(subscriptionStateProvider.notifier).showPaywall();
                    },
                    child: const Text('Manage'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Restore purchases link
            TextButton(
              onPressed: () async {
                await ref.read(subscriptionStateProvider.notifier).restorePurchases();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Purchases restored')),
                  );
                }
              },
              child: const Text(
                'Restore Purchases',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Admin action card widget
class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
