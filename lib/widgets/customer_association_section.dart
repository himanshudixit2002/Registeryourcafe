import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/customer.dart';
import '../models/table.dart';
import '../models/session.dart';

class CustomerAssociationSection extends StatelessWidget {
  final Customer? selectedCustomer;
  final SnookerTable? selectedTable;
  final TableSession? selectedTableSession;
  final VoidCallback onSelectCustomer;
  final VoidCallback onClearCustomer;
  final String? creditsText;

  const CustomerAssociationSection({
    super.key,
    this.selectedCustomer,
    this.selectedTable,
    this.selectedTableSession,
    required this.onSelectCustomer,
    required this.onClearCustomer,
    this.creditsText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final hasCustomer = selectedCustomer != null;
    final hasSession = selectedTableSession != null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onSelectCustomer();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasCustomer
                ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasCustomer
                  ? colorScheme.primary.withValues(alpha: 0.5)
                  : colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              // Icon container
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasCustomer
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  hasCustomer
                      ? Icons.person_rounded
                      : Icons.person_add_alt_1_rounded,
                  size: 20,
                  color: hasCustomer
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedCustomer?.name ?? 'Select Customer',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (hasCustomer) ...[
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          hasSession
                              ? 'Session on ${selectedTable?.name ?? '...'}'
                              : creditsText ?? 'Customer selected',
                          key: ValueKey(
                            hasSession ? 'session' : creditsText ?? 'default',
                          ),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Action button/icon
              if (hasCustomer)
                IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onClearCustomer();
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: colorScheme.error,
                  ),
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerChip extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;

  const CustomerChip({super.key, required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_rounded,
              size: 16,
              color: colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 6),
            Text(
              customer.name.split(' ').first,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
