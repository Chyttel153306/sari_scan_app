import 'package:flutter/material.dart';

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
  static List<BoxShadow> raisedShadows({double distance = 7, double blur = 16}) => [
    BoxShadow(color: baseDark, offset: Offset(distance, distance), blurRadius: blur),
    BoxShadow(color: baseLight, offset: Offset(-distance, -distance), blurRadius: blur),
  ];

  /// A smaller, tighter shadow pair for compact controls (icon badges, pills).
  static List<BoxShadow> softShadows() => raisedShadows(distance: 3, blur: 9);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: emerald).copyWith(
      primary: emerald,
      onPrimary: Colors.white,
      primaryContainer: emerald,
      onPrimaryContainer: mint,
      secondary: emeraldDeep,
      secondaryContainer: mint,
      onSecondaryContainer: emeraldDeep,
      surface: base,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: const Color(0xFFA6B4AA),
      outlineVariant: border,
      surfaceContainerHighest: const Color(0xFFDEE6E0),
      tertiary: warn,
      tertiaryContainer: warnBg,
      error: danger,
      errorContainer: dangerBg,
    );
    final rawBase = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'PlusJakartaSans',
    );
    final softShadowTint = baseDark.withValues(alpha: .6);

    return rawBase.copyWith(
      scaffoldBackgroundColor: base,
      textTheme: rawBase.textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
          color: ink,
        ),
        headlineMedium: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: ink,
        ),
        titleLarge: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: ink,
        ),
        titleMedium: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        bodyMedium: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 13,
          height: 1.5,
          color: ink,
        ),
        bodySmall: const TextStyle(
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
        titleTextStyle: const TextStyle(
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
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 24,
      ),
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
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9FAFA6)),
        labelStyle: const TextStyle(fontSize: 13, color: muted),
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
          borderSide: const BorderSide(color: emerald, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: danger, width: 1.3),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: danger, width: 1.6),
        ),
      ),
      // Filled buttons get a soft "raised pillow" shadow cast in their own
      // accent color, so a green Continue button looks gently lifted off
      // the page rather than flat or hard-edged.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: emerald,
          minimumSize: const Size(48, 52),
          elevation: 3,
          shadowColor: emeraldDeep.withValues(alpha: .55),
          textStyle: const TextStyle(
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
        style: IconButton.styleFrom(
          elevation: 2,
          shadowColor: softShadowTint,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: emerald,
        foregroundColor: Colors.white,
        elevation: 5,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        extendedTextStyle: const TextStyle(
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
        labelStyle: const TextStyle(
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
            color: states.contains(WidgetState.selected)
                ? emeraldDeep
                : muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 10,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? emeraldDeep
                : muted,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
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
          (states) => states.contains(WidgetState.selected)
              ? emerald
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? mint
              : baseSunken,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}