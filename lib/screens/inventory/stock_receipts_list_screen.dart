import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/stock_receipt.dart';
import '../../providers/tenant_provider.dart';
import '../../services/stock_receipt_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_panel.dart';

class StockReceiptsListScreen extends ConsumerStatefulWidget {
  const StockReceiptsListScreen({super.key});

  @override
  ConsumerState<StockReceiptsListScreen> createState() =>
      _StockReceiptsListScreenState();
}

class _StockReceiptsListScreenState
    extends ConsumerState<StockReceiptsListScreen> {
  void _showDetail(BuildContext context, StockReceipt r) {
    final df = DateFormat.yMMMd().add_jm();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.35,
          maxChildSize: 0.95,
          builder: (ctx, scroll) {
            return GlassPanel(
              blur: GlassBlur.modal,
              borderRadiusGeometry: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              padding: EdgeInsets.zero,
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Receipt',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    df.format(r.receivedAt.toDate()),
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vendor: ${r.vendorNameSnapshot ?? r.vendorId}',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  if (r.invoiceNumber != null && r.invoiceNumber!.isNotEmpty)
                    Text('Invoice: ${r.invoiceNumber}'),
                  if (r.reference != null && r.reference!.isNotEmpty)
                    Text('Ref: ${r.reference}'),
                  if (r.notes != null && r.notes!.isNotEmpty)
                    Text('Notes: ${r.notes}'),
                  Divider(
                    height: 24,
                    thickness: 1,
                    color: AppTheme.subtleDividerColor(Theme.of(ctx)),
                  ),
                  Text(
                    'Lines (${r.lineCount}) · Total \u20B9${r.totalCost.toStringAsFixed(2)}',
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...r.lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line.itemNameSnapshot,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  line.isMerchandiseSnapshot
                                      ? 'Merchandise'
                                      : 'Cafe',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      ctx,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${line.quantity} × \u20B9${line.unitCost.toStringAsFixed(2)}',
                              textAlign: TextAlign.end,
                            ),
                          ),
                          SizedBox(
                            width: 88,
                            child: Text(
                              '\u20B9${line.lineTotal.toStringAsFixed(2)}',
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (r.createdByName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Recorded by ${r.createdByName}',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat.yMMMd();
    final tenant = ref.watch(tenantRefProvider);

    if (tenant == null) {
      return const Center(child: Text('No company context'));
    }

    return StreamBuilder<List<StockReceipt>>(
      stream: StockReceiptService.watchReceipts(tenant, limit: 150),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        if (list.isEmpty) {
          return Center(
            child: Text(
              'No receipts yet',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return ListView.separated(
          physics: AppTheme.scrollPhysicsFor(context),
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = list[i];
            return AppSurface(
              padding: EdgeInsets.zero,
              child: ListTile(
                title: Text(r.vendorNameSnapshot ?? 'Vendor ${r.vendorId}'),
                subtitle: Text(
                  '${df.format(r.receivedAt.toDate())} · ${r.lineCount} lines · \u20B9${r.totalCost.toStringAsFixed(2)}',
                ),
                trailing: const Icon(Icons.open_in_new_rounded, size: 20),
                onTap: () => _showDetail(context, r),
              ),
            );
          },
        );
      },
    );
  }
}
