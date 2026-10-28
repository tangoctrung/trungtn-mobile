import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const ink = Color(0xFF0F0F0F);
  static const canvas = Colors.white;
  static const muted = Color(0xFF606060);
  static const soft = Color(0xFFF2F2F2);
  static const accent = Color(0xFFFF0033);

  static ThemeData get light {
    const colors = ColorScheme.light(
      primary: ink,
      onPrimary: Colors.white,
      primaryContainer: soft,
      onPrimaryContainer: ink,
      secondary: muted,
      onSecondary: Colors.white,
      secondaryContainer: soft,
      onSecondaryContainer: ink,
      tertiary: accent,
      onTertiary: Colors.white,
      surface: Colors.white,
      onSurface: ink,
      onSurfaceVariant: muted,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFFAFAFA),
      surfaceContainer: soft,
      surfaceContainerHigh: Color(0xFFEDEDED),
      surfaceContainerHighest: Color(0xFFE5E5E5),
      outline: Color(0xFF909090),
      outlineVariant: Color(0xFFE5E5E5),
      error: ink,
      onError: Colors.white,
      errorContainer: soft,
      onErrorContainer: ink,
      inverseSurface: ink,
      onInverseSurface: Colors.white,
      inversePrimary: Colors.white,
      surfaceTint: Colors.transparent,
    );
    const pill = StadiumBorder();
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: colors,
      scaffoldBackgroundColor: canvas,
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -.3,
          height: 1.2,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          letterSpacing: -.2,
          height: 1.25,
        ),
        titleSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: -.2,
          height: 1.25,
        ),
        bodyLarge: TextStyle(fontSize: 17, height: 1.3, letterSpacing: -.2),
        bodyMedium: TextStyle(fontSize: 16, height: 1.3, letterSpacing: -.2),
        bodySmall: TextStyle(
          fontSize: 13,
          height: 1.25,
          letterSpacing: -.1,
          color: muted,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
        labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 56,
        titleSpacing: 16,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        iconTheme: IconThemeData(size: 24, color: ink),
      ),
      iconTheme: const IconThemeData(size: 24, color: ink),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          padding: const EdgeInsets.all(8),
          shape: const CircleBorder(),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          shape: pill,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          shape: pill,
          side: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: pill,
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
        backgroundColor: soft,
        selectedColor: ink,
        checkmarkColor: Colors.white,
        labelStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: soft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ink),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: rounded,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: rounded,
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 4,
        horizontalTitleGap: 12,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: ink,
          height: 1.2,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13,
          height: 1.25,
          color: muted,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E5E5),
        thickness: .5,
      ),
    );
  }
}
