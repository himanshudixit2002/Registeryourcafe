import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';

class GuestLoyaltyScreen extends ConsumerWidget {
  const GuestLoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pad = AppTheme.isDesktop(context)
        ? AppTheme.kSpacingXLarge
        : AppTheme.kSpacingMedium;

    return Scaffold(
      appBar: AppBar(title: const Text('Loyalty rewards')),
      body: SingleChildScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: EdgeInsets.fromLTRB(pad, 16, pad, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              child: Column(
                children: [
                  Icon(Icons.workspace_premium,
                      color: theme.colorScheme.tertiary, size: 48),
                  const SizedBox(height: 8),
                  Text('Bronze Tier',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  AnimatedCountUp(
                    endValue: 0,
                    suffix: ' points',
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: 0,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                  Text('0 / 1000 points to Silver',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Tier benefits',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            FadeInWidget(
              delay: const Duration(milliseconds: 100),
              child: _TierCard(
                name: 'Bronze',
                pts: '0 pts',
                color: theme.colorScheme.onSurfaceVariant,
                benefits: ['Basic rewards', 'Birthday bonus'],
              ),
            ),
            const SizedBox(height: 8),
            FadeInWidget(
              delay: const Duration(milliseconds: 200),
              child: _TierCard(
              name: 'Silver',
              pts: '1,000 pts',
              color: theme.colorScheme.outline,
              benefits: ['5% cashback', 'Priority booking', 'Free upgrades'],
            ),
            ),
            const SizedBox(height: 8),
            FadeInWidget(
              delay: const Duration(milliseconds: 300),
              child: _TierCard(
              name: 'Gold',
              pts: '5,000 pts',
              color: theme.colorScheme.tertiary,
              benefits: ['10% cashback', 'VIP access', 'Exclusive events'],
            ),
            ),
            const SizedBox(height: 8),
            FadeInWidget(
              delay: const Duration(milliseconds: 400),
              child: _TierCard(
              name: 'Platinum',
              pts: '10,000 pts',
              color: theme.colorScheme.onSurfaceVariant,
              benefits: [
                '15% cashback',
                'Personal concierge',
                'All benefits',
              ],
            ),
            ),
            const SizedBox(height: 24),
            Text('Earn points',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const _EarnRule(
                icon: Icons.receipt,
                title: 'Place an order',
                subtitle: '1 point per \u20B910 spent'),
            const SizedBox(height: 6),
            const _EarnRule(
                icon: Icons.rate_review,
                title: 'Write a review',
                subtitle: '50 points per review'),
            const SizedBox(height: 6),
            const _EarnRule(
                icon: Icons.share,
                title: 'Refer a friend',
                subtitle: '100 points per referral'),
            const SizedBox(height: 6),
            const _EarnRule(
                icon: Icons.event_seat,
                title: 'Book a table',
                subtitle: '25 points per booking'),
            const SizedBox(height: 6),
            const _EarnRule(
                icon: Icons.cake,
                title: 'Birthday visit',
                subtitle: '200 bonus points'),
            const SizedBox(height: 6),
            const _EarnRule(
                icon: Icons.local_fire_department,
                title: 'Visit streak',
                subtitle: '50 points per day streak'),
            const SizedBox(height: 24),
            Text('Redeem',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            AppCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.redeem,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text('Earn more points to unlock rewards',
                          style: theme.textTheme.titleSmall),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final String name;
  final String pts;
  final Color color;
  final List<String> benefits;

  const _TierCard({
    required this.name,
    required this.pts,
    required this.color,
    required this.benefits,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.workspace_premium, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Text(pts,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
                const SizedBox(height: 4),
                for (final b in benefits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Icon(Icons.check,
                            size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(b, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EarnRule extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EarnRule({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Text(subtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
