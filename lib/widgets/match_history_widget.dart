import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/game_match.dart';
import '../theme/app_theme.dart';
import 'glass_panel.dart';

class MatchHistoryWidget extends StatelessWidget {
  final List<GameMatch> matches;
  final String customerId;
  final bool showCompact;

  const MatchHistoryWidget({
    super.key,
    required this.matches,
    required this.customerId,
    this.showCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      final theme = Theme.of(context);
      final cs = theme.colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sports_esports_outlined,
                size: 64,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No match history yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: matches.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final match = matches[index];
        final isWinner = match.winnerId == customerId;

        return showCompact
            ? _buildCompactMatchTile(context, match, isWinner)
            : _buildDetailedMatchTile(context, match, isWinner);
      },
    );
  }

  Widget _buildCompactMatchTile(
    BuildContext context,
    GameMatch match,
    bool isWinner,
  ) {
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: isWinner
                ? sem.success.withValues(alpha: 0.2)
                : cs.error.withValues(alpha: 0.2),
            child: Icon(
              isWinner ? Icons.emoji_events : Icons.close,
              color: isWinner ? sem.success : cs.error,
              size: 20,
            ),
          ),
          if (!match.isManualEntry)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: sem.info,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surface, width: 1),
                ),
                child: Icon(Icons.table_bar, size: 8, color: cs.surface),
              ),
            ),
        ],
      ),
      title: Text(
        isWinner
            ? 'Won against ${match.loserName ?? "Unknown"}'
            : 'Lost to ${match.winnerName}',
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        '${DateFormat('MMM dd, yyyy').format(match.matchDate)}${!match.isManualEntry ? ' • PTL' : ''}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: isWinner
          ? Text(
              '+${match.pointsAwarded.toStringAsFixed(0)} pts',
              style: TextStyle(
                color: sem.success,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  Widget _buildDetailedMatchTile(
    BuildContext context,
    GameMatch match,
    bool isWinner,
  ) {
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    return AppSurface(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isWinner
                      ? sem.success.withValues(alpha: 0.1)
                      : cs.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isWinner ? 'WIN' : 'LOSS',
                  style: TextStyle(
                    color: isWinner ? sem.success : cs.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                match.gameType.toUpperCase(),
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (!match.isManualEntry) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: sem.infoContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.table_bar,
                        size: 10,
                        color: sem.onInfoContainer,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'PTL',
                        style: TextStyle(
                          color: sem.onInfoContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              Text(
                DateFormat('MMM dd, yyyy').format(match.matchDate),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Winner',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      match.winnerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Loser',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      match.loserName ?? 'N/A',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isWinner) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: sem.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stars, color: sem.success, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '+${match.pointsAwarded.toStringAsFixed(0)} Points Awarded',
                    style: TextStyle(
                      color: sem.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (match.notes != null && match.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Notes: ${match.notes}',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (match.awardedByName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Recorded by: ${match.awardedByName}',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
