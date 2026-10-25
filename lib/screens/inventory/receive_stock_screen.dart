import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/stock_item.dart';
import '../../models/stock_receipt.dart';
import '../../models/vendor.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../services/stock_receipt_service.dart';
import '../../services/vendor_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/business_validators.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/glass_panel.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

enum _ChannelFilter { all, cafe, merch }

class _DraftLine {
  StockItem? item;
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController costController = TextEditingController();

  void dispose() {
    qtyController.dispose();
    costController.dispose();
  }
}

class ReceiveStockScreen extends ConsumerStatefulWidget {
  const ReceiveStockScreen({super.key});

  @override
  ConsumerState<ReceiveStockScreen> createState() => _ReceiveStockScreenState();
}

class _ReceiveStockScreenState extends ConsumerState<ReceiveStockScreen> {
  Vendor? _vendor;
  DateTime _receivedDate = DateTime.now();
  final _invoiceController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  _ChannelFilter _channelFilter = _ChannelFilter.all;
  final List<_DraftLine> _lines = [_DraftLine()];
  bool _submitting = false;

  @override
  void dispose() {
    _invoiceController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  void _refreshTotals() {
    if (mounted) setState(() {});
  }

  double? _lineTotal(_DraftLine d) {
    final q = double.tryParse(d.qtyController.text.trim());
    final c = double.tryParse(d.costController.text.trim());
    if (q == null || c == null || q <= 0 || c < 0) return null;
    return q * c;
  }

  double _grandTotal() {
    double sum = 0;
    for (final d in _lines) {
      final t = _lineTotal(d);
      if (t != null) sum += t;
    }
    return sum;
  }

  Future<StockItem?> _pickItem(List<StockItem> allItems) async {
    String query = '';
    return showDialog<StockItem>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final Iterable<StockItem> filtered = allItems.where((it) {
              if (_channelFilter == _ChannelFilter.cafe && it.isMerchandise) {
                return false;
              }
              if (_channelFilter == _ChannelFilter.merch && !it.isMerchandise) {
                return false;
              }
              if (query.isEmpty) return true;
              return it.name.toLowerCase().contains(query.toLowerCase());
            });
            final list = filtered.toList();

            return AlertDialog(
              title: const Text('Select stock item'),
              content: SizedBox(
                width: 420,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: AppTheme.baseInputDecoration.copyWith(
                        hintText: 'Search…',
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                      onChanged: (v) => setDialogState(() => query = v),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        physics: AppTheme.scrollPhysicsFor(ctx),
                        itemCount: list.length,
                        itemBuilder: (c, i) {
                          final it = list[i];
                          final tag = it.isMerchandise ? 'Merch' : 'Cafe';
                          return ListTile(
                            title: Text(it.name),
                            subtitle: Text(tag),
                            onTap: () => Navigator.pop(ctx, it),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(AppStrings.cancel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_vendor == null) {
      context.showErrorSnackbar('Select a vendor');
      return;
    }
    final commitLines = <StockReceiptCommitLine>[];
    for (final d in _lines) {
      if (d.item == null) {
        context.showErrorSnackbar('Each line needs a stock item');
        return;
      }
      final q = double.tryParse(d.qtyController.text.trim());
      final c = double.tryParse(d.costController.text.trim());
      if (q == null || q <= 0) {
        context.showErrorSnackbar('Enter a valid quantity on each line');
        return;
      }
      if (c == null || c < 0) {
        context.showErrorSnackbar('Enter a valid unit cost (≥ 0) on each line');
        return;
      }
      commitLines.add(
        StockReceiptCommitLine(
          stockItemId: d.item!.id,
          quantity: q,
          unitCost: c,
        ),
      );
    }

    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) {
      context.showErrorSnackbar('No company context');
      return;
    }

    final user = ref.read(appUserProvider).value;
    setState(() => _submitting = true);
    try {
      await StockReceiptService.commitReceipt(
        tenant,
        vendorId: _vendor!.id,
        receivedAt: _receivedDate,
        lines: commitLines,
        invoiceNumber: _invoiceController.text.trim().isEmpty
            ? null
            : _invoiceController.text.trim(),
        reference: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        vendorNameSnapshot: _vendor!.name,
        createdById: user?.uid,
        createdByName: user?.name,
      );
      if (mounted) {
        context.showSuccessSnackbar('Receipt posted and stock updated');
        setState(() {
          for (final d in _lines) {
            d.dispose();
          }
          _lines
            ..clear()
            ..add(_DraftLine());
          _invoiceController.clear();
          _referenceController.clear();
          _notesController.clear();
        });
      }
    } on Exception catch (e) {
      if (mounted) context.showErrorSnackbar(e.userMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat.yMMMd();
    final moneyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    final tenant = ref.watch(tenantRefProvider);
    final grand = _grandTotal();

    if (tenant == null) {
      return const Center(child: Text('No company context'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Record a delivery: quantities and last unit costs sync to the matching cafe or merchandise stock item.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: AbsorbPointer(
            absorbing: _submitting,
            child: Opacity(
              opacity: _submitting ? 0.55 : 1,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: tenant.stockItems().orderBy('name').snapshots(),
                builder: (context, stockSnap) {
                  if (!stockSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final allItems = stockSnap.data!.docs
                      .map((d) => StockItem.fromFirestore(d))
                      .toList();

                  return StreamBuilder<List<Vendor>>(
                    stream: VendorService.watchVendors(
                      tenant,
                      activeOnly: true,
                    ),
                    builder: (context, vendorSnap) {
                      final vendors = vendorSnap.data ?? [];

                      final vendorItems = <DropdownMenuItem<Vendor?>>[
                        const DropdownMenuItem<Vendor?>(
                          value: null,
                          child: Text('Select vendor'),
                        ),
                        ...vendors.map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(v.name),
                          ),
                        ),
                      ];
                      return ListView(
                        physics: AppTheme.scrollPhysicsFor(context),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          DropdownButtonFormField<Vendor?>(
                            initialValue: _vendor,
                            isExpanded: true,
                            decoration: AppTheme.baseInputDecoration.copyWith(
                              labelText: 'Vendor',
                              prefixIcon: const Icon(Icons.storefront_outlined),
                            ),
                            items: vendorItems,
                            selectedItemBuilder: (context) =>
                                AppTheme.dropdownSelectedItemBuilders(
                                  theme,
                                  vendorItems,
                                ),
                            onChanged: _submitting
                                ? null
                                : (v) => setState(() => _vendor = v),
                          ),
                          if (vendors.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Add a vendor in the Vendors tab first.',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Received date'),
                            subtitle: Text(dateFmt.format(_receivedDate)),
                            trailing: IconButton(
                              icon: const Icon(Icons.calendar_today_rounded),
                              onPressed: _submitting
                                  ? null
                                  : () async {
                                      final now = DateTime.now();
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _receivedDate.isAfter(now)
                                            ? now
                                            : _receivedDate,
                                        firstDate: DateTime(2020),
                                        lastDate: now,
                                      );
                                      if (picked != null) {
                                        setState(() => _receivedDate = picked);
                                      }
                                    },
                            ),
                          ),
                          TextField(
                            controller: _invoiceController,
                            enabled: !_submitting,
                            decoration: AppTheme.baseInputDecoration.copyWith(
                              labelText: 'Invoice / bill number (optional)',
                              prefixIcon: const Icon(
                                Icons.receipt_long_outlined,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _referenceController,
                            enabled: !_submitting,
                            decoration: AppTheme.baseInputDecoration.copyWith(
                              labelText: 'Reference (optional)',
                              prefixIcon: const Icon(Icons.tag_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _notesController,
                            enabled: !_submitting,
                            maxLines: 2,
                            decoration: AppTheme.baseInputDecoration.copyWith(
                              labelText: 'Notes (optional)',
                              prefixIcon: const Icon(Icons.notes_rounded),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Item picker filter',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SegmentedButton<_ChannelFilter>(
                            segments: const [
                              ButtonSegment(
                                value: _ChannelFilter.all,
                                label: Text('All'),
                              ),
                              ButtonSegment(
                                value: _ChannelFilter.cafe,
                                label: Text('Cafe'),
                              ),
                              ButtonSegment(
                                value: _ChannelFilter.merch,
                                label: Text('Merch'),
                              ),
                            ],
                            selected: {_channelFilter},
                            onSelectionChanged: (s) {
                              if (_submitting) return;
                              setState(() => _channelFilter = s.first);
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Text(
                                'Lines (max ${StockReceiptService.maxLinesPerReceipt})',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed:
                                    _lines.length >=
                                            StockReceiptService
                                                .maxLinesPerReceipt ||
                                        _submitting
                                    ? null
                                    : () {
                                        setState(
                                          () => _lines.add(_DraftLine()),
                                        );
                                      },
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Add line'),
                              ),
                            ],
                          ),
                          ...List.generate(_lines.length, (i) {
                            final d = _lines[i];
                            final lineTot = _lineTotal(d);
                            final linkCount =
                                d.item?.linkedStockItemIds.length ?? 0;
                            return AppSurface(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _submitting
                                              ? null
                                              : () async {
                                                  final picked =
                                                      await _pickItem(allItems);
                                                  if (picked != null) {
                                                    setState(() {
                                                      d.item = picked;
                                                      if (picked.lastUnitCost !=
                                                          null) {
                                                        d
                                                            .costController
                                                            .text = picked
                                                            .lastUnitCost!
                                                            .toStringAsFixed(2);
                                                      }
                                                    });
                                                  }
                                                },
                                          icon: const Icon(
                                            Icons.inventory_2_outlined,
                                            size: 18,
                                          ),
                                          label: Text(
                                            d.item?.name ?? 'Choose item',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      if (_lines.length > 1)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                          ),
                                          onPressed: _submitting
                                              ? null
                                              : () {
                                                  setState(() {
                                                    d.dispose();
                                                    _lines.removeAt(i);
                                                  });
                                                },
                                        ),
                                    ],
                                  ),
                                  if (d.item != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      d.item!.isMerchandise
                                          ? 'Merchandise · Sell ₹${d.item!.price?.toStringAsFixed(2) ?? '—'}'
                                          : 'Cafe · Sell ₹${d.item!.price?.toStringAsFixed(2) ?? '—'}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                    if (linkCount > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.link_rounded,
                                              size: 16,
                                              color: theme.colorScheme.primary,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'Also updates $linkCount linked item(s) with the same qty and cost.',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: theme
                                                          .colorScheme
                                                          .primary,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: d.qtyController,
                                          enabled: !_submitting,
                                          onChanged: (_) => _refreshTotals(),
                                          decoration: AppTheme
                                              .baseInputDecoration
                                              .copyWith(
                                                labelText: 'Quantity',
                                                suffixText: d.item?.unit,
                                              ),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextField(
                                          controller: d.costController,
                                          enabled: !_submitting,
                                          onChanged: (_) => _refreshTotals(),
                                          decoration: AppTheme
                                              .baseInputDecoration
                                              .copyWith(
                                                labelText: 'Unit cost (₹)',
                                                prefixIcon: const Icon(
                                                  Icons.currency_rupee_rounded,
                                                  size: 20,
                                                ),
                                              ),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (lineTot != null) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        'Line total: ${moneyFmt.format(lineTot)}',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Receipt total',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  moneyFmt.format(grand),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: _submitting
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded),
                            label: Text(
                              _submitting
                                  ? 'Posting…'
                                  : 'Post receipt & update stock',
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
