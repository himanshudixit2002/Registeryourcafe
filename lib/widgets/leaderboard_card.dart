import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../models/game_category_catalog.dart';
import '../providers/leaderboard_provider.dart';
import 'glass_panel.dart';

class LeaderboardCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onAwardTap;

  const LeaderboardCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onAwardTap,
  });

  static (Color rankColor, IconData? medalIcon) _rankStyle(
    int rank,
    ColorScheme cs,
  ) {
    if (rank == 1) {
      return (cs.tertiary, Icons.emoji_events);
    }
    if (rank == 2) {
      return (cs.secondary, Icons.emoji_events);
    }
    if (rank == 3) {
      return (cs.primary, Icons.emoji_events);
    }
    return (cs.onSurfaceVariant, null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final customer = entry.customer;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final (rankColor, medalIcon) = _rankStyle(entry.rank, cs);

    return AppSurface(
      borderRadius: 12,
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 4 : 8,
        vertical: isMobile ? 3 : 4,
      ),
      onTap: onTap,
      borderColor: entry.rank <= 3 ? rankColor.withValues(alpha: 0.35) : null,
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      child: isMobile
          ? _buildMobileLayout(
              context,
              theme,
              cs,
              customer,
              rankColor,
              medalIcon,
            )
          : _buildDesktopLayout(
              context,
              theme,
              cs,
              customer,
              rankColor,
              medalIcon,
            ),
    );
  }

  /// Mobile layout: Points prominently displayed, compact stats
  Widget _buildMobileLayout(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    Customer customer,
    Color rankColor,
    IconData? medalIcon,
  ) {
    return Row(
      children: [
        // Rank badge
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: rankColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: medalIcon != null
                ? Icon(medalIcon, color: rankColor, size: 24)
                : Text(
                    '#${entry.rank}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: rankColor,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        // Name and stats
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      customer.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (entry.gameCategory != null &&
                      entry.gameCategory != 'all') ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        GameCategoryCatalog.shortLabel(entry.gameCategory!),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              // Compact win/loss row
              Row(
                children: [
                  Icon(Icons.emoji_events, size: 12, color: cs.tertiary),
                  const SizedBox(width: 2),
                  Text(
                    '${entry.wins}W',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.close, size: 12, color: cs.error),
                  const SizedBox(width: 2),
                  Text(
                    '${entry.losses}L',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (entry.draws > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${entry.draws}D',
                      style: TextStyle(fontSize: 11, color: cs.secondary),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        // Points - prominently displayed
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withValues(alpha: 0.15),
                theme.colorScheme.primary.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                entry.points.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                'pts',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Desktop layout: Full stats display
  Widget _buildDesktopLayout(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    Customer customer,
    Color rankColor,
    IconData? medalIcon,
  ) {
    return Row(
      children: [
        // Rank indicator
        SizedBox(
          width: 50,
          child: Column(
            children: [
              if (medalIcon != null)
                Icon(medalIcon, color: rankColor, size: 32)
              else
                Text(
                  '#${entry.rank}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: rankColor,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Customer info
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      customer.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (entry.gameCategory != null &&
                      entry.gameCategory != 'all') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        GameCategoryCatalog.shortLabel(entry.gameCategory!),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                customer.phoneNumber,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // Stats for current context
        Expanded(
          flex: 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Flexible(
                child: _StatColumn(
                  label: 'Points',
                  value: entry.points.toStringAsFixed(0),
                  color: theme.colorScheme.primary,
                ),
              ),
              Flexible(
                child: _StatColumn(
                  label: 'Wins',
                  value: entry.wins.toString(),
                  color: cs.tertiary,
                ),
              ),
              Flexible(
                child: _StatColumn(
                  label: 'Losses',
                  value: entry.losses.toString(),
                  color: cs.error,
                ),
              ),
              Flexible(
                child: _StatColumn(
                  label: 'Draws',
                  value: entry.draws.toString(),
                  color: cs.secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isMobile ? 13 : 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        SizedBox(height: isMobile ? 1 : 2),
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 9 : 11,
            color: cs.onSurfaceVariant,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}

class CompactLeaderboardCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final VoidCallback? onTap;

  const CompactLeaderboardCard({super.key, required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customer = entry.customer;

    final (rankColor, _) = LeaderboardCard._rankStyle(
      entry.rank,
      theme.colorScheme,
    );

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: rankColor.withValues(alpha: 0.2),
        child: Text(
          '#${entry.rank}',
          style: TextStyle(color: rankColor, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        customer.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('${entry.wins}W / ${entry.losses}L'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${entry.points.toStringAsFixed(0)} pts',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
