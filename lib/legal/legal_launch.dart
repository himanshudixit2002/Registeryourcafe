import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:registeryourcafe/theme/app_page_transitions.dart';

import '../branding/legal_config.dart';
import '../screens/legal/legal_document_screen.dart';
import '../screens/legal/legal_sections.dart';
import '../widgets/glass_modal_bottom_sheet.dart';

/// Opens mailto, HTTPS policy URLs, and navigates to in-app legal screens.
abstract final class LegalLaunch {
  static Future<void> openEmail(String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': '${LegalConfig.appDisplayName} support'},
    );
    if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
      debugPrint('Could not launch mailto: $email');
    }
  }

  static Future<void> openHostedUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      debugPrint('Invalid legal URL: $url');
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch URL: $url');
    }
  }

  static Future<void> contactSupport() => openEmail(LegalConfig.supportEmail);

  static void pushPrivacy(BuildContext context) {
    Navigator.of(context).push<void>(
      AppMaterialPageRoute<void>(
        builder: (_) =>
            const LegalDocumentScreen(kind: LegalDocumentKind.privacy),
      ),
    );
  }

  static void pushTerms(BuildContext context) {
    Navigator.of(context).push<void>(
      AppMaterialPageRoute<void>(
        builder: (_) =>
            const LegalDocumentScreen(kind: LegalDocumentKind.terms),
      ),
    );
  }

  static void pushDataHandling(BuildContext context) {
    Navigator.of(context).push<void>(
      AppMaterialPageRoute<void>(
        builder: (_) =>
            const LegalDocumentScreen(kind: LegalDocumentKind.dataHandling),
      ),
    );
  }

  static Future<void> showLegalSupportSheet(BuildContext context) {
    final theme = Theme.of(context);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return GlassModalSheetChrome(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy policy'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  pushPrivacy(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('Terms of service'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  pushTerms(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: const Text('Data & permissions summary'),
                subtitle: Text(
                  'Overview for Play “Data safety”',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  pushDataHandling(context);
                },
              ),
              if (LegalConfig.hostedPrivacyPolicyUrl != null &&
                  LegalConfig.hostedPrivacyPolicyUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: const Text('Open privacy policy in browser'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    openHostedUrl(LegalConfig.hostedPrivacyPolicyUrl);
                  },
                ),
              if (LegalConfig.hostedTermsOfServiceUrl != null &&
                  LegalConfig.hostedTermsOfServiceUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: const Text('Open terms in browser'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    openHostedUrl(LegalConfig.hostedTermsOfServiceUrl);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Contact support'),
                subtitle: Text(LegalConfig.supportEmail),
                onTap: () {
                  Navigator.pop(sheetContext);
                  contactSupport();
                },
              ),
              ListTile(
                leading: const Icon(Icons.library_books_outlined),
                title: const Text('Open-source licenses'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showLicensePage(
                    context: context,
                    applicationName: LegalConfig.appDisplayName,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
