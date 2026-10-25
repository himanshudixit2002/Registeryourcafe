import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/loyalty_settings.dart';
import '../../providers/loyalty_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/permission_denied_scaffold.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/section_async_error.dart';

class LoyaltySettingsScreen extends ConsumerStatefulWidget {
  const LoyaltySettingsScreen({super.key});

  @override
  ConsumerState<LoyaltySettingsScreen> createState() =>
      _LoyaltySettingsScreenState();
}

class _LoyaltySettingsScreenState extends ConsumerState<LoyaltySettingsScreen> {
  late TextEditingController _pointsPerConversionController;
  late TextEditingController _creditsPerConversionController;
  late TextEditingController _valuePerPointController;
  late TextEditingController _minimumPointsController;
  bool _isEnabled = true;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _pointsPerConversionController = TextEditingController();
    _creditsPerConversionController = TextEditingController();
    _valuePerPointController = TextEditingController();
    _minimumPointsController = TextEditingController();
  }

  @override
  void dispose() {
    _pointsPerConversionController.dispose();
    _creditsPerConversionController.dispose();
    _valuePerPointController.dispose();
    _minimumPointsController.dispose();
    super.dispose();
  }

  void _initFromSettings(LoyaltySettings s) {
    if (_initialized) return;
    _initialized = true;
    _pointsPerConversionController.text = s.pointsPerConversion.toString();
    _creditsPerConversionController.text = s.creditsPerConversion
        .toStringAsFixed(0);
    _valuePerPointController.text = s.valuePerPoint.toString();
    _minimumPointsController.text = s.minimumPointsToConvert.toString();
    _isEnabled = s.isEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perms = ref.watchResolvedPermissions();
    if (!perms.canConfigureLoyaltySettings()) {
      return const PermissionDeniedScaffold(
        title: 'Loyalty Settings',
        message: 'You do not have permission to change loyalty settings.',
      );
    }

    final settingsAsync = ref.watch(loyaltySettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loyalty Settings'),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => SectionAsyncError(error: e),
        data: (settings) {
          _initFromSettings(settings);
          return _buildForm(context, theme);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, ThemeData theme) {
    final cs = theme.colorScheme;
    final sem = AppSemanticColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Enable / disable toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isEnabled ? sem.successContainer : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
              border: Border.all(
                color: _isEnabled
                    ? sem.success.withValues(alpha: 0.45)
                    : cs.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isEnabled
                      ? Icons.check_circle_outline
                      : Icons.block_outlined,
                  color: _isEnabled ? sem.success : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Loyalty Program',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _isEnabled ? 'Active' : 'Disabled',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isEnabled
                              ? sem.onSuccessContainer
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SwitchTheme(
                  data: SwitchThemeData(
                    thumbColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return sem.onSuccess;
                      }
                      return cs.outline;
                    }),
                    trackColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return sem.success.withValues(alpha: 0.5);
                      }
                      return cs.surfaceContainerHighest;
                    }),
                  ),
                  child: Switch(
                    value: _isEnabled,
                    onChanged: (v) => setState(() => _isEnabled = v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'CONVERSION RATES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          _buildField(
            label: 'Points per conversion unit',
            hint: 'e.g. 100',
            controller: _pointsPerConversionController,
            icon: Icons.stars_rounded,
            helperText: 'How many points make up one conversion unit',
          ),
          const SizedBox(height: 16),
          _buildField(
            label: 'Credits per conversion unit',
            hint: 'e.g. 50',
            controller: _creditsPerConversionController,
            icon: Icons.account_balance_wallet_outlined,
            helperText: 'Credits awarded per conversion unit',
          ),
          const SizedBox(height: 16),
          _buildField(
            label: 'Value per point',
            hint: 'e.g. 0.5',
            controller: _valuePerPointController,
            icon: Icons.monetization_on_outlined,
            helperText: 'Monetary value per loyalty point (for reporting)',
            isDecimal: true,
          ),
          const SizedBox(height: 16),
          _buildField(
            label: 'Minimum points to convert',
            hint: 'e.g. 100',
            controller: _minimumPointsController,
            icon: Icons.low_priority_rounded,
            helperText:
                'Customer must have at least this many points to convert',
          ),
          const SizedBox(height: 12),

          // Preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sem.warningContainer,
              borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
              border: Border.all(
                color: sem.warning.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: sem.warning,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Preview: ${_pointsPerConversionController.text} points '
                    '= ${_creditsPerConversionController.text} credits',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sem.onWarningContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
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
              icon: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    String? helperText,
    bool isDecimal = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
          inputFormatters: isDecimal
              ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
              : [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            helperText: helperText,
            helperMaxLines: 2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusSmall),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final pts = int.tryParse(_pointsPerConversionController.text);
    final creds = double.tryParse(_creditsPerConversionController.text);
    final vpp = double.tryParse(_valuePerPointController.text);
    final minPts = int.tryParse(_minimumPointsController.text);

    if (pts == null || creds == null || vpp == null || minPts == null) {
      context.showErrorSnackbar('Please enter valid numbers for all fields');
      return;
    }

    if (pts <= 0 || creds <= 0 || vpp <= 0 || minPts <= 0) {
      context.showErrorSnackbar('All values must be greater than 0');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final svc = ref.read(loyaltyServiceProvider);
      if (svc == null) {
        if (!mounted) return;
        context.showErrorSnackbar('No company context');
        setState(() => _isSaving = false);
        return;
      }
      await svc.updateSettings(
        LoyaltySettings(
          pointsPerConversion: pts,
          creditsPerConversion: creds,
          valuePerPoint: vpp,
          minimumPointsToConvert: minPts,
          isEnabled: _isEnabled,
        ),
      );

      if (!mounted) return;

      context.showSuccessSnackbar('Loyalty settings saved');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      context.showErrorSnackbar('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
