import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tenant_provider.dart';
import '../../services/export_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _exporting = false;
  String _lastResult = '';

  Future<void> _export(
      String label, Future<String> Function(ExportService) fn) async {
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) return;
    setState(() {
      _exporting = true;
      _lastResult = '';
    });
    try {
      final csv = await fn(ExportService(tenant));
      final lineCount =
          csv.split('\n').where((l) => l.trim().isNotEmpty).length - 1;
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) {
        setState(() => _lastResult = '$label: $lineCount rows copied to clipboard');
        context.showSuccessSnackbar('$label exported ($lineCount rows)');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Export failed: $e');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = AppTheme.isDesktop(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Export data')),
      body: SingleChildScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: EdgeInsets.fromLTRB(
          isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
          AppTheme.kSpacingMedium,
          isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
          AppTheme.kSpacingXLarge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Export workspace data as CSV. Each export copies to your clipboard.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            _ExportTile(
              icon: Icons.people_outline,
              title: 'Customers',
              subtitle: 'Name, phone, email, credits, membership',
              onTap: _exporting
                  ? null
                  : () => _export('Customers', (s) => s.exportCustomersCsv()),
            ),
            const SizedBox(height: 12),
            _ExportTile(
              icon: Icons.table_bar_outlined,
              title: 'Sessions',
              subtitle: 'Table, customer, status, duration, total',
              onTap: _exporting
                  ? null
                  : () => _export('Sessions', (s) => s.exportSessionsCsv()),
            ),
            const SizedBox(height: 12),
            _ExportTile(
              icon: Icons.inventory_2_outlined,
              title: 'Inventory',
              subtitle: 'Stock items with price, cost, and quantity',
              onTap: _exporting
                  ? null
                  : () =>
                      _export('Inventory', (s) => s.exportInventoryCsv()),
            ),
            const SizedBox(height: 12),
            _ExportTile(
              icon: Icons.receipt_long_outlined,
              title: 'Expenses',
              subtitle: 'Date, category, amount, description',
              onTap: _exporting
                  ? null
                  : () => _export('Expenses', (s) => s.exportExpensesCsv()),
            ),
            if (_exporting) ...[
              const SizedBox(height: 24),
              const ShimmerList(itemCount: 2),
            ],
            if (_lastResult.isNotEmpty) ...[
              const SizedBox(height: 24),
              AppCard(
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(_lastResult,
                            style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ExportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        trailing: FilledButton.tonal(
          onPressed: onTap,
          child: const Text('Export'),
        ),
      ),
    );
  }
}
