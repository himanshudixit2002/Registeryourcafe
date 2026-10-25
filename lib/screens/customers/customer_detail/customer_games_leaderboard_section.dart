import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/customer.dart';
import '../../../providers/leaderboard_provider.dart'
    show customerMatchHistoryProvider;
import '../../../providers/tenant_provider.dart';
import '../../../services/ptl_match_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/firestore_utils.dart';
import '../../../widgets/glass_panel.dart';
import '../../../widgets/section_async_error.dart';

/// Snooker / PTL stats and recent matches for gaming venues.
class CustomerGamesLeaderboardSection extends ConsumerWidget {
  const CustomerGamesLeaderboardSection({super.key, required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final matchesAsync = ref.watch(customerMatchHistoryProvider(customer.id));
    final tenant = ref.watch(tenantRefProvider);

    return AppSurface(
      padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Games & Leaderboard',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.kSpacingMedium),
          if (tenant == null)
            Text(
              'Company context unavailable.',
              style: theme.textTheme.bodyMedium,
            )
          else
            StreamBuilder<DocumentSnapshot>(
              stream: tenant.customers().doc(customer.id).snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() as Map<String, dynamic>?;
                final stats =
                    (data?['gameStats'] as Map<String, dynamic>?) ?? {};
                final wins = parseFirestoreInt(stats['gamesWon']);
                final losses = parseFirestoreInt(stats['gamesLost']);
                final draws = parseFirestoreInt(stats['gamesDrawn']);
                final currentPts = parseFirestoreDouble(
                  stats['currentLeaderboardPoints'],
                );
                final totalPts = parseFirestoreDouble(
                  stats['totalPointsEarned'],
                );
                final cs = theme.colorScheme;

                Widget metric(String label, String value, Color color) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        metric('Wins', wins.toString(), cs.tertiary),
                        metric('Losses', losses.toString(), cs.error),
                        metric('Draws', draws.toString(), cs.secondary),
                        metric(
                          'Current Pts',
                          currentPts.toStringAsFixed(0),
                          cs.primary,
                        ),
                        metric(
                          'Total Pts',
                          totalPts.toStringAsFixed(0),
                          cs.tertiary,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: AppTheme.kSpacingMedium),
          FutureBuilder<Map<String, dynamic>>(
            future: () {
              final t = ref.read(tenantRefProvider);
              if (t == null) {
                return Future.value(<String, dynamic>{});
              }
              return PTLMatchService(t).getPTLStatsForCustomer(customer.id);
            }(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }
              final p = snapshot.data!;
              final cs = theme.colorScheme;
              Widget chip(IconData icon, String label, Color color) {
                return Chip(
                  avatar: Icon(icon, size: 18, color: color),
                  label: Text(label),
                  backgroundColor: color.withValues(alpha: 0.08),
                  side: BorderSide(color: color.withValues(alpha: 0.3)),
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  chip(
                    Icons.emoji_events,
                    'PTL Wins: ${p['ptlWins']}',
                    cs.tertiary,
                  ),
                  chip(
                    Icons.close,
                    'PTL Losses: ${p['ptlLosses']}',
                    cs.error,
                  ),
                  chip(
                    Icons.stars,
                    'PTL Points: ${(p['ptlPointsEarned'] as double).toStringAsFixed(0)}',
                    cs.tertiary,
                  ),
                  chip(
                    Icons.sports_esports,
                    'PTL Sessions: ${p['ptlSessionsPlayed']}',
                    cs.primary,
                  ),
                  chip(
                    Icons.percent,
                    'PTL Win Rate: ${(p['ptlWinRate'] as double).toStringAsFixed(0)}%',
                    cs.secondary,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppTheme.kSpacingMedium),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: false,
            title: Text(
              'Recent Matches',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            children: [
              const SizedBox(height: AppTheme.kSpacingSmall),
              matchesAsync.when(
                data: (matches) {
                  if (matches.isEmpty) {
                    return const ListTile(
                      dense: true,
                      title: Text('No matches yet'),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: matches.length.clamp(0, 10),
                    separatorBuilder: (c, _) => Divider(
                      height: 8,
                      color: AppTheme.subtleDividerColor(Theme.of(c)),
                    ),
                    itemBuilder: (context, index) {
                      final m = matches[index];
                      final isWinner = m.winnerId == customer.id;
                      final cs = theme.colorScheme;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isWinner ? Icons.emoji_events : Icons.close,
                          color: isWinner ? cs.tertiary : cs.error,
                        ),
                        title: Text(
                          isWinner
                              ? 'Won vs ${m.loserName ?? "Unknown"}'
                              : 'Lost to ${m.winnerName}',
                        ),
                        subtitle: Text(m.matchDate.toString().split(' ').first),
                        trailing: isWinner
                            ? Text(
                                '+${m.pointsAwarded.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: cs.tertiary,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
                error: (e, s) => SectionAsyncError(error: e),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
