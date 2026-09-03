import 'package:flutter/material.dart';

const bgColor = Color(0xFFF2F6F4);
const inkColor = Color(0xFF14211E);
const tealColor = Color(0xFF007C7A);
const coralColor = Color(0xFFD74B4B);
const amberColor = Color(0xFFD89A21);
const mintColor = Color(0xFFE1F2EC);
const creamColor = Color(0xFFFFF7EA);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: tealColor,
    brightness: Brightness.light,
    primary: tealColor,
    secondary: coralColor,
    surface: Colors.white,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: bgColor,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w900,
        color: inkColor,
        letterSpacing: -0.6,
      ),
      titleLarge: TextStyle(fontWeight: FontWeight.w900, color: inkColor),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: inkColor),
      bodyMedium: TextStyle(color: inkColor),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.black.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(22),
      ),
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.white,
      shadowColor: const Color(0x22007C7A),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FBFA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: tealColor, width: 1.6),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white.withOpacity(0.96),
      indicatorColor: mintColor,
      height: 72,
      labelTextStyle: MaterialStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(MaterialState.selected)
              ? tealColor
              : Colors.black54,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    ),
  );
}
