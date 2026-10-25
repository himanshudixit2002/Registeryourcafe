import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/tournament.dart';
import '../../providers/tournament_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/section_async_error.dart';

class TournamentBracketWidget extends ConsumerWidget {
  final String tournamentId;
  final void Function(TournamentMatch)? onMatchTap;

  const TournamentBracketWidget({
    super.key,
    required this.tournamentId,
    this.onMatchTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentAsync = ref.watch(tournamentProvider(tournamentId));
    final matchesAsync = ref.watch(tournamentMatchesProvider(tournamentId));

    return tournamentAsync.when(
      data: (tournament) {
        if (tournament == null) {
          return const Center(child: Text('Tournament not found'));
        }

        return matchesAsync.when(
          data: (matches) {
            if (matches.isEmpty) {
              return const Center(child: Text('No matches generated yet'));
            }

            // Group matches by round
            final matchesByRound = <int, List<TournamentMatch>>{};
            for (final match in matches) {
              matchesByRound.putIfAbsent(match.round, () => []).add(match);
            }

            // Sort matches within each round
            for (final list in matchesByRound.values) {
              list.sort((a, b) => a.matchNumber.compareTo(b.matchNumber));
            }

            return _BracketView(
              tournament: tournament,
              matchesByRound: matchesByRound,
              onMatchTap: onMatchTap,
            );
          },
          loading: () => const Center(
            child: LoadingIndicator(message: 'Loading bracket...'),
          ),
          error: (error, _) => SectionAsyncError(error: error),
        );
      },
      loading: () => const Center(
        child: LoadingIndicator(message: 'Loading tournament...'),
      ),
      error: (error, _) => SectionAsyncError(error: error),
    );
  }
}

class _BracketView extends StatelessWidget {
  final Tournament tournament;
  final Map<int, List<TournamentMatch>> matchesByRound;
  final void Function(TournamentMatch)? onMatchTap;

  const _BracketView({
    required this.tournament,
    required this.matchesByRound,
    this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalRounds = matchesByRound.keys.isNotEmpty
        ? matchesByRound.keys.reduce((a, b) => a > b ? a : b)
        : 0;

    if (totalRounds == 0) {
      return const Center(child: Text('No bracket data'));
    }

    final isMobile = AppTheme.isMobile(context);
    final bracketContent = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: isMobile ? const NeverScrollableScrollPhysics() : AppTheme.scrollPhysicsFor(context),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        physics: isMobile ? const NeverScrollableScrollPhysics() : AppTheme.scrollPhysicsFor(context),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(totalRounds, (index) {
            final round = index + 1;
            final roundMatches = matchesByRound[round] ?? [];

            return Row(
              children: [
                _RoundColumn(
                  roundNumber: round,
                  roundName: tournament.getRoundName(round),
                  matches: roundMatches,
                  totalRounds: totalRounds,
                  onMatchTap: onMatchTap,
                ),
                if (round < totalRounds)
                  _BracketConnectors(
                    matchCount: roundMatches.length,
                    nextMatchCount: (matchesByRound[round + 1] ?? []).length,
                    lineColor: Theme.of(context).colorScheme.outlineVariant,
                  ),
              ],
            );
          }),
        ),
      ),
    );

    if (isMobile) {
      return InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(80),
        minScale: 0.4,
        maxScale: 2.5,
        child: bracketContent,
      );
    }

    return bracketContent;
  }
}

class _RoundColumn extends StatelessWidget {
  final int roundNumber;
  final String roundName;
  final List<TournamentMatch> matches;
  final int totalRounds;
  final void Function(TournamentMatch)? onMatchTap;

  const _RoundColumn({
    required this.roundNumber,
    required this.roundName,
    required this.matches,
    required this.totalRounds,
    this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Calculate spacing based on round
    // Later rounds have more spacing between matches
    final spacingMultiplier = _calculateSpacingMultiplier(
      roundNumber,
      totalRounds,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Round header
        Container(
          width: 180,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            roundName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        // Matches
        ...matches.asMap().entries.map((entry) {
          final index = entry.key;
          final match = entry.value;
          return Column(
            children: [
              if (index > 0) SizedBox(height: 16 * spacingMultiplier),
              _MatchCard(
                match: match,
                onTap: onMatchTap != null ? () => onMatchTap!(match) : null,
              ),
            ],
          );
        }),
      ],
    );
  }

  double _calculateSpacingMultiplier(int round, int total) {
    // Exponential spacing: each round doubles the spacing
    return (1 << (round - 1)).toDouble();
  }
}

class _MatchCard extends StatelessWidget {
  final TournamentMatch match;
  final VoidCallback? onTap;

