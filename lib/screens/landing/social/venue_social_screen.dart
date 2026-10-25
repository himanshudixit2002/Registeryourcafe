import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/public_venue_listing.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/snackbar_helper.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';

class VenueSocialScreen extends ConsumerWidget {
  final PublicVenueListing listing;
  const VenueSocialScreen({super.key, required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pad = AppTheme.isDesktop(context)
        ? AppTheme.kSpacingXLarge
        : AppTheme.kSpacingMedium;

    return Scaffold(
      appBar: AppBar(title: Text('${listing.displayName} community')),
      body: SingleChildScrollView(
        physics: AppTheme.scrollPhysicsFor(context),
        padding: EdgeInsets.fromLTRB(pad, 16, pad, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                children: [
                  Icon(Icons.share,
                      color: theme.colorScheme.primary, size: 32),
                  const SizedBox(height: 8),
                  Text('Share this venue',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      BounceTap(
                        onTap: () {
                          Clipboard.setData(ClipboardData(
                              text:
                                  'https://registeryourcafe.com/venue/${listing.companyId}'));
                          context.showSuccessSnackbar('Link copied!');
                        },
                        child: _ShareButton(
                          icon: Icons.copy,
                          label: 'Copy link',
                          onTap: () {
                            Clipboard.setData(ClipboardData(
                                text:
                                    'https://registeryourcafe.com/venue/${listing.companyId}'));
                            context.showSuccessSnackbar('Link copied!');
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      BounceTap(
                        child: _ShareButton(
                            icon: Icons.message,
                            label: 'WhatsApp',
                            onTap: () {}),
                      ),
                      const SizedBox(width: 16),
                      BounceTap(
                        child: _ShareButton(
                            icon: Icons.email,
                            label: 'Email',
                            onTap: () {}),
                      ),
                      const SizedBox(width: 16),
                      BounceTap(
                        child: _ShareButton(
                            icon: Icons.camera_alt,
                            label: 'Instagram',
                            onTap: () {}),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FadeInWidget(
              delay: const Duration(milliseconds: 100),
              child: _SocialAction(
              icon: Icons.location_on,
              title: 'Check in',
              subtitle: 'Let friends know you are here',
              color: theme.colorScheme.primary,
              onTap: () => context.showSuccessSnackbar('Checked in!'),
            ),
            ),
            const SizedBox(height: 10),
            FadeInWidget(
              delay: const Duration(milliseconds: 200),
              child: _SocialAction(
              icon: Icons.group_add,
              title: 'Invite friends',
              subtitle: 'Share this venue with your group',
              color: theme.colorScheme.tertiary,
              onTap: () {},
            ),
            ),
            const SizedBox(height: 10),
            FadeInWidget(
              delay: const Duration(milliseconds: 300),
              child: _SocialAction(
              icon: Icons.forum,
              title: 'Community tips',
              subtitle: 'See what others recommend here',
              color: theme.colorScheme.secondary,
              onTap: () {},
            ),
            ),
            const SizedBox(height: 10),
            FadeInWidget(
              delay: const Duration(milliseconds: 400),
              child: _SocialAction(
              icon: Icons.photo_camera,
              title: 'Photo contest',
              subtitle: 'Share your best photos and win',
              color: AppTheme.warningColor,
              onTap: () {},
            ),
            ),
            const SizedBox(height: 10),
            FadeInWidget(
              delay: const Duration(milliseconds: 500),
              child: _SocialAction(
              icon: Icons.trending_up,
              title: 'Trending now',
              subtitle: "See what's popular at this venue",
              color: theme.colorScheme.tertiary,
              onTap: () {},
            ),
            ),
            const SizedBox(height: 24),
            Text('Activity',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            AppCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.people_outline,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text('No community activity yet',
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        'Be the first to check in or leave a tip!',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ShareButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: theme.colorScheme.onPrimaryContainer, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _SocialAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SocialAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
