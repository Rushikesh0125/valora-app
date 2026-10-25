import 'package:flutter/material.dart';

abstract final class ValoraColors {
  static const forest = Color(0xFF1F5E4A);
  static const ink = Color(0xFF1D2923);
  static const muted = Color(0xFF708077);
  static const canvas = Color(0xFFF8F7F1);
  static const mint = Color(0xFFE7F0E8);
  static const line = Color(0xFFDCE5DB);
  static const amber = Color(0xFFFFF3DD);
  static const red = Color(0xFFFBE8E4);
}

ThemeData valoraTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: ValoraColors.canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ValoraColors.forest,
      primary: ValoraColors.forest,
      surface: ValoraColors.canvas,
      onSurface: ValoraColors.ink,
    ),
    fontFamily: 'DM Sans',
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: ValoraColors.ink,
      displayColor: ValoraColors.ink,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      backgroundColor: ValoraColors.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: ValoraColors.mint,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? ValoraColors.forest
              : ValoraColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: ValoraColors.line,
      thickness: 1,
      space: 28,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: Color(0xFF93A098), fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: ValoraColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: ValoraColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: ValoraColors.forest, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ValoraColors.forest,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        textStyle: const TextStyle(
          fontFamily: 'DM Sans',
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ValoraColors.forest,
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: ValoraColors.line),
        textStyle: const TextStyle(
          fontFamily: 'DM Sans',
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ValoraColors.forest,
        textStyle: const TextStyle(
          fontFamily: 'DM Sans',
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    ),
  );
}
