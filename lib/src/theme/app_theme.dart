import 'package:flutter/material.dart';

import 'theme_choice.dart';

/// SariScan's soft, green-tinted **neumorphic** design language.
///
/// Neumorphism keeps every surface the same base color and creates depth
/// purely through paired light/dark shadows instead of borders or flat
/// elevation. Most of that depth is applied centrally here, through
/// [light] and its component themes, so individual screens keep using the
/// same Material widgets (Card, FilledButton, TextField, Chip, NavigationBar,
/// FloatingActionButton, Dialog...) they always have — they just render
/// softer, rounder, and borderless now.
class AppTheme {
  // Base neumorphic surface. Scaffold, cards, and controls all share this
  // color; only the shadow pair around them signals whether something is
  // raised (a button, a card) or pressed in (a selected state).
  static const base = Color(0xFFE7ECE7);
  static const baseDark = Color(0xFFC7D1C9);
  static const baseLight = Color(0xFFFFFFFF);
  static const baseSunken = Color(0xFFEFF4F1);

  static const emerald = Color(0xFF3E9C6F);
  static const emeraldDeep = Color(0xFF2E7D53);
  static const mint = Color(0xFFDFF3E6);
  static const ink = Color(0xFF32403A);
  static const muted = Color(0xFF778A80);
  static const canvas = base;
  static const border = Color(0xFFD3DBD5);
  static const warn = Color(0xFFD98F4E);
  static const warnBg = Color(0xFFFBEEDD);
  static const danger = Color(0xFFD9705F);
  static const dangerBg = Color(0xFFFBE7E3);

  static const brandGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [emeraldDeep, emerald],
  );

  /// Diagonal gradient standing in for an inner ("pressed") shadow — Flutter
  /// has no native inset-shadow primitive, so a subtle dark-to-light
  /// diagonal on the same base hue gives inputs and selected chips a
  /// gently recessed feel without needing a border.
  static const insetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD9E2DB), Color(0xFFF6FAF7)],
  );

  /// The standard raised neumorphic shadow pair, cast from [base].
  static List<BoxShadow> raisedShadows({
    double distance = 7,
    double blur = 16,
  }) => [
    BoxShadow(
      color: baseDark,
      offset: Offset(distance, distance),
      blurRadius: blur,
    ),
    BoxShadow(
      color: baseLight,
      offset: Offset(-distance, -distance),
      blurRadius: blur,
    ),
  ];

  /// A smaller, tighter shadow pair for compact controls (icon badges, pills).
  static List<BoxShadow> softShadows() => raisedShadows(distance: 3, blur: 9);

  static ThemeData get light => forChoice(ThemeChoice.defaultTheme);

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>() ??
      AppPalette.forChoice(ThemeChoice.defaultTheme);

  static ThemeData forChoice(ThemeChoice choice) {
    final palette = AppPalette.forChoice(choice);
    final scheme = palette.scheme;
    final base = palette.base;
    final baseDark = palette.baseDark;
    final baseSunken = palette.baseSunken;
    final emerald = palette.emerald;
    final emeraldDeep = palette.emeraldDeep;
    final mint = palette.mint;
    final ink = palette.ink;
    final muted = palette.muted;
    final border = palette.border;
    final danger = palette.danger;
    final rawBase = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [palette],
      fontFamily: 'PlusJakartaSans',
    );
    final softShadowTint = baseDark.withValues(alpha: .6);

    return rawBase.copyWith(
      scaffoldBackgroundColor: base,
      textTheme: rawBase.textTheme.copyWith(
        headlineLarge: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 13,
          height: 1.5,
          color: ink,
        ),
        bodySmall: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 11,
          height: 1.5,
          color: muted,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: base,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        shadowColor: softShadowTint,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 3,
        toolbarHeight: 68,
        titleTextStyle: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      // Cards keep the same base color as the scaffold and gain depth from a
      // single soft, warm-grey shadow instead of a border — the hallmark of
      // a neumorphic "raised" surface, kept gentle rather than 3D.
      cardTheme: CardThemeData(
        color: base,
        surfaceTintColor: Colors.transparent,
        shadowColor: softShadowTint,
        elevation: 4,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 24),
      // Inputs drop the hard outline for a filled, gently sunken well —
      // borderless by default, with just a soft focus ring in the accent
      // green so the field still reads clearly when active.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: baseSunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        prefixIconColor: muted,
        hintStyle: TextStyle(fontSize: 13, color: muted),
        labelStyle: TextStyle(fontSize: 13, color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: emerald, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: danger, width: 1.3),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: danger, width: 1.6),
        ),
      ),
      // Filled buttons get a soft "raised pillow" shadow cast in their own
      // accent color, so a green Continue button looks gently lifted off
      // the page rather than flat or hard-edged.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: emerald,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          elevation: 3,
          shadowColor: emeraldDeep.withValues(alpha: .55),
          textStyle: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: ink,
          backgroundColor: base,
          side: BorderSide.none,
          elevation: 2,
          shadowColor: softShadowTint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: emeraldDeep,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(elevation: 2, shadowColor: softShadowTint),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: emerald,
        foregroundColor: Colors.white,
        elevation: 5,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        extendedTextStyle: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      // Chips (category filters, quick-cash amounts) become soft rounded
      // pebbles — no outline, a light shadow when idle, solid green fill
      // with a slightly deeper shadow when selected.
      chipTheme: ChipThemeData(
        backgroundColor: baseSunken,
        selectedColor: emerald,
        checkmarkColor: Colors.white,
        side: BorderSide.none,
        elevation: 2,
        pressElevation: 0,
        shadowColor: softShadowTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      // The bottom bar floats as one soft raised slab, its items highlighted
      // by a rounded mint "pressed" indicator rather than a hard pill.
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: base,
        surfaceTintColor: Colors.transparent,
        shadowColor: softShadowTint,
        elevation: 0,
        indicatorColor: mint,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected) ? emeraldDeep : muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 10,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? emeraldDeep : muted,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: TextStyle(color: base),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: base,
        surfaceTintColor: Colors.transparent,
        shadowColor: softShadowTint,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: base,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: softShadowTint,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? emerald : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? mint : baseSunken,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}

