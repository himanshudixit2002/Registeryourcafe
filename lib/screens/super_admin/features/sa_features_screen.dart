import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/feature_registry.dart';
import '../../../providers/super_admin_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';

final _globalFlagsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(superAdminServiceProvider).getGlobalFeatureFlags();
});

class SAFeaturesScreen extends ConsumerStatefulWidget {
  const SAFeaturesScreen({super.key});

  @override
  ConsumerState<SAFeaturesScreen> createState() => _SAFeaturesScreenState();
}

class _SAFeaturesScreenState extends ConsumerState<SAFeaturesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _categories = FeatureCategory.values;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flagsAsync = ref.watch(_globalFlagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Flags'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_globalFlagsProvider),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _categories.map((c) => Tab(text: c.label)).toList(),
        ),
      ),
      body: flagsAsync.when(
        data: (flags) => TabBarView(
          controller: _tabController,
          children: _categories.map((cat) {
            final features = FeatureRegistry.byCategory(cat);
            if (features.isEmpty) {
              return Center(
                child: Text(
                  'No features in ${cat.label}',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              );
            }
            return ListView.builder(
              physics: AppTheme.scrollPhysicsFor(context),
              padding: AppTheme.getScreenPadding(context),
              itemCount: features.length,
              itemBuilder: (context, index) {
                final feature = features[index];
                final isEnabled = flags[feature.id] as bool? ?? feature.defaultEnabled;
                return FadeInWidget(
                  delay: Duration(milliseconds: 60 * index),
                  child: _FeatureTile(
                    feature: feature,
                    isEnabled: isEnabled,
                    onToggle: (val) => _toggleFeature(feature.id, val),
                  ),
                );
              },
            );
          }).toList(),
        ),
        loading: () => const ShimmerList(),
        error: (e, _) => Center(
          child: Text('Error loading flags: $e', style: TextStyle(color: theme.colorScheme.error)),
        ),
      ),
    );
  }

  Future<void> _toggleFeature(String featureId, bool enabled) async {
    try {
      final service = ref.read(superAdminServiceProvider);
      await service.setGlobalFeatureFlag(featureId, enabled);
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      service.logSuperAdminAction(action: 'feature_flag_toggled', actorEmail: email, entityType: 'feature', entityId: featureId, details: '${enabled ? "Enabled" : "Disabled"} feature $featureId');
      ref.invalidate(_globalFlagsProvider);
      if (mounted) {
        context.showSuccessSnackbar('Feature ${enabled ? "enabled" : "disabled"}');
      }
    } catch (e) {
      if (mounted) context.showErrorSnackbar('Error: $e');
    }
  }
}

class _FeatureTile extends StatelessWidget {
  final PlatformFeature feature;
  final bool isEnabled;
  final ValueChanged<bool> onToggle;

  const _FeatureTile({
    required this.feature,
    required this.isEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppCard(
      child: SwitchListTile(
        value: isEnabled,
        onChanged: onToggle,
        title: Text(
          feature.name,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(feature.description, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              feature.id,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isEnabled
                ? AppTheme.successColor.withValues(alpha: 0.12)
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isEnabled ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isEnabled ? AppTheme.successColor : cs.onSurfaceVariant,
            size: 20,
          ),
        ),
      ),
    );
  }
}
