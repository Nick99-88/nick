import 'package:flutter/material.dart';

class KeyboardTheme {
  final Color backgroundColor;
  final BoxDecoration buttonDecoration;
  final TextStyle keyTextStyle;
  final TextStyle modeLabelStyle;
  final Color accentColor;
  final double keyHeight;
  final double keySpacing;
  final BorderRadius keyBorderRadius;

  const KeyboardTheme({
    this.backgroundColor = const Color(0xFF1E1E2C),
    this.buttonDecoration = const BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      gradient: LinearGradient(
        colors: [Color(0xFF2D2D44), Color(0xFF3A3A55)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
      ],
    ),
    this.keyTextStyle = const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
    this.modeLabelStyle = const TextStyle(color: Colors.white70, fontSize: 12),
    this.accentColor = const Color(0xFF6C63FF),
    this.keyHeight = 48,
    this.keySpacing = 4,
    this.keyBorderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  KeyboardTheme copyWith({
    Color? backgroundColor,
    BoxDecoration? buttonDecoration,
    TextStyle? keyTextStyle,
    TextStyle? modeLabelStyle,
    Color? accentColor,
    double? keyHeight,
    double? keySpacing,
    BorderRadius? keyBorderRadius,
  }) {
    return KeyboardTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      buttonDecoration: buttonDecoration ?? this.buttonDecoration,
      keyTextStyle: keyTextStyle ?? this.keyTextStyle,
      modeLabelStyle: modeLabelStyle ?? this.modeLabelStyle,
      accentColor: accentColor ?? this.accentColor,
      keyHeight: keyHeight ?? this.keyHeight,
      keySpacing: keySpacing ?? this.keySpacing,
      keyBorderRadius: keyBorderRadius ?? this.keyBorderRadius,
    );
  }
}
