import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/super_admin_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';

class SALoyaltyScreen extends ConsumerStatefulWidget {
  const SALoyaltyScreen({super.key});

  @override
  ConsumerState<SALoyaltyScreen> createState() => _SALoyaltyScreenState();
}

class _SALoyaltyScreenState extends ConsumerState<SALoyaltyScreen> {
  String? _selectedCompanyId;
  String? _selectedCompanyName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final companiesAsync = ref.watch(allCompaniesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loyalty Programs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(allCompaniesProvider),
          ),
        ],
      ),
      body: _selectedCompanyId != null
          ? _CompanyLoyaltyDetail(
              companyId: _selectedCompanyId!,
              companyName: _selectedCompanyName ?? '',
              onBack: () => setState(() {
                _selectedCompanyId = null;
                _selectedCompanyName = null;
              }),
            )
          : companiesAsync.when(
              loading: () => const ShimmerList(),
              error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: cs.error))),
              data: (companies) {
                if (companies.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.loyalty_outlined, size: 64, color: cs.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text('No companies', style: theme.textTheme.titleMedium),
                      ],
                    ),
                  );
                }
                return ListView(
                  physics: AppTheme.scrollPhysicsFor(context),
                  padding: AppTheme.getScreenPadding(context),
                  children: [
                    const GradientHeader(
                      title: 'Customer Loyalty',
                      subtitle: 'View and manage loyalty programs for each company',
                    ),
                    const SizedBox(height: AppTheme.kSpacingMedium),
                    Text(
                      'Select a company to manage its loyalty program',
                      style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppTheme.kSpacingMedium),
                    ...companies.map((doc) {
                      final data = doc.data();
                      final name = data['name'] as String? ?? 'Unnamed';
                      final venueKind = data['venueKind'] as String? ?? '';
                      final suspended = data['suspended'] == true;
                      return AppCard(
                        onTap: () => setState(() {
                          _selectedCompanyId = doc.id;
                          _selectedCompanyName = name;
                        }),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.loyalty, color: cs.primary, size: 20),
                            ),
                            const SizedBox(width: AppTheme.kSpacingMedium),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                                      ),
                                      if (suspended) ...[
                                        const SizedBox(width: 8),
                                        StatusBadge(label: 'SUSPENDED', color: AppTheme.warningColor),
                                      ],
                                    ],
                                  ),
                                  Text(venueKind, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: AppTheme.kSpacingXLarge),
                  ],
                );
              },
            ),
    );
  }
}

class _CompanyLoyaltyDetail extends ConsumerStatefulWidget {
  final String companyId;
  final String companyName;
  final VoidCallback onBack;

  const _CompanyLoyaltyDetail({
    required this.companyId,
    required this.companyName,
    required this.onBack,
  });

  @override
  ConsumerState<_CompanyLoyaltyDetail> createState() => _CompanyLoyaltyDetailState();
}

