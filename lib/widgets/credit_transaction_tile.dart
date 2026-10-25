import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';
import '../models/credit_transaction.dart';
import '../models/session.dart';
import '../theme/app_theme.dart';
import '../services/whatsapp_service.dart';
import '../utils/firestore_utils.dart';

class CreditTransactionTile extends StatelessWidget {
  final CreditTransaction tx;
  final TenantRef tenant;
  const CreditTransactionTile({
    super.key,
    required this.tx,
    required this.tenant,
  });

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.amount >= 0;
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);

    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor:
            isCredit ? sem.successContainer : cs.errorContainer,
        child: Icon(
          isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
          color: isCredit ? sem.success : cs.error,
        ),
      ),
      title: Text(
        '${isCredit ? '+' : '-'}${tx.amount.abs().toStringAsFixed(0)} credits',
      ),
      subtitle: Text(DateFormat.yMMMd().add_jm().format(tx.date)),
      // If the transaction relates to a session / cafe / merchandise order, automatically
      // expand so that the user can immediately view the order details. Keeping it collapsed
      // for other transactions avoids excessive UI noise.
      initiallyExpanded:
          tx.reference != null ||
          (tx.note ?? '').startsWith('Cafe order') ||
          (tx.note ?? '').startsWith('Merchandise order') ||
          (tx.note ?? '').startsWith('Refund cafe order') ||
          (tx.note ?? '').startsWith('Partial refund cafe order') ||
          (tx.note ?? '').startsWith('Refund merchandise order') ||
          (tx.note ?? '').startsWith('Partial refund merchandise order'),
      children: _buildDetailChildren(context),
    );
  }

  List<Widget> _buildDetailChildren(BuildContext context) {
    final List<Widget> rows = [];
    rows.add(_kv('Payment Method', tx.paymentMethod.name.toUpperCase()));
    if ((tx.note ?? '').isNotEmpty) {
      rows.add(_kv('Note', tx.note!));
    }
    if ((tx.performedByName ?? '').isNotEmpty) {
      rows.add(
        _kv(
          'By',
          '${(tx.performedByRole ?? 'staff').toUpperCase()} : ${tx.performedByName}',
        ),
      );
    }

    if (tx.reference != null &&
        '${tx.reference!['type'] ?? ''}' == 'session_payment') {
      rows.add(const Divider());
      rows.add(
        _SessionDetailsSection(
          tenant: tenant,
          sessionId: '${tx.reference!['sessionId'] ?? ''}',
        ),
      );
    }

    // ------------------------------------------------------------------
    // HANDLE CAFE ORDER CREDIT DEBITS/REFUNDS (note contains variants)
    // ------------------------------------------------------------------
    if ((tx.note ?? '').isNotEmpty) {
      final note = tx.note!;
      if (note.startsWith('Cafe order ') ||
          note.startsWith('Refund cafe order ') ||
          note.startsWith('Partial refund cafe order ')) {
        final String orderId = note
            .replaceFirst('Partial refund cafe order ', '')
            .replaceFirst('Refund cafe order ', '')
            .replaceFirst('Cafe order ', '')
            .trim();
        if (orderId.isNotEmpty) {
          rows.add(const Divider());
          rows.add(_CafeOrderDetailsSection(tenant: tenant, orderId: orderId));
        }
      }
    }

    // ------------------------------------------------------------------
    // HANDLE MERCHANDISE ORDER CREDIT DEBITS/REFUNDS (note contains variants)
    // ------------------------------------------------------------------
    if ((tx.note ?? '').isNotEmpty) {
      final note = tx.note!;
      if (note.startsWith('Merchandise order ') ||
          note.startsWith('Refund merchandise order ') ||
          note.startsWith('Partial refund merchandise order ')) {
        final String orderId = note
            .replaceFirst('Partial refund merchandise order ', '')
            .replaceFirst('Refund merchandise order ', '')
            .replaceFirst('Merchandise order ', '')
            .trim();
        if (orderId.isNotEmpty) {
          rows.add(const Divider());
          rows.add(
            _MerchandiseOrderDetailsSection(tenant: tenant, orderId: orderId),
          );
        }
      }
    }

    return rows
        .map(
          (w) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: w,
          ),
        )
        .toList();
  }

  Widget _kv(String k, String v) => Row(
    children: [
      Text('$k: ', style: const TextStyle(fontWeight: FontWeight.bold)),
      Expanded(child: Text(v)),
    ],
  );
}

