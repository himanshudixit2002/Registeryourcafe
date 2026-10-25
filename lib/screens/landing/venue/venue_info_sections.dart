import 'package:flutter/material.dart';

import '../../../models/public_venue_listing.dart';
import '../../../theme/app_theme.dart';

class VenueFAQSection extends StatelessWidget {
  const VenueFAQSection({super.key});

  static const _faqs = [
    (
      'What are the operating hours?',
      'Check the About tab for detailed hours.',
    ),
    (
      'Is parking available?',
      'Check with the venue directly for parking information.',
    ),
    (
      'Can I make a reservation?',
      'Yes! Use the Book tab to make a reservation.',
    ),
    (
      'Do they have WiFi?',
      'Most venues offer free WiFi. Check the amenities section.',
    ),
    (
      'What payment methods are accepted?',
      'Cash, UPI, and card payments are typically accepted.',
    ),
    (
      'Is there a dress code?',
      'Most venues are casual. Check with the venue for special events.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Frequently asked questions',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        for (final (q, a) in _faqs)
          ExpansionTile(
            title: Text(
              q,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  a,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class VenuePopularTimesSection extends StatelessWidget {
  const VenuePopularTimesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hours = List.generate(14, (i) => i + 8);
    const values = [
      0.1, 0.15, 0.3, 0.5, 0.7, 0.9, 1.0, 0.95, 0.85, 0.7, 0.5, 0.3, 0.15,
      0.1,
    ];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Popular times',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Based on typical visit patterns',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < hours.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Tooltip(
                        message: '${hours[i]}:00',
                        child: Container(
                          height: 100 * values[i],
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: values[i] > 0.7 ? 0.9 : 0.5,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '8am',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              Text(
                '2pm',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              Text(
                '9pm',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class VenueBadgesSection extends StatelessWidget {
  final PublicVenueListing listing;
  const VenueBadgesSection({super.key, required this.listing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _badge(theme, Icons.verified, 'Verified', theme.colorScheme.primary),
          if (listing.coverImageUrl != null)
            _badge(theme, Icons.photo, 'Photos', theme.colorScheme.tertiary),
          if (listing.phone != null)
            _badge(theme, Icons.phone, 'Direct call', AppTheme.successColor),
          if (listing.address != null)
            _badge(theme, Icons.location_on, 'Listed address', AppTheme.warningColor),
          _badge(
            theme,
            Icons.star,
            listing.venueKind.label,
            theme.colorScheme.tertiary,
          ),
        ],
      ),
    );
  }

  Widget _badge(ThemeData theme, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class VenueAmenitiesSection extends StatelessWidget {
  const VenueAmenitiesSection({super.key});

  static const _amenities = [
    (Icons.wifi, 'Free WiFi'),
    (Icons.local_parking, 'Parking'),
    (Icons.ac_unit, 'Air conditioned'),
    (Icons.accessible, 'Wheelchair access'),
    (Icons.deck, 'Outdoor seating'),
    (Icons.power, 'Power outlets'),
    (Icons.pets, 'Pet friendly'),
    (Icons.child_care, 'Kid friendly'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amenities',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (icon, label) in _amenities)
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
