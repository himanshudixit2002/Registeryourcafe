import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/promotion.dart';
import '../../providers/promotion_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';
import 'create_promotion_screen.dart';

class PromotionListScreen extends ConsumerWidget {
  const PromotionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final promosAsync = ref.watch(promotionsProvider);
    final isDesktop = AppTheme.isDesktop(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Promotions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => const CreatePromotionScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: promosAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (promos) {
          if (promos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_offer_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No promotions',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to create your first promotion.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            physics: AppTheme.scrollPhysicsFor(context),
            padding: EdgeInsets.fromLTRB(
              isDesktop
                  ? AppTheme.kSpacingXLarge
                  : AppTheme.kSpacingMedium,
              AppTheme.kSpacingMedium,
              isDesktop
                  ? AppTheme.kSpacingXLarge
                  : AppTheme.kSpacingMedium,
              AppTheme.kSpacingXLarge +
                  MediaQuery.paddingOf(context).bottom +
                  80,
            ),
            itemCount: promos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) =>
                _PromoCard(promo: promos[i]),
          );
        },
      ),
    );
  }
}

class _PromoCard extends ConsumerWidget {
  final Promotion promo;
  const _PromoCard({required this.promo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final active = promo.isCurrentlyActive;
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: active
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            promo.type == PromotionType.happyHour
                ? Icons.access_time
                : Icons.local_offer,
            color: active
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
        title: Text(
          promo.name,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${promo.type.label} \u2022 ${_valueLabel(promo)}'),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (active
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    active ? 'Active' : 'Inactive',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: active
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (promo.couponCode != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Code: ${promo.couponCode}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Switch(
          value: promo.isActive,
          onChanged: (v) async {
            try {
              final service = ref.read(promotionServiceProvider);
              if (service == null) return;
              await service.toggleActive(promo.id, v);
            } catch (e) {
              if (context.mounted) {
                context.showErrorSnackbar('Failed: $e');
              }
            }
          },
        ),
        isThreeLine: true,
      ),
    );
  }

  String _valueLabel(Promotion p) {
    switch (p.type) {
      case PromotionType.percentageDiscount:
        return '${p.value.toStringAsFixed(0)}% off';
      case PromotionType.flatDiscount:
        return '\u20B9${p.value.toStringAsFixed(0)} off';
      case PromotionType.happyHour:
        return '${p.value.toStringAsFixed(0)}% off (${p.startHour ?? ''}-${p.endHour ?? ''})';
      case PromotionType.buyXGetY:
        return 'Buy ${p.value.toInt()} get 1 free';
      case PromotionType.couponCode:
        return '${p.value.toStringAsFixed(0)}% off with code';
    }
  }
}
