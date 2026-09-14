import 'package:flutter/material.dart';

class SideEditorTheme {
  // Main colors
  static const Color backgroundDark = Color(0xFF1E1E2E);
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceDark = Color(0xFF282A36);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFFF8F8F2);
  static const Color textLight = Color(0xFF212121);
  static const Color accentBlue = Color(0xFF50FA7B);
  static const Color accentPurple = Color(0xFFBD93F9);
  static const Color accentOrange = Color(0xFFFFB86C);
  static const Color accentPink = Color(0xFFFF79C6);
  static const Color accentCyan = Color(0xFF8BE9FD);
  static const Color accentYellow = Color(0xFFF1FA8C);
  static const Color accentGreen = Color(0xFF50FA7B);
  static const Color errorRed = Color(0xFFFF5555);
  static const Color successGreen = Color(0xFF50FA7B);
  static const Color lineNumberColor = Color(0xFF6272A4);

  // Syntax highlighting colors
  static const Map<String, Color> syntaxColors = {
    'keyword': Color(0xFFFF79C6),
    'string': Color(0xFFF1FA8C),
    'comment': Color(0xFF6272A4),
    'number': Color(0xFFBD93F9),
    'function': Color(0xFF50FA7B),
    'class': Color(0xFF8BE9FD),
    'operator': Color(0xFFFF79C6),
    'variable': Color(0xFFF8F8F2),
    'type': Color(0xFF8BE9FD),
    'annotation': Color(0xFFFFB86C),
  };

  // Editor styles
  static const double editorFontSize = 14.0;
  static const double lineNumberFontSize = 12.0;
  static const double outputFontSize = 13.0;
  static const double tabBarFontSize = 12.0;

  // Spacing
  static const double editorPadding = 16.0;
  static const double consolePadding = 12.0;
  static const double borderWidth = 1.0;
  static const double borderRadius = 8.0;

  // Shadows
  static List<BoxShadow> get editorShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get consoleShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, -2),
        ),
      ];
}
