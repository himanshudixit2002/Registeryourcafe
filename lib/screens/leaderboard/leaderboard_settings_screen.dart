import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/permission_id.dart';
import '../../models/game_category_catalog.dart';
import '../../models/leaderboard_settings.dart';
import '../../providers/leaderboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../utils/snackbar_helper.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/glass_modal_bottom_sheet.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class LeaderboardSettingsScreen extends ConsumerStatefulWidget {
  const LeaderboardSettingsScreen({super.key});

  @override
  ConsumerState<LeaderboardSettingsScreen> createState() =>
      _LeaderboardSettingsScreenState();
}

class _LeaderboardSettingsScreenState
    extends ConsumerState<LeaderboardSettingsScreen>
    with SingleTickerProviderStateMixin {
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;
  bool _isResetting = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  List<String> _mergedPointsKeys(LeaderboardSettings settings) {
    final visible = ref
        .read(visibleLeaderboardCategoryKeysProvider)
        .where((k) => k != GameCategoryCatalog.allKey)
        .toSet();
    final fromDoc = settings.defaultPointsByTableType.keys.toSet();
    final merged = {...visible, ...fromDoc}.toList();
    merged.sort(
      (a, b) => GameCategoryCatalog.sortIndex(
        a,
      ).compareTo(GameCategoryCatalog.sortIndex(b)),
    );
    return merged;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _confirmAndResetPoints() async {
    await HapticFeedback.mediumImpact();
    if (!mounted) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildResetConfirmationSheet(),
    );

    if (confirmed == true) {
      await _resetLeaderboardPoints();
    }
  }

  Widget _buildResetConfirmationSheet() {
    final theme = Theme.of(context);
    final err = theme.colorScheme.error;
    return GlassModalSheetChrome(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: err.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded, color: err, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              'Reset All Points?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will set leaderboard points to 0 for all players. Match history will remain intact.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(AppStrings.cancel),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: err,
                      foregroundColor: theme.colorScheme.onError,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _resetLeaderboardPoints() async {
    setState(() => _isResetting = true);

    try {
      final currentUser = ref.read(appUserProvider).valueOrNull;
      if (currentUser == null) {
        if (mounted) {
          context.showErrorSnackbar('Please sign in again.');
        }
        return;
      }

      final service = ref.read(leaderboardServiceProvider);
      await service.resetAllLeaderboardPoints(resetBy: currentUser);

      if (mounted) {
        context.showSuccessSnackbar('Points reset for all players!');
        ref.invalidate(leaderboardProvider);
        ref.invalidate(leaderboardStatsProvider);
        ref.invalidate(categoryPeriodLeaderboardProvider);
        ref.invalidate(periodLeaderboardProvider);
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        if (e.code == 'permission-denied') {
          context.showErrorSnackbar(
            'Permission denied. If this persists, ask an admin to deploy Firestore rules.',
          );
        } else {
          context.showErrorSnackbar('Firestore error: ${e.message ?? e.code}.');
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Failed to reset: $e');
      }
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;
    final settingsAsync = ref.watch(leaderboardSettingsProvider);
    final canManage = ref.watchResolvedPermissions().can(
      PermissionIds.opsLeaderboardManage,
    );

    if (!canManage) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leaderboard settings')),
        body: const Center(child: Text('Access denied.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard Settings'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.08),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: theme.colorScheme.onSurface,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: settingsAsync.when(
        data: (settings) {
          final keys = _mergedPointsKeys(settings);
          for (final key in keys) {
            if (!_controllers.containsKey(key)) {
              final points = settings.getDefaultPoints(key);
              _controllers[key] = TextEditingController(
                text: points.toStringAsFixed(0),
              );
            }
          }

          return FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              physics: AppTheme.scrollPhysicsFor(context),
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderCard(theme, isMobile),
                  const SizedBox(height: 16),
                  _buildResetCard(theme, isMobile),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(
                        Icons.tune,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Points Configuration',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Set default points for each game type',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._mergedPointsKeys(settings).asMap().entries.map(
                    (e) => _buildPointsCard(
                      context,
                      e.value,
                      GameCategoryCatalog.displayName(e.value),
                      e.key,
                      isMobile,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSaveButton(context, settings, isMobile),
                  const SizedBox(height: 12),
                  _buildResetDefaultsButton(context, isMobile),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 56,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading settings',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(leaderboardSettingsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, bool isMobile) {
    return AppCard(
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
      borderColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'PTL Point System',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 15 : 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoRow(
            Icons.check_circle_outline,
            'Winners earn points automatically',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.pie_chart_outline,
            'Points split among all winners',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.account_balance_wallet_outlined,
            'Loser pays the bill',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildResetCard(ThemeData theme, bool isMobile) {
    final err = theme.colorScheme.error;
    return AppCard(
      backgroundColor: err.withValues(alpha: 0.08),
      borderColor: err.withValues(alpha: 0.28),
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: err.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.restart_alt_rounded, color: err, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Season Reset',
                  style: TextStyle(
                    color: err,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Reset all player points to 0',
                  style: TextStyle(
                    color: err.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _isResetting ? null : _confirmAndResetPoints,
            style: ElevatedButton.styleFrom(
              backgroundColor: err,
              foregroundColor: theme.colorScheme.onError,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 18,
                vertical: isMobile ? 10 : 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: _isResetting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onError,
                    ),
                  )
                : Text(
                    'Reset',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile ? 13 : 14,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsCard(
    BuildContext context,
    String type,
    String label,
    int index,
    bool isMobile,
  ) {
    final controller = _controllers[type];
    if (controller == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final color = GameCategoryCatalog.categoryAccent(type, cs);
    final tableIcon = GameCategoryCatalog.iconFor(type);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          padding: EdgeInsets.all(isMobile ? 14 : 16),
          child: Row(
            children: [
              Container(
                width: isMobile ? 44 : 50,
                height: isMobile ? 44 : 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tableIcon, color: color, size: isMobile ? 22 : 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Points per win',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: isMobile ? 80 : 90,
                height: isMobile ? 44 : 48,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.35)),
                ),
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    suffixText: 'pts',
                    suffixStyle: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(
    BuildContext context,
    LeaderboardSettings currentSettings,
    bool isMobile,
  ) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : () => _saveSettings(currentSettings),
        icon: _isSaving
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onPrimary,
                ),
              )
            : const Icon(Icons.save_rounded, size: 20),
        label: Text(
          _isSaving ? 'Saving...' : 'Save Changes',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildResetDefaultsButton(BuildContext context, bool isMobile) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _isSaving ? null : _resetToDefaults,
        icon: const Icon(Icons.restore_rounded, size: 18),
        label: const Text(
          'Reset to Defaults',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _saveSettings(LeaderboardSettings currentSettings) async {
    setState(() => _isSaving = true);
    await HapticFeedback.mediumImpact();
    if (!mounted) return;

    try {
      final newPointsMap = <String, double>{};

      for (final key in _mergedPointsKeys(currentSettings)) {
        final controller = _controllers[key];
        if (controller != null) {
          final points = double.tryParse(controller.text) ?? 10.0;
          newPointsMap[key] = points.clamp(1.0, 200.0);
        }
      }

      final updatedSettings = currentSettings.copyWith(
        defaultPointsByTableType: newPointsMap,
      );

      final tenant = ref.read(tenantRefProvider);
      if (tenant == null) {
        if (mounted) {
          context.showErrorSnackbar('No company context');
        }
        return;
      }
      await tenant
          .leaderboardSettings()
          .doc('default')
          .set(updatedSettings.toFirestore(), SetOptions(merge: true));

      if (mounted) {
        context.showSuccessSnackbar('Settings saved successfully!');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Error saving: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetToDefaults() {
    HapticFeedback.lightImpact();
    final defaults = LeaderboardSettings.defaults();
    final current =
        ref.read(leaderboardSettingsProvider).valueOrNull ?? defaults;
    setState(() {
      for (final key in _mergedPointsKeys(current)) {
        _controllers[key]?.text = defaults
            .getDefaultPoints(key)
            .toStringAsFixed(0);
      }
    });
    context.showInfoSnackbar('Reset to defaults. Save to apply.');
  }
}
