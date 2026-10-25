/// Stored in SharedPreferences; mapped to [ThemeMode] in the UI layer.
enum UiThemePreference { system, light, dark }

class UserUiPrefs {
  const UserUiPrefs({
    required this.showBottomNavLabels,
    required this.compactListDensity,
    required this.themePreference,
  });

  final bool showBottomNavLabels;
  final bool compactListDensity;
  final UiThemePreference themePreference;

  static const UserUiPrefs defaults = UserUiPrefs(
    showBottomNavLabels: true,
    compactListDensity: false,
    themePreference: UiThemePreference.system,
  );

  static UiThemePreference themePreferenceFromStorage(String? raw) {
    switch (raw) {
      case 'light':
        return UiThemePreference.light;
      case 'dark':
        return UiThemePreference.dark;
      default:
        return UiThemePreference.system;
    }
  }

  UserUiPrefs copyWith({
    bool? showBottomNavLabels,
    bool? compactListDensity,
    UiThemePreference? themePreference,
  }) {
    return UserUiPrefs(
      showBottomNavLabels: showBottomNavLabels ?? this.showBottomNavLabels,
      compactListDensity: compactListDensity ?? this.compactListDensity,
      themePreference: themePreference ?? this.themePreference,
    );
  }
}
