import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_page_transitions.dart';
import 'app_scroll_behavior.dart';

/// Registeryourcafe — mint accent; supports light and dark [ColorScheme]s.
class AppTheme {
  static const double kMobileBreakpoint = 600;
  static const double kTabletBreakpoint = 900;
  static const double kDesktopBreakpoint = 1200;

  /// Mint accent.
  static const Color brandAccent = Color(0xFF2EE6A8);
  static const Color shellDeep = Color(0xFF07090D);

  static const Color errorColor = Color(0xFFFF6B6B);
  static const Color successColor = Color(0xFF4ADE80);
  static const Color warningColor = Color(0xFFFBBF24);
  static const Color infoColor = Color(0xFF38BDF8);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0D1118), Color(0xFF141C2A), Color(0xFF0F1724)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Lighter gradient for light-mode headers (still on-brand).
  static const LinearGradient primaryGradientLight = LinearGradient(
    colors: [Color(0xFFE8FDF6), Color(0xFFD5F5EB), Color(0xFFC8F0E4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Mesh-style backdrop behind glass panels (transparent scaffolds show this).
  static LinearGradient shellBackdropGradient(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF06080D),
          Color(0xFF0C1219),
          Color(0xFF0E1620),
          Color(0xFF080C12),
        ],
        stops: [0.0, 0.32, 0.68, 1.0],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFE3F4FC),
        Color(0xFFF2F9FD),
        Color(0xFFE8F9F3),
        Color(0xFFF7FBFE),
      ],
      stops: [0.0, 0.35, 0.65, 1.0],
    );
  }

  static List<BoxShadow> cardShadowFor(Brightness brightness) {
    return [
      BoxShadow(
        color: brightness == Brightness.dark
            ? Colors.black.withValues(alpha: 0.35)
            : Colors.black.withValues(alpha: 0.08),
        blurRadius: brightness == Brightness.dark ? 16 : 12,
        offset: Offset(0, brightness == Brightness.dark ? 6 : 4),
      ),
    ];
  }

  static final List<BoxShadow> cardShadow = cardShadowFor(Brightness.dark);

  static const double kBorderRadiusSmall = 8.0;
  static const double kBorderRadiusMedium = 12.0;
  static const double kBorderRadiusLarge = 16.0;

  static const double kSpacingXSmall = 4.0;
  static const double kSpacingSmall = 8.0;
  static const double kSpacingMedium = 16.0;
  static const double kSpacingLarge = 24.0;
  static const double kSpacingXLarge = 32.0;

  static const Duration kAnimationDurationShort = Duration(milliseconds: 200);
  static const Duration kAnimationDurationMedium = Duration(milliseconds: 300);
  static const Duration kAnimationDurationLong = Duration(milliseconds: 400);

  static ColorScheme _darkColorScheme() {
    return ColorScheme.fromSeed(
      seedColor: brandAccent,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF10141C),
      surfaceDim: const Color(0xFF0B0E13),
      surfaceBright: const Color(0xFF1A2030),
      surfaceContainerLowest: shellDeep,
      surfaceContainerLow: const Color(0xFF121722),
      surfaceContainer: const Color(0xFF161C27),
      surfaceContainerHigh: const Color(0xFF1C2330),
      surfaceContainerHighest: const Color(0xFF252D3D),
      outline: const Color(0xFF4A5568),
      outlineVariant: const Color(0xFF343E4F),
      onSurface: const Color(0xFFEEF3F8),
      onSurfaceVariant: const Color(0xFFB8C5D6),
    );
  }

  static ColorScheme _lightColorScheme() {
    return ColorScheme.fromSeed(
      seedColor: brandAccent,
      brightness: Brightness.light,
    ).copyWith(
      surface: const Color(0xFFF4F7F9),
      surfaceDim: const Color(0xFFE8EEF2),
      surfaceBright: const Color(0xFFFCFDFD),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF0F4F7),
      surfaceContainer: const Color(0xFFE6ECF0),
      surfaceContainerHigh: const Color(0xFFD9E2E8),
      surfaceContainerHighest: const Color(0xFFC9D4DC),
      outline: const Color(0xFF8A9BA8),
      outlineVariant: const Color(0xFFC5D0D8),
    );
  }

  /// Dark product shell (mint on near-black).
  static ThemeData darkTheme() {
    final colorScheme = _darkColorScheme();
    return _buildAppTheme(
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldColor: Colors.transparent,
      // Opaque: [DropdownButton] menus paint with [ThemeData.canvasColor]; a
      // transparent value made lists unreadable on glass dialogs.
      canvasColor: colorScheme.surfaceContainerHighest,
    );
  }

  /// Light mode with the same typography and component structure.
  static ThemeData lightTheme() {
    final colorScheme = _lightColorScheme();
    return _buildAppTheme(
      colorScheme: colorScheme,
      brightness: Brightness.light,
      scaffoldColor: Colors.transparent,
      canvasColor: colorScheme.surfaceContainerHighest,
    );
  }

  static ThemeData _buildAppTheme({
    required ColorScheme colorScheme,
    required Brightness brightness,
    required Color scaffoldColor,
    required Color canvasColor,
  }) {
    final baseText = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );

    final textTheme = baseText.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    final cardBorderAlpha = brightness == Brightness.dark ? 0.25 : 0.22;
    // Solid surfaces for menus and dialogs so lists don’t “ghost” over glass
    // (semi-transparent dialog + default M3 menu tint stacks into unreadable text).
    final Color opaqueMenuSurface = colorScheme.surfaceContainerHighest;
    final MenuStyle opaqueMenuStyle = MenuStyle(
      backgroundColor: WidgetStatePropertyAll<Color>(opaqueMenuSurface),
      surfaceTintColor: WidgetStatePropertyAll<Color>(Colors.transparent),
      shadowColor: WidgetStatePropertyAll<Color>(
        Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.45 : 0.14),
      ),
      elevation: WidgetStatePropertyAll<double>(3),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkRipple.splashFactory,
      splashColor: colorScheme.primary.withValues(alpha: 0.12),
      highlightColor: colorScheme.primary.withValues(alpha: 0.06),
      extensions: <ThemeExtension<dynamic>>[
        ChartTheme(
          gridColor: colorScheme.outline.withValues(alpha: 0.35),
          axisLabelColor: colorScheme.onSurfaceVariant,
          linePrimary: colorScheme.primary,
          lineSecondary: colorScheme.tertiary,
          fillBelowLine: colorScheme.primary.withValues(alpha: 0.12),
        ),
        LiquidGlassTheme.standard(brightness),
        AppSemanticColors.forScheme(colorScheme, brightness),
      ],
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AppFadeSlidePageTransitionsBuilder(),
          TargetPlatform.fuchsia: AppFadeSlidePageTransitionsBuilder(),
          TargetPlatform.linux: AppFadeSlidePageTransitionsBuilder(),
          TargetPlatform.macOS: AppFadeSlidePageTransitionsBuilder(),
          TargetPlatform.windows: AppFadeSlidePageTransitionsBuilder(),
          TargetPlatform.iOS: AppFadeSlidePageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: scaffoldColor,
      canvasColor: canvasColor,
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.52),
        shadowColor: brightness == Brightness.dark
            ? Colors.black.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kBorderRadiusMedium),
          side: BorderSide(
            color: colorScheme.outline.withValues(alpha: cardBorderAlpha),
          ),
        ),
        margin: const EdgeInsets.all(kSpacingSmall),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withValues(
          alpha: brightness == Brightness.dark ? 0.35 : 0.08,
        ),
        backgroundColor: colorScheme.surfaceContainer.withValues(alpha: 0.72),
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(
            horizontal: kSpacingLarge,
            vertical: kSpacingMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kBorderRadiusMedium),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: colorScheme.onPrimary,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(
            horizontal: kSpacingLarge,
            vertical: kSpacingMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kBorderRadiusMedium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: kSpacingLarge,
            vertical: kSpacingMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kBorderRadiusMedium),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          splashFactory: InkRipple.splashFactory,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        circularTrackColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: brightness == Brightness.dark ? 0.5 : 0.65,
        ),
        linearTrackColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: brightness == Brightness.dark ? 0.45 : 0.6,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kBorderRadiusMedium),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: kSpacingMedium,
          vertical: kSpacingXSmall,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainer.withValues(alpha: 0.65),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kBorderRadiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kBorderRadiusMedium),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.35),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kBorderRadiusMedium),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kBorderRadiusMedium),
          borderSide: BorderSide(
            color: colorScheme.error.withValues(alpha: 0.8),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: kSpacingMedium,
          vertical: kSpacingMedium,
        ),
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.78),
        ),
        labelStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.92),
        ),
        floatingLabelStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.96),
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: textTheme.copyWith(
        headlineLarge: GoogleFonts.spaceGrotesk(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: colorScheme.onSurface,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: colorScheme.onSurface,
        ),
        headlineSmall: GoogleFonts.spaceGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
          color: colorScheme.onSurface,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: colorScheme.onSurface,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        titleSmall: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kBorderRadiusSmall),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacingSmall,
          vertical: kSpacingXSmall,
        ),
        // Opaque fills + no surface tint so chips stay readable on glass / gradients.
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primaryContainer,
        disabledColor: colorScheme.onSurface.withValues(alpha: 0.08),
        labelStyle: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        secondaryLabelStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        surfaceTintColor: Colors.transparent,
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.35)),
        checkmarkColor: colorScheme.primary,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(kBorderRadiusSmall),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: kSpacingMedium,
          vertical: kSpacingSmall,
        ),
        textStyle: TextStyle(
          color: colorScheme.onInverseSurface,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        preferBelow: false,
      ),
      tabBarTheme: TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: colorScheme.outline.withValues(alpha: 0.35),
        labelColor: colorScheme.onPrimary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicator: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(kBorderRadiusSmall),
            topRight: Radius.circular(kBorderRadiusSmall),
          ),
        ),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        overlayColor: WidgetStateProperty.all(
          colorScheme.primary.withValues(alpha: 0.12),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer.withValues(alpha: 0.78),
        elevation: 0,
        height: 64,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            );
          }
          return TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary, size: 26);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant, size: 24);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surfaceContainer.withValues(alpha: 0.78),
        elevation: 0,
        useIndicator: true,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        selectedIconTheme: IconThemeData(color: colorScheme.primary, size: 26),
        unselectedIconTheme: IconThemeData(
          color: colorScheme.onSurfaceVariant,
          size: 24,
        ),
        selectedLabelTextStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        labelType: NavigationRailLabelType.none,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.2),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withValues(alpha: 0.25),
        thickness: 1,
      ),
      menuTheme: MenuThemeData(style: opaqueMenuStyle),
      dropdownMenuTheme: DropdownMenuThemeData(menuStyle: opaqueMenuStyle),
      popupMenuTheme: PopupMenuThemeData(
        color: opaqueMenuSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: Colors.black.withValues(
          alpha: brightness == Brightness.dark ? 0.45 : 0.14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kBorderRadiusMedium),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(
          alpha: brightness == Brightness.dark ? 0.45 : 0.12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kBorderRadiusLarge),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh.withValues(
          alpha: 0.9,
        ),
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: colorScheme.primary,
        headerForegroundColor: colorScheme.onPrimary,
        dayStyle: TextStyle(color: colorScheme.onSurface),
        yearStyle: TextStyle(color: colorScheme.onSurface),
        weekdayStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        todayForegroundColor: WidgetStatePropertyAll(colorScheme.primary),
        rangeSelectionBackgroundColor: colorScheme.primary.withValues(
          alpha: 0.22,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: colorScheme.onInverseSurface,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kBorderRadiusMedium),
        ),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: brightness == Brightness.dark
            ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.94)
            : colorScheme.surfaceContainer.withValues(alpha: 0.92),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        dragHandleColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(kBorderRadiusLarge),
          ),
        ),
      ),
    );
  }

  static InputDecoration get baseInputDecoration {
    return InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kBorderRadiusMedium),
      ),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: kSpacingMedium,
        vertical: kSpacingMedium,
      ),
    );
  }

  static InputDecoration inputDecoration(
    ThemeData theme,
    String labelText, [
    IconData? prefixIcon,
  ]) {
    final cs = theme.colorScheme;
    return InputDecoration(
      labelText: labelText,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: cs.onSurfaceVariant.withValues(alpha: 0.85))
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kBorderRadiusMedium),
      ),
      filled: true,
      fillColor: cs.surfaceContainer.withValues(alpha: 0.9),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: kSpacingMedium,
        vertical: kSpacingSmall,
      ),
      hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.72)),
      labelStyle: TextStyle(
        color: cs.onSurfaceVariant.withValues(alpha: 0.92),
      ),
      floatingLabelStyle: TextStyle(
        color: cs.onSurface.withValues(alpha: 0.96),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// Builds [DropdownButtonFormField.selectedItemBuilder] children: one aligned row
  /// per [items] entry with solid [onSurface] text. Reduces “ghosted” duplicate text
  /// on dark/glass surfaces with Material 3 dropdowns (web/desktop).
  ///
  /// Prefer pairing with `isExpanded: true` on every [DropdownButtonFormField].
  static List<Widget> dropdownSelectedItemBuilders<T>(
    ThemeData theme,
    List<DropdownMenuItem<T>> items,
  ) {
    final cs = theme.colorScheme;
    final selectedValueStyle = TextStyle(
      color: cs.onSurface,
      fontWeight: FontWeight.w600,
    );
    return items
        .map(
          (DropdownMenuItem<T> item) => Align(
            alignment: AlignmentDirectional.centerStart,
            child: DefaultTextStyle.merge(
              style: selectedValueStyle,
              child: item.child,
            ),
          ),
        )
        .toList();
  }

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < kMobileBreakpoint;

  /// Scroll physics aligned with [AppScrollBehavior] (bouncy on mobile platforms,
  /// clamping on desktop/web). Use instead of hardcoding [BouncingScrollPhysics].
  static ScrollPhysics scrollPhysicsFor(BuildContext context) {
    return const AppScrollBehavior().getScrollPhysics(context);
  }

  /// Physical phone / small device. Stays true in landscape (unlike [isMobile],
  /// which keys only on width and treats landscape phones as “tablet”).
  static bool isHandset(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide < kMobileBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= kMobileBreakpoint &&
      MediaQuery.of(context).size.width < kDesktopBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= kDesktopBreakpoint;

  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < kMobileBreakpoint) return 1;
    if (width < kTabletBreakpoint) return 2;
    if (width < kDesktopBreakpoint) return 3;
    return 4;
  }

  static double getContentMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < kMobileBreakpoint) return width;
    if (width < kTabletBreakpoint) return kTabletBreakpoint;
    if (width < kDesktopBreakpoint) return kDesktopBreakpoint;
    return kDesktopBreakpoint * 1.2;
  }

  /// Horizontal inset from viewport edges for shell layout math (web / wide desktop).
  /// ~3% of width, clamped so gutters stay readable.
  static double shellHorizontalGutter(double viewportWidth) =>
      (viewportWidth * 0.03).clamp(24.0, 48.0);

  /// Target max width for shell pages before clamping to the parent [LayoutBuilder].
  /// Wider caps on large viewports reduce the “skinny column” look on web.
  /// Returns [double.infinity] below [kTabletBreakpoint] so the parent fully dictates width.
  static double shellContentIdealMaxWidth(double viewportWidth) {
    if (viewportWidth < kTabletBreakpoint) return double.infinity;
    if (viewportWidth < kDesktopBreakpoint) return 1120;
    if (viewportWidth < 1600) return 1520;
    if (viewportWidth < 1920) return 1680;
    return 1760;
  }

  /// Resolved shell content width: `min(ideal cap, layout max width)`.
  static double shellContentMaxWidth(
    double viewportWidth,
    double layoutMaxWidth,
  ) {
    final ideal = shellContentIdealMaxWidth(viewportWidth);
    if (!ideal.isFinite) return layoutMaxWidth;
    return ideal < layoutMaxWidth ? ideal : layoutMaxWidth;
  }

  static Color hexToColor(String code) {
    return Color(int.parse(code.substring(1, 7), radix: 16) + 0xFF000000);
  }

  static EdgeInsets getScreenPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    }
    return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
  }

  static EdgeInsets getCardPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(12);
    }
    return const EdgeInsets.all(16);
  }

  /// Vertical gap between major sections (filters, headers, lists) on scroll pages.
  static double sectionGap(BuildContext context) =>
      isMobile(context) ? kSpacingMedium : kSpacingLarge;

  /// Divider and subtle border color for both light and dark [ThemeData].
  static Color subtleDividerColor(ThemeData theme) {
    final o = theme.colorScheme.outline;
    return o.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.38 : 0.45,
    );
  }

  static double getMinTouchTarget(BuildContext context) {
    return isMobile(context) ? 48.0 : 44.0;
  }

  static double getIconSize(BuildContext context, {bool large = false}) {
    final isMobileDevice = isMobile(context);
    if (large) {
      return isMobileDevice ? 28.0 : 32.0;
    }
    return isMobileDevice ? 22.0 : 24.0;
  }

  static double getFontSize(BuildContext context, FontSizeType type) {
    final isMobileDevice = isMobile(context);
    switch (type) {
      case FontSizeType.headline:
        return isMobileDevice ? 22.0 : 28.0;
      case FontSizeType.title:
        return isMobileDevice ? 18.0 : 20.0;
      case FontSizeType.subtitle:
        return isMobileDevice ? 15.0 : 16.0;
      case FontSizeType.body:
        return isMobileDevice ? 14.0 : 15.0;
      case FontSizeType.caption:
        return isMobileDevice ? 12.0 : 13.0;
      case FontSizeType.small:
        return isMobileDevice ? 10.0 : 11.0;
    }
  }

  static double getBorderRadius(BuildContext context, {bool large = false}) {
    final isMobileDevice = isMobile(context);
    if (large) {
      return isMobileDevice ? 16.0 : 20.0;
    }
    return isMobileDevice ? 12.0 : 14.0;
  }

  static double getSpacing(BuildContext context, SpacingSize size) {
    final isMobileDevice = isMobile(context);
    switch (size) {
      case SpacingSize.xs:
        return 4.0;
      case SpacingSize.sm:
        return 8.0;
      case SpacingSize.md:
        return isMobileDevice ? 12.0 : 16.0;
      case SpacingSize.lg:
        return isMobileDevice ? 20.0 : 24.0;
      case SpacingSize.xl:
        return isMobileDevice ? 28.0 : 32.0;
    }
  }
}

