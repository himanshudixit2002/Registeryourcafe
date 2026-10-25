import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tax_config.dart';
import '../../providers/tenant_provider.dart';
import '../../services/invoice_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';

class TaxSettingsScreen extends ConsumerStatefulWidget {
  const TaxSettingsScreen({super.key});

  @override
  ConsumerState<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends ConsumerState<TaxSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _taxIdController = TextEditingController();
  final _taxRateController = TextEditingController();
  final _taxLabelController = TextEditingController();
  final _invoicePrefixController = TextEditingController();
  bool _taxEnabled = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConfig());
  }

  Future<void> _loadConfig() async {
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final config = await InvoiceService(tenant).getTaxConfig();
      _taxIdController.text = config.taxId ?? '';
      _taxRateController.text =
          config.taxRate > 0 ? config.taxRate.toString() : '';
      _taxLabelController.text = config.taxLabel;
      _invoicePrefixController.text = config.invoicePrefix;
      _taxEnabled = config.taxEnabled;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final tenant = ref.read(tenantRefProvider);
    if (tenant == null) return;
    setState(() => _saving = true);
    try {
      final config = TaxConfig(
        taxId: _taxIdController.text.trim().isEmpty
            ? null
            : _taxIdController.text.trim(),
        taxRate: double.tryParse(_taxRateController.text.trim()) ?? 0,
        taxLabel: _taxLabelController.text.trim().isEmpty
            ? 'GST'
            : _taxLabelController.text.trim(),
        invoicePrefix: _invoicePrefixController.text.trim().isEmpty
            ? 'INV'
            : _invoicePrefixController.text.trim(),
        taxEnabled: _taxEnabled,
      );
      await InvoiceService(tenant).saveTaxConfig(config);
      if (mounted) {
        context.showSuccessSnackbar('Tax settings saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) context.showErrorSnackbar('Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _taxIdController.dispose();
    _taxRateController.dispose();
    _taxLabelController.dispose();
    _invoicePrefixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppTheme.isDesktop(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tax & invoices')),
        body: const ShimmerList(),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tax & invoices')),
      body: SingleChildScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: EdgeInsets.fromLTRB(
          isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
          AppTheme.kSpacingMedium,
          isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
          AppTheme.kSpacingXLarge,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable tax on bills'),
                      subtitle: const Text(
                        'Add tax line to checkout and invoices',
                      ),
                      value: _taxEnabled,
                      onChanged: (v) => setState(() => _taxEnabled = v),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _taxIdController,
                      decoration: const InputDecoration(
                        labelText: 'Tax ID / GSTIN',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _taxRateController,
                      decoration: const InputDecoration(
                        labelText: 'Tax rate (%)',
                        prefixIcon: Icon(Icons.percent),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _taxLabelController,
                      decoration: const InputDecoration(
                        labelText: 'Tax label',
                        hintText: 'GST',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _invoicePrefixController,
                      decoration: const InputDecoration(
                        labelText: 'Invoice prefix',
                        hintText: 'INV',
                        prefixIcon: Icon(Icons.receipt_long_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Save tax settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
