import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';
import 'add_expense_screen.dart';

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final expensesAsync = ref.watch(expensesProvider);
    final isDesktop = AppTheme.isDesktop(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AddExpenseScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: expensesAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (expenses) {
          if (expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No expenses recorded',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Tap + to add your first expense.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }
          final total = expenses.fold(0.0, (sum, e) => sum + e.amount);
          return ListView(
            physics: AppTheme.scrollPhysicsFor(context),
            padding: EdgeInsets.fromLTRB(
              isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
              AppTheme.kSpacingMedium,
              isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
              AppTheme.kSpacingXLarge +
                  MediaQuery.paddingOf(context).bottom +
                  80,
            ),
            children: [
              AppCard(
                child: Column(
                  children: [
                    Text('Total expenses',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      '\u20B9${total.toStringAsFixed(0)}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final expense in expenses) ...[
                _ExpenseTile(expense: expense),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ExpenseTile extends ConsumerWidget {
  final Expense expense;

  const _ExpenseTile({required this.expense});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.errorContainer,
          child: Icon(_iconFor(expense.category),
              color: theme.colorScheme.onErrorContainer, size: 20),
        ),
        title: Text(
            expense.description.isEmpty
                ? expense.category.label
                : expense.description,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${expense.category.label} \u2022 ${expense.date.day}/${expense.date.month}/${expense.date.year}'),
        trailing: Text(
          '\u20B9${expense.amount.toStringAsFixed(0)}',
          style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700, color: theme.colorScheme.error),
        ),
        onLongPress: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete expense?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete')),
              ],
            ),
          );
          if (confirm != true || !context.mounted) return;
          try {
            final service = ref.read(expenseServiceProvider);
            if (service == null) return;
            await service.deleteExpense(expense.id);
            if (context.mounted) context.showSuccessSnackbar('Expense deleted');
          } catch (e) {
            if (context.mounted) context.showErrorSnackbar('Failed: $e');
          }
        },
      ),
    );
  }

  IconData _iconFor(ExpenseCategory cat) {
    switch (cat) {
      case ExpenseCategory.rent:
        return Icons.home_outlined;
      case ExpenseCategory.utilities:
        return Icons.bolt_outlined;
      case ExpenseCategory.salaries:
        return Icons.people_outline;
      case ExpenseCategory.supplies:
        return Icons.inventory_2_outlined;
      case ExpenseCategory.maintenance:
        return Icons.build_outlined;
      case ExpenseCategory.marketing:
        return Icons.campaign_outlined;
      case ExpenseCategory.equipment:
        return Icons.devices_outlined;
      case ExpenseCategory.other:
        return Icons.receipt_outlined;
    }
  }
}
