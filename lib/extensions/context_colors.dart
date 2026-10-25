import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shorthand for semantic colors registered on [ThemeData].
extension AppThemeContextColors on BuildContext {
  AppSemanticColors get semanticColors => AppSemanticColors.of(this);
}
