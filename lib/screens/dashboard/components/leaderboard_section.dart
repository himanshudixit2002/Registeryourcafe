import 'package:flutter/material.dart';
import '../../../widgets/dashboard_leaderboard_widget.dart';
import '../../../theme/app_theme.dart';

class LeaderboardSection extends StatelessWidget {
  const LeaderboardSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = AppTheme.isDesktop(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leaderboard & Competition',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(flex: 2, child: DashboardLeaderboardWidget()),
              const SizedBox(width: 24),
              const Expanded(flex: 1, child: DashboardLeaderboardStatsWidget()),
            ],
          )
        else
          const Column(
            children: [
              DashboardLeaderboardWidget(),
              SizedBox(height: 24),
              DashboardLeaderboardStatsWidget(),
            ],
          ),
      ],
    );
  }
}
