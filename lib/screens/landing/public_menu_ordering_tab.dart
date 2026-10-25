import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/ui_helpers.dart';

import '../../models/guest_cafe_order.dart';
import '../../models/public_floor_table.dart';
import '../../models/public_menu_item.dart';
import '../../models/venue_kind.dart';
import '../../services/guest_cafe_order_service.dart';
import '../../utils/landing_guest_auth.dart';
import '../../widgets/safe_network_avatar.dart';
import 'landing_providers.dart';

enum _PublicOrderPlacement { table, counter }

/// Menu tab with guest cart and submit to [guest_cafe_orders].
class PublicMenuOrderingTab extends ConsumerStatefulWidget {
  const PublicMenuOrderingTab({
    super.key,
    required this.companyId,
    required this.venueKind,
  });

  final String companyId;
  final VenueKind venueKind;

  @override
  ConsumerState<PublicMenuOrderingTab> createState() =>
      _PublicMenuOrderingTabState();
}

class _CartLine {
  _CartLine({required this.item, required this.quantity});
  final PublicMenuItem item;
  int quantity;
}

class _PublicMenuOrderingTabState extends ConsumerState<PublicMenuOrderingTab> {
  final Map<String, _CartLine> _cart = {};
  _PublicOrderPlacement _placement = _PublicOrderPlacement.counter;
  PublicFloorTable? _table;
  bool _submitting = false;

  String get _emptyMessage {
    switch (widget.venueKind) {
      case VenueKind.gamingCafe:
        return 'No public menu items yet. The venue may add snacks, drinks, or other items for guests.';
      case VenueKind.diningCafe:
        return 'No public menu items yet. Dining menus appear here for guests — without stock counts.';
      case VenueKind.restaurantCafe:
        return 'No public menu items yet. Food and drink offerings will show here for guests.';
    }
  }

  int get _cartCount =>
      _cart.values.fold(0, (s, line) => s + line.quantity);

  double get _cartTotal =>
      _cart.values.fold(0.0, (s, line) => s + line.item.price * line.quantity);

  void _add(PublicMenuItem m) {
    setState(() {
      final line = _cart.putIfAbsent(m.id, () => _CartLine(item: m, quantity: 0));
      line.quantity += 1;
    });
  }

  void _removeOne(String id) {
    setState(() {
      final line = _cart[id];
      if (line == null) return;
      line.quantity -= 1;
      if (line.quantity <= 0) _cart.remove(id);
    });
  }

