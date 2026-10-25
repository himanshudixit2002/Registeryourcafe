import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/expense.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_card.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _vendorController = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.supplies;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _vendorController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final user = ref.read(appUserProvider).valueOrNull;
      final expense = Expense(
        id: '',
        category: _category,
        amount: double.parse(_amountController.text.trim()),
        date: _date,
        description: _descriptionController.text.trim(),
        vendorName: _vendorController.text.trim().isEmpty
            ? null
            : _vendorController.text.trim(),
        createdBy: user?.name ?? 'Unknown',
        createdAt: DateTime.now(),
      );
      await ref.read(expenseServiceProvider)?.addExpense(expense);
      if (mounted) {
        context.showSuccessSnackbar('Expense added');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) context.showErrorSnackbar('Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AppTheme.isDesktop(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Add expense')),
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
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixIcon: Icon(Icons.currency_rupee)),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (double.tryParse(v.trim()) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<ExpenseCategory>(
                      value: _category,
                      decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined)),
                      items: ExpenseCategory.values
                          .map((c) => DropdownMenuItem(
                              value: c, child: Text(c.label)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _category = v ?? _category),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description_outlined)),
                      maxLines: 2,
                      minLines: 1,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _vendorController,
                      decoration: const InputDecoration(
                          labelText: 'Vendor (optional)',
                          prefixIcon: Icon(Icons.store_outlined)),
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: Text(
                          '${_date.day}/${_date.month}/${_date.year}'),
                      trailing: TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => _date = picked);
                        },
                        child: const Text('Change'),
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
                        child:
                            CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Add expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
