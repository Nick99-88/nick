import 'package:flutter/material.dart';

class StarlightTheme {
  // 🏛️ Brand Colors
  static const Color primaryBlue = Color(0xFF1A237E);
  static const Color secondaryBlack = Color(0xFF212121);
  static const Color accentGreen = Color(0xFF2E7D32); // For Green Sign Box
  static const Color errorRed = Color(0xFFC62828);    // For Red Sign Box
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color ghostGrey = Color(0xFFF5F5F5);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter', // High-end tech look
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: secondaryBlack,
        error: errorRed,
        surface: surfaceWhite,
      ),
      scaffoldBackgroundColor: surfaceWhite,

      // 🏛️ AppBar - Standard for Starlight Institution
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceWhite,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: secondaryBlack),
        titleTextStyle: TextStyle(
            color: secondaryBlack,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1
        ),
      ),

      // 🏛️ Input Fields (No Alerts, use these borders)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ghostGrey,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelStyle: const TextStyle(color: secondaryBlack, fontSize: 14),
        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
        prefixIconColor: Colors.grey[600],
        suffixIconColor: Colors.grey[600],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: errorRed, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // 🏛️ Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: secondaryBlack,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
    );
  }
}
