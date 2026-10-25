import 'package:flutter/material.dart';

import '../../branding/legal_config.dart';
import '../../legal/legal_launch.dart';
import 'legal_sections.dart';

class LegalDocumentScreen extends StatelessWidget {
  final LegalDocumentKind kind;

  const LegalDocumentScreen({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = LegalSections.titleFor(kind);
    final sections = LegalSections.sectionsFor(kind);
    final hosted = LegalSections.hostedUrlFor(kind);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (hosted != null && hosted.isNotEmpty)
            IconButton(
              tooltip: 'Open in browser',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => LegalLaunch.openHostedUrl(hosted),
            ),
          IconButton(
            tooltip: 'Email support',
            icon: const Icon(Icons.email_outlined),
            onPressed: LegalLaunch.contactSupport,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (hosted == null || hosted.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Material(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'For Google Play and your website, publish this document at a public HTTPS URL '
                          'and set hostedPrivacyPolicyUrl / hostedTermsOfServiceUrl in lib/branding/legal_config.dart.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Text(
            'Last updated: ${LegalConfig.lastUpdatedLabel}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          for (final s in sections) ...[
            Text(
              s.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              s.body,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}
