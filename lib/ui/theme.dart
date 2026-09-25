import 'package:flutter/material.dart';

class MinaTheme {
  static const bg = Color(0xFF080D12);
  static const bg2 = Color(0xFF0D141B);
  static const panel = Color(0xFF111920);
  static const panel2 = Color(0xFF151E26);
  static const border = Color(0xFF2A343E);
  static const border2 = Color(0xFF3B4650);
  static const text = Color(0xFFF4F6F8);
  static const muted = Color(0xFF9DA6B0);
  static const yellow = Color(0xFFF5B900);
  static const yellow2 = Color(0xFFFFD42C);
  static const green = Color(0xFF43C86A);
  static const red = Color(0xFFFF4D4F);
  static const blue = Color(0xFF3B9DF8);

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: yellow2,
      secondary: yellow,
      surface: panel,
      error: red,
      onPrimary: Color(0xFF080B0D),
      onSurface: text,
    );
    return ThemeData(
      colorScheme: scheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      useMaterial3: true,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xF20A1016),
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xF20C1319),
        indicatorColor: yellow.withValues(alpha: .16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          color: states.contains(WidgetState.selected) ? yellow : const Color(0xFF7F8992),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? yellow : const Color(0xFF7F8992),
        )),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF141A20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: border2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: yellow, width: 1.4)),
        labelStyle: const TextStyle(color: Color(0xFFD8DDE2)),
        hintStyle: const TextStyle(color: muted),
      ),
      cardTheme: CardThemeData(
        color: panel,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: border)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: yellow2,
          foregroundColor: const Color(0xFF080B0D),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: yellow,
          side: const BorderSide(color: Color(0xFFB98A00)),
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      dividerColor: border,
    );
  }
}
