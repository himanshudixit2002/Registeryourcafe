import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unicons/unicons.dart';

import '../../../models/kitchen_order.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/safe_network_avatar.dart';

class KitchenOrderCard extends StatefulWidget {
  final KitchenOrder order;
  final VoidCallback? onAccept;
  final VoidCallback? onReady;
  final VoidCallback? onDeliver;

  const KitchenOrderCard({
    super.key,
    required this.order,
    this.onAccept,
    this.onReady,
    this.onDeliver,
  });

  @override
  State<KitchenOrderCard> createState() => _KitchenOrderCardState();
}

class _KitchenOrderCardState extends State<KitchenOrderCard> {
  Timer? _timer;
  late Duration _duration;

  @override
  void initState() {
    super.initState();
    _duration = DateTime.now().difference(widget.order.createdAt);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _duration = DateTime.now().difference(widget.order.createdAt);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = AppTheme.isMobile(context);
    final color = _getStatusColor(widget.order.status, theme);
    final bool isAging = _duration.inMinutes >= 10;
    final bool isUrgent = _duration.inMinutes >= 15;

    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      child: AppCard(
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isUrgent ? theme.colorScheme.error : color,
                width: isMobile ? 4 : 5,
              ),
            ),
            gradient: isUrgent
                ? LinearGradient(
                    colors: [
                      theme.colorScheme.error.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCardHeader(theme, color, isAging, isUrgent, isMobile),
              _buildItemList(theme, isMobile),
              if (widget.onAccept != null ||
                  widget.onReady != null ||
                  widget.onDeliver != null)
                _buildActionButtons(theme, isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(
    ThemeData theme,
    Color color,
    bool isAging,
    bool isUrgent,
    bool isMobile,
  ) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: (isUrgent ? colorScheme.error : color).withValues(alpha: 0.08),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(AppTheme.kBorderRadiusMedium - 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Order number
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 10,
                        vertical: isMobile ? 4 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        '#${widget.order.orderNumber}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 14 : 16,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status chip
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 6 : 8,
                        vertical: isMobile ? 2 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.order.status.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: isMobile ? 9 : 10,
                          fontWeight: FontWeight.w900,
                          color: color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Timer
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 10,
                  vertical: isMobile ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color:
                      (isUrgent
                              ? colorScheme.error
                              : isAging
                              ? colorScheme.tertiary
                              : color)
                          .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        (isUrgent
                                ? colorScheme.error
                                : isAging
                                ? colorScheme.tertiary
                                : color)
                            .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUrgent ? Icons.warning_rounded : UniconsLine.clock,
                      size: isMobile ? 12 : 14,
                      color: isUrgent
                          ? colorScheme.error
                          : isAging
                          ? colorScheme.tertiary
                          : color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        fontWeight: FontWeight.bold,
                        color: isUrgent
                            ? colorScheme.error
                            : isAging
                            ? colorScheme.tertiary
                            : color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Customer/Table info
          if (widget.order.tableName != null ||
              widget.order.customerName != null) ...[
            SizedBox(height: isMobile ? 8 : 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (widget.order.tableName != null)
                  _buildInfoChip(
                    icon: Icons.table_restaurant_rounded,
                    text: widget.order.tableName!,
                    theme: theme,
                    isMobile: isMobile,
                  ),
                if (widget.order.customerName != null)
                  _buildInfoChip(
                    icon: Icons.person_rounded,
                    text: widget.order.customerName!,
                    theme: theme,
                    isMobile: isMobile,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required ThemeData theme,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 10,
        vertical: isMobile ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isMobile ? 12 : 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(ThemeData theme, bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.order.items.map((item) {
          return Padding(
            padding: EdgeInsets.only(bottom: isMobile ? 6 : 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Quantity badge
                Container(
                  width: isMobile ? 28 : 32,
                  height: isMobile ? 28 : 32,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${item.quantity}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 13 : 14,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isMobile ? 10 : 12),
                if (item.imageUrl != null && item.imageUrl!.trim().isNotEmpty) ...[
                  SafeNetworkAvatar(
                    imageUrl: item.imageUrl,
                    radius: isMobile ? 14 : 16,
                    fallbackIcon: Icons.restaurant_rounded,
                  ),
                  SizedBox(width: isMobile ? 8 : 10),
                ],
                Expanded(
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme, bool isMobile) {
    final sem =
        theme.extension<AppSemanticColors>() ??
        AppSemanticColors.forScheme(theme.colorScheme, theme.brightness);
    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 10 : 12,
        0,
        isMobile ? 10 : 12,
        isMobile ? 10 : 12,
      ),
      child: Row(
        children: [
          if (widget.onDeliver != null &&
              widget.onAccept == null &&
              widget.onReady == null)
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  widget.onDeliver!();
                },
                icon: Icon(
                  Icons.check_circle_rounded,
                  size: isMobile ? 18 : 20,
                ),
                label: Text(
                  'Mark Done',
                  style: TextStyle(fontSize: isMobile ? 13 : 14),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: sem.success,
                  foregroundColor: sem.onSuccess,
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            )
          else ...[
            if (widget.onAccept != null)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.onAccept!();
                  },
                  icon: Icon(
                    Icons.play_arrow_rounded,
                    size: isMobile ? 18 : 20,
                  ),
                  label: Text(
                    'Start',
                    style: TextStyle(fontSize: isMobile ? 13 : 14),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: sem.info,
                    foregroundColor: sem.onInfo,
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            if (widget.onReady != null) ...[
              SizedBox(width: isMobile ? 6 : 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onReady!();
                  },
                  icon: Icon(
                    Icons.soup_kitchen_rounded,
                    size: isMobile ? 18 : 20,
                  ),
                  label: Text(
                    'Ready',
                    style: TextStyle(fontSize: isMobile ? 13 : 14),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: sem.success,
                    foregroundColor: sem.onSuccess,
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
            if (widget.onDeliver != null) ...[
              SizedBox(width: isMobile ? 6 : 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onDeliver!();
                  },
                  icon: Icon(
                    Icons.delivery_dining_rounded,
                    size: isMobile ? 18 : 20,
                  ),
                  label: Text(
                    'Deliver',
                    style: TextStyle(fontSize: isMobile ? 13 : 14),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: sem.success,
                    foregroundColor: sem.onSuccess,
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(KitchenOrderStatus status, ThemeData theme) {
    final cs = theme.colorScheme;
    final sem =
        theme.extension<AppSemanticColors>() ??
        AppSemanticColors.forScheme(cs, theme.brightness);
    switch (status) {
      case KitchenOrderStatus.pending:
        return sem.warning;
      case KitchenOrderStatus.preparing:
        return cs.primary;
      case KitchenOrderStatus.ready:
        return sem.success;
      default:
        return cs.outline;
    }
  }
}
