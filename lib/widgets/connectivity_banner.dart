import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connectivity_provider.dart';

/// Thin strip when the device has no network; complements Firestore local cache.
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineAsync = ref.watch(isOfflineProvider);
    return offlineAsync.when(
      data: (offline) {
        if (!offline) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        return Material(
          color: cs.tertiaryContainer.withValues(alpha: 0.92),
          child: SafeArea(
            bottom: false,
            minimum: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cloud_off_outlined, size: 20, color: cs.onTertiaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You appear to be offline. Cached data may be shown; '
                      'changes usually sync when you reconnect.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onTertiaryContainer,
                            height: 1.35,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (Object error, StackTrace stackTrace) =>
          const SizedBox.shrink(),
    );
  }
}
