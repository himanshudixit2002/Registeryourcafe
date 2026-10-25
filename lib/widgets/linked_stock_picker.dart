import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../firestore/tenant_firestore.dart';
import '../models/stock_item.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

/// Shows linked stock document name (or id) after a one-shot read.
class LinkedStockItemLabel extends StatelessWidget {
  const LinkedStockItemLabel({
    super.key,
    required this.id,
    required this.tenant,
  });

  final String id;
  final TenantRef tenant;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: tenant.stockItems().doc(id).get(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return Text(id, maxLines: 1, overflow: TextOverflow.ellipsis);
        }
        final name = snap.data!.data()?['name'] as String? ?? id;
        return Text(name, maxLines: 1, overflow: TextOverflow.ellipsis);
      },
    );
  }
}

Future<StockItem?> showLinkedStockItemPicker({
  required BuildContext context,
  required TenantRef tenant,
  required Set<String> excludeIds,
}) {
  return showDialog<StockItem>(
    context: context,
    builder: (ctx) {
      return Dialog(
        child: SizedBox(
          width: 420,
          height: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Link another stock item',
                  style: Theme.of(
                    ctx,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: tenant.stockItems().orderBy('name').snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(child: Text('Error: ${snap.error}'));
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snap.data!.docs
                        .map((d) => StockItem.fromFirestore(d))
                        .where((it) => !excludeIds.contains(it.id))
                        .toList();
                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (c, i) {
                        final it = items[i];
                        final tag = it.isMerchandise ? 'Merch' : 'Cafe';
                        return ListTile(
                          title: Text(it.name),
                          subtitle: Text(tag),
                          onTap: () => Navigator.pop(ctx, it),
                        );
                      },
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(AppStrings.cancel),
              ),
            ],
          ),
        ),
      );
    },
  );
}
