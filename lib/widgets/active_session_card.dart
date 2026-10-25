import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/session.dart';
import '../models/table.dart';
import '../models/table_type_definition.dart';
import '../providers/company_module_provider.dart';
import '../providers/table_type_provider.dart';
import '../theme/app_theme.dart';
import 'animated_card.dart';
import 'occupied_table_timer_text.dart';

/// A rich, interactive card displaying an active table session on the dashboard.
///
/// Shows live timer, running charges, PTL badge, pause indicator,
/// order count badges, customer name, table type icon and hourly rate.
class ActiveSessionCard extends ConsumerWidget {
  final TableSession session;
  final SnookerTable? table;
  final VoidCallback? onTap;

  const ActiveSessionCard({
    super.key,
    required this.session,
    this.table,
    this.onTap,
  });

  /// Accent for the card border / highlights.
  Color _badgeColor(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sem = AppSemanticColors.of(context);
    if (session.isDining) {
      return sem.warning;
    }
    final hours = session.duration.inMinutes / 60.0;
    if (hours > 2) return cs.error;
    if (hours > 1) return sem.warning;
    return cs.primary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sem = AppSemanticColors.of(context);
    final isMobile = AppTheme.isMobile(context);
    final badgeColor = _badgeColor(context);
    final venueKind = ref.watch(venueKindProvider);
    final typeId = table?.typeId ?? venueKind.defaultTableTypeId;
    final typeDef = ref
        .watch(tableTypeDefinitionsProvider)
        .maybeWhen(
          data: (defs) =>
              resolveTableTypeForDisplay(defs, typeId, venueKind: venueKind),
          orElse: () => null,
        );
    final typeIcon = tableTypeIconFromKey(typeDef?.iconKey);
    final containerWidth = isMobile ? 200.0 : 260.0;

    final int linkedOrderCount = session.linkedOrderDocumentCount;
    final bool hasOrderCharges =
        session.hasCafeBillActivity || session.hasMerchandiseBillActivity;
    final bool showOrderBadge = linkedOrderCount > 0 || hasOrderCharges;
    final String orderBadgeLabel = linkedOrderCount > 0
        ? '$linkedOrderCount order${linkedOrderCount != 1 ? 's' : ''}'
        : 'Orders';
    final String tableName = table?.name ?? session.tableName;
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return AnimatedCard(
      onTap: onTap,
      elevation: 2,
      padding: EdgeInsets.zero,
      child: Container(
        width: containerWidth,
        padding: EdgeInsets.all(isMobile ? 10 : 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
          border: Border.all(
            color: badgeColor.withValues(alpha: 0.5),
            width: 1.5,
          ),
          gradient: LinearGradient(
            colors: [
              badgeColor.withValues(alpha: 0.06),
              theme.colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---- Row 1: Table name + type icon + pause/PTL badges ----
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 5 : 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    typeIcon,
                    color: badgeColor,
                    size: isMobile ? 16 : 20,
                  ),
                ),
                SizedBox(width: isMobile ? 6 : 8),
                Expanded(
                  child: Text(
                    tableName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 13 : 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (session.isDining) ...[
                  SizedBox(width: isMobile ? 4 : 6),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 4 : 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: sem.warningContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: sem.warning.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: isMobile ? 10 : 12,
                          color: sem.warning,
                        ),
                        SizedBox(width: 2),
                        Text(
                          'DINING',
                          style: TextStyle(
                            fontSize: isMobile ? 7 : 9,
                            fontWeight: FontWeight.w700,
                            color: sem.onWarningContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (session.isGaming && session.isOnBreak)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 4 : 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: sem.infoContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: sem.info.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.coffee_rounded,
                          size: isMobile ? 10 : 12,
                          color: sem.info,
                        ),
                        SizedBox(width: 2),
                        Text(
                          'On Break',
                          style: TextStyle(
                            fontSize: isMobile ? 8 : 10,
                            fontWeight: FontWeight.w600,
                            color: sem.onInfoContainer,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (session.isGaming && session.isPaused)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 4 : 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: sem.warningContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: sem.warning.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pause_circle_filled,
                          size: isMobile ? 10 : 12,
                          color: sem.warning,
                        ),
                        SizedBox(width: 2),
                        Text(
                          'Paused',
                          style: TextStyle(
                            fontSize: isMobile ? 8 : 10,
                            fontWeight: FontWeight.w600,
                            color: sem.onWarningContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: isMobile ? 6 : 8),

            // ---- Row 2: Customer name ----
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: isMobile ? 13 : 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    session.customerName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: isMobile ? 11 : 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 8 : 10),

            // ---- Row 3: Live timer (gaming) or order total (dining) ----
            Center(
              child: session.isGaming
                  ? OccupiedTableTimerText(
                      startTime: session.startTime,
                      isPaused: session.isPaused,
                      pausedAt: session.pausedAt,
                      totalPausedSeconds: session.totalPausedSeconds,
                      isOnBreak: session.isOnBreak,
                      breakStartedAt: session.breakStartedAt,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 20 : 24,
                        color: badgeColor,
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Order total',
                          style: TextStyle(
                            fontSize: isMobile ? 9 : 10,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          currencyFormat.format(session.combinedOrderAmount),
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ],
                    ),
            ),
            SizedBox(height: isMobile ? 8 : 10),

            // ---- Row 4: Running table charges (gaming) or F&B breakdown (dining) ----
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.isDining ? 'Linked orders' : 'Table (est.)',
                      style: TextStyle(
                        fontSize: isMobile ? 8 : 9,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      currencyFormat.format(
                        session.isDining
                            ? session.combinedOrderAmount
                            : session.tableCharges,
                      ),
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 15,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 6 : 8,
                    vertical: isMobile ? 2 : 3,
                  ),
                  decoration: BoxDecoration(
                    color: session.isDining
                        ? sem.warningContainer
                        : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                    border: session.isDining
                        ? Border.all(
                            color: sem.warning.withValues(alpha: 0.45),
                          )
                        : null,
                  ),
                  child: Text(
                    session.isDining
                        ? 'No time charge'
                        : '${currencyFormat.format(session.hourlyRate)}/hr',
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 10,
                      fontWeight: FontWeight.w600,
                      color: session.isDining
                          ? sem.onWarningContainer
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 6 : 8),

            // ---- Row 5: Badges row (PTL, orders) ----
            Row(
              children: [
                // PTL badge (gaming only in practice)
                if (session.isGaming && session.isPTL) ...[
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 5 : 7,
                      vertical: isMobile ? 2 : 3,
                    ),
                    decoration: BoxDecoration(
                      color: cs.tertiaryContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: cs.tertiary.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sports_esports_rounded,
                          size: isMobile ? 10 : 12,
                          color: cs.onTertiaryContainer,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'PTL ${session.playerCount ?? '-'}P',
                          style: TextStyle(
                            fontSize: isMobile ? 8 : 10,
                            fontWeight: FontWeight.w600,
                            color: cs.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: isMobile ? 4 : 6),
                ],
                // Orders badge (counts linked ids; falls back when totals exist but ids are stale)
                if (showOrderBadge)
                  Tooltip(
                    message: linkedOrderCount == 0 && hasOrderCharges
                        ? 'Open session for order details'
                        : 'Orders on this session',
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 5 : 7,
                        vertical: isMobile ? 2 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: isMobile ? 10 : 12,
                            color: cs.primary,
                          ),
                          SizedBox(width: 3),
                          Text(
                            orderBadgeLabel,
                            style: TextStyle(
                              fontSize: isMobile ? 8 : 10,
                              fontWeight: FontWeight.w600,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Unbilled warning
                if (session.hasUnbilledOrders) ...[
                  SizedBox(width: isMobile ? 4 : 6),
                  Tooltip(
                    message: 'Has unbilled orders',
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: isMobile ? 14 : 16,
                      color: sem.warning,
                    ),
                  ),
                ],
                const Spacer(),
                // Start time
                Text(
                  DateFormat.jm().format(session.startTime),
                  style: TextStyle(
                    fontSize: isMobile ? 8 : 10,
                    color: cs.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
