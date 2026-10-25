import 'package:flutter/material.dart';
import 'package:unicons/unicons.dart';

import '../../../models/kitchen_order.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/empty_state_widget.dart';
import 'kitchen_order_card.dart';

class KitchenColumn extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color headerColor;
  final Stream<List<KitchenOrder>> orderStream;
  final void Function(String, String) onUpdateStatus;

  const KitchenColumn({
    super.key,
    required this.title,
    required this.icon,
    required this.headerColor,
    required this.orderStream,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
        border: Border.all(color: theme.dividerColor, width: 1.5),
      ),
      child: Column(
        children: [
          _buildHeader(theme),
          Expanded(child: _buildOrderList()),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
      decoration: BoxDecoration(
        color: headerColor.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppTheme.kBorderRadiusMedium - 1),
          topRight: Radius.circular(AppTheme.kBorderRadiusMedium - 1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: headerColor, size: 28),
          const SizedBox(width: AppTheme.kSpacingSmall),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: headerColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList() {
    return StreamBuilder<List<KitchenOrder>>(
      stream: orderStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            children: List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return const EmptyStateWidget(
            icon: UniconsLine.server_alt,
            message: 'Error loading orders.',
          );
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return EmptyStateWidget(
            icon: UniconsLine.check_circle,
            message: 'No $title orders.',
          );
        }

        return ListView.builder(
          physics: AppTheme.scrollPhysicsFor(context),
          padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return RepaintBoundary(
              child: KitchenOrderCard(
                order: order,
                onDeliver: () => _markDone(context, order),
              ),
            );
          },
        );
      },
    );
  }

  void _markDone(BuildContext context, KitchenOrder order) {
    final prevStatus = order.status.name; // pending/preparing/ready
    onUpdateStatus(order.id, 'delivered');

    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: cs.inverseSurface,
        content: Text(
          'Order #${order.orderNumber} marked done',
          style: TextStyle(color: cs.onInverseSurface),
        ),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: cs.primary,
          onPressed: () {
            onUpdateStatus(order.id, prevStatus);
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
