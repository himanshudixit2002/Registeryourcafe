import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/glass_panel.dart';
import '../../widgets/mobile_stat_card.dart';
import '../../widgets/shimmer_skeleton.dart';
import '../../widgets/stat_card.dart';

/// In-app gallery for shared UI building blocks. Toggle preview theme without
/// changing the global [ThemeMode].
class WidgetCatalogScreen extends StatefulWidget {
  const WidgetCatalogScreen({super.key});

  @override
  State<WidgetCatalogScreen> createState() => _WidgetCatalogScreenState();
}

class _WidgetCatalogScreenState extends State<WidgetCatalogScreen> {
  bool _previewDark = false;
  String? _sampleDropdown;

  ThemeData get _previewTheme =>
      _previewDark ? AppTheme.darkTheme() : AppTheme.lightTheme();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _previewTheme,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final cs = theme.colorScheme;
          final pad = AppTheme.getCardPadding(context);
          return Scaffold(
            appBar: AppBar(
              title: const Text('Widget catalog'),
            ),
            body: MediaQuery.withClampedTextScaling(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.35,
              child: ListView(
              physics: AppTheme.scrollPhysicsFor(context),
              padding: pad.copyWith(
                bottom: pad.bottom + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Light preview'),
                      icon: Icon(Icons.light_mode_outlined, size: 18),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Dark preview'),
                      icon: Icon(Icons.dark_mode_outlined, size: 18),
                    ),
                  ],
                  selected: {_previewDark},
                  onSelectionChanged: (s) {
                    if (s.isEmpty) return;
                    setState(() => _previewDark = s.first);
                  },
                ),
                const SizedBox(height: AppTheme.kSpacingSmall),
                Text(
                  'Preview only — does not change app theme',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: AppTheme.sectionGap(context)),
                _label(theme, 'AppCard + GlassPanel'),
                AppCard(
                  child: Text(
                    'AppCard body text',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: AppTheme.kSpacingSmall),
                GlassPanel(
                  padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
                  child: Text(
                    'GlassPanel',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                SizedBox(height: AppTheme.sectionGap(context)),
                _label(theme, 'Stat cards'),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 420;
                    final stat = StatCard(
                      title: 'Stat',
                      value: '42',
                      icon: Icons.analytics_outlined,
                      color: cs.primary,
                    );
                    final mobile = MobileStatCard(
                      title: 'Mobile',
                      value: '12',
                      icon: Icons.phone_android_outlined,
                      color: cs.tertiary,
                    );
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          stat,
                          const SizedBox(height: AppTheme.kSpacingSmall),
                          mobile,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: stat),
                        const SizedBox(width: AppTheme.kSpacingSmall),
                        Expanded(child: mobile),
                      ],
                    );
                  },
                ),
                SizedBox(height: AppTheme.sectionGap(context)),
                _label(theme, 'Empty state'),
                EmptyStateWidget(
                  icon: Icons.inbox_outlined,
                  message: 'Nothing here yet',
                  details: 'Secondary copy uses theme colors.',
                ),
                SizedBox(height: AppTheme.sectionGap(context)),
                _label(theme, 'Shimmer skeleton'),
                ShimmerSkeleton.card(height: 72),
                const SizedBox(height: AppTheme.kSpacingSmall),
                Row(
                  children: [
                    ShimmerSkeleton.text(width: 120),
                    const SizedBox(width: 8),
                    ShimmerSkeleton.avatar(size: 40),
                  ],
                ),
                SizedBox(height: AppTheme.sectionGap(context)),
                _label(theme, 'Form field + dropdown'),
                TextField(
                  decoration: AppTheme.inputDecoration(
                    theme,
                    'Label',
                    Icons.edit_outlined,
                  ),
                ),
                const SizedBox(height: AppTheme.kSpacingMedium),
                Builder(
                  builder: (ctx) {
                    final items = const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text('All'),
                      ),
                      DropdownMenuItem(value: 'a', child: Text('Option A')),
                      DropdownMenuItem(value: 'b', child: Text('Option B')),
                    ];
                    return DropdownButtonFormField<String>(
                      initialValue: _sampleDropdown,
                      isExpanded: true,
                      decoration: AppTheme.inputDecoration(
                        theme,
                        'Sample',
                        Icons.list_alt_outlined,
                      ),
                      items: items,
                      selectedItemBuilder: (context) =>
                          AppTheme.dropdownSelectedItemBuilders(theme, items),
                      onChanged: (v) => setState(() => _sampleDropdown = v),
                    );
                  },
                ),
                SizedBox(height: AppTheme.sectionGap(context)),
                _label(theme, 'Chips'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Filter'),
                      selected: true,
                      onSelected: (_) {},
                    ),
                    ActionChip(
                      label: const Text('Action'),
                      onPressed: () {},
                    ),
                    Chip(
                      avatar: const Icon(Icons.info_outline, size: 18),
                      label: const Text('Chip'),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.sectionGap(context)),
                _label(theme, 'Divider token'),
                Divider(
                  color: AppTheme.subtleDividerColor(theme),
                  thickness: 1,
                ),
                SizedBox(height: AppTheme.sectionGap(context)),
                _label(theme, 'Buttons'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () {},
                      child: const Text('Filled'),
                    ),
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text('Outlined'),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Text'),
                    ),
                  ],
                ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  static Widget _label(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.kSpacingSmall),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
