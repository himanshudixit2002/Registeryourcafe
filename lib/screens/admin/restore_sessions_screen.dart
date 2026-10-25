import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/permission_id.dart';
import '../../models/session.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/table_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/app_card.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/permission_denied_scaffold.dart';

class RestoreSessionsScreen extends ConsumerStatefulWidget {
  const RestoreSessionsScreen({super.key});

  @override
  ConsumerState<RestoreSessionsScreen> createState() =>
      _RestoreSessionsScreenState();
}

class _RestoreSessionsScreenState extends ConsumerState<RestoreSessionsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  final Set<String> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _markAsCompleted(TableSession session) async {
    setState(() => _processingIds.add(session.id));
    await HapticFeedback.mediumImpact();

    try {
      await ref
          .read(tableServiceProvider)
          .markOrphanCancelledAsCompleted(session: session);

      if (mounted) {
        context.showSuccessSnackbar(
          'Session marked as completed! Sales are now tracked.',
        );
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(session.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppTheme.kMobileBreakpoint;

    if (!ref.watchResolvedPermissions().can(PermissionIds.opsSessionAdmin)) {
      return const PermissionDeniedScaffold(
        title: 'Restore Sessions',
        message: 'You do not have access to session administration.',
      );
    }

    final orphanSessionsAsync = ref.watch(orphanCancelledSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restore Sessions'),
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
                  color: theme.colorScheme.shadow.withValues(alpha: 0.08),
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
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  children: [
                    _buildHeaderIcon(context, theme),
                    const SizedBox(height: 16),
                    Text(
                      'Affected Sessions',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'These sessions were incorrectly cancelled.\nMark them as completed to track sales.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Session List
              Expanded(
                child: orphanSessionsAsync.when(
                  data: (sessions) {
                    if (sessions.isEmpty) {
                      return const Center(
                        child: EmptyStateWidget(
                          icon: Icons.check_circle_outline,
                          message: 'No affected sessions',
                          details:
                              'All sessions are healthy. Nothing to restore.',
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 24,
                        vertical: 8,
                      ),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        return _buildSessionCard(
                          context,
                          theme,
                          session,
                          isMobile,
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: LoadingIndicator(message: 'Loading sessions...'),
                  ),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load sessions',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
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

  Widget _buildHeaderIcon(BuildContext context, ThemeData theme) {
    final sem = AppSemanticColors.of(context);
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [sem.warning, theme.colorScheme.error],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: sem.warning.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        Icons.restore_rounded,
        color: sem.onWarning,
        size: 32,
      ),
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    ThemeData theme,
    TableSession session,
    bool isMobile,
  ) {
    final cs = theme.colorScheme;
    final sem = AppSemanticColors.of(context);
    final isProcessing = _processingIds.contains(session.id);
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final endTime = session.endTime;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: EdgeInsets.all(isMobile ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.table_restaurant,
                    color: cs.error,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.tableName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.customerName,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Cancelled',
                    style: TextStyle(
                      color: cs.onErrorContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            Divider(
              color: AppTheme.subtleDividerColor(theme),
              height: 1,
            ),
            const SizedBox(height: 14),

            // Session Details
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    context,
                    icon: Icons.play_arrow_rounded,
                    label: 'Started',
                    value: dateFormat.format(session.startTime),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoItem(
                    context,
                    icon: Icons.stop_rounded,
                    label: 'Terminated',
                    value: endTime != null
                        ? dateFormat.format(endTime)
                        : 'Unknown',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    context,
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: session.formattedDuration,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoItem(
                    context,
                    icon: Icons.currency_rupee,
                    label: 'Hourly Rate',
                    value: '₹${session.hourlyRate.toStringAsFixed(0)}/hr',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Estimated bill amount
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sem.successContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: sem.success.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 18,
                    color: sem.success,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Estimated Bill: ',
                    style: TextStyle(
                      color: sem.onSuccessContainer,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '₹${_calculateEstimatedBill(session).toStringAsFixed(0)}',
                    style: TextStyle(
                      color: sem.onSuccessContainer,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            if (session.isPTL) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.group,
                          size: 14,
                          color: cs.onTertiaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'PTL Mode • ${session.playerCount ?? 2} Players',
                          style: TextStyle(
                            color: cs.onTertiaryContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Mark as Completed Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: isProcessing
                    ? null
                    : () => _markAsCompleted(session),
                icon: isProcessing
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            sem.onSuccess,
                          ),
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: Text(
                  isProcessing ? 'Processing...' : 'Mark as Completed',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: sem.success,
                  foregroundColor: sem.onSuccess,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isProcessing ? 0 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: muted),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: muted, fontSize: 11),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _calculateEstimatedBill(TableSession session) {
    // Calculate table charges
    final endTime = session.endTime ?? DateTime.now();
    final duration = endTime.difference(session.startTime);
    final pausedSeconds = session.totalPausedSeconds;
    final billableMinutes = duration.inMinutes - (pausedSeconds ~/ 60);
    double elapsedHours = billableMinutes / 60.0;

    // Apply minimum billable time if configured
    if ((session.minimumBillableMinutes ?? 0) > 0) {
      final double minHours = (session.minimumBillableMinutes! / 60.0);
      if (elapsedHours < minHours) elapsedHours = minHours;
    }

    final double tableCharges = elapsedHours * session.hourlyRate;
    final double cafeAmount = session.totalCafeAmount ?? 0;
    final double merchandiseAmount = session.totalMerchandiseAmount ?? 0;

    return tableCharges + cafeAmount + merchandiseAmount;
  }
}