/// Colors for custom widgets, carried by Theme so open routes update together.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette(this.scheme, {this.highlight = Colors.white});
  final ColorScheme scheme;
  final Color highlight;

  factory AppPalette.forChoice(ThemeChoice choice) {
    if (choice == ThemeChoice.defaultTheme) {
      return AppPalette(
        ColorScheme.fromSeed(seedColor: AppTheme.emerald).copyWith(
          primary: AppTheme.emerald,
          onPrimary: Colors.white,
          primaryContainer: AppTheme.emerald,
          onPrimaryContainer: AppTheme.mint,
          secondary: AppTheme.emeraldDeep,
          secondaryContainer: AppTheme.mint,
          onSecondaryContainer: AppTheme.emeraldDeep,
          surface: AppTheme.base,
          onSurface: AppTheme.ink,
          onSurfaceVariant: AppTheme.muted,
          outline: const Color(0xFFA6B4AA),
          outlineVariant: AppTheme.border,
          surfaceContainerLow: AppTheme.baseSunken,
          surfaceContainerHighest: const Color(0xFFDEE6E0),
          shadow: AppTheme.baseDark,
          tertiary: AppTheme.warn,
          tertiaryContainer: AppTheme.warnBg,
          error: AppTheme.danger,
          errorContainer: AppTheme.dangerBg,
        ),
      );
    }
    final dark = choice == ThemeChoice.dark;
    final seed = switch (choice) {
      ThemeChoice.blue => const Color(0xFF2864C5),
      ThemeChoice.red => const Color(0xFFB93838),
      ThemeChoice.pink => const Color(0xFFB53679),
      _ => AppTheme.emerald,
    };
    final generated = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: dark ? Brightness.dark : Brightness.light,
    );
    final accent = dark ? const Color(0xFF4DAA7B) : seed;
    return AppPalette(
      generated.copyWith(
        primary: accent,
        onPrimary: Colors.white,
        primaryContainer: accent,
        onPrimaryContainer: Colors.white,
        secondary: dark
            ? const Color(0xFF8BD8B1)
            : Color.lerp(seed, Colors.black, .2),
        secondaryContainer: dark
            ? const Color(0xFF223E30)
            : Color.lerp(seed, Colors.white, .86),
        surface: dark
            ? const Color(0xFF1C2420)
            : Color.lerp(seed, Colors.white, .92),
        surfaceContainerLow: dark
            ? const Color(0xFF252F29)
            : Color.lerp(seed, Colors.white, .96),
        shadow: dark
            ? const Color(0xFF101612)
            : Color.lerp(seed, Colors.white, .77),
        tertiary: dark ? const Color(0xFFE9AE70) : AppTheme.warn,
        tertiaryContainer: dark ? const Color(0xFF4A3421) : AppTheme.warnBg,
      ),
      highlight: dark ? const Color(0xFF303C34) : Colors.white,
    );
  }

  Color get base => scheme.surface;
  Color get canvas => base;
  Color get baseDark => scheme.shadow;
  Color get baseLight => highlight;
  Color get baseSunken => scheme.surfaceContainerLow;
  Color get emerald => scheme.primary;
  Color get emeraldDeep => scheme.secondary;
  Color get mint => scheme.secondaryContainer;
  Color get ink => scheme.onSurface;
  Color get muted => scheme.onSurfaceVariant;
  Color get border => scheme.outlineVariant;
  Color get warn => scheme.tertiary;
  Color get warnBg => scheme.tertiaryContainer;
  Color get danger => scheme.error;
  Color get dangerBg => scheme.errorContainer;

  LinearGradient get brandGradient => LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [Color.lerp(emerald, Colors.black, .25)!, emerald],
  );
  LinearGradient get insetGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color.lerp(base, baseDark, .45)!, baseSunken],
  );
  LinearGradient get heroGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(emerald, Colors.black, .3)!,
      Color.lerp(emerald, Colors.black, .65)!,
    ],
  );
  List<BoxShadow> raisedShadows({double distance = 7, double blur = 16}) => [
    BoxShadow(
      color: baseDark,
      offset: Offset(distance, distance),
      blurRadius: blur,
    ),
    BoxShadow(
      color: baseLight,
      offset: Offset(-distance, -distance),
      blurRadius: blur,
    ),
  ];
  List<BoxShadow> softShadows() => raisedShadows(distance: 3, blur: 9);

  @override
  AppPalette copyWith({ColorScheme? scheme, Color? highlight}) =>
      AppPalette(scheme ?? this.scheme, highlight: highlight ?? this.highlight);

  @override
  AppPalette lerp(covariant AppPalette? other, double t) => other == null
      ? this
      : AppPalette(
          ColorScheme.lerp(scheme, other.scheme, t),
          highlight: Color.lerp(highlight, other.highlight, t)!,
        );
}
