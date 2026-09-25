import 'package:flutter/material.dart';

class MinaTheme {
  static const yellow = Color(0xFFFFC51B);
  static const bg = Color(0xFF070A0C);
  static const panel = Color(0xFF11171C);
  static const border = Color(0xFF39434C);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: yellow,
      brightness: Brightness.dark,
      surface: panel,
    );
    return ThemeData(
      colorScheme: scheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF11171C),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: yellow, width: 1.6)),
      ),
      cardTheme: const CardThemeData(
        color: panel,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: yellow,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
