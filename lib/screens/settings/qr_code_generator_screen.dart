import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/company_module_provider.dart';
import '../../providers/table_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';

class QrCodeGeneratorScreen extends ConsumerWidget {
  const QrCodeGeneratorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final companyId = ref.watch(currentCompanyIdProvider);
    final profile = ref.watch(companyProfileProvider).valueOrNull;
    final tablesAsync = ref.watch(tableListProvider);
    final isDesktop = AppTheme.isDesktop(context);
    final venueName = profile?.name ?? 'Your Venue';

    return Scaffold(
      appBar: AppBar(title: const Text('QR codes')),
      body: SingleChildScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: EdgeInsets.fromLTRB(
          isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
          AppTheme.kSpacingMedium,
          isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium,
          AppTheme.kSpacingXLarge + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionLabel(context, 'Venue QR'),
            const SizedBox(height: 8),
            _QrCard(
              theme: theme,
              title: venueName,
              subtitle: 'Guests scan to discover your venue',
              data: 'registeryourcafe://venue/$companyId',
              icon: Icons.storefront_outlined,
            ),
            const SizedBox(height: 24),
            _sectionLabel(context, 'Menu QR'),
            const SizedBox(height: 8),
            _QrCard(
              theme: theme,
              title: 'Public Menu',
              subtitle: 'Scan to view menu and prices',
              data: 'registeryourcafe://menu/$companyId',
              icon: Icons.restaurant_menu_outlined,
            ),
            const SizedBox(height: 24),
            _sectionLabel(context, 'Table QR codes'),
            const SizedBox(height: 8),
            tablesAsync.when(
              loading: () => const ShimmerList(itemCount: 3),
              error: (e, _) => Text('Error loading tables: $e'),
              data: (tables) {
                if (tables.isEmpty) {
                  return AppCard(
                    child: Text(
                      'No tables found. Add tables first.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final table in tables) ...[
                      _QrCard(
                        theme: theme,
                        title: table.name,
                        subtitle: 'Scan to order from this table',
                        data:
                            'registeryourcafe://table/$companyId/${table.id}',
                        icon: Icons.table_bar_outlined,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  final ThemeData theme;
  final String title;
  final String subtitle;
  final String data;
  final IconData icon;

  const _QrCard({
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.data,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_2_rounded,
                    size: 100,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: data));
                  context.showSuccessSnackbar('Link copied to clipboard');
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy link'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  context.showSuccessSnackbar('QR code ready to print');
                },
                icon: const Icon(Icons.print, size: 16),
                label: const Text('Print'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