class _SessionDetailsSection extends StatelessWidget {
  final TenantRef tenant;
  final String sessionId;
  const _SessionDetailsSection({required this.tenant, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    if (sessionId.isEmpty) return const SizedBox();
    return FutureBuilder<DocumentSnapshot>(
      future: tenant.sessions().doc(sessionId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.kSpacingSmall),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('Session details not found');
        }
        final session = TableSession.fromFirestore(snapshot.data!);
        final durationMinutes = session.duration.inMinutes;
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final items = (data['orderItems'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        final billVal = session.totalBillAmount ?? session.totalAmount;

        final List<Widget> children = [];
        children.add(
          Text(
            'Session Details',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        );
        children.add(const SizedBox(height: 4));
        children.add(_kv('Table', session.tableName));
        children.add(
          _kv('Start', DateFormat.yMMMd().add_jm().format(session.startTime)),
        );
        if (session.endTime != null) {
          children.add(
            _kv('End', DateFormat.yMMMd().add_jm().format(session.endTime!)),
          );
        }
        children.add(_kv('Duration', '$durationMinutes min'));
        if (billVal != null) {
          children.add(_kv('Bill', '₹${billVal.toStringAsFixed(2)}'));
        }
        if (session.creditsUsed != null && session.creditsUsed! > 0) {
          children.add(
            _kv('Credits Used', session.creditsUsed!.toStringAsFixed(0)),
          );
        }

        // Build message string for WhatsApp
        String buildWhatsAppMessage() {
          final b = StringBuffer();
          b.writeln('Registeryourcafe - Session Bill');
          b.writeln('Table: ${session.tableName}');
          b.writeln(
            'Date: ${DateFormat.yMMMd().add_jm().format(session.startTime)}',
          );
          if (session.endTime != null) {
            b.writeln(
              'End: ${DateFormat.yMMMd().add_jm().format(session.endTime!)}',
            );
          }
          b.writeln('Duration: $durationMinutes min');
          if (items.isNotEmpty) {
            b.writeln('\nItems:');
            for (final it in items) {
              final qty = parseFirestoreInt(it['quantity'], fallback: 1);
              final name = it['name'] ?? 'Item';
              final unitPrice = parseFirestoreDouble(it['price']);
              final lineTotal = unitPrice * qty;
              b.writeln('×$qty $name – ₹${lineTotal.toStringAsFixed(2)}');
            }
          }
          final billVal2 = session.totalBillAmount ?? session.totalAmount;
          if (billVal2 != null) {
            b.writeln('\nBill: ₹${billVal2.toStringAsFixed(2)}');
          }
          if (session.creditsUsed != null && session.creditsUsed! > 0) {
            b.writeln(
              'Credits Used: ${session.creditsUsed!.toStringAsFixed(0)}',
            );
          }
          b.writeln('\nThank you!');
          return b.toString();
        }

        children.add(const SizedBox(height: 8));
        children.add(
          ElevatedButton.icon(
            icon: const Icon(Icons.send_rounded),
            label: const Text('Send via WhatsApp'),
            onPressed: () async {
              final phone = session.customerPhoneNumber ?? '';
              if (phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Customer phone not found')),
                );
                return;
              }
              final msg = buildWhatsAppMessage();
              try {
                await WhatsAppService.sendMessage(
                  rawPhone: phone,
                  message: msg,
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
          ),
        );

        if (items.isNotEmpty) {
          children.add(const Divider());
          children.add(
            Text('Items', style: Theme.of(context).textTheme.titleMedium),
          );
          for (final it in items) {
            final name = it['name'] ?? 'Item';
            final qty = parseFirestoreInt(it['quantity'], fallback: 1);
            final unitPrice = parseFirestoreDouble(it['price']);
            final lineTotal = unitPrice * qty;
            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '×$qty  $name  —  ₹${lineTotal.toStringAsFixed(2)}',
                ),
              ),
            );
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children
              .map(
                (w) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: w,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _kv(String k, String v) => Row(
    children: [
      Text('$k: ', style: const TextStyle(fontWeight: FontWeight.bold)),
      Expanded(child: Text(v)),
    ],
  );
}

class _CafeOrderDetailsSection extends StatelessWidget {
  final TenantRef tenant;
  final String orderId;
  const _CafeOrderDetailsSection({required this.tenant, required this.orderId});

  @override
  Widget build(BuildContext context) {
    if (orderId.isEmpty) return const SizedBox();
    return FutureBuilder<DocumentSnapshot>(
      future: tenant.cafeOrders().doc(orderId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.kSpacingSmall),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('Cafe order details not found');
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final items = (data['items'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final total = parseFirestoreDoubleOrNull(data['total']);
        final tableName = data['tableName'] as String?;
        final creditsUsed = parseFirestoreDoubleOrNull(data['creditsUsed']);

        final List<Widget> children = [];
        children.add(
          Text('Cafe Order', style: Theme.of(context).textTheme.titleMedium),
        );
        if (tableName != null && tableName.isNotEmpty) {
          children.add(_kv('Table', tableName));
        }
        if (createdAt != null) {
          children.add(
            _kv('Placed', DateFormat.yMMMd().add_jm().format(createdAt)),
          );
        }
        if (total != null) {
          children.add(_kv('Total', '₹${total.toStringAsFixed(2)}'));
        }
        if (creditsUsed != null && creditsUsed > 0) {
          children.add(_kv('Credits Used', creditsUsed.toStringAsFixed(0)));
        }

        if (items.isNotEmpty) {
          children.add(const Divider());
          children.add(
            Text('Items', style: Theme.of(context).textTheme.titleMedium),
          );
          for (final it in items) {
            final name = it['name'] ?? 'Item';
            final qty = parseFirestoreInt(it['quantity'], fallback: 1);
            final unitPrice = parseFirestoreDouble(it['price']);
            final lineTotal = unitPrice * qty;
            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '×$qty  $name  —  ₹${lineTotal.toStringAsFixed(2)}',
                ),
              ),
            );
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children
              .map(
                (w) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: w,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _kv(String k, String v) => Row(
    children: [
      Text('$k: ', style: const TextStyle(fontWeight: FontWeight.bold)),
      Expanded(child: Text(v)),
    ],
  );
}

class _MerchandiseOrderDetailsSection extends StatelessWidget {
  final TenantRef tenant;
  final String orderId;
  const _MerchandiseOrderDetailsSection({
    required this.tenant,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    if (orderId.isEmpty) return const SizedBox();
    return FutureBuilder<DocumentSnapshot>(
      future: tenant.merchandiseOrders().doc(orderId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.kSpacingSmall),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('Merchandise order details not found');
        }
        final data = snapshot.data!.data() as Map<String, dynamic>;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final items = (data['items'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final total = parseFirestoreDoubleOrNull(data['total']);
        final tableName = data['tableName'] as String?;
        final creditsUsed = parseFirestoreDoubleOrNull(data['creditsUsed']);

        final List<Widget> children = [];
        children.add(
          Text(
            'Merchandise Order',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        );
        if (tableName != null && tableName.isNotEmpty) {
          children.add(_kv('Table', tableName));
        }
        if (createdAt != null) {
          children.add(
            _kv('Placed', DateFormat.yMMMd().add_jm().format(createdAt)),
          );
        }
        if (total != null) {
          children.add(_kv('Total', '₹${total.toStringAsFixed(2)}'));
        }
        if (creditsUsed != null && creditsUsed > 0) {
          children.add(_kv('Credits Used', creditsUsed.toStringAsFixed(0)));
        }

        if (items.isNotEmpty) {
          children.add(const Divider());
          children.add(
            Text('Items', style: Theme.of(context).textTheme.titleMedium),
          );
          for (final it in items) {
            final name = it['name'] ?? 'Item';
            final qty = parseFirestoreInt(it['quantity'], fallback: 1);
            final unitPrice = parseFirestoreDouble(it['price']);
            final lineTotal = unitPrice * qty;
            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '×$qty  $name  —  ₹${lineTotal.toStringAsFixed(2)}',
                ),
              ),
            );
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children
              .map(
                (w) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: w,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _kv(String k, String v) => Row(
    children: [
      Text('$k: ', style: const TextStyle(fontWeight: FontWeight.bold)),
      Expanded(child: Text(v)),
    ],
  );
}
