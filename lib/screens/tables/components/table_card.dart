import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/customer.dart';
import '../../../models/session.dart';
import '../../../models/table.dart';
import '../../../models/table_type_definition.dart';
import '../../../models/venue_kind.dart';
import '../../../models/venue_ui_config.dart';
import '../../../providers/table_type_provider.dart';
import '../../../providers/customer_provider.dart';
import '../../../providers/company_module_provider.dart';
import '../../../providers/table_provider.dart';
import '../../../providers/tenant_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/app_logger.dart';
import '../../../widgets/occupied_table_timer_text.dart';

/// Foreground on saturated custom fills (type chip, footer pressed) without hardcoded [Colors.white].
Color _contrastOnFill(Color fill, ColorScheme cs) {
  return fill.computeLuminance() < 0.5 ? cs.onPrimary : cs.onSurface;
}

class TableCard extends ConsumerStatefulWidget {
  final SnookerTable table;
  final VoidCallback onTap;

  const TableCard({super.key, required this.table, required this.onTap});

  @override
  ConsumerState<TableCard> createState() => _TableCardState();
}

class _TableCardState extends ConsumerState<TableCard> {
  bool _isPressed = false;
  bool _autoResumeInProgress = false;

  SnookerTable get table => widget.table;

  void _handleTapDown(TapDownDetails details) {
    if (!mounted) return;
    setState(() => _isPressed = true);
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!mounted) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (!mounted) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = AppTheme.isMobile(context);
    final isOccupied = table.status == TableStatus.occupied;
    final isMaintenance = table.status == TableStatus.maintenance;
    final isAvailable = table.status == TableStatus.available;
    final venueKind = ref.watch(venueKindProvider);
    final typeLabel = ref
        .watch(tableTypeDefinitionsProvider)
        .maybeWhen(
          data: (defs) => resolveTableTypeDisplayLabel(
            defs,
            table.typeId,
            venueKind: venueKind,
          ).toUpperCase(),
          orElse: () => table.typeId.toUpperCase(),
        );

    final cs = theme.colorScheme;
    // Enhanced colors for better visibility
    final Color statusColor = isOccupied
        ? const Color(0xFF5D4037) // Warm brown for occupied
        : isMaintenance
        ? cs.outline
        : const Color(0xFF43A047); // Fresh green for available

    final borderColor = _isPressed
        ? statusColor.withValues(alpha: 1.0)
        : isOccupied
        ? statusColor.withValues(alpha: 0.7)
        : isMaintenance
        ? cs.outline.withValues(alpha: 0.55)
        : statusColor.withValues(alpha: 0.4);

    final cardColor = _isPressed
        ? statusColor.withValues(alpha: isOccupied ? 0.18 : 0.12)
        : isOccupied
        ? statusColor.withValues(alpha: 0.08)
        : isMaintenance
        ? cs.surfaceContainerHighest.withValues(alpha: 0.45)
        : cs.surface;

