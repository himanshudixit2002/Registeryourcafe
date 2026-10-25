/// URLs and contact details for store listings (Play Console, App Store) and the website.
///
/// Replace [supportEmail] and optionally set [hostedPrivacyPolicyUrl] /
/// [hostedTermsOfServiceUrl] to your **public** HTTPS pages. Google Play
/// requires a privacy policy URL in the listing; hosting the same policy on
/// your site and linking it here satisfies that while the in-app screens
/// provide disclosure inside the product.
abstract final class LegalConfig {
  static const String appDisplayName = 'Registeryourcafe';

  /// Used in policy text and mailto links — set to your real support inbox.
  static const String supportEmail = 'support@registeryourcafe.com';

  /// Example: `https://registeryourcafe.com/privacy` — `null` until you deploy.
  static const String? hostedPrivacyPolicyUrl = null;

  /// Example: `https://registeryourcafe.com/terms`
  static const String? hostedTermsOfServiceUrl = null;

  static const String lastUpdatedLabel = 'April 2026';
}