/// Success / warning / info surfaces that work in light and dark mode.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  factory AppSemanticColors.forScheme(ColorScheme cs, Brightness brightness) {
    final baseSurface = cs.surfaceContainerHigh;
    final isDark = brightness == Brightness.dark;

    Color container(Color accent, double lightMix, double darkMix) {
      final a = isDark ? darkMix : lightMix;
      return Color.alphaBlend(accent.withValues(alpha: a), baseSurface);
    }

    Color onContainer(Color accent, Color containerColor) {
      final lum = containerColor.computeLuminance();
      if (lum > 0.55) {
        return Color.alphaBlend(Colors.black.withValues(alpha: 0.72), accent);
      }
      return Color.alphaBlend(Colors.white.withValues(alpha: 0.92), accent);
    }

    final successC = container(AppTheme.successColor, 0.2, 0.32);
    final warningC = container(AppTheme.warningColor, 0.22, 0.34);
    final infoC = container(AppTheme.infoColor, 0.2, 0.32);

    Color strongForeground(Color accent) => isDark
        ? accent
        : Color.alphaBlend(Colors.black.withValues(alpha: 0.78), accent);

    return AppSemanticColors(
      success: AppTheme.successColor,
      onSuccess: strongForeground(AppTheme.successColor),
      successContainer: successC,
      onSuccessContainer: onContainer(AppTheme.successColor, successC),
      warning: AppTheme.warningColor,
      onWarning: strongForeground(AppTheme.warningColor),
      warningContainer: warningC,
      onWarningContainer: onContainer(AppTheme.warningColor, warningC),
      info: AppTheme.infoColor,
      onInfo: strongForeground(AppTheme.infoColor),
      infoContainer: infoC,
      onInfoContainer: onContainer(AppTheme.infoColor, infoC),
    );
  }

  static AppSemanticColors of(BuildContext context) {
    return Theme.of(context).extension<AppSemanticColors>() ??
        AppSemanticColors.forScheme(
          Theme.of(context).colorScheme,
          Theme.of(context).brightness,
        );
  }

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    );
  }

  @override
  ThemeExtension<AppSemanticColors> lerp(
    ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
    );
  }
}

