import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/tournament.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';
import '../landing_providers.dart';

bool _isPermissionError(Object e) {
  final s = e.toString();
  return s.contains('permission-denied') || s.contains('PERMISSION_DENIED');
}

class EnhancedEventsScreen extends ConsumerWidget {
  const EnhancedEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final eventsAsync = ref.watch(publicTournamentsProvider);
    final pad = AppTheme.isDesktop(context)
        ? AppTheme.kSpacingXLarge
        : AppTheme.kSpacingMedium;

    return Scaffold(
      appBar: AppBar(title: const Text('Events & tournaments')),
      body: eventsAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 52, color: theme.colorScheme.error.withValues(alpha: 0.6)),
                const SizedBox(height: 16),
                Text('Could not load events', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  _isPermissionError(e) ? 'Access was denied. Anonymous sign-in may be disabled.' : 'Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.35),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 8),
                  SelectableText('$e', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error, fontSize: 11)),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(publicTournamentsProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (events) {
          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No upcoming events',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            );
          }
          return ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.fromLTRB(pad, 16, pad, 80),
            children: [
              Text(
                'Upcoming events',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '${events.length} events available',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              for (int idx = 0; idx < events.length; idx++) ...[
                FadeInWidget(
                  delay: Duration(milliseconds: 80 * idx),
                  child: _EventDetailCard(event: events[idx]),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EventDetailCard extends StatelessWidget {
  final Tournament event;
  const _EventDetailCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLive = event.status == TournamentStatus.inProgress;
    final isRegistration = event.status == TournamentStatus.registration;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(theme, isLive, isRegistration)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isLive ? 'LIVE' : isRegistration ? 'OPEN' : 'UPCOMING',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _statusColor(theme, isLive, isRegistration),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${event.startDate.day}/${event.startDate.month}/${event.startDate.year}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            event.name,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              event.description!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (event.entryFee > 0) ...[
                Icon(Icons.currency_rupee,
                    size: 14, color: theme.colorScheme.outline),
                Text(
                  '${event.entryFee.toStringAsFixed(0)} entry',
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(width: 16),
              ],
              if (event.prizePool > 0) ...[
                const Icon(Icons.emoji_events, size: 14, color: Colors.amber),
                const SizedBox(width: 2),
                Text(
                  '\u20B9${event.prizePool.toStringAsFixed(0)} prize',
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(width: 16),
              ],
              Icon(Icons.people, size: 14, color: theme.colorScheme.outline),
              const SizedBox(width: 2),
              Text(
                '${event.currentParticipantCount}/${event.maxParticipants}',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (isRegistration)
                Expanded(
                  child: FilledButton(
                    onPressed: () {},
                    child: const Text('Register'),
                  ),
                ),
              if (!isRegistration)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: Text(isLive ? 'Watch live' : 'Notify me'),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.share), onPressed: () {}),
              IconButton(
                icon: const Icon(Icons.bookmark_outline),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(ThemeData theme, bool isLive, bool isRegistration) {
    if (isLive) return Colors.red;
    if (isRegistration) return theme.colorScheme.primary;
    return theme.colorScheme.outline;
  }
}
