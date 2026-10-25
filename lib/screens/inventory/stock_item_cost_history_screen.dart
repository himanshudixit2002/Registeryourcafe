import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/permission_id.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/permission_denied_scaffold.dart';
import '../../theme/app_theme.dart';
import '../../services/stock_cost_service.dart';
import '../../utils/firestore_utils.dart';

/// Audit trail for [lastUnitCost] changes (vendor receipts and manual edits).
class StockItemCostHistoryScreen extends ConsumerWidget {
  const StockItemCostHistoryScreen({
    super.key,
    required this.stockItemId,
    required this.itemName,
  });

  final String stockItemId;
  final String itemName;

  static String _fmtCost(double? v) {
    if (v == null) return '—';
    return '\u20B9${v.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final df = DateFormat.yMMMd().add_jm();
    final tenant = ref.watch(tenantRefProvider);

    if (!ref.watchResolvedPermissions().can(PermissionIds.navInventory)) {
      return const PermissionDeniedScaffold(
        title: 'Cost history',
        message: 'You do not have access to inventory.',
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Cost history'),
            Text(
              itemName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
      body: tenant == null
          ? const Center(child: Text('No company context'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: tenant
                  .stockItems()
                  .doc(stockItemId)
                  .collection(StockCostService.subcollection)
                  .orderBy('timestamp', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No cost changes recorded yet.\n'
                        'Posting a vendor receipt or setting unit cost on the item will appear here.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  physics: AppTheme.scrollPhysicsFor(context),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    thickness: 1,
                    color: AppTheme.subtleDividerColor(theme),
                  ),
                  itemBuilder: (context, i) {
                    final d = docs[i].data();
                    final ts = d['timestamp'];
                    final when = ts is Timestamp ? df.format(ts.toDate()) : '—';
                    final source = d['source'] as String? ?? '';
                    final prev = parseFirestoreDoubleOrNull(
                      d['previousUnitCost'],
                    );
                    final next = parseFirestoreDoubleOrNull(d['newUnitCost']);
                    final receiptId = d['receiptId'] as String?;
                    final invoice = d['invoiceNumber'] as String?;
                    final qtyRec = parseFirestoreDoubleOrNull(
                      d['quantityReceived'],
                    );
                    final note = d['note'] as String?;
                    final by = d['updatedByName'] as String?;

                    String sourceLabel;
                    if (source == StockCostService.sourceVendorReceipt) {
                      sourceLabel = 'Vendor receipt';
                      if (receiptId != null && receiptId.isNotEmpty) {
                        sourceLabel += ' · $receiptId';
                      }
                      if (invoice != null && invoice.isNotEmpty) {
                        sourceLabel += ' · Inv. $invoice';
                      }
                      if (qtyRec != null && qtyRec > 0) {
                        final qStr = qtyRec == qtyRec.roundToDouble()
                            ? qtyRec.toInt().toString()
                            : qtyRec.toStringAsFixed(2);
                        sourceLabel += ' · +$qStr qty';
                      }
                    } else if (source == StockCostService.sourceManualEdit) {
                      sourceLabel = 'Manual edit';
                      if (by != null && by.isNotEmpty) {
                        sourceLabel += ' · $by';
                      }
                    } else {
                      sourceLabel = source;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            when,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_fmtCost(prev)} → ${_fmtCost(next)}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sourceLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (note != null && note.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(note, style: theme.textTheme.bodySmall),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