/// Global “liquid glass” tuning: blur strength, frost gradient, rim.
///
/// Use [surfaceBlurSigma] (default 0) for scroll-heavy surfaces; use
/// [modalBlurSigma] for a single modal/sheet shell where blur is affordable.
@immutable
class LiquidGlassTheme extends ThemeExtension<LiquidGlassTheme> {
  const LiquidGlassTheme({
    required this.surfaceBlurSigma,
    required this.modalBlurSigma,
    required this.outlineAlpha,
    required this.rimTintAlpha,
    required this.fillTopDark,
    required this.fillBottomDark,
    required this.fillTopLight,
    required this.fillBottomLight,
  });

  final double surfaceBlurSigma;
  final double modalBlurSigma;
  final double outlineAlpha;
  final double rimTintAlpha;
  final double fillTopDark;
  final double fillBottomDark;
  final double fillTopLight;
  final double fillBottomLight;

  factory LiquidGlassTheme.standard(Brightness brightness) {
    return LiquidGlassTheme(
      surfaceBlurSigma: 0,
      modalBlurSigma: brightness == Brightness.dark ? 14 : 12,
      outlineAlpha: brightness == Brightness.dark ? 0.36 : 0.30,
      rimTintAlpha: brightness == Brightness.dark ? 0.2 : 0.14,
      fillTopDark: 0.18,
      fillBottomDark: 0.09,
      fillTopLight: 0.68,
      fillBottomLight: 0.50,
    );
  }

