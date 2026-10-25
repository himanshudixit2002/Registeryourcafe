import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/public_venue_listing.dart';
import '../../../utils/ui_helpers.dart';
import '../landing_providers.dart';

class VenueGalleryScreen extends ConsumerWidget {
  final PublicVenueListing listing;
  const VenueGalleryScreen({super.key, required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reviewsAsync = ref.watch(venueReviewsFamily(listing.companyId));
    final allPhotos = <String>[];
    if (listing.coverImageUrl != null) allPhotos.add(listing.coverImageUrl!);
    reviewsAsync.whenData((reviews) {
      for (final r in reviews) {
        allPhotos.addAll(r.photoUrls);
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text('${listing.displayName} photos')),
      body: allPhotos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No photos yet', style: theme.textTheme.titleMedium),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: allPhotos.length,
              itemBuilder: (context, i) => FadeInWidget(
                delay: Duration(milliseconds: 50 * i),
                child: GestureDetector(
                onTap: () => _showFullScreen(context, allPhotos, i),
                child: Hero(
                  tag: 'gallery-photo-$i',
                  child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    allPhotos[i],
                    cacheWidth: 300,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
                ),
              ),
              ),
            ),
    );
  }

  void _showFullScreen(
      BuildContext context, List<String> photos, int initial) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            _FullScreenGallery(photos: photos, initial: initial),
      ),
    );
  }
}

class _FullScreenGallery extends StatelessWidget {
  final List<String> photos;
  final int initial;
  const _FullScreenGallery({required this.photos, required this.initial});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.scrim,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.scrim,
        foregroundColor: theme.colorScheme.onSurface,
        title: Text('${initial + 1} / ${photos.length}'),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initial),
        itemCount: photos.length,
        itemBuilder: (context, i) => InteractiveViewer(
          child: Center(
            child: Image.network(
              photos[i],
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.broken_image,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.54),
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
