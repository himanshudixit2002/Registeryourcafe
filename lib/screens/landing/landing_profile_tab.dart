import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../help/help_center_screen.dart';
import 'loyalty/guest_loyalty_screen.dart';
import 'wallet/guest_wallet_screen.dart';

class LandingProfileTab extends ConsumerWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback? onGoogleSignIn;
  final VoidCallback? onGoToBookings;
  final VoidCallback? onGoToOrders;
  final VoidCallback? onGoToSearch;

  const LandingProfileTab({
    super.key,
    required this.onLogin,
    required this.onRegister,
    this.onGoogleSignIn,
    this.onGoToBookings,
    this.onGoToOrders,
    this.onGoToSearch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < AppTheme.kMobileBreakpoint;
    final fbUser = FirebaseAuth.instance.currentUser;

    if (fbUser == null || fbUser.isAnonymous) {
      return _buildSignInPrompt(context, theme, isMobile);
    }

    return _buildSignedInProfile(context, ref, theme, isMobile, fbUser);
  }

  Widget _buildSignInPrompt(BuildContext context, ThemeData theme, bool isMobile) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.person_rounded, size: 48, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 20),
            Text('Your Profile', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Sign in to access your profile, loyalty points, wallet balance, and favourite venues.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.45),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(onPressed: onLogin, icon: const Icon(Icons.login_rounded, size: 18), label: const Text('Sign in')),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: onGoogleSignIn, icon: const Icon(Icons.g_mobiledata_rounded, size: 20), label: const Text('Sign in with Google')),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRegister,
              child: Text('Register your venue', style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignedInProfile(BuildContext context, WidgetRef ref, ThemeData theme, bool isMobile, User user) {
    final pad = isMobile ? AppTheme.kSpacingMedium : AppTheme.kSpacingXLarge;

    return SingleChildScrollView(
      physics: AppTheme.scrollPhysicsFor(context),
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                child: user.photoURL == null
                    ? Icon(Icons.person, size: 40, color: theme.colorScheme.onPrimaryContainer)
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                user.displayName ?? user.email ?? 'Customer',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (user.email != null) ...[
                const SizedBox(height: 4),
                Text(user.email!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          _sectionLabel(theme, 'My activity'),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _tile(theme, Icons.event_seat_outlined, 'My bookings', 'Table reservations across all venue types', onTap: onGoToBookings),
              _tile(theme, Icons.receipt_long_outlined, 'My orders', 'Orders from gaming cafes, dining, and restaurants', onTap: onGoToOrders),
              _tile(theme, Icons.sports_esports_outlined, 'Gaming sessions', 'Track active and past gaming sessions', onTap: onGoToBookings),
              _tile(theme, Icons.favorite_outline, 'Saved venues', 'Your favourite cafes and restaurants', onTap: onGoToSearch),
            ]),
          ),
          const SizedBox(height: 16),
          _sectionLabel(theme, 'Rewards'),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _tile(theme, Icons.workspace_premium, 'Loyalty points', 'Earn and redeem points across venues',
                onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const GuestLoyaltyScreen()))),
              _tile(theme, Icons.account_balance_wallet_outlined, 'Wallet', 'Top up and pay with your balance',
                onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const GuestWalletScreen()))),
              _tile(theme, Icons.card_giftcard, 'Gift cards', 'Buy and redeem gift cards',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')))),
              _tile(theme, Icons.share, 'Refer a friend', 'Earn points for every referral',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')))),
            ]),
          ),
          const SizedBox(height: 16),
          _sectionLabel(theme, 'Settings'),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _tile(theme, Icons.restaurant_menu, 'Dietary preferences', 'Vegetarian, vegan, allergies',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')))),
              _tile(theme, Icons.notifications_outlined, 'Notifications', 'Push, email, and SMS preferences',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')))),
              _tile(theme, Icons.help_outline, 'Help centre', 'FAQs and support',
                onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const HelpCenterScreen()))),
            ]),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onRegister,
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Register your venue'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(ThemeData theme, String text) {
    return Text(text, style: theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant, letterSpacing: 0.4));
  }

  Widget _tile(ThemeData theme, IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary, size: 22),
      title: Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant, size: 20),
      dense: true,
      onTap: onTap ?? () {},
    );
  }
}
