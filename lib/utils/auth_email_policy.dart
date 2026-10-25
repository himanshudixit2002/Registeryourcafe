/// Workspace auth: product policy requires Gmail addresses only.
abstract final class AuthEmailPolicy {
  static const String gmailOnlyHint = 'you@gmail.com';

  static const String gmailOnlyRequirementMessage =
      'Use a Gmail address ending in @gmail.com';

  /// Trimmed, lowercased for comparisons. Does not validate Gmail-only.
  static String normalizeEmail(String raw) => raw.trim().toLowerCase();

  /// True if [raw] is non-empty after trim, has exactly one `@`, a non-empty
  /// local part, and the domain is exactly `gmail.com` (case-insensitive via
  /// [normalizeEmail]). Does not allow `googlemail.com` or other domains.
  static bool isWorkspaceGmailEmail(String raw) {
    final t = normalizeEmail(raw);
    if (t.isEmpty) return false;
    final parts = t.split('@');
    if (parts.length != 2) return false;
    return parts[0].isNotEmpty && parts[1] == 'gmail.com';
  }

  /// `null` if valid; otherwise a short form error string.
  static String? workspaceGmailFieldError(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Please enter your email';
    }
    if (!isWorkspaceGmailEmail(raw)) {
      return gmailOnlyRequirementMessage;
    }
    return null;
  }
}
