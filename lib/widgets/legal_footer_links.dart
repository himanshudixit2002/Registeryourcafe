import 'package:flutter/material.dart';

import '../legal/legal_launch.dart';

/// Footer row for landing, login, etc. (Play-friendly disclosure entry points).
class LegalFooterLinks extends StatelessWidget {
  final bool compact;

  const LegalFooterLinks({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    final sepStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
    );

    Widget link(String label, VoidCallback onTap) {
      return TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 10,
            vertical: compact ? 2 : 6,
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onTap,
        child: Text(label, style: style),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          link('Privacy', () => LegalLaunch.pushPrivacy(context)),
          Text(' · ', style: sepStyle),
          link('Terms', () => LegalLaunch.pushTerms(context)),
          Text(' · ', style: sepStyle),
          link('Data', () => LegalLaunch.pushDataHandling(context)),
          Text(' · ', style: sepStyle),
          link('Support', LegalLaunch.contactSupport),
          Text(' · ', style: sepStyle),
          link('More', () => LegalLaunch.showLegalSupportSheet(context)),
        ],
      ),
    );
  }
}
