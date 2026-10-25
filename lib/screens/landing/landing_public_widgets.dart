import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/tournament.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';

/// Compact empty state (dark-theme safe).
class PublicTournamentsEmpty extends StatelessWidget {
  const PublicTournamentsEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No public events right now',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Tournaments and events will appear here when venues publish them. Check back soon!',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class PublicTournamentSkeleton extends StatelessWidget {
  const PublicTournamentSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme.outline.withValues(alpha: 0.28);
    return Container(
      height: 132,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 12,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const Spacer(),
              Container(
                width: 48,
                height: 12,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: 180,
            height: 16,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const Spacer(),
          Container(
            height: 10,
            width: double.infinity,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slim tournament row/card for public landing (theme-aware).
class PublicTournamentCard extends StatelessWidget {
  final Tournament tournament;
  final VoidCallback? onRegister;

  const PublicTournamentCard({
    super.key,
    required this.tournament,
    this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLive = tournament.status == TournamentStatus.inProgress;
    final isRegistration = tournament.status == TournamentStatus.registration;

    Color statusColor;
    String statusLabel;
    if (isLive) {
      statusColor = AppTheme.successColor;
      statusLabel = 'LIVE';
    } else if (isRegistration) {
      statusColor = theme.colorScheme.secondary;
      statusLabel = 'REGISTER';
    } else {
      statusColor = AppTheme.warningColor;
      statusLabel = 'SOON';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isRegistration ? onRegister : null,
        borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppTheme.kBorderRadiusMedium),
            border: Border.all(
              color: statusColor.withValues(alpha: isLive ? 0.45 : 0.2),
              width: isLive ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isLive)
                    const PulsingDot(
                      color: AppTheme.successColor,
                      showGlow: true,
                    )
                  else
                    Icon(Icons.circle, size: 8, color: statusColor),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    tournament.gameType.displayName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                tournament.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                _metaLine(tournament),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (isRegistration && onRegister != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: onRegister,
                    child: const Text('Register'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _metaLine(Tournament t) {
    final entry = t.entryFee > 0
        ? '₹${t.entryFee.toStringAsFixed(0)}'
        : 'Free entry';
    final prize = t.prizePool > 0
        ? 'Prize ₹${t.prizePool.toStringAsFixed(0)}'
        : 'Prize TBD';
    final dateStr = DateFormat.MMMd().format(t.startDate);
    return '$entry · $prize · $dateStr';
  }
}