class _CompanyLoyaltyDetailState extends ConsumerState<_CompanyLoyaltyDetail> {
  final _pointsPerConversionController = TextEditingController();
  final _creditsPerConversionController = TextEditingController();
  final _valuePerPointController = TextEditingController();
  final _minimumPointsController = TextEditingController();
  bool _isEnabled = true;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _pointsPerConversionController.dispose();
    _creditsPerConversionController.dispose();
    _valuePerPointController.dispose();
    _minimumPointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final service = ref.watch(superAdminServiceProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.kSpacingSmall, 0, AppTheme.kSpacingSmall, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.companyName,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: service.watchCompanyLoyaltySettings(widget.companyId),
            builder: (context, settingsSnap) {
              if (settingsSnap.connectionState == ConnectionState.waiting && !_loaded) {
                return const ShimmerList();
              }

              if (settingsSnap.hasData && !_loaded) {
                final data = settingsSnap.data?.data() ?? {};
                _pointsPerConversionController.text = '${data['pointsPerConversion'] ?? 100}';
                _creditsPerConversionController.text = '${data['creditsPerConversion'] ?? 50}';
                _valuePerPointController.text = '${data['valuePerPoint'] ?? 0.5}';
                _minimumPointsController.text = '${data['minimumPointsToConvert'] ?? 100}';
                _isEnabled = data['isEnabled'] as bool? ?? true;
                _loaded = true;
              }

              return ListView(
                physics: AppTheme.scrollPhysicsFor(context),
                padding: AppTheme.getScreenPadding(context),
                children: [
                  AppCard(
                    child: SwitchListTile(
                      value: _isEnabled,
                      onChanged: (val) => setState(() => _isEnabled = val),
                      title: Text('Loyalty Program', style: theme.textTheme.titleSmall),
                      subtitle: Text(
                        _isEnabled ? 'Program is active' : 'Program is disabled',
                        style: TextStyle(color: _isEnabled ? AppTheme.successColor : cs.onSurfaceVariant),
                      ),
                      secondary: Icon(
                        _isEnabled ? Icons.loyalty : Icons.loyalty_outlined,
                        color: _isEnabled ? AppTheme.successColor : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.kSpacingLarge),
                  Text('Conversion Settings', style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppTheme.kSpacingSmall),
                  AppCard(
                    child: Column(
                      children: [
                        TextField(
                          controller: _pointsPerConversionController,
                          decoration: const InputDecoration(
                            labelText: 'Points per conversion',
                            prefixIcon: Icon(Icons.stars_outlined),
                            helperText: 'How many points make one conversion unit',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: AppTheme.kSpacingMedium),
                        TextField(
                          controller: _creditsPerConversionController,
                          decoration: const InputDecoration(
                            labelText: 'Credits per conversion',
                            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                            helperText: 'Credits awarded per conversion unit',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: AppTheme.kSpacingMedium),
                        TextField(
                          controller: _valuePerPointController,
                          decoration: const InputDecoration(
                            labelText: 'Value per point',
                            prefixIcon: Icon(Icons.currency_rupee),
                            helperText: 'Monetary value of each loyalty point',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: AppTheme.kSpacingMedium),
                        TextField(
                          controller: _minimumPointsController,
                          decoration: const InputDecoration(
                            labelText: 'Minimum points to convert',
                            prefixIcon: Icon(Icons.low_priority),
                            helperText: 'Minimum balance required for conversion',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: AppTheme.kSpacingLarge),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _saveSettings,
                            icon: _saving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.save, size: 18),
                            label: const Text('Save Settings'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.kSpacingLarge),
                  Text('Recent Conversions', style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppTheme.kSpacingSmall),
                  StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                    stream: service.watchCompanyLoyaltyConversions(widget.companyId),
                    builder: (context, convSnap) {
                      if (convSnap.connectionState == ConnectionState.waiting) {
                        return const ShimmerList(itemCount: 3, itemHeight: 60);
                      }
                      final conversions = convSnap.data ?? [];
                      if (conversions.isEmpty) {
                        return AppCard(
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.kSpacingLarge),
                            child: Center(
                              child: Text('No conversions yet', style: TextStyle(color: cs.onSurfaceVariant)),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: conversions.map((doc) {
                          final d = doc.data();
                          final customerName = d['customerName'] as String? ?? 'Unknown';
                          final pointsConverted = (d['pointsConverted'] as num?)?.toDouble() ?? 0;
                          final creditsAwarded = (d['creditsAwarded'] as num?)?.toDouble() ?? 0;
                          final convertedAt = d['convertedAt'];
                          String dateStr = '';
                          if (convertedAt is Timestamp) {
                            dateStr = DateFormat.yMMMd().add_jm().format(convertedAt.toDate());
                          }
                          return AppCard(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.swap_horiz, color: AppTheme.successColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(customerName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                                      Text(
                                        '${pointsConverted.toStringAsFixed(0)} pts \u2192 ${creditsAwarded.toStringAsFixed(0)} credits',
                                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(dateStr, style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: AppTheme.kSpacingXLarge),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      final service = ref.read(superAdminServiceProvider);
      await service.updateCompanyLoyaltySettings(widget.companyId, {
        'pointsPerConversion': int.tryParse(_pointsPerConversionController.text) ?? 100,
        'creditsPerConversion': double.tryParse(_creditsPerConversionController.text) ?? 50,
        'valuePerPoint': double.tryParse(_valuePerPointController.text) ?? 0.5,
        'minimumPointsToConvert': int.tryParse(_minimumPointsController.text) ?? 100,
        'isEnabled': _isEnabled,
      });
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      service.logSuperAdminAction(
        action: 'loyalty_settings_updated',
        actorEmail: email,
        entityType: 'company',
        entityId: widget.companyId,
        details: 'Updated loyalty settings for ${widget.companyName}',
      );
      if (mounted) context.showSuccessSnackbar('Loyalty settings saved');
    } catch (e) {
      if (mounted) context.showErrorSnackbar('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
