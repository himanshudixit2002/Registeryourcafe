import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';

import '../../models/customer.dart';
import '../../models/loyalty_settings.dart';
import '../../models/loyalty_conversion.dart';
import '../../providers/customer_provider.dart';
import '../../providers/loyalty_provider.dart';
import '../../auth/permission_id.dart';
import '../../providers/permissions_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/permission_denied_scaffold.dart';
import '../../widgets/section_async_error.dart';
import '../../utils/app_logger.dart';
import 'components/convert_points_dialog.dart';
import 'components/loyalty_stats_card.dart';
import 'loyalty_settings_screen.dart';
import 'loyalty_conversion_history_screen.dart';

class LoyaltyScreen extends ConsumerStatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  ConsumerState<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends ConsumerState<LoyaltyScreen> {
  @override
  Widget build(BuildContext context) {
    if (!ref.watchResolvedPermissions().can(PermissionIds.navLoyalty)) {
      return const PermissionDeniedScaffold(
        title: 'Loyalty',
        message: 'You do not have access to loyalty.',
      );
    }

    final theme = Theme.of(context);
    final canConfigure = ref.watchResolvedPermissions().can(
      PermissionIds.opsLoyaltyConfigure,
    );
    final canConvertPts = ref.watchResolvedPermissions().canConvertLoyaltyPoints();
    final tabCount = canConvertPts ? 3 : 2;

    return DefaultTabController(
      key: ValueKey<int>(tabCount),
      length: tabCount,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Loyalty Program'),
          elevation: 0,
          scrolledUnderElevation: 1,
          actions: [
            if (canConfigure)
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () => Navigator.push(
                  context,
                  AppMaterialPageRoute<void>(
                    builder: (_) => const LoyaltySettingsScreen(),
                  ),
                ),
              ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
              if (canConvertPts)
                const Tab(icon: Icon(Icons.swap_horiz), text: 'Convert'),
              const Tab(icon: Icon(Icons.history), text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(),
            if (canConvertPts) const _ConvertTab(),
            const _HistoryTab(),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Overview Tab
// =============================================================================

class _OverviewTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(loyaltySettingsProvider);
    final conversionsAsync = ref.watch(loyaltyConversionsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => SectionAsyncError(error: e),
      data: (settings) {
        return conversionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => SectionAsyncError(error: e),
          data: (conversions) => _buildOverview(context, settings, conversions),
        );
      },
    );
  }

  Widget _buildOverview(
    BuildContext context,
    LoyaltySettings settings,
    List<LoyaltyConversion> conversions,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sem = AppSemanticColors.of(context);
    final totalPoints = conversions.fold<double>(
      0,
      (s, c) => s + c.pointsConverted,
    );
    final totalCredits = conversions.fold<double>(
      0,
      (s, c) => s + c.creditsAwarded,
    );

    final now = DateTime.now();
    final thisMonth = conversions.where(
      (c) => c.convertedAt.year == now.year && c.convertedAt.month == now.month,
    );
    final monthlyCredits = thisMonth.fold<double>(
      0,
      (s, c) => s + c.creditsAwarded,
    );

    final dateFmt = DateFormat('dd MMM, hh:mm a');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: settings.isEnabled
                  ? LinearGradient(
                      colors: [sem.warning, cs.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        cs.surfaceContainerHighest,
                        cs.surfaceContainerHigh,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusLarge),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: settings.isEnabled
                        ? sem.onWarning.withValues(alpha: 0.2)
                        : cs.onSurfaceVariant.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.card_giftcard,
                    color: settings.isEnabled ? sem.onWarning : cs.onSurfaceVariant,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.isEnabled
                            ? 'Loyalty Program Active'
                            : 'Loyalty Program Disabled',
                        style: TextStyle(
                          color: settings.isEnabled
                              ? sem.onWarning
                              : cs.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${settings.pointsPerConversion} points = '
                        '${settings.creditsPerConversion.toStringAsFixed(0)} credits',
                        style: TextStyle(
                          color: settings.isEnabled
                              ? sem.onWarning.withValues(alpha: 0.92)
                              : cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stats grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              LoyaltyStatsCard(
                title: 'Total Conversions',
                value: conversions.length.toString(),
                icon: Icons.swap_horiz,
                color: cs.primary,
                subtitle: 'all time',
              ),
              LoyaltyStatsCard(
                title: 'Points Converted',
                value: totalPoints.toStringAsFixed(0),
                icon: Icons.stars_rounded,
                color: sem.warning,
                subtitle: 'all time',
              ),
              LoyaltyStatsCard(
                title: 'Credits Awarded',
                value: totalCredits.toStringAsFixed(0),
                icon: Icons.account_balance_wallet,
                color: sem.success,
                subtitle: 'all time',
              ),
              LoyaltyStatsCard(
                title: 'Monthly Cost',
                value: monthlyCredits.toStringAsFixed(0),
                icon: Icons.calendar_today,
                color: cs.tertiary,
                subtitle: DateFormat('MMM yyyy').format(now),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent conversions
          Row(
            children: [
              Text(
                'Recent Conversions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              if (conversions.isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    AppMaterialPageRoute<void>(
                      builder: (_) => const LoyaltyConversionHistoryScreen(),
                    ),
                  ),
                  child: const Text('See All'),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (conversions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(
                  AppTheme.kBorderRadiusMedium,
                ),
                border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.history,
                    size: 48,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No conversions yet',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            ...conversions
                .take(5)
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(
                          AppTheme.kBorderRadiusMedium,
                        ),
                        border: Border.all(
                          color: cs.outline.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: sem.warningContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.swap_horiz,
                              color: sem.warning,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.customerName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: cs.onSurface,
                                  ),
                                ),
                                Text(
                                  dateFmt.format(c.convertedAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${c.pointsConverted.toStringAsFixed(0)} pts',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${c.creditsAwarded.toStringAsFixed(0)} cr',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: sem.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// =============================================================================
// Convert Tab
// =============================================================================

class _ConvertTab extends ConsumerStatefulWidget {
  const _ConvertTab();

  @override
  ConsumerState<_ConvertTab> createState() => _ConvertTabState();
}

class _ConvertTabState extends ConsumerState<_ConvertTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Customer>? _searchResults;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsAsync = ref.watch(loyaltySettingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => SectionAsyncError(error: e),
      data: (settings) {
        if (!settings.isEnabled) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.block,
                  size: 56,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'Loyalty program is disabled',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enable it from settings to convert points',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search customer by name or phone...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = null;
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppTheme.kBorderRadiusMedium,
                    ),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.35),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppTheme.kBorderRadiusMedium,
                    ),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.35),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppTheme.kBorderRadiusMedium,
                    ),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHigh,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: _onSearch,
              ),
            ),

            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_searchResults != null && _searchResults!.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_search,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No customers found',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_searchResults != null)
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _searchResults!.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final customer = _searchResults![index];
                    return _CustomerConvertCard(
                      customer: customer,
                      settings: settings,
                    );
                  },
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        size: 56,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Search for a customer to convert points',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${settings.pointsPerConversion} points = '
                        '${settings.creditsPerConversion.toStringAsFixed(0)} credits',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = null;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await ref
          .read(customerServiceProvider)
          .searchCustomers(query.trim(), limit: 20);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e, st) {
      AppLogger.debug(
        'Loyalty customer search failed: $e\n$st',
        tag: 'LoyaltyScreen',
      );
      if (mounted) setState(() => _isSearching = false);
    }
  }
}

class _CustomerConvertCard extends ConsumerWidget {
  final Customer customer;
  final LoyaltySettings settings;

  const _CustomerConvertCard({required this.customer, required this.settings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sem = AppSemanticColors.of(context);
    final pointsAsync = ref.watch(customerLoyaltyPointsProvider(customer.id));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Text(
              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  customer.phoneNumber,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          pointsAsync.when(
            loading: () => const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, _) => const Icon(Icons.error_outline, size: 20),
            data: (points) {
              final canConvertPts =
                  ref.watchResolvedPermissions().canConvertLoyaltyPoints();
              final canConvert =
                  canConvertPts && points >= settings.minimumPointsToConvert;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.stars_rounded,
                            size: 14,
                            color: sem.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            points.toStringAsFixed(0),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: sem.warning,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'points',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: canConvert
                          ? () => _openConvertDialog(context)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        disabledBackgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        disabledForegroundColor:
                            theme.colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.kBorderRadiusSmall,
                          ),
                        ),
                        elevation: 0,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('Convert'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _openConvertDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => ConvertPointsDialog(
        customerId: customer.id,
        customerName: customer.name,
      ),
    );
  }
}

// =============================================================================
// History Tab (embedded)
// =============================================================================

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sem = AppSemanticColors.of(context);
    final conversionsAsync = ref.watch(loyaltyConversionsProvider);
    final dateFmt = DateFormat('dd MMM, hh:mm a');

    return conversionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => SectionAsyncError(error: e),
      data: (conversions) {
        if (conversions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 56, color: cs.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  'No conversion history yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // View all button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Text(
                    '${conversions.length} recent conversions',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      AppMaterialPageRoute<void>(
                        builder: (_) => const LoyaltyConversionHistoryScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Full History'),
                    style: TextButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: conversions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final c = conversions[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(
                        AppTheme.kBorderRadiusMedium,
                      ),
                      border: Border.all(
                        color: cs.outline.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: sem.warningContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.swap_horiz,
                            color: sem.warning,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.customerName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: cs.onSurface,
                                ),
                              ),
                              Text(
                                dateFmt.format(c.convertedAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '- ${c.pointsConverted.toStringAsFixed(0)} pts',
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '+ ${c.creditsAwarded.toStringAsFixed(0)} cr',
                              style: TextStyle(
                                fontSize: 12,
                                color: sem.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
