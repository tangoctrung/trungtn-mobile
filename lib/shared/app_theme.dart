import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const ink = Color(0xFF171717);
  static const canvas = Color(0xFFF5F5F5);

  static ThemeData get light {
    const colors = ColorScheme.light(
      primary: ink,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFECECEC),
      onPrimaryContainer: ink,
      secondary: Color(0xFF555555),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFEEEEEE),
      onSecondaryContainer: ink,
      tertiary: Color(0xFF777777),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFF0F0F0),
      onTertiaryContainer: ink,
      surface: Colors.white,
      onSurface: ink,
      onSurfaceVariant: Color(0xFF686868),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFFAFAFA),
      surfaceContainer: Color(0xFFF2F2F2),
      surfaceContainerHigh: Color(0xFFECECEC),
      surfaceContainerHighest: Color(0xFFE5E5E5),
      outline: Color(0xFF999999),
      outlineVariant: Color(0xFFE4E4E4),
      error: Color(0xFF292929),
      onError: Colors.white,
      errorContainer: Color(0xFFECECEC),
      onErrorContainer: ink,
      inverseSurface: ink,
      onInverseSurface: Colors.white,
      inversePrimary: Color(0xFFDDDDDD),
      surfaceTint: Colors.transparent,
      shadow: Colors.black,
      scrim: Colors.black,
    );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'BeVietnamPro',
      colorScheme: colors,
      scaffoldBackgroundColor: canvas,
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.5,
          height: 1.25,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.1,
          height: 1.3,
        ),
        headlineMedium: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          letterSpacing: -1,
          height: 1.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          letterSpacing: -.7,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -.5,
          height: 1.35,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -.3,
          height: 1.4,
        ),
        titleSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        bodyLarge: TextStyle(fontSize: 17, height: 1.6, letterSpacing: -.2),
        bodyMedium: TextStyle(fontSize: 16, height: 1.5, letterSpacing: -.2),
        bodySmall: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Color(0xFF686868),
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -.2,
        ),
        labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 23,
          fontWeight: FontWeight.w600,
          color: ink,
          letterSpacing: -.7,
        ),
      ),
      iconTheme: const IconThemeData(size: 26, color: ink),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: rounded,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: rounded,
          side: const BorderSide(color: Color(0xFFD8D8D8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: rounded),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: Colors.white,
        selectedColor: ink,
        checkmarkColor: Colors.white,
        labelStyle: const TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: ink),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
        minVerticalPadding: 12,
        titleTextStyle: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'BeVietnamPro',
          fontSize: 14,
          height: 1.6,
          color: Color(0xFF686868),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFEAEAEA),
        thickness: 1,
      ),
    );
  }
}
