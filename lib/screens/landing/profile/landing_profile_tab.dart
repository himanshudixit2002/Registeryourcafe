import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/ui_helpers.dart';
import '../../../widgets/app_card.dart';

class LandingProfileTab extends ConsumerWidget {
  final VoidCallback? onLogin;
  final VoidCallback? onRegister;

  const LandingProfileTab({super.key, this.onLogin, this.onRegister});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDesktop = AppTheme.isDesktop(context);
    final pad =
        isDesktop ? AppTheme.kSpacingXLarge : AppTheme.kSpacingMedium;
    final user = FirebaseAuth.instance.currentUser;
    final isSignedIn = user != null && !user.isAnonymous;

    return SingleChildScrollView(
      physics: AppTheme.scrollPhysicsFor(context),
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeInWidget(
            delay: const Duration(milliseconds: 100),
            child: AppCard(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    isSignedIn ? Icons.person : Icons.person_outline,
                    size: 40,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isSignedIn
                      ? (user.displayName ?? user.email ?? 'Guest')
                      : 'Guest user',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  isSignedIn
                      ? 'Signed in'
                      : 'Sign in for full experience',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                if (!isSignedIn) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton(
                          onPressed: onLogin,
                          child: const Text('Sign in')),
                      const SizedBox(width: 12),
                      OutlinedButton(
                          onPressed: onRegister,
                          child: const Text('Create account')),
                    ],
                  ),
                ],
              ],
            ),
          ),
          ),
          const SizedBox(height: 16),
          FadeInWidget(
            delay: const Duration(milliseconds: 200),
            child: const _SectionTitle('Account'),
          ),
          const SizedBox(height: 8),
          FadeInWidget(
            delay: const Duration(milliseconds: 300),
            child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ProfileTile(
                  icon: Icons.favorite_outline,
                  title: 'Saved venues',
                  subtitle: 'Your favorite places',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.star_outline,
                  title: 'My reviews',
                  subtitle: 'Reviews you have written',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.history,
                  title: 'Recently viewed',
                  subtitle: 'Venues you browsed',
                  onTap: () {},
                ),
              ],
            ),
          ),
          ),
          const SizedBox(height: 16),
          FadeInWidget(
            delay: const Duration(milliseconds: 400),
            child: const _SectionTitle('Rewards'),
          ),
          const SizedBox(height: 8),
          FadeInWidget(
            delay: const Duration(milliseconds: 500),
            child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ProfileTile(
                  icon: Icons.workspace_premium,
                  title: 'Loyalty points',
                  subtitle: '0 points \u2022 Bronze tier',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Wallet',
                  subtitle: '\u20B90 balance',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.card_giftcard,
                  title: 'Gift cards',
                  subtitle: 'Buy and redeem gift cards',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.share,
                  title: 'Refer a friend',
                  subtitle: 'Earn points for referrals',
                  onTap: () {},
                ),
              ],
            ),
          ),
          ),
          const SizedBox(height: 16),
          FadeInWidget(
            delay: const Duration(milliseconds: 600),
            child: const _SectionTitle('Preferences'),
          ),
          const SizedBox(height: 8),
          FadeInWidget(
            delay: const Duration(milliseconds: 700),
            child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ProfileTile(
                  icon: Icons.restaurant_menu,
                  title: 'Dietary preferences',
                  subtitle: 'Veg, vegan, allergies',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Push, email, SMS settings',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.language,
                  title: 'Language',
                  subtitle: 'English',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'Appearance',
                  subtitle: 'Light / Dark / System',
                  onTap: () {},
                ),
              ],
            ),
          ),
          ),
          const SizedBox(height: 16),
          FadeInWidget(
            delay: const Duration(milliseconds: 800),
            child: const _SectionTitle('Support'),
          ),
          const SizedBox(height: 8),
          FadeInWidget(
            delay: const Duration(milliseconds: 900),
            child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ProfileTile(
                  icon: Icons.help_outline,
                  title: 'Help center',
                  subtitle: 'FAQs and guides',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy policy',
                  subtitle: 'How we handle your data',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of service',
                  subtitle: 'Usage terms',
                  onTap: () {},
                ),
              ],
            ),
          ),
          ),
          if (isSignedIn) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary, size: 22),
      title: Text(title,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant)),
      trailing: Icon(Icons.chevron_right,
          color: theme.colorScheme.onSurfaceVariant, size: 20),
      onTap: onTap,
      dense: true,
    );
  }
}
