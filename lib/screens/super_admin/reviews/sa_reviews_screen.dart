import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/super_admin_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';

class SAReviewsScreen extends ConsumerStatefulWidget {
  const SAReviewsScreen({super.key});

  @override
  ConsumerState<SAReviewsScreen> createState() => _SAReviewsScreenState();
}

class _SAReviewsScreenState extends ConsumerState<SAReviewsScreen> {
  String _search = '';
  int _ratingFilter = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reviewsAsync = ref.watch(allReviewsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Moderation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(allReviewsProvider),
          ),
        ],
      ),
      body: reviewsAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('Error loading reviews', style: TextStyle(color: cs.error)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(allReviewsProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (reviews) {
          if (reviews.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.rate_review_outlined, size: 64, color: cs.onSurfaceVariant),
              const SizedBox(height: 16), Text('No reviews', style: theme.textTheme.titleMedium),
            ]));
          }

          double totalRating = 0;
          int flagged = 0;
          for (final r in reviews) {
            final d = r.data();
            totalRating += (d['rating'] as num?)?.toDouble() ?? 0;
            if (d['flagged'] == true) flagged++;
          }
          final avgRating = reviews.isNotEmpty ? totalRating / reviews.length : 0.0;

          final filtered = reviews.where((doc) {
            final d = doc.data();
            final rating = (d['rating'] as num?)?.toInt() ?? 0;
            if (_ratingFilter > 0 && rating != _ratingFilter) return false;
            if (_search.isEmpty) return true;
            final q = _search.toLowerCase();
            final reviewerName = (d['reviewerName'] as String? ?? '').toLowerCase();
            final comment = (d['comment'] as String? ?? '').toLowerCase();
            final companyId = doc.reference.parent.parent?.id ?? '';
            return reviewerName.contains(q) || comment.contains(q) || companyId.toLowerCase().contains(q);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTheme.kSpacingMedium),
                child: Row(
                  children: [
                    Expanded(
                      child: AppCard(
                        child: Column(
                          children: [
                            AnimatedCountUp(
                              endValue: reviews.length.toDouble(),
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: cs.primary),
                            ),
                            Text('Total', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppCard(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  avgRating.toStringAsFixed(1),
                                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.tertiary),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.star_rounded, color: theme.colorScheme.tertiary, size: 18),
                              ],
                            ),
                            Text('Avg Rating', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppCard(
                        child: Column(
                          children: [
                            AnimatedCountUp(
                              endValue: flagged.toDouble(),
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: cs.error),
                            ),
                            Text('Flagged', style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.kSpacingMedium),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by reviewer, comment, company...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _search = ''),
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(height: AppTheme.kSpacingSmall),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.kSpacingMedium),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('All'),
                        selected: _ratingFilter == 0,
                        onSelected: (_) => setState(() => _ratingFilter = 0),
                      ),
                    ),
                    for (int star = 5; star >= 1; star--)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$star'),
                              const SizedBox(width: 2),
                              Icon(Icons.star_rounded, color: theme.colorScheme.tertiary, size: 14),
                            ],
                          ),
                          selected: _ratingFilter == star,
                          onSelected: (_) => setState(() => _ratingFilter = _ratingFilter == star ? 0 : star),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.kSpacingSmall),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text('No reviews match your filters', style: TextStyle(color: cs.onSurfaceVariant)))
                    : ListView.separated(
                        physics: AppTheme.scrollPhysicsFor(context),
                        padding: EdgeInsets.all(AppTheme.isDesktop(context) ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final doc = filtered[i];
                          return FadeInWidget(
                            delay: Duration(milliseconds: 50 * i),
                            child: _ReviewCard(doc: doc),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _ReviewCard({required this.doc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final d = doc.data();
    final rating = (d['rating'] as num?)?.toInt() ?? 0;
    final companyId = doc.reference.parent.parent?.id ?? '';

    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(radius: 16, backgroundColor: cs.primaryContainer,
          child: Text(((d['reviewerName'] as String?) ?? '?').isNotEmpty ? (d['reviewerName'] as String? ?? '?')[0].toUpperCase() : '?',
            style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700, fontSize: 14))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d['reviewerName'] as String? ?? 'Anonymous', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          Text('Company: $companyId', style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
        ])),
        Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (j) => Icon(
          j < rating ? Icons.star_rounded : Icons.star_outline_rounded, color: cs.tertiary, size: 16))),
      ]),
      if ((d['comment'] as String? ?? '').isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(d['comment'] as String? ?? '', style: theme.textTheme.bodyMedium),
      ],
      const SizedBox(height: 8),
      Row(children: [
        Text((d['createdAt'] as Timestamp?) != null ? DateFormat.yMMMd().format((d['createdAt'] as Timestamp).toDate()) : '',
          style: theme.textTheme.labelSmall?.copyWith(color: cs.outline)),
        const Spacer(),
        if (d['flagged'] == true) Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(8)),
          child: Text('Flagged', style: theme.textTheme.labelSmall?.copyWith(color: cs.onErrorContainer, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          onSelected: (action) async {
            if (action == 'delete') {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete review?'),
                  content: const Text('This action cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !context.mounted) return;
            }
            try {
              final service = ref.read(superAdminServiceProvider);
              await service.moderateReview(companyId, doc.id, action);
              final email = FirebaseAuth.instance.currentUser?.email ?? '';
              service.logSuperAdminAction(action: 'review_$action', actorEmail: email, entityType: 'review', entityId: doc.id, details: '${action == "flag" ? "Flagged" : "Deleted"} review by ${d['reviewerName'] ?? 'unknown'} in $companyId');
              if (context.mounted) {
                context.showSuccessSnackbar(
                  action == 'flag' ? 'Review flagged' : 'Review deleted',
                );
              }
            } catch (e) {
              if (context.mounted) context.showErrorSnackbar('Failed: $e');
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'flag', child: Text('Flag')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ]),
    ]));
  }
}
