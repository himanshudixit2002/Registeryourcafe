import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/permission_id.dart';
import '../../../models/loyalty_settings.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/permissions_provider.dart';
import '../../../providers/loyalty_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/snackbar_helper.dart';
import 'package:registeryourcafe/constants/app_strings.dart';

class ConvertPointsDialog extends ConsumerStatefulWidget {
  final String customerId;
  final String customerName;

  const ConvertPointsDialog({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  ConsumerState<ConvertPointsDialog> createState() =>
      _ConvertPointsDialogState();
}

class _ConvertPointsDialogState extends ConsumerState<ConvertPointsDialog> {
  int _selectedUnits = 1;
  bool _isConverting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pointsAsync = ref.watch(
      customerLoyaltyPointsProvider(widget.customerId),
    );
    final settingsAsync = ref.watch(loyaltySettingsProvider);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: pointsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error loading points: $e'),
          ),
          data: (currentPoints) {
            return settingsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error loading settings: $e'),
              ),
              data: (settings) {
                return _buildContent(context, theme, currentPoints, settings);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    double currentPoints,
    LoyaltySettings settings,
  ) {
    final perms = ref.watchResolvedPermissions();
    if (!perms.can(PermissionIds.navLoyalty)) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'You do not have access to loyalty.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(AppStrings.close),
            ),
          ],
        ),
      );
    }

    if (!perms.canConvertLoyaltyPoints()) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'You do not have permission to convert loyalty points.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(AppStrings.close),
            ),
          ],
        ),
      );
    }

    final cs = theme.colorScheme;
    final sem = AppSemanticColors.of(context);
    final maxUnits = (currentPoints / settings.pointsPerConversion).floor();
    final canConvert = maxUnits >= 1 && settings.isEnabled;

    if (_selectedUnits > maxUnits && maxUnits > 0) {
      _selectedUnits = maxUnits;
    }

    final pointsToConvert = _selectedUnits * settings.pointsPerConversion;
    final creditsToAward = _selectedUnits * settings.creditsPerConversion;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: sem.warningContainer,
                    borderRadius: BorderRadius.circular(
                      AppTheme.kBorderRadiusMedium,
                    ),
                  ),
                  child: Icon(
                    Icons.card_giftcard,
                    color: sem.warning,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Convert Loyalty Points',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.customerName,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Current points card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    sem.warningContainer,
                    sem.warning.withValues(alpha: 0.22),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(
                  AppTheme.kBorderRadiusMedium,
                ),
                border: Border.all(
                  color: sem.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.stars_rounded,
                    color: sem.warning,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Points',
                          style: TextStyle(
                            fontSize: 12,
                            color: sem.onWarningContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          currentPoints.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: sem.onWarningContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${settings.pointsPerConversion} pts = ${settings.creditsPerConversion.toStringAsFixed(0)} cr',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: sem.onWarningContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (!settings.isEnabled) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(
                    AppTheme.kBorderRadiusSmall,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: cs.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Loyalty program is currently disabled.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!canConvert) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sem.warningContainer,
                  borderRadius: BorderRadius.circular(
                    AppTheme.kBorderRadiusSmall,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: sem.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Need at least ${settings.minimumPointsToConvert} points to convert.',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Units selector
              Text(
                'Select amount to convert',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStepperButton(
                    icon: Icons.remove,
                    onPressed: _selectedUnits > 1 && !_isConverting
                        ? () => setState(() => _selectedUnits--)
                        : null,
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(
                          AppTheme.kBorderRadiusSmall,
                        ),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Text(
                        '$_selectedUnits x ${settings.pointsPerConversion} = $pointsToConvert pts',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  _buildStepperButton(
                    icon: Icons.add,
                    onPressed: _selectedUnits < maxUnits && !_isConverting
                        ? () => setState(() => _selectedUnits++)
                        : null,
                  ),
                ],
              ),
              if (maxUnits > 2) ...[
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: theme.colorScheme.primary,
                    inactiveTrackColor: theme.colorScheme.primary.withValues(
                      alpha: 0.15,
                    ),
                    thumbColor: theme.colorScheme.primary,
                    overlayColor: theme.colorScheme.primary.withValues(
                      alpha: 0.12,
                    ),
                  ),
                  child: Slider(
                    min: 1,
                    max: maxUnits.toDouble(),
                    divisions: maxUnits > 1 ? maxUnits - 1 : 1,
                    value: _selectedUnits.toDouble(),
                    onChanged: _isConverting
                        ? null
                        : (v) => setState(() => _selectedUnits = v.round()),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Conversion preview
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: sem.successContainer,
                  borderRadius: BorderRadius.circular(
                    AppTheme.kBorderRadiusMedium,
                  ),
                  border: Border.all(
                    color: sem.success.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Icon(
                            Icons.stars_rounded,
                            color: sem.warning,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '- $pointsToConvert',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: cs.error,
                            ),
                          ),
                          Text(
                            'Points',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: sem.success,
                      size: 24,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            color: sem.success,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+ ${creditsToAward.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: sem.success,
                            ),
                          ),
                          Text(
                            'Credits',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Remaining points: ${(currentPoints - pointsToConvert).toStringAsFixed(0)}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),

              // Convert button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isConverting ||
                          !ref.watchResolvedPermissions().canConvertLoyaltyPoints()
                      ? null
                      : _handleConvert,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.kBorderRadiusMedium,
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: _isConverting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : Text(
                          'Convert $pointsToConvert Points → ${creditsToAward.toStringAsFixed(0)} Credits',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: onPressed != null
          ? theme.colorScheme.primary.withValues(alpha: 0.1)
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusSmall),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusSmall),
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: onPressed != null
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        ),
      ),
    );
  }

  Future<void> _handleConvert() async {
    final perms = ref.readResolvedPermissions();
    if (!perms.can(PermissionIds.navLoyalty)) {
      if (mounted) {
        context.showErrorSnackbar('You do not have access to loyalty.');
      }
      return;
    }
    if (!perms.canConvertLoyaltyPoints()) {
      if (mounted) {
        context.showErrorSnackbar(
          'You do not have permission to convert loyalty points.',
        );
      }
      return;
    }

    final settings = ref.read(loyaltySettingsProvider).valueOrNull;
    if (settings == null) return;

    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    final pointsToConvert = (_selectedUnits * settings.pointsPerConversion)
        .toDouble();
    final creditsToAward = _selectedUnits * settings.creditsPerConversion;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
        ),
        title: const Text('Confirm Conversion'),
        content: Text(
          'Convert ${pointsToConvert.toStringAsFixed(0)} points to '
          '${creditsToAward.toStringAsFixed(0)} credits for ${widget.customerName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text(AppStrings.confirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isConverting = true);

    final svc = ref.read(loyaltyServiceProvider);
    if (svc == null) {
      setState(() => _isConverting = false);
      if (mounted) {
        context.showErrorSnackbar('No company context');
      }
      return;
    }

    final result = await svc.convertPointsToCredits(
      customerId: widget.customerId,
      pointsToConvert: pointsToConvert,
      performedBy: user,
    );

    if (!mounted) return;

    setState(() => _isConverting = false);

    if (result.success) {
      context.showSuccessSnackbar(
        'Converted ${result.pointsConverted.toStringAsFixed(0)} points → '
        '${result.creditsAwarded.toStringAsFixed(0)} credits',
      );
      Navigator.pop(context, true);
    } else {
      context.showErrorSnackbar(result.error ?? 'Conversion failed');
    }
  }
}
