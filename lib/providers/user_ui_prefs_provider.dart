import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_ui_prefs.dart';

ThemeMode themeModeFromPreference(UiThemePreference p) {
  return switch (p) {
    UiThemePreference.system => ThemeMode.system,
    UiThemePreference.light => ThemeMode.light,
    UiThemePreference.dark => ThemeMode.dark,
  };
}

class UserUiPrefsNotifier extends StateNotifier<UserUiPrefs> {
  UserUiPrefsNotifier() : super(UserUiPrefs.defaults) {
    _restore();
  }

  static const _kNavLabels = 'user_ui_prefs_show_bottom_nav_labels';
  static const _kCompact = 'user_ui_prefs_compact_list_density';
  static const _kTheme = 'user_ui_prefs_theme';

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    state = UserUiPrefs(
      showBottomNavLabels: p.getBool(_kNavLabels) ?? true,
      compactListDensity: p.getBool(_kCompact) ?? false,
      themePreference: UserUiPrefs.themePreferenceFromStorage(
        p.getString(_kTheme),
      ),
    );
  }

  Future<void> setShowBottomNavLabels(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kNavLabels, value);
    state = state.copyWith(showBottomNavLabels: value);
  }

  Future<void> setCompactListDensity(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kCompact, value);
    state = state.copyWith(compactListDensity: value);
  }

  Future<void> setThemePreference(UiThemePreference value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTheme, switch (value) {
      UiThemePreference.light => 'light',
      UiThemePreference.dark => 'dark',
      UiThemePreference.system => 'system',
    });
    state = state.copyWith(themePreference: value);
  }
}

final userUiPrefsProvider =
    StateNotifierProvider<UserUiPrefsNotifier, UserUiPrefs>((ref) {
      return UserUiPrefsNotifier();
    });

final themeModeProvider = Provider<ThemeMode>((ref) {
  return themeModeFromPreference(
    ref.watch(userUiPrefsProvider).themePreference,
  );
});
