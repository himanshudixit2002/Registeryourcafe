import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/customer_feedback.dart';
import '../../providers/feedback_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_card.dart';

class FeedbackDashboardScreen extends ConsumerWidget {
  const FeedbackDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final feedbackAsync = ref.watch(feedbackListProvider);
    final isDesktop = AppTheme.isDesktop(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Customer feedback')),
      body: feedbackAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (feedbackList) {
          if (feedbackList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rate_review_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No feedback yet',
                      style: theme.textTheme.titleMedium),
                ],
              ),
            );
          }
          final avg = feedbackList.fold(0, (sum, f) => sum + f.rating) /
              feedbackList.length;
          return ListView(
            physics: AppTheme.scrollPhysicsFor(context),
            padding: EdgeInsets.fromLTRB(
              isDesktop
                  ? AppTheme.kSpacingXLarge
                  : AppTheme.kSpacingMedium,
              AppTheme.kSpacingMedium,
              isDesktop
                  ? AppTheme.kSpacingXLarge
                  : AppTheme.kSpacingMedium,
              AppTheme.kSpacingXLarge +
                  MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              AppCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Text(
                          avg.toStringAsFixed(1),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < avg.round()
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: Theme.of(context).colorScheme.tertiary,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${feedbackList.length} reviews',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final f in feedbackList) ...[
                _FeedbackTile(feedback: f),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FeedbackTile extends ConsumerWidget {
  final CustomerFeedback feedback;
  const _FeedbackTile({required this.feedback});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  feedback.customerName.isNotEmpty
                      ? feedback.customerName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  feedback.customerName,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < feedback.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Theme.of(context).colorScheme.tertiary,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          if (feedback.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(feedback.comment, style: theme.textTheme.bodyMedium),
          ],
          if (feedback.response != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Owner response',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(feedback.response!,
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${feedback.createdAt.day}/${feedback.createdAt.month}/${feedback.createdAt.year}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const Spacer(),
              if (feedback.response == null)
                TextButton.icon(
                  onPressed: () => _showRespondDialog(context, ref),
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('Respond'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showRespondDialog(
      BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Respond to feedback'),
        content: TextField(
          controller: controller,
          decoration:
              const InputDecoration(hintText: 'Your response...'),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty || !context.mounted) return;
    try {
      await ref
          .read(feedbackServiceProvider)
          ?.respondToFeedback(feedback.id, result);
      if (context.mounted) context.showSuccessSnackbar('Response sent');
    } catch (e) {
      if (context.mounted) context.showErrorSnackbar('Failed: $e');
    }
  }
}