  static LiquidGlassTheme of(BuildContext context) {
    return Theme.of(context).extension<LiquidGlassTheme>() ??
        LiquidGlassTheme.standard(Theme.of(context).brightness);
  }

  List<Color> fillGradient(ColorScheme cs, Brightness b) {
    if (b == Brightness.dark) {
      return [
        Color.alphaBlend(
          Colors.white.withValues(alpha: fillTopDark),
          cs.surface.withValues(alpha: 0.52),
        ),
        Color.alphaBlend(
          Colors.white.withValues(alpha: fillBottomDark),
          cs.primary.withValues(alpha: 0.14),
        ),
      ];
    }
    return [
      Color.alphaBlend(
        Colors.white.withValues(alpha: fillTopLight),
        cs.surface.withValues(alpha: 0.58),
      ),
      Color.alphaBlend(
        AppTheme.brandAccent.withValues(alpha: 0.1),
        Colors.white.withValues(alpha: fillBottomLight),
      ),
    ];
  }

  List<BoxShadow> panelShadows(ColorScheme cs, Brightness b) {
    return [
      BoxShadow(
        color: cs.primary.withValues(alpha: b == Brightness.dark ? 0.14 : 0.12),
        blurRadius: b == Brightness.dark ? 26 : 18,
        offset: const Offset(0, 8),
        spreadRadius: -5,
      ),
      BoxShadow(
        color: Colors.black.withValues(
          alpha: b == Brightness.dark ? 0.38 : 0.08,
        ),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ];
  }

  @override
  LiquidGlassTheme copyWith({
    double? surfaceBlurSigma,
    double? modalBlurSigma,
    double? outlineAlpha,
    double? rimTintAlpha,
    double? fillTopDark,
    double? fillBottomDark,
    double? fillTopLight,
    double? fillBottomLight,
  }) {
    return LiquidGlassTheme(
      surfaceBlurSigma: surfaceBlurSigma ?? this.surfaceBlurSigma,
      modalBlurSigma: modalBlurSigma ?? this.modalBlurSigma,
      outlineAlpha: outlineAlpha ?? this.outlineAlpha,
      rimTintAlpha: rimTintAlpha ?? this.rimTintAlpha,
      fillTopDark: fillTopDark ?? this.fillTopDark,
      fillBottomDark: fillBottomDark ?? this.fillBottomDark,
      fillTopLight: fillTopLight ?? this.fillTopLight,
      fillBottomLight: fillBottomLight ?? this.fillBottomLight,
    );
  }

  @override
  ThemeExtension<LiquidGlassTheme> lerp(
    ThemeExtension<LiquidGlassTheme>? other,
    double t,
  ) {
    if (other is! LiquidGlassTheme) return this;
    return LiquidGlassTheme(
      surfaceBlurSigma:
          surfaceBlurSigma + (other.surfaceBlurSigma - surfaceBlurSigma) * t,
      modalBlurSigma:
          modalBlurSigma + (other.modalBlurSigma - modalBlurSigma) * t,
      outlineAlpha: outlineAlpha + (other.outlineAlpha - outlineAlpha) * t,
      rimTintAlpha: rimTintAlpha + (other.rimTintAlpha - rimTintAlpha) * t,
      fillTopDark: fillTopDark + (other.fillTopDark - fillTopDark) * t,
      fillBottomDark:
          fillBottomDark + (other.fillBottomDark - fillBottomDark) * t,
      fillTopLight: fillTopLight + (other.fillTopLight - fillTopLight) * t,
      fillBottomLight:
          fillBottomLight + (other.fillBottomLight - fillBottomLight) * t,
    );
  }
}

/// fl_chart and custom chart colors that follow the active theme.
@immutable
class ChartTheme extends ThemeExtension<ChartTheme> {
  const ChartTheme({
    required this.gridColor,
    required this.axisLabelColor,
    required this.linePrimary,
    required this.lineSecondary,
    required this.fillBelowLine,
  });

