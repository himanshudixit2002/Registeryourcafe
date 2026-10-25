import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/customer.dart';
import '../../models/game_category_catalog.dart';
import '../../providers/company_module_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../providers/leaderboard_provider.dart';
import '../../widgets/enhanced_customer_search.dart';
import '../../widgets/app_card.dart';
import '../../theme/app_theme.dart';
import '../../models/table.dart';
import '../../models/table_type_definition.dart';
import '../../firestore/tenant_firestore.dart';
import '../../providers/membership_type_provider.dart';
import '../../providers/table_type_provider.dart';
import '../../auth/permission_id.dart';
import '../../providers/permissions_provider.dart';

class AwardPointsScreen extends ConsumerStatefulWidget {
  const AwardPointsScreen({super.key});

  @override
  ConsumerState<AwardPointsScreen> createState() => _AwardPointsScreenState();
}

class _AwardPointsScreenState extends ConsumerState<AwardPointsScreen> {
  Customer? _selectedWinner;
  final List<Customer> _selectedLosers = [];
  final _pointsController = TextEditingController(text: '10');
  final _notesController = TextEditingController();
  String _selectedGameType = 'snooker';
  bool _isSubmitting = false;
  bool _splitPoints = true;
  String? _selectedTableId;
  String? _selectedTableName;

  List<String> _visibleGameTypeKeys() {
    final tenant = ref
        .watch(visibleLeaderboardCategoryKeysProvider)
        .where((k) => k != GameCategoryCatalog.allKey)
        .toList();
    if (tenant.isNotEmpty) return tenant;
    return List<String>.from(GameCategoryCatalog.orderedKeys);
  }

  // Category-specific point configurations
  Map<String, List<int>> get _pointPresetsByCategory => {
    'snooker': [10, 15, 20, 25, 30, 50],
    'pool': [5, 10, 15, 20, 25, 30],
    'carrom': [5, 8, 10, 15, 20, 25],
    'darts': [3, 5, 8, 10, 15, 20],
    'ps5': [5, 10, 15, 20, 25, 30],
    'other': [5, 10, 15, 20, 25, 50],
  };

  List<int> get _currentPresets =>
      _pointPresetsByCategory[_selectedGameType] ?? [5, 10, 15, 20, 25, 50];

