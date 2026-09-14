import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

/// Underline style options for a cell
enum CellUnderlineStyle {
  none,
  single,
  double,
  dotted,
  dashed,
}

/// Represents styling parameters for a cell
class CellStyle {
  final bool isBold;
  final bool isItalic;
  final CellUnderlineStyle underlineStyle;
  final bool hasBulletPoint;
  final String? fontFamily;
  final double? fontSize;
  final Color textColor;
  final Color backgroundColor;
  final PlutoColumnTextAlign textAlign;

  const CellStyle({
    this.isBold = false,
    this.isItalic = false,
    this.underlineStyle = CellUnderlineStyle.none,
    this.hasBulletPoint = false,
    this.fontFamily,
    this.fontSize,
    this.textColor = Colors.black,
    this.backgroundColor = Colors.transparent,
    this.textAlign = PlutoColumnTextAlign.center,
  });

  CellStyle copyWith({
    bool? isBold,
    bool? isItalic,
    CellUnderlineStyle? underlineStyle,
    bool? hasBulletPoint,
    Object? fontFamily = _sentinel,
    Object? fontSize = _sentinel,
    Color? textColor,
    Color? backgroundColor,
    PlutoColumnTextAlign? textAlign,
  }) {
    return CellStyle(
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      underlineStyle: underlineStyle ?? this.underlineStyle,
      hasBulletPoint: hasBulletPoint ?? this.hasBulletPoint,
      fontFamily: fontFamily == _sentinel ? this.fontFamily : fontFamily as String?,
      fontSize: fontSize == _sentinel ? this.fontSize : fontSize as double?,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textAlign: textAlign ?? this.textAlign,
    );
  }
}

// Sentinel to distinguish "not provided" from explicit null for nullable fields
const Object _sentinel = Object();
