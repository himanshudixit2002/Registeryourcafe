/// Single-language UI copy. Use these instead of scattering duplicate literals.
abstract final class AppStrings {
  // --- Common actions ---
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String close = 'Close';
  static const String ok = 'OK';
  static const String retry = 'Retry';
  static const String done = 'Done';
  static const String next = 'Next';
  static const String back = 'Back';
  static const String submit = 'Submit';

  // --- Status / feedback ---
  static const String loading = 'Loading...';
  static const String somethingWentWrong = 'Something went wrong';

  // --- Auth (shared) ---
  static const String signIn = 'Sign in';
  static const String signOut = 'Sign out';

  /// After Firebase sends a verification or reset message (delivery is async).
  static const String authEmailSentHints =
      'If nothing arrives within a few minutes, check Spam and the Gmail '
      'Promotions tab. Messages come from Firebase (noreply).';

  // --- Empty / errors (reusable) ---
  static const String noData = 'No data';
  static const String tryAgain = 'Try again';
}