  @override
  void dispose() {
    _pointsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watchResolvedPermissions().can(PermissionIds.navLeaderboard)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Award Points')),
        body: const Center(
          child: Text('You do not have access to the leaderboard.'),
        ),
      );
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;
    final gameTypeKeys = _visibleGameTypeKeys();
    if (!gameTypeKeys.contains(_selectedGameType)) {
      final next = gameTypeKeys.first;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedGameType != next) {
          setState(() => _selectedGameType = next);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Award Points'),
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
                  color: theme.shadowColor.withValues(alpha: 0.12),
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
      body: SingleChildScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(context, isMobile),
            SizedBox(height: isMobile ? 20 : 24),
            _buildSectionTitle(
              'Select Winner',
              Icons.emoji_events,
              cs.tertiary,
            ),
            const SizedBox(height: 12),
            _buildCustomerSelector(
              context: context,
              customer: _selectedWinner,
              label: 'Winner',
              onSelect: () async {
                await HapticFeedback.lightImpact();
                if (!context.mounted) return;
                final customer = await _selectCustomer(context);
                if (customer != null &&
                    !_selectedLosers.any((x) => x.id == customer.id)) {
                  setState(() => _selectedWinner = customer);
                }
              },
              onClear: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedWinner = null);
              },
            ),
            SizedBox(height: isMobile ? 20 : 24),
            _buildSectionTitle(
              'Select Losers (Optional)',
              Icons.person_outline,
              cs.error,
            ),
            const SizedBox(height: 12),
            _buildMultiLoserSelector(context, isMobile),
            SizedBox(height: isMobile ? 20 : 24),
            _buildSectionTitle(
              'Game Details',
              Icons.sports_esports,
              cs.primary,
            ),
            const SizedBox(height: 12),
            _buildGameTypeSelector(theme, isMobile, gameTypeKeys),
            const SizedBox(height: 16),
            _buildTableSelector(context, isMobile),
            const SizedBox(height: 16),
            _buildPointsSection(isMobile),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Switch(
                    value: _splitPoints,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _splitPoints = v);
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Split points among losers',
                      style: TextStyle(fontSize: isMobile ? 13 : 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildNotesField(isMobile),
            SizedBox(height: isMobile ? 24 : 32),
            _buildSubmitButton(context, isMobile),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesField(bool isMobile) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: TextField(
        controller: _notesController,
        decoration: InputDecoration(
          labelText: 'Notes (Optional)',
          labelStyle: TextStyle(fontSize: isMobile ? 13 : 14),
          prefixIcon: Icon(Icons.note_outlined, size: isMobile ? 20 : 22),
          border: InputBorder.none,
          hintText: 'Any additional details...',
          hintStyle: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: isMobile ? 13 : 14,
          ),
        ),
        maxLines: 2,
        style: TextStyle(fontSize: isMobile ? 14 : 15),
      ),
    );
  }

  Widget _buildTableSelector(BuildContext context, bool isMobile) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      onTap: () async {
        await HapticFeedback.lightImpact();
        if (!context.mounted) return;
        final tenant = ref.read(tenantRefProvider);
        if (tenant == null) return;
        final selected = await showDialog<Map<String, String>?>(
          context: context,
          builder: (ctx) => _TablePickerDialog(tenant: tenant),
        );
        if (selected != null) {
          setState(() {
            _selectedTableId = selected['id'];
            _selectedTableName = selected['name'];
            final t = selected['type'] ?? '';
            _selectedGameType = _gameCategoryForTableTypeId(
              t,
              ref
                  .read(tableTypeDefinitionsProvider)
                  .maybeWhen(data: (d) => d, orElse: () => null),
            );
          });
        }
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.table_bar,
              size: isMobile ? 18 : 20,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Table (Optional)',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedTableName ?? 'Tap to select',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 15,
                    fontWeight: FontWeight.w500,
                    color: _selectedTableName == null
                        ? cs.onSurfaceVariant.withValues(alpha: 0.65)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          if (_selectedTableId != null)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedTableId = null;
                  _selectedTableName = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, size: 14, color: cs.onSurfaceVariant),
              ),
            )
          else
            Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _buildMultiLoserSelector(BuildContext context, bool isMobile) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        ..._selectedLosers.map(
          (c) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 10 : 12,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: isMobile ? 16 : 18,
                    backgroundColor: cs.error.withValues(alpha: 0.12),
                    child: Text(
                      c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: cs.error,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isMobile ? 14 : 15,
                          ),
                        ),
                        Text(
                          c.phoneNumber,
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(
                        () => _selectedLosers.removeWhere((x) => x.id == c.id),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: cs.error.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 16, color: cs.error),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await HapticFeedback.lightImpact();
                  if (!context.mounted) return;
                  final customer = await _selectCustomer(context);
                  if (customer == null) return;
                  if (_selectedWinner != null &&
                      customer.id == _selectedWinner!.id) {
                    return;
                  }
                  if (_selectedLosers.any((x) => x.id == customer.id)) return;
                  setState(() => _selectedLosers.add(customer));
                },
                icon: Icon(Icons.person_add_rounded, size: isMobile ? 18 : 20),
                label: Text(
                  'Add Loser',
                  style: TextStyle(fontSize: isMobile ? 13 : 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.error.withValues(alpha: 0.12),
                  foregroundColor: cs.error,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (_selectedLosers.isNotEmpty) ...[
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedLosers.clear());
                },
                icon: Icon(Icons.delete_outline, size: isMobile ? 16 : 18),
                label: Text(
                  'Clear',
                  style: TextStyle(fontSize: isMobile ? 12 : 13),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, bool isMobile) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      backgroundColor: cs.primaryContainer.withValues(alpha: 0.35),
      borderColor: cs.primary.withValues(alpha: 0.22),
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.info_outline, color: cs.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Award points to match winners',
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Point presets vary by game. Loser selection is optional.',
            style: TextStyle(
              color: cs.onPrimaryContainer.withValues(alpha: 0.9),
              fontSize: isMobile ? 12 : 13,
            ),
          ),
        ],
      ),
    );
  }

  // _buildCategoryInfo removed - simplified info card

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerSelector({
    required BuildContext context,
    required Customer? customer,
    required String label,
    required VoidCallback onSelect,
    required VoidCallback onClear,
  }) {
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;
    final cs = Theme.of(context).colorScheme;
    final isWinner = label == 'Winner';
    final accentColor = isWinner ? cs.tertiary : cs.onSurfaceVariant;

    return AppCard(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      borderColor: customer != null ? accentColor.withValues(alpha: 0.3) : null,
      onTap: onSelect,
      child: customer == null
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.person_add,
                    color: cs.onSurfaceVariant,
                    size: isMobile ? 20 : 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Tap to select $label',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: isMobile ? 14 : 15,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isWinner ? cs.tertiary : cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    customer.name[0].toUpperCase(),
                    style: TextStyle(
                      color: isWinner ? cs.onTertiary : cs.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 15 : 16,
                        ),
                      ),
                      Text(
                        customer.phoneNumber,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: isMobile ? 12 : 13,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClear,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGameTypeSelector(
    ThemeData theme,
    bool isMobile,
    List<String> gameTypeKeys,
  ) {
    final cs = theme.colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: AppTheme.scrollPhysicsFor(context),
      child: Row(
        children: gameTypeKeys.map((type) {
          final isSelected = _selectedGameType == type;
          final color = GameCategoryCatalog.categoryAccent(type, cs);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedGameType = type;
                  final defaultPoint = _currentPresets.isNotEmpty
                      ? _currentPresets[0]
                      : 10;
                  _pointsController.text = defaultPoint.toString();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 14,
                  vertical: isMobile ? 10 : 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? cs.primaryContainer
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? color
                        : cs.outline.withValues(alpha: 0.35),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      GameCategoryCatalog.iconFor(type),
                      size: isMobile ? 16 : 18,
                      color: isSelected
                          ? cs.onPrimaryContainer
                          : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      GameCategoryCatalog.displayName(type),
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPointsSection(bool isMobile) {
    final presetPoints = _currentPresets;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppCard(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.tertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.stars_rounded, size: 20, color: cs.tertiary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Points to Award',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: cs.outline.withValues(alpha: 0.35),
                              ),
                            ),
                            child: TextField(
                              controller: _pointsController,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                suffixText: 'pts',
                                suffixStyle: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: isMobile ? 12 : 13,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 20,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            _buildPointButton('+5', () {
                              final current =
                                  int.tryParse(_pointsController.text) ?? 0;
                              setState(
                                () => _pointsController.text = (current + 5)
                                    .clamp(1, 10000)
                                    .toString(),
                              );
                            }),
                            const SizedBox(height: 4),
                            _buildPointButton('-5', () {
                              final current =
                                  int.tryParse(_pointsController.text) ?? 0;
                              setState(
                                () => _pointsController.text = (current - 5)
                                    .clamp(0, 10000)
                                    .toString(),
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Quick Select:',
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presetPoints.map((points) {
              final isSelected = _pointsController.text == points.toString();
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _pointsController.text = points.toString());
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 14,
                    vertical: isMobile ? 8 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cs.primary.withValues(alpha: 0.15)
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? cs.primary
                          : cs.outline.withValues(alpha: 0.35),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    '$points pts',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPointButton(String label, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 36,
        height: 28,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context, bool isMobile) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _selectedWinner == null || _isSubmitting
            ? null
            : _submitAward,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: _isSubmitting ? 0 : 2,
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: theme.colorScheme.onPrimary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events_rounded, size: isMobile ? 20 : 22),
                  const SizedBox(width: 10),
                  Text(
                    'Award Points',
                    style: TextStyle(
                      fontSize: isMobile ? 15 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<Customer?> _selectCustomer(BuildContext context) async {
    return await showSearch<Customer?>(
      context: context,
      delegate: EnhancedCustomerSearchDelegate(
        customers: ref.read(tenantRefProvider)!.customers(),
        membershipDefinitions:
            ref.read(activeMembershipTypeDefinitionsProvider).valueOrNull ?? [],
        canAddCustomer:
            ref.readResolvedPermissions().can(PermissionIds.navCustomers),
      ),
    );
  }

  Future<void> _submitAward() async {
    if (_selectedWinner == null) return;

    final points = double.tryParse(_pointsController.text) ?? 0;
    if (points <= 0) {
      _showErrorDialog('Please enter a valid points value');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUser = ref.read(appUserProvider).value;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final service = ref.read(leaderboardServiceProvider);
      if (_selectedLosers.isEmpty) {
        await service.awardPointsToWinner(
          winner: _selectedWinner!,
          points: points,
          awardedBy: currentUser,
          gameType: _selectedGameType,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text
              : null,
          tableId: _selectedTableId,
          tableName: _selectedTableName,
        );
      } else {
        await service.awardPointsToWinnerMultiLosers(
          winner: _selectedWinner!,
          losers: _selectedLosers,
          points: points,
          awardedBy: currentUser,
          gameType: _selectedGameType,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text
              : null,
          splitPointsAmongLosers: _splitPoints,
          tableId: _selectedTableId,
          tableName: _selectedTableName,
        );
      }

      if (mounted) {
        final snackCs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully awarded $points points to ${_selectedWinner!.name}!',
              style: TextStyle(color: snackCs.onTertiary),
            ),
            backgroundColor: snackCs.tertiary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to award points: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _gameCategoryForTableTypeId(
    String typeId,
    List<TableTypeDefinition>? defs,
  ) {
    if (defs != null) {
      final d = lookupTableType(defs, typeId);
      if (d != null) return d.gameCategoryKey;
    }
    switch (typeId.toLowerCase()) {
      case 'snooker':
        return 'snooker';
      case 'pool':
        return 'pool';
      case 'carrom':
        return 'carrom';
      case 'darts':
        return 'darts';
      case 'ps5':
        return 'ps5';
      default:
        return 'other';
    }
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _TablePickerDialog extends ConsumerStatefulWidget {
  final TenantRef tenant;
  const _TablePickerDialog({required this.tenant});

  @override
  ConsumerState<_TablePickerDialog> createState() => _TablePickerDialogState();
}

class _TablePickerDialogState extends ConsumerState<_TablePickerDialog> {
  bool _availableOnly = false;
  String _typeFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final venueKind = ref.watch(venueKindProvider);
    final typeDefs = ref
        .watch(tableTypeDefinitionsProvider)
        .maybeWhen(data: (d) => d, orElse: () => <TableTypeDefinition>[]);
    final activeTypes = typeDefs.where((d) => !d.isArchived).toList();
    return AlertDialog(
      title: const Text('Select Table'),
      content: SizedBox(
        width: 480,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Switch(
                  value: _availableOnly,
                  onChanged: (v) => setState(() => _availableOnly = v),
                ),
                const SizedBox(width: 8),
                const Text('Available only'),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTypeChip('all', 'ALL'),
                ...activeTypes.map(
                  (d) => _buildTypeChip(d.id, d.name.toUpperCase()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: widget.tenant.tables().orderBy('name').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('Error loading tables');
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) return const Text('No tables found');
                  final tables = docs
                      .map((d) {
                        final data = d.data() as Map<String, dynamic>;
                        return SnookerTable.fromJson(
                          {...data, 'id': d.id},
                          venueKind: venueKind,
                        );
                      })
                      .where((t) {
                        final passAvail =
                            !_availableOnly ||
                            t.status == TableStatus.available;
                        final passType =
                            _typeFilter == 'all' || t.typeId == _typeFilter;
                        return passAvail && passType;
                      })
                      .toList();
                  if (tables.isEmpty) {
                    return const Text('No tables match filters');
                  }
                  return ListView.separated(
                    itemCount: tables.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final table = tables[index];
                      return ListTile(
                        leading: const Icon(Icons.table_bar),
                        title: Text(table.name),
                        subtitle: Text(
                          '${resolveTableTypeDisplayLabel(typeDefs, table.typeId, venueKind: venueKind).toUpperCase()} · ₹${table.hourlyRate.toStringAsFixed(0)}/hr',
                        ),
                        trailing: Text(
                          table.status.name.toUpperCase(),
                          style: TextStyle(
                            color: table.status == TableStatus.available
                                ? cs.tertiary
                                : cs.secondary,
                          ),
                        ),
                        onTap: () => Navigator.pop(context, {
                          'id': table.id,
                          'name': table.name,
                          'type': table.typeId,
                        }),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildTypeChip(String value, String label) {
    final selected = _typeFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _typeFilter = value),
    );
  }
}