  Future<void> _pickTable() async {
    final picked = await showModalBottomSheet<PublicFloorTable>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final async = ref.watch(publicFloorTablesFamily(widget.companyId));
            return async.when(
              data: (tables) {
                if (tables.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No live floor is published yet. Use counter / takeaway.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                return SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Select your table',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...tables.map(
                        (t) => ListTile(
                          leading: const Icon(Icons.event_seat_outlined),
                          title: Text(t.name),
                          subtitle: Text('${t.capacity} seats'),
                          onTap: () => Navigator.pop(ctx, t),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: ShimmerList(itemCount: 3, itemHeight: 48),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load tables: $e'),
              ),
            );
          },
        );
      },
    );
    if (picked != null) {
      setState(() {
        _table = picked;
        _placement = _PublicOrderPlacement.table;
      });
    }
  }

  Future<void> _submit() async {
    if (_cart.isEmpty) return;
    if (_placement == _PublicOrderPlacement.table &&
        (_table == null || _table!.id.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a table or switch to counter.')),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        final pad = MediaQuery.viewInsetsOf(ctx);
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: pad.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Almost there',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pay at the venue when staff confirms. '
                'They will send this order to the kitchen after you submit.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty ||
                      phoneCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Enter name and phone.')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Submit order'),
              ),
            ],
          ),
        );
      },
    );

    if (ok != true) {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      noteCtrl.dispose();
      return;
    }

    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final note = noteCtrl.text.trim();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    noteCtrl.dispose();

    setState(() => _submitting = true);
    try {
      await ensureLandingGuestUser();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        throw StateError('Could not sign in anonymously.');
      }

      final items = <GuestCafeOrderItem>[];
      for (final line in _cart.values) {
        final m = line.item;
        if (m.id.trim().isEmpty) continue;
        items.add(
          GuestCafeOrderItem(
            itemId: m.id,
            name: m.name,
            price: m.price,
            quantity: line.quantity,
            imageUrl: m.imageUrl,
          ),
        );
      }
      if (items.isEmpty) throw StateError('No valid line items.');

      final mode =
          _placement == _PublicOrderPlacement.table ? 'table' : 'counter';
      final tableId = _table?.id ?? '';
      final tableName = _table?.name ?? '';

      await submitGuestCafeOrder(
        companyId: widget.companyId,
        items: items,
        total: _cartTotal,
        guestName: name,
        guestPhone: phone,
        orderMode: mode,
        tableId: tableId,
        tableName: tableName,
        guestNotes: note,
        requesterUid: uid,
      );

      if (!mounted) return;
      setState(() {
        _cart.clear();
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Order sent. The venue will add it to the kitchen queue shortly.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(publicMenuItemsFamily(widget.companyId));

    return Stack(
      children: [
        async.when(
          data: (items) {
            final visible = items
                .where((e) => e.isAvailable)
                .toList(growable: false);
            if (visible.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _emptyMessage,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }
            final byCat = <String, List<PublicMenuItem>>{};
            for (final m in visible) {
              final k = (m.categoryLabel?.trim().isNotEmpty == true)
                  ? m.categoryLabel!.trim()
                  : 'Menu';
              byCat.putIfAbsent(k, () => []).add(m);
            }
            final keys = byCat.keys.toList()..sort();

            return ListView.builder(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
              itemCount: keys.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildHeader(theme);
                }
                final sectionIdx = index - 1;
                final key = keys[sectionIdx];
                final rows = List<PublicMenuItem>.from(byCat[key]!)
                  ..sort((a, b) {
                    final o = a.sortOrder.compareTo(b.sortOrder);
                    if (o != 0) return o;
                    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                  });
                return FadeInWidget(
                  delay: Duration(milliseconds: 80 * sectionIdx),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (sectionIdx > 0) const SizedBox(height: 20),
                      Text(
                        key,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...rows.map((m) => _menuRow(theme, m)),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const ShimmerList(),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.restaurant_menu_rounded,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Could not load menu',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The menu may not be publicly available yet.\nThe venue owner can enable it in their discovery settings.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(
                      publicMenuItemsFamily(widget.companyId),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_cartCount > 0)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shopping_cart_checkout_outlined),
              label: Text(
                'Place order · $_cartCount items · ₹${_cartTotal.toStringAsFixed(0)}',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Where should this go?',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<_PublicOrderPlacement>(
              segments: const [
                ButtonSegment(
                  value: _PublicOrderPlacement.table,
                  label: Text('At a table'),
                  icon: Icon(Icons.event_seat_outlined, size: 18),
                ),
                ButtonSegment(
                  value: _PublicOrderPlacement.counter,
                  label: Text('Counter'),
                  icon: Icon(Icons.takeout_dining_outlined, size: 18),
                ),
              ],
              selected: {_placement},
              onSelectionChanged: (s) {
                setState(() {
                  _placement = s.first;
                  if (_placement == _PublicOrderPlacement.counter) {
                    _table = null;
                  }
                });
              },
            ),
            if (_placement == _PublicOrderPlacement.table) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickTable,
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: Text(
                  _table == null
                      ? 'Choose table from live floor'
                      : 'Table: ${_table!.name}',
                ),
              ),
              if (_table != null)
                TextButton(
                  onPressed: () => setState(() => _table = null),
                  child: const Text('Clear table'),
                ),
            ],
            const SizedBox(height: 6),
            Text(
              'Prices are set by the venue. Pay when you pick up or when staff bills you.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuRow(ThemeData theme, PublicMenuItem m) {
    final line = _cart[m.id];
    final qty = line?.quantity ?? 0;
    return Card(
      child: ListTile(
        leading: SafeNetworkAvatar(
          imageUrl: m.imageUrl,
          radius: 22,
          fallbackIcon: Icons.restaurant_rounded,
        ),
        title: Text(m.name),
        subtitle:
            m.description != null && m.description!.trim().isNotEmpty
            ? Text(m.description!)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\u20B9${m.price.toStringAsFixed(0)}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (qty > 0) ...[
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => _removeOne(m.id),
              ),
              Text('$qty', style: theme.textTheme.titleSmall),
            ],
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _add(m),
            ),
          ],
        ),
      ),
    );
  }
}
