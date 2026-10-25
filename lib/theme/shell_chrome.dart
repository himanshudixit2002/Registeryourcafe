/// Layout and decoration tokens for the signed-in workspace shell (nav pill,
/// app bar, hub). Centralizes shell “chrome” without scattering magic numbers.
abstract final class ShellChrome {
  static const double appBarBottomCornerRadius = 20;

  /// Outline strength for the floating mobile nav capsule (0–1 alpha scale).
  static const double mobileNavBorderOpacity = 0.28;
}