    // Gradient overlay for press state
    final Gradient? pressGradient = _isPressed
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              statusColor.withValues(alpha: 0.15),
              statusColor.withValues(alpha: 0.05),
            ],
          )
        : null;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.92 + (0.08 * value.clamp(0.0, 1.0)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.all(
              isMobile ? AppTheme.kSpacingSmall : AppTheme.kSpacingSmall + 4,
            ),
            decoration: BoxDecoration(
              color: cardColor,
              gradient: pressGradient,
              borderRadius: BorderRadius.circular(
                isMobile ? 14 : AppTheme.kBorderRadiusLarge,
              ),
              border: Border.all(
                color: borderColor,
                width: _isPressed ? 2.5 : (isMobile ? 2 : 1.5),
              ),
              boxShadow: [
                // Primary shadow
                BoxShadow(
                  color: _isPressed
                      ? statusColor.withValues(alpha: 0.35)
                      : isOccupied
                      ? statusColor.withValues(alpha: 0.2)
                      : cs.shadow.withValues(alpha: 0.12),
                  blurRadius: _isPressed ? 16 : (isOccupied ? 12 : 8),
                  spreadRadius: _isPressed ? 2 : (isOccupied ? 1 : 0),
                  offset: Offset(0, _isPressed ? 2 : 4),
                ),
                // Glow effect on press
                if (_isPressed)
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.25),
                    blurRadius: 20,
                    spreadRadius: 0,
                  ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardContent = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(
                      context,
                      theme,
                      isOccupied,
                      isMobile,
                      statusColor,
                      typeLabel,
                    ),
                    Flexible(
                      fit: FlexFit.loose,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: isMobile ? 6 : 10,
                        ),
                        child: _buildBody(
                          context,
                          ref,
                          theme,
                          isOccupied,
                          isMobile,
                          statusColor,
                        ),
                      ),
                    ),
                    _buildFooter(
                      theme,
                      isOccupied,
                      isMobile,
                      statusColor,
                      isAvailable,
                    ),
                  ],
                );

                if (!isMobile) return cardContent;

                return Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 4,
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight > 0 ? constraints.maxHeight * 0.6 : 40,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: cardContent),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    bool isOccupied,
    bool isMobile,
    Color statusColor,
    String typeLabel,
  ) {
    final cs = theme.colorScheme;
    final typeChipFill = _isPressed
        ? statusColor
        : (isOccupied ? statusColor.withValues(alpha: 0.85) : statusColor);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 140;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                table.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 15 : 18,
                  color: isOccupied ? statusColor : theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            SizedBox(width: isMobile ? 4 : AppTheme.kSpacingXSmall),
            Flexible(
              flex: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (table.tablePurpose == TablePurpose.dining)
                    Padding(
                      padding: EdgeInsets.only(right: isMobile ? 4 : 6),
                      child: Icon(
                        Icons.restaurant_menu,
                        size: isMobile ? 14 : 16,
                        color: isOccupied
                            ? statusColor
                            : theme.colorScheme.primary,
                      ),
                    ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 6 : 8,
                      vertical: isMobile ? 3 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isPressed
                          ? statusColor
                          : (isOccupied
                                ? statusColor.withValues(alpha: 0.85)
                                : statusColor),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: _isPressed
                          ? [
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.4),
                                blurRadius: 4,
                                spreadRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      typeLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: isMobile ? 9 : 10,
                        color: _contrastOnFill(typeChipFill, cs),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (!isNarrow && !isMobile)
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'Usage Info',
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  onPressed: () => _showUsageInfo(context),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    bool isOccupied,
    bool isMobile,
    Color statusColor,
  ) {
    if (isOccupied) {
      final sessionProvider = ref.watch(
        activeSessionDetailsProvider(table.currentSessionId ?? ''),
      );
      return sessionProvider.when(
        data: (session) {
          if (session == null) {
            return Center(
              child: Text('Loading...', style: theme.textTheme.bodySmall),
            );
          }
          if (session.isBreakExpired && !_autoResumeInProgress) {
            _autoResumeInProgress = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                await ref
                    .read(tableServiceProvider)
                    .checkAndAutoResumeBreak(session: session);
              } catch (e, st) {
                AppLogger.error(
                  'checkAndAutoResumeBreak failed',
                  tag: 'TableCard',
                  error: e,
                  stackTrace: st,
                );
              }
              if (mounted) _autoResumeInProgress = false;
            });
          }
          final customerProvider = ref.watch(
            singleCustomerProvider(session.customerId),
          );
          return customerProvider.when(
            data: (customer) => _buildOccupiedDetails(
              context,
              theme,
              session,
              customer,
              isMobile,
              statusColor,
            ),
            loading: () => Center(
              child: SizedBox(
                width: isMobile ? 20 : 24,
                height: isMobile ? 20 : 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: statusColor,
                ),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Customer unavailable',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => Center(
          child: SizedBox(
            width: isMobile ? 20 : 24,
            height: isMobile ? 20 : 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: statusColor,
            ),
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Customer unavailable',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    } else if (table.status == TableStatus.maintenance) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isPressed
                    ? theme.colorScheme.surfaceContainerHighest
                    : theme.colorScheme.surfaceContainerHigh
                        .withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.build_rounded,
                size: isMobile ? 28 : 36,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),
            Text(
              'Maintenance',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: isMobile ? 13 : 15,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else {
      final venueKind = ref.watch(venueKindProvider);
      final availableIcon = venueKind.isGaming
          ? Icons.sports_esports_rounded
          : venueKind == VenueKind.restaurantCafe
              ? Icons.restaurant_rounded
              : Icons.table_restaurant_rounded;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isPressed
                    ? statusColor.withValues(alpha: 0.2)
                    : statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isPressed
                      ? statusColor.withValues(alpha: 0.5)
                      : statusColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                availableIcon,
                size: isMobile ? 28 : 36,
                color: _isPressed
                    ? statusColor
                    : statusColor.withValues(alpha: 0.8),
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),
            Text(
              venueKind.availableSubtitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: isMobile ? 13 : 15,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildOccupiedDetails(
    BuildContext context,
    ThemeData theme,
    TableSession session,
    Customer? customer,
    bool isMobile,
    Color statusColor,
  ) {
    final cs = theme.colorScheme;
    final venueKind = ref.watch(venueKindProvider);
    Widget playerChips() {
      if (!session.isPTL || session.playerNames.isEmpty) {
        return customer != null
            ? Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 10,
                  vertical: isMobile ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: _isPressed
                      ? statusColor.withValues(alpha: 0.15)
                      : statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: isMobile ? 14 : 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        customer.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: isMobile ? 11 : 12,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink();
      }

      final names = session.playerNames;
      final chips = <Widget>[];
      final maxToShow = isMobile ? 2 : 3;
      for (int i = 0; i < names.length && i < maxToShow; i++) {
        chips.add(
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 6 : 8,
              vertical: isMobile ? 3 : 4,
            ),
            decoration: BoxDecoration(
              color: _isPressed
                  ? statusColor.withValues(alpha: 0.15)
                  : statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_rounded,
                  size: isMobile ? 11 : 13,
                  color: statusColor,
                ),
                const SizedBox(width: 3),
                Text(
                  names[i],
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isMobile ? 9 : 11,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      if (names.length > maxToShow) {
        chips.add(
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 6 : 8,
              vertical: isMobile ? 3 : 4,
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '+${names.length - maxToShow}',
              style: TextStyle(
                fontSize: isMobile ? 9 : 11,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: isMobile ? 4 : 6,
        runSpacing: isMobile ? 4 : 6,
        children: chips,
      );
    }

    return SingleChildScrollView(
      physics: AppTheme.scrollPhysicsFor(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          playerChips(),
          if (session.isPTL) ...[
            SizedBox(height: isMobile ? 6 : 8),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 10,
                vertical: isMobile ? 4 : 5,
              ),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.tertiary.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sports_esports_rounded,
                    size: isMobile ? 13 : 15,
                    color: cs.onTertiaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'LTP • ${session.playerCount ?? '-'}',
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 12,
                      color: cs.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: isMobile ? 8 : 10),
          if (session.isGaming && venueKind.isGaming)
            OccupiedTableTimerText(
              startTime: session.startTime,
              isPaused: session.isPaused,
              pausedAt: session.pausedAt,
              totalPausedSeconds: session.totalPausedSeconds,
              isOnBreak: session.isOnBreak,
              breakStartedAt: session.breakStartedAt,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 18 : 22,
                color: _isPressed ? statusColor : theme.colorScheme.onSurface,
              ),
            )
          else
            Column(
              children: [
                Text(
                  '\u20B9${((session.totalCafeAmount ?? 0) + (session.totalMerchandiseAmount ?? 0)).toStringAsFixed(0)}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 16 : 18,
                    color: statusColor,
                  ),
                ),
                if (venueKind.isDiningOrRestaurant)
                  Text(
                    'Seated',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: isMobile ? 9 : 10,
                    ),
                  ),
              ],
            ),
          if (session.isGaming && session.isOnBreak)
            Padding(
              padding: EdgeInsets.only(top: isMobile ? 4 : 6),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 10,
                  vertical: isMobile ? 3 : 4,
                ),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.secondary.withValues(alpha: 0.32),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.coffee_rounded,
                      size: isMobile ? 12 : 14,
                      color: cs.onSecondaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'On Break',
                      style: TextStyle(
                        fontSize: isMobile ? 9 : 11,
                        fontWeight: FontWeight.w600,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (session.isGaming && session.isBreakAvailable)
            Padding(
              padding: EdgeInsets.only(top: isMobile ? 4 : 6),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 10,
                  vertical: isMobile ? 3 : 4,
                ),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_rounded,
                      size: isMobile ? 12 : 14,
                      color: cs.onPrimaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Break Due',
                      style: TextStyle(
                        fontSize: isMobile ? 9 : 11,
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: isMobile ? 3 : 5),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 6 : 8,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Started ${DateFormat.jm().format(session.startTime)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: isMobile ? 9 : 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
    ThemeData theme,
    bool isOccupied,
    bool isMobile,
    Color statusColor,
    bool isAvailable,
  ) {
    final cs = theme.colorScheme;
    final venueKind = ref.watch(venueKindProvider);
    String footerText;
    Color footerColor;
    IconData footerIcon;

    switch (table.status) {
      case TableStatus.occupied:
        footerText = isMobile ? venueKind.checkoutTitle : 'Tap to ${venueKind.checkoutTitle}';
        footerColor = _isPressed
            ? const Color(0xFFD32F2F)
            : const Color(0xFFE57373);
        footerIcon = Icons.stop_circle_rounded;
        break;
      case TableStatus.available:
        footerText = isMobile ? venueKind.sessionStartCtaMobile : venueKind.sessionStartCta;
        footerColor = _isPressed
            ? statusColor
            : statusColor.withValues(alpha: 0.9);
        footerIcon = Icons.play_circle_rounded;
        break;
      case TableStatus.maintenance:
        footerText = isMobile ? 'Unavailable' : 'Under Maintenance';
        footerColor = theme.colorScheme.outline;
        footerIcon = Icons.build_circle_rounded;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 10,
        vertical: isMobile ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: _isPressed
            ? footerColor.withValues(alpha: 0.15)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        border: _isPressed
            ? Border.all(color: footerColor.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: isMobile ? 13 : 15,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    venueKind.showHourlyRate && table.tablePurpose != TablePurpose.dining
                        ? '\u20B9${table.hourlyRate.toStringAsFixed(0)}/hr'
                        : venueKind.availableSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: isMobile ? 11 : 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: isMobile ? 4 : 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 10,
              vertical: isMobile ? 4 : 5,
            ),
            decoration: BoxDecoration(
              color: _isPressed
                  ? footerColor
                  : footerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
              boxShadow: _isPressed
                  ? [
                      BoxShadow(
                        color: footerColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  footerIcon,
                  size: isMobile ? 14 : 16,
                  color: _isPressed
                      ? _contrastOnFill(footerColor, cs)
                      : footerColor,
                ),
                const SizedBox(width: 4),
                Text(
                  footerText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _isPressed
                        ? _contrastOnFill(footerColor, cs)
                        : footerColor,
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 11 : 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- Usage Dialog --------------------
  Future<void> _showUsageInfo(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${table.name} Usage'),
        content: FutureBuilder<Map<String, double>>(
          future: _calculateUsageMetrics(),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Text('Failed to load usage data');
            }

            final data = snapshot.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetricRow('Daily Usage', data['dailyUsage'] ?? 0.0),
                _buildMetricRow('Total Usage', data['totalUsage'] ?? 0.0),
                _buildMetricRow('Average Usage', data['avgUsage'] ?? 0.0),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, num hours) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            _formatHours(hours.toDouble()),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatHours(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    return '${h}h ${m}m';
  }

  Future<Map<String, double>> _calculateUsageMetrics() async {
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) {
      return {'dailyUsage': 0, 'totalUsage': 0, 'avgUsage': 0};
    }

    // Fetch all sessions for this table
    final snapshot = await tenant
        .sessions()
        .where('tableId', isEqualTo: table.id)
        .get();

    double totalUsageHours = 0;
    double todayUsageHours = 0;
    int sessionCount = 0;

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final startTime = (data['startTime'] as Timestamp?)?.toDate();
      if (startTime == null) continue;
      final endTime = (data['endTime'] as Timestamp?)?.toDate() ?? now;
      final durationMinutes = endTime.difference(startTime).inMinutes;
      final hours = durationMinutes / 60.0;

      totalUsageHours += hours;
      if (startTime.isAfter(startOfToday)) {
        todayUsageHours += hours;
      }
      sessionCount += 1;
    }

    final avgUsage = sessionCount > 0 ? totalUsageHours / sessionCount : 0;

    // Round to 2 decimal places for readability
    final double daily = double.parse(todayUsageHours.toStringAsFixed(2));
    final double total = double.parse(totalUsageHours.toStringAsFixed(2));
    final double average = double.parse(avgUsage.toStringAsFixed(2));

    return {'dailyUsage': daily, 'totalUsage': total, 'avgUsage': average};
  }
}