  final Color gridColor;
  final Color axisLabelColor;
  final Color linePrimary;
  final Color lineSecondary;
  final Color fillBelowLine;

  static ChartTheme of(BuildContext context) {
    return Theme.of(context).extension<ChartTheme>() ??
        ChartTheme(
          gridColor: Theme.of(
            context,
          ).colorScheme.outline.withValues(alpha: 0.35),
          axisLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          linePrimary: Theme.of(context).colorScheme.primary,
          lineSecondary: Theme.of(context).colorScheme.tertiary,
          fillBelowLine: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.12),
        );
  }

  @override
  ChartTheme copyWith({
    Color? gridColor,
    Color? axisLabelColor,
    Color? linePrimary,
    Color? lineSecondary,
    Color? fillBelowLine,
  }) {
    return ChartTheme(
      gridColor: gridColor ?? this.gridColor,
      axisLabelColor: axisLabelColor ?? this.axisLabelColor,
      linePrimary: linePrimary ?? this.linePrimary,
      lineSecondary: lineSecondary ?? this.lineSecondary,
      fillBelowLine: fillBelowLine ?? this.fillBelowLine,
    );
  }

  @override
  ThemeExtension<ChartTheme> lerp(ThemeExtension<ChartTheme>? other, double t) {
    if (other is! ChartTheme) return this;
    return ChartTheme(
      gridColor: Color.lerp(gridColor, other.gridColor, t)!,
      axisLabelColor: Color.lerp(axisLabelColor, other.axisLabelColor, t)!,
      linePrimary: Color.lerp(linePrimary, other.linePrimary, t)!,
      lineSecondary: Color.lerp(lineSecondary, other.lineSecondary, t)!,
      fillBelowLine: Color.lerp(fillBelowLine, other.fillBelowLine, t)!,
    );
  }
}

enum FontSizeType { headline, title, subtitle, body, caption, small }

enum SpacingSize { xs, sm, md, lg, xl }
