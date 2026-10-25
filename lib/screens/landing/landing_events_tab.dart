import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tournament.dart';
import '../../theme/app_theme.dart';
import '../tournament/register_tournament_dialog.dart';
import 'landing_providers.dart';
import 'landing_public_widgets.dart';

/// Third surface: public tournament strip only.
class LandingEventsTab extends ConsumerWidget {
  const LandingEventsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.sizeOf(context).width < AppTheme.kMobileBreakpoint;
    final async = ref.watch(publicTournamentsProvider);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 48,
        16,
        isMobile ? 16 : 48,
        24,
      ),
      children: [
        Text(
          'Public events',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Browse tournaments and events that venues have made public.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        async.when(
          data: (list) {
            if (list.isEmpty) return const PublicTournamentsEmpty();
            return _buildList(context, list, isMobile);
          },
          loading: () => _skeletons(isMobile),
          error: (e, _) => _ErrorCard(error: e, onRetry: () => ref.invalidate(publicTournamentsProvider)),
        ),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    List<Tournament> list,
    bool isMobile,
  ) {
    if (isMobile) {
      return Column(
        children: list
            .map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PublicTournamentCard(
                  tournament: t,
                  onRegister: t.status == TournamentStatus.registration
                      ? () => _openRegister(context, t)
                      : null,
                ),
              ),
            )
            .toList(),
      );
    }
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: list
          .map(
            (t) => SizedBox(
              width: 320,
              child: PublicTournamentCard(
                tournament: t,
                onRegister: t.status == TournamentStatus.registration
                    ? () => _openRegister(context, t)
                    : null,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _skeletons(bool isMobile) {
    return Column(
      children: List.generate(
        isMobile ? 4 : 3,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: PublicTournamentSkeleton(),
        ),
      ),
    );
  }

  void _openRegister(BuildContext context, Tournament tournament) {
    showDialog<void>(
      context: context,
      builder: (_) => RegisterTournamentDialog(tournament: tournament),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry, this.error});

  final VoidCallback onRetry;
  final Object? error;

  bool get _isPermission {
    final s = error?.toString() ?? '';
    return s.contains('permission-denied') || s.contains('PERMISSION_DENIED');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
        border: Border.all(color: scheme.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(
            _isPermission ? Icons.lock_outline_rounded : Icons.wifi_off_rounded,
            size: 40,
            color: scheme.error.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            _isPermission ? 'Access denied' : 'Could not load events',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _isPermission
                ? 'Anonymous sign-in may be disabled, or Firestore rules are blocking this query.'
                : 'Check your connection and try again.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
            textAlign: TextAlign.center,
          ),
          if (kDebugMode && error != null) ...[
            const SizedBox(height: 8),
            SelectableText('$error', style: theme.textTheme.bodySmall?.copyWith(color: scheme.error, fontSize: 10)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
