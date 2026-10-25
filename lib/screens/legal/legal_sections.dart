import '../../branding/legal_config.dart';

/// One titled block for [LegalDocumentScreen].
class LegalSection {
  final String title;
  final String body;

  const LegalSection(this.title, this.body);
}

enum LegalDocumentKind { privacy, terms, dataHandling }

abstract final class LegalSections {
  static String titleFor(LegalDocumentKind kind) {
    return switch (kind) {
      LegalDocumentKind.privacy => 'Privacy policy',
      LegalDocumentKind.terms => 'Terms of service',
      LegalDocumentKind.dataHandling => 'Data & permissions',
    };
  }

  static String? hostedUrlFor(LegalDocumentKind kind) {
    return switch (kind) {
      LegalDocumentKind.privacy => LegalConfig.hostedPrivacyPolicyUrl,
      LegalDocumentKind.terms => LegalConfig.hostedTermsOfServiceUrl,
      LegalDocumentKind.dataHandling => null,
    };
  }

  static List<LegalSection> sectionsFor(LegalDocumentKind kind) {
    return switch (kind) {
      LegalDocumentKind.privacy => privacy,
      LegalDocumentKind.terms => terms,
      LegalDocumentKind.dataHandling => dataHandling,
    };
  }

  /// Template — replace company details and practices with your final legal review.
  static final List<LegalSection> privacy = [
    LegalSection(
      'Introduction',
      'This privacy policy describes how ${LegalConfig.appDisplayName} ("we", "us") '
          'handles information when you use our mobile and web applications (the "Services"). '
          'Last updated: ${LegalConfig.lastUpdatedLabel}. '
          'By using the Services you agree to this policy alongside our terms of service.',
    ),
    LegalSection(
      'Information we collect',
      '• Account information: email address and credentials you provide when you sign in.\n'
          '• Operational data: tournament registrations, session and usage data needed to run the product.\n'
          '• Device and technical data: basic diagnostics may be collected by our hosting and analytics providers as configured in your deployment.',
    ),
    LegalSection(
      'How we use information',
      'We use the information above to authenticate users, operate tournaments and cafe features, '
          'provide support, secure the Services, and comply with law. We do not sell your personal information.',
    ),
    LegalSection(
      'Third-party services',
      'The Services rely on Google Firebase (authentication, database, and related cloud features) '
          'and other providers you enable in your project. Those services process data under their own terms '
          'and privacy policies. Review your Firebase and Google Cloud configuration for full detail.',
    ),
    LegalSection(
      'Retention and security',
      'We retain information as long as needed to provide the Services and meet legal obligations. '
          'We use industry-standard safeguards appropriate to the nature of the data; no method of transmission '
          'over the Internet is 100% secure.',
    ),
    LegalSection(
      'Your choices',
      'You may request access, correction, or deletion of certain account information where applicable law requires. '
          'Contact us using the address below. You can stop using the Services at any time.',
    ),
    LegalSection(
      'Children',
      'The Services are not directed at children under 13 (or the minimum age in your jurisdiction). '
          'We do not knowingly collect personal information from children.',
    ),
    LegalSection(
      'Changes',
      'We may update this policy from time to time. We will post the updated version in the app and, '
          'where appropriate, on our website.',
    ),
    LegalSection(
      'Contact',
      'Questions about this policy: ${LegalConfig.supportEmail}',
    ),
  ];

  static final List<LegalSection> terms = [
    LegalSection(
      'Agreement',
      'These terms of service ("Terms") govern your use of ${LegalConfig.appDisplayName}. '
          'Last updated: ${LegalConfig.lastUpdatedLabel}. '
          'If you do not agree, do not use the Services.',
    ),
    LegalSection(
      'The Services',
      '${LegalConfig.appDisplayName} provides software for managing cafe and tournament-related workflows. '
          'Features may change; we aim to keep the Services reasonably available but do not guarantee uninterrupted access.',
    ),
    LegalSection(
      'Accounts',
      'You are responsible for maintaining the confidentiality of your account credentials and for activity under your account. '
          'Notify us if you suspect unauthorized access.',
    ),
    LegalSection(
      'Acceptable use',
      'You agree not to misuse the Services, including attempting unauthorized access, interfering with other users, '
          'or using the Services in violation of applicable law.',
    ),
    LegalSection(
      'Content and data',
      'You retain rights to content you submit. You grant us the license needed to host, process, and display that content '
          'solely to operate the Services for you and your organization.',
    ),
    LegalSection(
      'Disclaimer',
      'The Services are provided "as is" to the fullest extent permitted by law. We disclaim implied warranties where allowed.',
    ),
    LegalSection(
      'Limitation of liability',
      'To the maximum extent permitted by law, we are not liable for indirect, incidental, special, consequential, or punitive damages, '
          'or loss of profits or data, arising from your use of the Services.',
    ),
    LegalSection(
      'Governing law',
      'These Terms are governed by the laws applicable to your operating entity, unless otherwise required by mandatory local law.',
    ),
    LegalSection(
      'Contact',
      'Legal or account questions: ${LegalConfig.supportEmail}',
    ),
  ];

  /// Short in-app summary to align with Google Play Data safety disclosures (not a substitute for the form in Play Console).
  static final List<LegalSection> dataHandling = [
    LegalSection(
      'Purpose',
      'This summary helps users understand what the app may access or process. '
          'You must still complete Google Play’s Data safety section accurately for your production build.',
    ),
    LegalSection(
      'Account & authentication',
      'Email address and authentication tokens via Firebase Auth (or your configured identity provider).',
    ),
    LegalSection(
      'Cloud data',
      'Tournament, session, and related operational data stored in Firebase / Firestore (or equivalent backend you configure).',
    ),
    LegalSection(
      'Optional / device',
      'If you enable features such as file pickers, printing, or notifications, the OS may expose related permissions; '
          'only request permissions your app actually uses.',
    ),
    LegalSection(
      'Sharing',
      'Data is processed by infrastructure providers (e.g. Google) as needed to run the Services. We do not sell personal data.',
    ),
    LegalSection(
      'Deletion',
      'Users can contact ${LegalConfig.supportEmail} for account-related deletion requests where your policies and law allow.',
    ),
  ];
}