  const _MatchCard({required this.match, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompleted =
        match.status == MatchStatus.completed ||
        match.status == MatchStatus.walkover;
    final isInProgress = match.status == MatchStatus.inProgress;
    final isPending = match.status == MatchStatus.pending && match.isReady;

    Color borderColor = cs.outlineVariant;
    if (isCompleted) {
      borderColor = cs.tertiary;
    } else if (isInProgress) {
      borderColor = cs.secondary;
    } else if (isPending) {
      borderColor = cs.primary;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Player 1
            _PlayerSlot(
              name: match.participant1Name ?? 'TBD',
              score: match.participant1Score,
              isWinner:
                  match.winnerId == match.participant1Id &&
                  match.participant1Id != null,
              isBye: false,
            ),
            Container(height: 1, color: cs.outlineVariant),
            // Player 2
            _PlayerSlot(
              name: match.isBye ? 'BYE' : (match.participant2Name ?? 'TBD'),
              score: match.isBye ? null : match.participant2Score,
              isWinner:
                  match.winnerId == match.participant2Id &&
                  match.participant2Id != null,
              isBye: match.isBye,
            ),
            // Status indicator
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(6),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getStatusIcon(match.status),
                    size: 12,
                    color: borderColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    match.isBye ? 'Walkover' : match.status.displayName,
                    style: TextStyle(
                      fontSize: 10,
                      color: borderColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(MatchStatus status) {
    switch (status) {
      case MatchStatus.pending:
        return Icons.hourglass_empty;
      case MatchStatus.scheduled:
        return Icons.schedule;
      case MatchStatus.inProgress:
        return Icons.play_circle;
      case MatchStatus.completed:
        return Icons.check_circle;
      case MatchStatus.cancelled:
        return Icons.cancel;
      case MatchStatus.walkover:
        return Icons.arrow_forward;
    }
  }
}

class _PlayerSlot extends StatelessWidget {
  final String name;
  final int? score;
  final bool isWinner;
  final bool isBye;

  const _PlayerSlot({
    required this.name,
    this.score,
    required this.isWinner,
    required this.isBye,
  });

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = name == 'TBD' || isBye;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isWinner ? cs.tertiary.withValues(alpha: 0.12) : null,
      ),
      child: Row(
        children: [
          if (isWinner)
            Container(
              margin: const EdgeInsets.only(right: 6),
              child: Icon(Icons.emoji_events, size: 14, color: cs.tertiary),
            ),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                color: isPlaceholder ? cs.onSurfaceVariant : cs.onSurface,
                fontStyle: isBye ? FontStyle.italic : FontStyle.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (score != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isWinner ? cs.tertiary : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                score.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isWinner ? cs.onTertiary : cs.onSurface,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BracketConnectors extends StatelessWidget {
  final int matchCount;
  final int nextMatchCount;
  final Color lineColor;

  const _BracketConnectors({
    required this.matchCount,
    required this.nextMatchCount,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    // Simple connector lines between rounds
    return SizedBox(
      width: 40,
      child: CustomPaint(
        size: Size(40, matchCount * 100.0),
        painter: _ConnectorPainter(
          matchCount: matchCount,
          nextMatchCount: nextMatchCount,
          lineColor: lineColor,
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final int matchCount;
  final int nextMatchCount;
  final Color lineColor;

  _ConnectorPainter({
    required this.matchCount,
    required this.nextMatchCount,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final matchHeight = size.height / matchCount;
    final nextMatchHeight = size.height / nextMatchCount;

    for (int i = 0; i < nextMatchCount; i++) {
      final startY1 = i * 2 * matchHeight + matchHeight / 2;
      final startY2 = (i * 2 + 1) * matchHeight + matchHeight / 2;
      final endY = i * nextMatchHeight + nextMatchHeight / 2;

      // Draw horizontal lines from matches
      canvas.drawLine(
        Offset(0, startY1),
        Offset(size.width / 3, startY1),
        paint,
      );
      canvas.drawLine(
        Offset(0, startY2),
        Offset(size.width / 3, startY2),
        paint,
      );

      // Draw vertical line connecting them
      canvas.drawLine(
        Offset(size.width / 3, startY1),
        Offset(size.width / 3, startY2),
        paint,
      );

      // Draw horizontal line to next match
      final midY = (startY1 + startY2) / 2;
      canvas.drawLine(
        Offset(size.width / 3, midY),
        Offset(size.width, endY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TournamentBracketListView extends ConsumerWidget {
  final String tournamentId;
  final void Function(TournamentMatch)? onMatchTap;

  const TournamentBracketListView({
    super.key,
    required this.tournamentId,
    this.onMatchTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentAsync = ref.watch(tournamentProvider(tournamentId));
    final matchesAsync = ref.watch(tournamentMatchesProvider(tournamentId));

    return tournamentAsync.when(
      data: (tournament) {
        if (tournament == null) {
          return const Center(child: Text('Tournament not found'));
        }

        return matchesAsync.when(
          data: (matches) {
            if (matches.isEmpty) {
              return const Center(child: Text('No matches generated yet'));
            }

            // Group and sort matches by round
            final matchesByRound = <int, List<TournamentMatch>>{};
            for (final match in matches) {
              matchesByRound.putIfAbsent(match.round, () => []).add(match);
            }
            for (final list in matchesByRound.values) {
              list.sort((a, b) => a.matchNumber.compareTo(b.matchNumber));
            }

            final rounds = matchesByRound.keys.toList()..sort();

            return ListView.builder(
              physics: AppTheme.scrollPhysicsFor(context),
              padding: const EdgeInsets.all(16),
              itemCount: rounds.length,
              itemBuilder: (context, index) {
                final round = rounds[index];
                final roundMatches = matchesByRound[round]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tournament.getRoundName(round),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    ...roundMatches.map(
                      (match) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _MatchCard(
                          match: match,
                          onTap: onMatchTap != null
                              ? () => onMatchTap!(match)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            );
          },
          loading: () => const Center(
            child: LoadingIndicator(message: 'Loading matches...'),
          ),
          error: (error, _) => SectionAsyncError(error: error),
        );
      },
      loading: () => const Center(
        child: LoadingIndicator(message: 'Loading tournament...'),
      ),
      error: (error, _) => SectionAsyncError(error: error),
    );
  }
}
