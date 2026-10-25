/// Sync with [pubspec.yaml] `version:` when releasing.
abstract final class AppBuildInfo {
  static const String version = '1.0.0';
  static const int buildNumber = 1;

  static String get label => '$version+$buildNumber';
}
