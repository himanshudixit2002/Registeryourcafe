import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/venue_review.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';
import '../landing_providers.dart';

class VenueReviewsScreen extends ConsumerStatefulWidget {
  final String companyId;
  final String venueName;
  const VenueReviewsScreen({
    super.key,
    required this.companyId,
    required this.venueName,
  });
  @override
  ConsumerState<VenueReviewsScreen> createState() =>
      _VenueReviewsScreenState();
}

class _VenueReviewsScreenState extends ConsumerState<VenueReviewsScreen> {
  String _sortBy = 'recent';
  int? _filterRating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reviewsAsync = ref.watch(venueReviewsFamily(widget.companyId));

    return Scaffold(
      appBar: AppBar(title: Text('Reviews for ${widget.venueName}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showWriteReview(context),
        icon: const Icon(Icons.rate_review),
        label: const Text('Write review'),
      ),
      body: reviewsAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (reviews) {
          var filtered = reviews.toList();
          if (_filterRating != null) {
            filtered =
                filtered.where((r) => r.rating == _filterRating).toList();
          }
          switch (_sortBy) {
            case 'highest':
              filtered.sort((a, b) => b.rating.compareTo(a.rating));
            case 'lowest':
              filtered.sort((a, b) => a.rating.compareTo(b.rating));
            case 'helpful':
              filtered
                  .sort((a, b) => b.helpfulCount.compareTo(a.helpfulCount));
            default:
              filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }

          final avg = reviews.isEmpty
              ? 0.0
              : reviews.fold(0, (s, r) => s + r.rating) / reviews.length;

          return ListView(
            physics: AppTheme.scrollPhysicsFor(context),
            padding: EdgeInsets.all(
              AppTheme.isDesktop(context)
                  ? AppTheme.kSpacingXLarge
                  : AppTheme.kSpacingMedium,
            ),
            children: [
              _SummaryCard(avg: avg, count: reviews.length),
              const SizedBox(height: 12),
              _FilterBar(
                sortBy: _sortBy,
                filterRating: _filterRating,
                onSortChanged: (v) => setState(() => _sortBy = v),
                onFilterChanged: (v) => setState(
                    () => _filterRating = _filterRating == v ? null : v),
              ),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('No reviews match your filter',
                        style: theme.textTheme.bodyMedium),
                  ),
                )
              else
                for (int idx = 0; idx < filtered.length; idx++) ...[
                  FadeInWidget(
                    delay: Duration(milliseconds: 60 * idx),
                    child: _ReviewCard(review: filtered[idx], companyId: widget.companyId),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showWriteReview(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      context.showErrorSnackbar('Please sign in to write a review');
      return;
    }

    int rating = 0;
    int? food, ambiance, service, value;
    final commentController = TextEditingController();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Rate your experience',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => GestureDetector(
                    onTap: () => setSheetState(() => rating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i < rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: Theme.of(ctx).colorScheme.tertiary,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MiniRating('Food', food,
                      (v) => setSheetState(() => food = v)),
                  _MiniRating('Ambiance', ambiance,
                      (v) => setSheetState(() => ambiance = v)),
                  _MiniRating('Service', service,
                      (v) => setSheetState(() => service = v)),
                  _MiniRating('Value', value,
                      (v) => setSheetState(() => value = v)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  hintText: 'Share your experience...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                minLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      rating > 0 ? () => Navigator.pop(ctx, true) : null,
                  child: const Text('Submit review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (submitted == true && mounted) {
      final review = VenueReview(
        id: '',
        companyId: widget.companyId,
        reviewerUid: user.uid,
        reviewerName: user.displayName ?? user.email ?? 'Guest',
        rating: rating,
        foodRating: food,
        ambianceRating: ambiance,
        serviceRating: service,
        valueRating: value,
        comment: commentController.text.trim(),
        createdAt: DateTime.now(),
      );
      await ref.read(reviewServiceProvider).submitReview(review);
      if (mounted) context.showSuccessSnackbar('Review submitted!');
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final double avg;
  final int count;
  const _SummaryCard({required this.avg, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
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
                    color: theme.colorScheme.tertiary,
                    size: 20,
                  ),
                ),
              ),
              Text(
                '$count reviews',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String sortBy;
  final int? filterRating;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<int> onFilterChanged;

  const _FilterBar({
    required this.sortBy,
    required this.filterRating,
    required this.onSortChanged,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          PopupMenuButton<String>(
            initialValue: sortBy,
            onSelected: onSortChanged,
            child:
                Chip(avatar: const Icon(Icons.sort, size: 16), label: const Text('Sort')),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'recent', child: Text('Most recent')),
              PopupMenuItem(value: 'highest', child: Text('Highest rated')),
              PopupMenuItem(value: 'lowest', child: Text('Lowest rated')),
              PopupMenuItem(value: 'helpful', child: Text('Most helpful')),
            ],
          ),
          const SizedBox(width: 8),
          for (final r in [5, 4, 3, 2, 1]) ...[
            GestureDetector(
              onTap: () => onFilterChanged(r),
              child: Chip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$r'),
                    const SizedBox(width: 2),
                    Icon(Icons.star,
                        size: 14,
                        color: filterRating == r
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.tertiary),
                  ],
                ),
                backgroundColor:
                    filterRating == r ? theme.colorScheme.primary : null,
                labelStyle: filterRating == r
                    ? TextStyle(color: theme.colorScheme.onPrimary)
                    : null,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _MiniRating extends StatelessWidget {
  final String label;
  final int? value;
  final ValueChanged<int> onChanged;
  const _MiniRating(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label, style: theme.textTheme.labelSmall),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (i) => GestureDetector(
              onTap: () => onChanged(i + 1),
              child: Icon(
                i < (value ?? 0)
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: theme.colorScheme.tertiary,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  final VenueReview review;
  final String companyId;
  const _ReviewCard({required this.review, required this.companyId});

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
                radius: 18,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  review.reviewerName.isNotEmpty
                      ? review.reviewerName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(review.reviewerName,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        if (review.isVerified) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.verified,
                              size: 14, color: theme.colorScheme.primary),
                        ],
                      ],
                    ),
                    Text(
                      '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: theme.colorScheme.tertiary,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(review.comment,
                style:
                    theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
          ],
          if (review.ownerResponse != null) ...[
            const SizedBox(height: 10),
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
                  Text('Owner response',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(review.ownerResponse!,
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () async {
                  await ref
                      .read(reviewServiceProvider)
                      .markHelpful(companyId, review.id);
                  if (context.mounted) {
                    context.showSuccessSnackbar('Marked helpful');
                  }
                },
                icon: const Icon(Icons.thumb_up_outlined, size: 16),
                label: Text('Helpful (${review.helpfulCount})'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
