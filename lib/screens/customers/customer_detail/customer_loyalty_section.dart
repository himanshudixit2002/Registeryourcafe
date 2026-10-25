import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../auth/permission_id.dart';
import '../../../models/customer.dart';
import '../../../providers/loyalty_provider.dart';
import '../../../providers/permissions_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_panel.dart';
import '../../../widgets/section_async_error.dart';
import '../../loyalty/components/convert_points_dialog.dart';

/// Loyalty points balance, convert CTA, and recent conversions.
class CustomerLoyaltySection extends ConsumerWidget {
  const CustomerLoyaltySection({super.key, required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final canUseLoyalty =
        ref.watchResolvedPermissions().can(PermissionIds.navLoyalty);
    final canConvertPts =
        ref.watchResolvedPermissions().canConvertLoyaltyPoints();
    final pointsAsync = ref.watch(customerLoyaltyPointsProvider(customer.id));
    final settingsAsync = ref.watch(loyaltySettingsProvider);
    final conversionsAsync = ref.watch(
      customerConversionsProvider(customer.id),
    );

    return AppSurface(
      padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.card_giftcard,
                color: theme.colorScheme.tertiary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Loyalty Points',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.kSpacingMedium),
          pointsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (e, _) => SectionAsyncError(error: e),
            data: (points) {
              final settings = settingsAsync.valueOrNull;
              final canConvert =
                  canUseLoyalty &&
                  canConvertPts &&
                  settings != null &&
                  settings.isEnabled &&
                  points >= settings.minimumPointsToConvert;
              final maxUnits = settings != null
                  ? (points / settings.pointsPerConversion).floor()
                  : 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer
                          .withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(
                        AppTheme.kBorderRadiusMedium,
                      ),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.stars_rounded,
                          color: theme.colorScheme.onTertiaryContainer,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Points',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onTertiaryContainer
                                      .withValues(alpha: 0.85),
                                ),
                              ),
                              Text(
                                points.toStringAsFixed(0),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canConvert)
                          ElevatedButton.icon(
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                builder: (_) => ConvertPointsDialog(
                                  customerId: customer.id,
                                  customerName: customer.name,
                                ),
                              );
                            },
                            icon: const Icon(Icons.swap_horiz, size: 18),
                            label: const Text('Convert'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.kBorderRadiusSmall,
                                ),
                              ),
                            ),
                          )
                        else if (settings != null && settings.isEnabled)
                          Text(
                            !canUseLoyalty
                                ? 'No access to loyalty'
                                : !canConvertPts
                                    ? 'No permission to convert points'
                                    : 'Need ${settings.minimumPointsToConvert} pts',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (settings != null && canConvert) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Can convert up to ${maxUnits * settings.pointsPerConversion} pts '
                      '→ ${(maxUnits * settings.creditsPerConversion).toStringAsFixed(0)} credits',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          conversionsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (conversions) {
              if (conversions.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  Text(
                    'Recent Conversions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...conversions
                      .take(3)
                      .map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.swap_horiz,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.65),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${c.pointsConverted.toStringAsFixed(0)} pts → '
                                '${c.creditsAwarded.toStringAsFixed(0)} cr',
                                style: const TextStyle(fontSize: 13),
                              ),
                              const Spacer(),
                              Text(
                                DateFormat('dd MMM').format(c.convertedAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
