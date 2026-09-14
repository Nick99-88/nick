import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import '../../../core/theme.dart';

// --- DATA MODEL: INDEPENDENT STROKES ---
class DrawingStroke {
  final List<Offset> points;
  Color color;
  double width;
  String?
      shapeType; // 'free', 'line', 'rectangle', 'circle', 'triangle', 'polygon', 'arrow', 'diamond', 'parallelogram', 'star', 'heart', 'speech_bubble', 'ruler', 'text'
  String? text;
  Color? fillColor;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.width,
    this.shapeType = 'free',
    this.text,
    this.fillColor,
  });

  String get activeShape => shapeType ?? 'free';
}

// --- INTERACTIVE TEXT NOTE MODEL ---
class _TextNote {
  Offset position;
  double width;
  double height;
  String text;
  Color color;
  double fontSize;
  bool isExpanded;
  double rotation;
  TextEditingController controller;

  _TextNote({
    required this.position,
    this.width = 160,
    this.height = 50,
    required this.text,
    this.color = Colors.black,
    this.fontSize = 14,
    this.isExpanded = false,
    this.rotation = 0,
  }) : controller = TextEditingController(text: text);

  void syncText() => text = controller.text;

  void dispose() => controller.dispose();
}

// --- ACTIVE CROP OVERLAY PAINTER ---
class CropOverlayPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final bool showHandles;

  CropOverlayPainter({required this.start, required this.end, this.showHandles = true});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(start, end);

    // 1. Semi-transparent black overlay on the cropped-out background
    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()..addRect(rect);
    final finalPath =
        Path.combine(PathOperation.difference, backgroundPath, holePath);
    canvas.drawPath(finalPath, backgroundPaint);

    // 2. Active crop boundary
    final borderPaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, borderPaint);

    if (showHandles) {
      // 3. Corner handles
      final handlePaint = Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.fill;
      const double hs = 10.0;
      for (final c in [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight]) {
        canvas.drawRect(Rect.fromCenter(center: c, width: hs, height: hs), handlePaint);
        canvas.drawRect(Rect.fromCenter(center: c, width: hs, height: hs), Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      }
      // Edge midpoints
      final edgePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      const double es = 6.0;
      for (final c in [
        Offset(rect.center.dx, rect.top),
        Offset(rect.center.dx, rect.bottom),
        Offset(rect.left, rect.center.dy),
        Offset(rect.right, rect.center.dy),
      ]) {
        canvas.drawCircle(c, es / 2, edgePaint);
        canvas.drawCircle(c, es / 2, Paint()
          ..color = Colors.cyanAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CropOverlayPainter oldDelegate) => true;
}

// --- SUBTLE GRID BACKGROUND PAINTER ---
class GridBackgroundPainter extends CustomPainter {
  final Color lineColor;
  final bool isIsometric;
  GridBackgroundPainter({required this.lineColor, this.isIsometric = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (isIsometric) {
      _paintIsometric(canvas, size);
    } else {
      _paintSquare(canvas, size);
    }
  }

  void _paintSquare(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.8;
    const double step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintIsometric(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.6;
    const double step = 40.0;
    final double d = step * 0.866; // cos(30°) ≈ 0.866

    // Right-going lines (30° up-right)
    for (double start = -size.height * 1.5; start < size.width + size.height; start += d) {
      canvas.drawLine(Offset(start, 0.0), Offset(start + size.height * 0.577, size.height), paint);
    }
    // Left-going lines (150° up-left)
    for (double start = -size.height * 1.5; start < size.width + size.height; start += d) {
      canvas.drawLine(Offset(start, 0.0), Offset(start - size.height * 0.577, size.height), paint);
    }
    // Vertical lines
    for (double x = -size.height * 0.5; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0.0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridBackgroundPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor || oldDelegate.isIsometric != isIsometric;
}

// --- LIVE SHAPE PREVIEW PAINTER ---
class ShapePreviewPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final String shapeType;
  final Color color;
  final double width;

  ShapePreviewPainter({
    required this.start,
    required this.end,
    required this.shapeType,
    required this.color,
    required this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.5) // Semi-transparent preview
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromPoints(start, end);

    if (shapeType == 'line') {
      canvas.drawLine(start, end, paint);
    } else if (shapeType == 'rectangle') {
      canvas.drawRect(rect, paint);
    } else if (shapeType == 'circle') {
      canvas.drawOval(rect, paint);
    } else if (shapeType == 'triangle') {
      final path = Path()
        ..moveTo((start.dx + end.dx) / 2, start.dy)
        ..lineTo(end.dx, end.dy)
        ..lineTo(start.dx, end.dy)
        ..close();
      canvas.drawPath(path, paint);
    } else if (shapeType == 'polygon') {
      // 6-Sided Hexagon Polygon
      final center = rect.center;
      final radiusX = rect.width / 2;
      final radiusY = rect.height / 2;
      final path = Path();
      const int sides = 6;
      for (int i = 0; i < sides; i++) {
        final double angle = (i * 2 * pi / sides) - (pi / 2);
        final double x = center.dx + radiusX * cos(angle);
        final double y = center.dy + radiusY * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    } else if (shapeType == 'arrow') {
      canvas.drawLine(start, end, paint);
      final double dX = end.dx - start.dx;
      final double dY = end.dy - start.dy;
      final double angle = atan2(dY, dX);
      const double arrowSize = 10.0;
      final path = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - arrowSize * cos(angle - pi / 6),
            end.dy - arrowSize * sin(angle - pi / 6))
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - arrowSize * cos(angle + pi / 6),
            end.dy - arrowSize * sin(angle + pi / 6));
      canvas.drawPath(path, paint);
    } else if (shapeType == 'diamond') {
      final double centerX = (start.dx + end.dx) / 2;
      final double centerY = (start.dy + end.dy) / 2;
      final path = Path()
        ..moveTo(centerX, start.dy)
        ..lineTo(end.dx, centerY)
        ..lineTo(centerX, end.dy)
        ..lineTo(start.dx, centerY)
        ..close();
      canvas.drawPath(path, paint);
    } else if (shapeType == 'parallelogram') {
      final double skew = rect.width * 0.25; // 25% skew width
      final path = Path()
        ..moveTo(start.dx + skew, start.dy)
        ..lineTo(end.dx, start.dy)
        ..lineTo(end.dx - skew, end.dy)
        ..lineTo(start.dx, end.dy)
        ..close();
      canvas.drawPath(path, paint);
    } else if (shapeType == 'star') {
      final center = rect.center;
      final radiusX = rect.width / 2;
      final radiusY = rect.height / 2;
      final path = Path();
      const int points = 5;
      for (int i = 0; i < 2 * points; i++) {
        final double rX = i % 2 == 0 ? radiusX : radiusX / 2.2;
        final double rY = i % 2 == 0 ? radiusY : radiusY / 2.2;
        final double angle = (i * pi / points) - (pi / 2);
        final double x = center.dx + rX * cos(angle);
        final double y = center.dy + rY * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    } else if (shapeType == 'heart') {
      final double w = rect.width;
      final double h = rect.height;
      final path = Path();
      path.moveTo(rect.left + w / 2, rect.top + h * 0.25);
      path.cubicTo(
        rect.left + w * 0.15,
        rect.top - h * 0.1,
        rect.left - w * 0.15,
        rect.top + h * 0.5,
        rect.left + w / 2,
        rect.bottom,
      );
      path.moveTo(rect.left + w / 2, rect.top + h * 0.25);
      path.cubicTo(
        rect.right - w * 0.15,
        rect.top - h * 0.1,
        rect.right + w * 0.15,
        rect.top + h * 0.5,
        rect.left + w / 2,
        rect.bottom,
      );
      canvas.drawPath(path, paint);
    } else if (shapeType == 'speech_bubble') {
      final path = Path()
        ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)))
        ..moveTo(rect.left + rect.width * 0.2, rect.bottom)
        ..lineTo(rect.left + rect.width * 0.15, rect.bottom + 12)
        ..lineTo(rect.left + rect.width * 0.3, rect.bottom)
        ..close();
      canvas.drawPath(path, paint);
    } else if (shapeType == 'curve') {
      // Straight line during initial drag
      canvas.drawLine(start, end, paint);
    } else if (shapeType == 'dotted_line') {
      final dx = end.dx - start.dx, dy = end.dy - start.dy;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist >= 1) {
        const double dashLen = 8, gapLen = 6;
        final total = dashLen + gapLen;
        final steps = (dist / total).floor();
        final ux = dx / dist, uy = dy / dist;
        for (int i = 0; i <= steps; i++) {
          final t0 = (i * total) / dist;
          final t1 = ((i * total + dashLen) / dist).clamp(0, 1);
          canvas.drawLine(
            Offset(start.dx + ux * t0 * dist, start.dy + uy * t0 * dist),
            Offset(start.dx + ux * t1 * dist, start.dy + uy * t1 * dist),
            paint,
          );
        }
      }
    } else if (shapeType == 'ruler') {
      canvas.drawLine(start, end, paint);
      final double dX = end.dx - start.dx;
      final double dY = end.dy - start.dy;
      final double angle = atan2(dY, dX);
      const double arrowSize = 10.0;
      final path = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - arrowSize * cos(angle - pi / 6),
            end.dy - arrowSize * sin(angle - pi / 6))
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - arrowSize * cos(angle + pi / 6),
            end.dy - arrowSize * sin(angle + pi / 6))
        ..moveTo(start.dx, start.dy)
        ..lineTo(start.dx + arrowSize * cos(angle - pi / 6),
            start.dy + arrowSize * sin(angle - pi / 6))
        ..moveTo(start.dx, start.dy)
        ..lineTo(start.dx + arrowSize * cos(angle + pi / 6),
            start.dy + arrowSize * sin(angle + pi / 6));
      canvas.drawPath(path, paint);

      // Label preview (unit will be set from stroke.text when finalized)
      final double distance = sqrt(dX * dX + dY * dY);
      final tp = TextPainter(
        text: TextSpan(
          text: " ${(distance / 10).toStringAsFixed(1)} cm ",
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.white.withOpacity(0.8),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    } else if (shapeType == 'plane') {
      // Show a crosshair cursor at tap point for preview
      final paint = Paint()
        ..color = Colors.indigo
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final double crossSize = 10;
      canvas.drawLine(Offset(start.dx - crossSize, start.dy),
          Offset(start.dx + crossSize, start.dy), paint);
      canvas.drawLine(Offset(start.dx, start.dy - crossSize),
          Offset(start.dx, start.dy + crossSize), paint);
    }
  }

  @override
  bool shouldRepaint(covariant ShapePreviewPainter oldDelegate) => true;
}

// --- CURVE BEND PREVIEW PAINTER ---
class CurvePreviewPainter extends CustomPainter {
  final List<Offset> fixedPoints;
  final Offset dragPreview;
  final Color color;
  final double width;

  CurvePreviewPainter({
    required this.fixedPoints,
    required this.dragPreview,
    required this.color,
    required this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    if (fixedPoints.length == 2) {
      // First bend: fixedPoints = [P0, P3], drag is P1
      final path = Path()
        ..moveTo(fixedPoints[0].dx, fixedPoints[0].dy)
        ..quadraticBezierTo(dragPreview.dx, dragPreview.dy,
            fixedPoints[1].dx, fixedPoints[1].dy);
      canvas.drawPath(path, paint);

      // Draw handle dot
      final handlePaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dragPreview, 5, handlePaint);
      canvas.drawCircle(dragPreview, 5, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    } else if (fixedPoints.length == 3) {
      // Second bend: fixedPoints = [P0, P1, P3], drag is P2
      final path = Path()
        ..moveTo(fixedPoints[0].dx, fixedPoints[0].dy)
        ..cubicTo(fixedPoints[1].dx, fixedPoints[1].dy,
            dragPreview.dx, dragPreview.dy,
            fixedPoints[2].dx, fixedPoints[2].dy);
      canvas.drawPath(path, paint);

      // Draw control point handles
      final handlePaint = Paint()
        ..color = Colors.orange
        ..style = PaintingStyle.fill;
      canvas.drawCircle(fixedPoints[1], 4, handlePaint);
      canvas.drawCircle(dragPreview, 5, handlePaint);
      // Ghost line from P1 to P3 showing previous curve
      final ghostPath = Path()
        ..moveTo(fixedPoints[0].dx, fixedPoints[0].dy)
        ..quadraticBezierTo(fixedPoints[1].dx, fixedPoints[1].dy,
            fixedPoints[2].dx, fixedPoints[2].dy);
      canvas.drawPath(ghostPath, Paint()
        ..color = color.withOpacity(0.2)
        ..strokeWidth = width
        ..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CurvePreviewPainter oldDelegate) => true;
}

// --- COMPASS DRAG PREVIEW PAINTER ---
class CompassPreviewPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final double angle;
  final Color color;
  final double width;

  CompassPreviewPainter({
    required this.center,
    required this.radius,
    required this.angle,
    required this.color,
    required this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    // Guide line
    final end = Offset(
      center.dx + radius * cos(angle),
      center.dy + radius * sin(angle),
    );
    canvas.drawLine(center, end, Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 1);
    // Arc
    final arcPath = Path()
      ..moveTo(center.dx + radius, center.dy)
      ..arcToPoint(end, radius: Radius.circular(radius), clockwise: angle > 0);
    canvas.drawPath(arcPath, paint);
    // Center dot
    canvas.drawCircle(center, 4, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CompassPreviewPainter oldDelegate) => true;
}

// --- DASHED BORDER PAINTER (for selected note outline) ---
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final w = size.width, h = size.height;
    const double dash = 6, gap = 4;
    void drawDashedLine(double x1, double y1, double x2, double y2) {
      final dx = x2 - x1, dy = y2 - y1;
      final len = sqrt(dx * dx + dy * dy);
      if (len < 1) return;
      final ux = dx / len, uy = dy / len;
      double dist = 0;
      while (dist < len) {
        final end = (dist + dash > len) ? len : dist + dash;
        canvas.drawLine(
          Offset(x1 + ux * dist, y1 + uy * dist),
          Offset(x1 + ux * end, y1 + uy * end),
          paint,
        );
        dist = end + gap;
      }
    }

    drawDashedLine(0, 0, w, 0);
    drawDashedLine(w, 0, w, h);
    drawDashedLine(w, h, 0, h);
    drawDashedLine(0, h, 0, 0);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

// --- ROTATION SCALE PAINTER (for text note rotation slider) ---
class _RotationScalePainter extends CustomPainter {
  final double rotation;
  _RotationScalePainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final degrees = (rotation * 180 / pi);
    // Center line
    final centerLine = Paint()
      ..color = Colors.indigo
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), centerLine);
    // Tick marks every 30 degrees
    for (int deg = -180; deg <= 180; deg += 30) {
      final frac = (deg + 180) / 360;
      final x = frac * w;
      final isMajor = deg % 90 == 0;
      final tickH = isMajor ? 8.0 : 4.0;
      final tick = Paint()
        ..color = Colors.indigo.withOpacity(isMajor ? 0.8 : 0.4)
        ..strokeWidth = 1;
      canvas.drawLine(
          Offset(x, (h - tickH) / 2), Offset(x, (h + tickH) / 2), tick);
      if (isMajor) {
        final lbl = TextPainter(
          text: TextSpan(
            text: '${deg ~/ 90}',
            style: TextStyle(
                color: Colors.indigo, fontSize: 8, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        lbl.paint(canvas, Offset(x - lbl.width / 2, (h - lbl.height) / 2 + 6));
      }
    }
    // Current rotation indicator
    final indicatorX = ((degrees + 180) / 360.0 * w).clamp(0.0, w);
    final indicator = Paint()
      ..color = Colors.indigo
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(indicatorX, h / 2), 4, indicator);
  }

  @override
  bool shouldRepaint(covariant _RotationScalePainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}

// --- CUSTOM CANVAS PAINTER ---
class DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;

  DrawingPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (var stroke in strokes) {
      // --- Fill pass ---
      if (stroke.fillColor != null) {
        final fillPaint = Paint()
          ..color = stroke.fillColor!
          ..style = PaintingStyle.fill;
        _drawFilledShape(canvas, stroke, fillPaint);
      }

      // --- Stroke outline pass ---
      final paint = Paint()
        ..color = stroke.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.width
        ..style = PaintingStyle.stroke;

      if (stroke.points.isEmpty) continue;

      if (stroke.activeShape == 'free') {
        if (stroke.points.length == 1) {
          canvas.drawCircle(stroke.points.first, stroke.width / 2,
              paint..style = PaintingStyle.fill);
        } else {
          final path = Path();
          path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
          for (int i = 1; i < stroke.points.length; i++) {
            path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
          }
          canvas.drawPath(path, paint);
        }
      } else if (stroke.activeShape == 'line') {
        canvas.drawLine(stroke.points.first, stroke.points.last, paint);
      } else if (stroke.activeShape == 'rectangle') {
        canvas.drawRect(
            Rect.fromPoints(stroke.points.first, stroke.points.last), paint);
      } else if (stroke.activeShape == 'circle') {
        canvas.drawOval(
            Rect.fromPoints(stroke.points.first, stroke.points.last), paint);
      } else if (stroke.activeShape == 'triangle') {
        final start = stroke.points.first;
        final end = stroke.points.last;
        final path = Path()
          ..moveTo((start.dx + end.dx) / 2, start.dy)
          ..lineTo(end.dx, end.dy)
          ..lineTo(start.dx, end.dy)
          ..close();
        canvas.drawPath(path, paint);
      } else if (stroke.activeShape == 'polygon') {
        final start = stroke.points.first;
        final end = stroke.points.last;
        final rect = Rect.fromPoints(start, end);
        final center = rect.center;
        final radiusX = rect.width / 2;
        final radiusY = rect.height / 2;
        final path = Path();
        const int sides = 6;
        for (int i = 0; i < sides; i++) {
          final double angle = (i * 2 * pi / sides) - (pi / 2);
          final double x = center.dx + radiusX * cos(angle);
          final double y = center.dy + radiusY * sin(angle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      } else if (stroke.activeShape == 'arrow') {
        final start = stroke.points.first;
        final end = stroke.points.last;
        canvas.drawLine(start, end, paint);

        final double dX = end.dx - start.dx;
        final double dY = end.dy - start.dy;
        final double angle = atan2(dY, dX);
        const double arrowSize = 10.0;
        final path = Path()
          ..moveTo(end.dx, end.dy)
          ..lineTo(end.dx - arrowSize * cos(angle - pi / 6),
              end.dy - arrowSize * sin(angle - pi / 6))
          ..moveTo(end.dx, end.dy)
          ..lineTo(end.dx - arrowSize * cos(angle + pi / 6),
              end.dy - arrowSize * sin(angle + pi / 6));
        canvas.drawPath(path, paint);
      } else if (stroke.activeShape == 'diamond') {
        final start = stroke.points.first;
        final end = stroke.points.last;
        final double centerX = (start.dx + end.dx) / 2;
        final double centerY = (start.dy + end.dy) / 2;
        final path = Path()
          ..moveTo(centerX, start.dy)
          ..lineTo(end.dx, centerY)
          ..lineTo(centerX, end.dy)
          ..lineTo(start.dx, centerY)
          ..close();
        canvas.drawPath(path, paint);
      } else if (stroke.activeShape == 'parallelogram') {
        final start = stroke.points.first;
        final end = stroke.points.last;
        final rect = Rect.fromPoints(start, end);
        final double skew = rect.width * 0.25;
        final path = Path()
          ..moveTo(start.dx + skew, start.dy)
          ..lineTo(end.dx, start.dy)
          ..lineTo(end.dx - skew, end.dy)
          ..lineTo(start.dx, end.dy)
          ..close();
        canvas.drawPath(path, paint);
      } else if (stroke.activeShape == 'star') {
        final start = stroke.points.first;
        final end = stroke.points.last;
        final rect = Rect.fromPoints(start, end);
        final center = rect.center;
        final radiusX = rect.width / 2;
        final radiusY = rect.height / 2;
        final path = Path();
        const int points = 5;
        for (int i = 0; i < 2 * points; i++) {
          final double rX = i % 2 == 0 ? radiusX : radiusX / 2.2;
          final double rY = i % 2 == 0 ? radiusY : radiusY / 2.2;
          final double angle = (i * pi / points) - (pi / 2);
          final double x = center.dx + rX * cos(angle);
          final double y = center.dy + rY * sin(angle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      } else if (stroke.activeShape == 'heart') {
        final start = stroke.points.first;
        final end = stroke.points.last;
        final rect = Rect.fromPoints(start, end);
        final double w = rect.width;
        final double h = rect.height;
        final path = Path();
        path.moveTo(rect.left + w / 2, rect.top + h * 0.25);
        path.cubicTo(
          rect.left + w * 0.15,
          rect.top - h * 0.1,
          rect.left - w * 0.15,
          rect.top + h * 0.5,
          rect.left + w / 2,
          rect.bottom,
        );
        path.moveTo(rect.left + w / 2, rect.top + h * 0.25);
        path.cubicTo(
          rect.right - w * 0.15,
          rect.top - h * 0.1,
          rect.right + w * 0.15,
          rect.top + h * 0.5,
          rect.left + w / 2,
          rect.bottom,
        );
        canvas.drawPath(path, paint);
      } else if (stroke.activeShape == 'speech_bubble') {
        final start = stroke.points.first;
        final end = stroke.points.last;
        final rect = Rect.fromPoints(start, end);
        final path = Path()
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)))
          ..moveTo(rect.left + rect.width * 0.2, rect.bottom)
          ..lineTo(rect.left + rect.width * 0.15, rect.bottom + 12)
          ..lineTo(rect.left + rect.width * 0.3, rect.bottom)
          ..close();
        canvas.drawPath(path, paint);
      } else if (stroke.activeShape == 'ruler') {
        final start = stroke.points.first;
        final end = stroke.points.last;
        canvas.drawLine(start, end, paint);

        final double dX = end.dx - start.dx;
        final double dY = end.dy - start.dy;
        final double angle = atan2(dY, dX);
        const double arrowSize = 10.0;
        final path = Path()
          ..moveTo(end.dx, end.dy)
          ..lineTo(end.dx - arrowSize * cos(angle - pi / 6),
              end.dy - arrowSize * sin(angle - pi / 6))
          ..moveTo(end.dx, end.dy)
          ..lineTo(end.dx - arrowSize * cos(angle + pi / 6),
              end.dy - arrowSize * sin(angle + pi / 6))
          ..moveTo(start.dx, start.dy)
          ..lineTo(start.dx + arrowSize * cos(angle - pi / 6),
              start.dy + arrowSize * sin(angle - pi / 6))
          ..moveTo(start.dx, start.dy)
          ..lineTo(start.dx + arrowSize * cos(angle + pi / 6),
              start.dy + arrowSize * sin(angle + pi / 6));
        canvas.drawPath(path, paint);

        final double distance = sqrt(dX * dX + dY * dY);
        final String unit = stroke.text ?? 'cm';
        final String textStr = "${(distance / 10).toStringAsFixed(1)} $unit";
        final tp = TextPainter(
          text: TextSpan(
            text: " $textStr ",
            style: TextStyle(
              color: stroke.color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.white.withOpacity(0.85),
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        tp.layout();
        final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
        tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      } else if (stroke.activeShape == 'curve') {
        final pts = stroke.points;
        if (pts.length == 2) {
          canvas.drawLine(pts[0], pts[1], paint);
        } else if (pts.length == 3) {
          final path = Path()
            ..moveTo(pts[0].dx, pts[0].dy)
            ..quadraticBezierTo(
                pts[1].dx, pts[1].dy, pts[2].dx, pts[2].dy);
          canvas.drawPath(path, paint);
        } else if (pts.length >= 4) {
          final path = Path()
            ..moveTo(pts[0].dx, pts[0].dy)
            ..cubicTo(pts[1].dx, pts[1].dy, pts[2].dx, pts[2].dy,
                pts[3].dx, pts[3].dy);
          canvas.drawPath(path, paint);
        }
      } else if (stroke.activeShape == 'dotted_line') {
        final start = stroke.points.first, end = stroke.points.last;
        final dx = end.dx - start.dx, dy = end.dy - start.dy;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < 1) {
          canvas.drawCircle(start, stroke.width / 2, paint);
        } else {
          const double dashLen = 8, gapLen = 6;
          final total = dashLen + gapLen;
          final steps = (dist / total).floor();
          final ux = dx / dist, uy = dy / dist;
          for (int i = 0; i <= steps; i++) {
            final t0 = (i * total) / dist;
            final t1 = ((i * total + dashLen) / dist).clamp(0, 1);
            canvas.drawLine(
              Offset(start.dx + ux * t0 * dist, start.dy + uy * t0 * dist),
              Offset(start.dx + ux * t1 * dist, start.dy + uy * t1 * dist),
              paint,
            );
          }
        }
      } else if (stroke.activeShape == 'blur') {
        if (stroke.points.length >= 2) {
          final blurPaint = Paint()
            ..color = stroke.color
            ..style = PaintingStyle.fill;
          for (int i = 1; i < stroke.points.length; i++) {
            final r = stroke.width / 2;
            final mid = Offset(
              (stroke.points[i - 1].dx + stroke.points[i].dx) / 2,
              (stroke.points[i - 1].dy + stroke.points[i].dy) / 2,
            );
            canvas.drawRect(
              Rect.fromCenter(center: mid, width: stroke.width, height: stroke.width),
              blurPaint,
            );
            // Draw pixel blocks for mosaic effect
            final pixelPaint = Paint()
              ..color = Colors.white.withOpacity(0.15)
              ..style = PaintingStyle.fill;
            for (int px = 0; px < 3; px++) {
              for (int py = 0; py < 3; py++) {
                canvas.drawRect(
                  Rect.fromCenter(
                    center: Offset(
                      mid.dx - r + px * r / 2,
                      mid.dy - r + py * r / 2,
                    ),
                    width: r / 4,
                    height: r / 4,
                  ),
                  pixelPaint,
                );
              }
            }
          }
        }
      } else if (stroke.activeShape == 'protractor') {
        final pts = stroke.points;
        if (pts.length >= 3) {
          final v = pts[0], a = pts[1], b = pts[2];
          final r = min((a - v).distance, (b - v).distance);
          final angleA = atan2(a.dy - v.dy, a.dx - v.dx);
          final angleB = atan2(b.dy - v.dy, b.dx - v.dx);
          // Draw arms
          canvas.drawLine(v, a, paint);
          canvas.drawLine(v, b, paint);
          // Draw arc
          final arcPath = Path()
            ..moveTo(v.dx + r * cos(angleA), v.dy + r * sin(angleA))
            ..arcToPoint(Offset(v.dx + r * cos(angleB), v.dy + r * sin(angleB)),
                radius: Radius.circular(r), clockwise: angleB > angleA);
          canvas.drawPath(arcPath, paint);
          // Degree label
          final degText = stroke.text ?? '0';
          final midAngle = (angleA + angleB) / 2;
          final labelOff = r * 0.7;
          final lbl = TextPainter(
            text: TextSpan(
              text: '$degText°',
              style: TextStyle(
                  color: stroke.color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  backgroundColor: Colors.white.withOpacity(0.85)),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          lbl.paint(
            canvas,
            Offset(v.dx + labelOff * cos(midAngle) - lbl.width / 2,
                v.dy + labelOff * sin(midAngle) - lbl.height / 2),
          );
        }
      } else if (stroke.activeShape == 'compass') {
        if (stroke.points.isNotEmpty) {
          final center = stroke.points.first;
          final parts = (stroke.text ?? '50|0').split('|');
          final radius = double.tryParse(parts[0]) ?? 50;
          final sweepAngle = double.tryParse(parts[1]) ?? 0;
          // Draw radial guide line
          final lineEnd = Offset(
            center.dx + radius * cos(sweepAngle),
            center.dy + radius * sin(sweepAngle),
          );
          final guidePaint = Paint()
            ..color = stroke.color.withOpacity(0.4)
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke;
          canvas.drawLine(center, lineEnd, guidePaint);
          // Draw arc from 0° to sweepAngle°
          final arcPath = Path()
            ..moveTo(center.dx + radius, center.dy)
            ..arcToPoint(
              Offset(
                center.dx + radius * cos(sweepAngle),
                center.dy + radius * sin(sweepAngle),
              ),
              radius: Radius.circular(radius),
              clockwise: sweepAngle > 0,
            );
          canvas.drawPath(arcPath, paint);
          // Center dot
          canvas.drawCircle(center, 3, paint);
          // Radius label
          final lbl = TextPainter(
            text: TextSpan(
              text: 'r=${radius.toStringAsFixed(0)}',
              style: TextStyle(
                  color: stroke.color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  backgroundColor: Colors.white.withOpacity(0.85)),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final mid = Offset(
            (center.dx + lineEnd.dx) / 2,
            (center.dy + lineEnd.dy) / 2,
          );
          lbl.paint(
            canvas,
            Offset(mid.dx - lbl.width / 2 + 6, mid.dy - lbl.height / 2 - 6),
          );
        }
      } else if (stroke.activeShape == 'plane') {
        final origin = stroke.points.first;
        final parts = (stroke.text ?? '2|100|80|100|80').split('|');
        final dimCount = int.tryParse(parts[0]) ?? 2;
        final vals =
            parts.skip(1).map((s) => double.tryParse(s) ?? 100).toList();
        // vals: [negX, posX, negY, posY, negZ, posZ]
        final axisColors = [stroke.color, stroke.color, stroke.color];
        void drawAxis(int axisIdx, double dx, double dy, double negLen,
            double posLen, String label, Color col) {
          final start =
              Offset(origin.dx + dx * negLen, origin.dy + dy * negLen);
          final endPt =
              Offset(origin.dx + dx * posLen, origin.dy + dy * posLen);
          final axisPaint = Paint()
            ..color = col
            ..strokeWidth = stroke.width
            ..style = PaintingStyle.stroke;
          canvas.drawLine(start, endPt, axisPaint);
          // Arrow at positive end
          final arrowSize = 8.0;
          final angle = atan2(endPt.dy - origin.dy, endPt.dx - origin.dx);
          final arrow = Path()
            ..moveTo(endPt.dx, endPt.dy)
            ..lineTo(endPt.dx - arrowSize * cos(angle - pi / 6),
                endPt.dy - arrowSize * sin(angle - pi / 6))
            ..moveTo(endPt.dx, endPt.dy)
            ..lineTo(endPt.dx - arrowSize * cos(angle + pi / 6),
                endPt.dy - arrowSize * sin(angle + pi / 6));
          canvas.drawPath(arrow, axisPaint);
          // Tick marks
          final totalLen = negLen + posLen;
          final tickStep = (totalLen / 6).clamp(10, 100);
          final textStyle = TextStyle(
              color: col,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.white.withOpacity(0.85));
          for (double d = -negLen; d <= posLen; d += tickStep) {
            if (d.abs() < 0.1) continue;
            final tx = origin.dx + dx * d;
            final ty = origin.dy + dy * d;
            final tickSize = 4.0;
            final perpDx = -dy * tickSize;
            final perpDy = dx * tickSize;
            canvas.drawLine(Offset(tx - perpDx, ty - perpDy),
                Offset(tx + perpDx, ty + perpDy), axisPaint);
            if (axisIdx == 0 || axisIdx == 1) {
              final lbl = TextPainter(
                  text: TextSpan(
                      text: d.toStringAsFixed(0), style: textStyle),
                  textDirection: TextDirection.ltr)
                ..layout();
              lbl.paint(
                  canvas,
                  Offset(
                      tx - lbl.width / 2 + (axisIdx == 0 ? 0 : -lbl.width - 2),
                      ty - lbl.height / 2 + (axisIdx == 0 ? 8 : -2)));
            }
          }
          // Label
          final lbl = TextPainter(
              text: TextSpan(
                  text: label,
                  style: TextStyle(
                      color: col, fontSize: 13, fontWeight: FontWeight.bold)),
              textDirection: TextDirection.ltr)
            ..layout();
          lbl.paint(canvas, Offset(endPt.dx + dx * 8, endPt.dy + dy * 8));
          // Origin label
          final zeroLbl = TextPainter(
              text: TextSpan(text: '0', style: textStyle),
              textDirection: TextDirection.ltr)
            ..layout();
          zeroLbl.paint(
              canvas,
              Offset(origin.dx - zeroLbl.width / 2 + 2,
                  origin.dy - zeroLbl.height / 2 + 8));
        }

        if (dimCount >= 1) {
          drawAxis(0, 1, 0, vals[0], vals[1], 'X', axisColors[0]);
        }
        if (dimCount >= 2) {
          drawAxis(1, 0, -1, vals[2], vals[3], 'Y', axisColors[1]);
        }
        if (dimCount >= 3 && vals.length >= 6) {
          drawAxis(2, 0.5, -0.5, vals[4], vals[5], 'Z', axisColors[2]);
        }
      }
    }
  }

  void _drawFilledShape(Canvas canvas, DrawingStroke stroke, Paint fillPaint) {
    final pts = stroke.points;
    if (pts.isEmpty) return;
    final start = pts.first, end = pts.last;
    final rect = Rect.fromPoints(start, end);
    final sp = stroke.activeShape;
    if (sp == 'rectangle') {
      canvas.drawRect(rect, fillPaint);
    } else if (sp == 'circle') {
      canvas.drawOval(rect, fillPaint);
    } else if (sp == 'triangle') {
      canvas.drawPath(
          Path()
            ..moveTo((start.dx + end.dx) / 2, start.dy)
            ..lineTo(end.dx, end.dy)
            ..lineTo(start.dx, end.dy)
            ..close(),
          fillPaint);
    } else if (sp == 'polygon') {
      final center = rect.center;
      final rx = rect.width / 2, ry = rect.height / 2;
      final path = Path();
      for (int i = 0; i < 6; i++) {
        final a = (i * 2 * pi / 6) - (pi / 2);
        final x = center.dx + rx * cos(a), y = center.dy + ry * sin(a);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, fillPaint);
    } else if (sp == 'diamond') {
      final cx = (start.dx + end.dx) / 2, cy = (start.dy + end.dy) / 2;
      canvas.drawPath(
          Path()
            ..moveTo(cx, start.dy)
            ..lineTo(end.dx, cy)
            ..lineTo(cx, end.dy)
            ..lineTo(start.dx, cy)
            ..close(),
          fillPaint);
    } else if (sp == 'parallelogram') {
      final skew = rect.width * 0.25;
      canvas.drawPath(
          Path()
            ..moveTo(start.dx + skew, start.dy)
            ..lineTo(end.dx, start.dy)
            ..lineTo(end.dx - skew, end.dy)
            ..lineTo(start.dx, end.dy)
            ..close(),
          fillPaint);
    } else if (sp == 'star') {
      final center = rect.center;
      final rx = rect.width / 2, ry = rect.height / 2;
      final path = Path();
      for (int i = 0; i < 10; i++) {
        final rrx = i % 2 == 0 ? rx : rx / 2.2;
        final rry = i % 2 == 0 ? ry : ry / 2.2;
        final a = (i * pi / 5) - (pi / 2);
        final x = center.dx + rrx * cos(a), y = center.dy + rry * sin(a);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, fillPaint);
    } else if (sp == 'heart') {
      final w = rect.width, h = rect.height;
      final path = Path();
      path.moveTo(rect.left + w / 2, rect.top + h * 0.25);
      path.cubicTo(rect.left + w * 0.15, rect.top - h * 0.1,
          rect.left - w * 0.15, rect.top + h * 0.5,
          rect.left + w / 2, rect.bottom);
      path.moveTo(rect.left + w / 2, rect.top + h * 0.25);
      path.cubicTo(rect.right - w * 0.15, rect.top - h * 0.1,
          rect.right + w * 0.15, rect.top + h * 0.5,
          rect.left + w / 2, rect.bottom);
      canvas.drawPath(path, fillPaint);
    } else if (sp == 'speech_bubble') {
      canvas.drawPath(
          Path()
            ..addRRect(
                RRect.fromRectAndRadius(rect, const Radius.circular(12)))
            ..moveTo(rect.left + rect.width * 0.2, rect.bottom)
            ..lineTo(rect.left + rect.width * 0.15, rect.bottom + 12)
            ..lineTo(rect.left + rect.width * 0.3, rect.bottom)
            ..close(),
          fillPaint);
    } else if (sp == 'free' && pts.length >= 3) {
      final path = Path();
      path.moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      path.close();
      canvas.drawPath(path, fillPaint);
    }
    // dotted_line, blur, protractor, compass — not fillable
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}

class DrawDesignScreen extends StatefulWidget {
  final Uint8List? backgroundImageBytes;
  const DrawDesignScreen({super.key, this.backgroundImageBytes});

  @override
  State<DrawDesignScreen> createState() => _DrawDesignScreenState();
}

class _DrawDesignScreenState extends State<DrawDesignScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  final TextEditingController _nameController =
      TextEditingController(text: "New 2D Design");
  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.0;
  bool _isColorPanelOpen = false;
  bool _showGrid = false;

  // Active Crop State variables
  bool _isCropping = false;
  Offset? _cropStart;
  Offset? _cropEnd;
  String _cropHandle = 'none'; // 'none','tl','tr','bl','br','top','bottom','left','right','move'
  Offset? _cropDragRawStart;
  Offset? _cropMoveOriginStart;
  Offset? _cropMoveOriginEnd;

  // Pan mode (double-tap to toggle, lets InteractiveViewer handle scrolling)
  bool _isPanMode = false;

  final TransformationController _transformationController =
      TransformationController();

  // Active Shape State variables
  String _activeShape =
      'free'; // 'free', 'line', 'rectangle', 'circle', 'triangle', 'polygon', 'arrow', 'diamond', 'parallelogram', 'star', 'heart', 'speech_bubble', 'curve', 'dotted_line', 'protractor', 'compass', 'blur', 'fill', 'eraser', 'ruler', 'text', 'plane'
  Offset? _shapeStart;
  Offset? _shapeEnd;

  // List to persist all independent multi-color strokes
  final List<DrawingStroke> _strokes = [];
  final List<DrawingStroke> _redoStrokes = [];
  final List<_TextNote> _undoNotes = [];
  Uint8List? _currentBgBytes;

  // Dynamic Canvas Size (expands as content is added)
  Size _canvasSize = const Size(2000, 2000);

  // Interactive Text Notes
  final List<_TextNote> _textNotes = [];
  int? _selectedNoteIndex;
  Offset? _dragStartGlobal;

  Offset? _dragNoteStartPos;

  final Map<int, Offset> _joystickKnob = {};

  Timer? _canvasJoystickTimer;
  Offset _canvasJoystickDisplacement = Offset.zero;

  String _selectedUnit = 'cm';
  List<double> _planeValues = [2, 50, 80, 50, 60];

  // Curve tool state (3-step: line → first bend → second bend)
  int _curvePhase = 0; // 0=idle, 1=line_drawn, 2=first_bend_done, 3=locked
  int _curveStrokeIndex = -1;
  Offset? _curveDragPreview;

  // Protractor tool state (vertex → start arm → end arm)
  int _protractorPhase = 0; // 0=idle, 1=vertex_set, 2=start_arm_set, 3=done
  final List<Offset> _protractorPoints = [];

  // Compass / Arc tool state (center → radius → angle)
  int _compassPhase = 0; // 0=idle, 1=center_set, 2=radius_set, 3=done
  Offset? _compassCenter;
  double _compassRadius = 0;
  double _compassAngle = 0;

  // Isometric grid toggle
  bool _isIsometricGrid = false;

  // Snap-to toggle
  bool _snapEnabled = false;

  // Canvas Theme State
  String _canvasTheme =
      'white'; // 'white', 'blueprint', 'grid_paper', 'chalkboard'

  Color get canvasBackgroundColor {
    switch (_canvasTheme) {
      case 'blueprint':
        return const Color(0xFF0A1D37);
      case 'grid_paper':
        return const Color(0xFFFAF8F5);
      case 'chalkboard':
        return const Color(0xFF1E262B);
      case 'dark':
        return const Color(0xFF2D2D2D);
      case 'sepia':
        return const Color(0xFFF5E6C8);
      case 'mint':
        return const Color(0xFFE8F5E9);
      case 'sky':
        return const Color(0xFFE3F2FD);
      case 'white':
      default:
        return Colors.white;
    }
  }

  Color get gridLineColor {
    switch (_canvasTheme) {
      case 'blueprint':
        return Colors.cyan.withOpacity(0.18);
      case 'grid_paper':
        return Colors.orange.withOpacity(0.12);
      case 'chalkboard':
        return Colors.green.withOpacity(0.12);
      case 'dark':
        return Colors.white.withOpacity(0.10);
      case 'sepia':
        return Colors.brown.withOpacity(0.15);
      case 'mint':
        return Colors.green.withOpacity(0.12);
      case 'sky':
        return Colors.blue.withOpacity(0.12);
      case 'white':
      default:
        return Colors.grey.withOpacity(0.15);
    }
  }

  void _expandCanvasForPoint(Offset point) {
    const double margin = 800;
    final neededW = point.dx + margin;
    final neededH = point.dy + margin;
    if (neededW > _canvasSize.width || neededH > _canvasSize.height) {
      setState(() {
        _canvasSize = Size(
          neededW > _canvasSize.width ? neededW : _canvasSize.width,
          neededH > _canvasSize.height ? neededH : _canvasSize.height,
        );
      });
    }
  }

  void _addStroke(DrawingStroke stroke) {
    setState(() {
      for (var pt in stroke.points) _expandCanvasForPoint(pt);
      _strokes.add(stroke);
      _redoStrokes.clear();
    });
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _redoStrokes.add(_strokes.removeLast());
      });
      _showMessage("Undo applied", true);
    } else if (_textNotes.isNotEmpty) {
      setState(() {
        _undoNotes.add(_textNotes.removeLast());
      });
      _showMessage("Undo applied", true);
    } else {
      _showMessage("Nothing to Undo", false);
    }
  }

  void _redo() {
    if (_redoStrokes.isNotEmpty) {
      setState(() {
        _strokes.add(_redoStrokes.removeLast());
      });
      _showMessage("Redo applied", true);
    } else if (_undoNotes.isNotEmpty) {
      setState(() {
        _textNotes.add(_undoNotes.removeLast());
      });
      _showMessage("Redo applied", true);
    } else {
      _showMessage("Nothing to Redo", false);
    }
  }

  void _eraseStrokeAt(Offset position) {
    const double eraseThreshold = 20.0;
    bool erasedAny = false;
    setState(() {
      for (int i = _strokes.length - 1; i >= 0; i--) {
        final stroke = _strokes[i];
        for (var pt in stroke.points) {
          final double distance = (pt - position).distance;
          if (distance < eraseThreshold) {
            _redoStrokes.add(stroke);
            _strokes.removeAt(i);
            erasedAny = true;
            break;
          }
        }
      }
    });
    if (erasedAny) {
      // Provide user subtle feedback or skip to avoid noise
    }
  }

  void _addTextLabel(Offset position) {
    _expandCanvasForPoint(position);
    _expandCanvasForPoint(Offset(position.dx + 200, position.dy + 100));
    setState(() {
      _textNotes.add(_TextNote(
        position: position,
        text: '',
        color: _selectedColor,
        fontSize: _strokeWidth * 2 + 10,
        isExpanded: true,
      ));
      _selectedNoteIndex = _textNotes.length - 1;
      _undoNotes.clear();
    });
  }

  void _addPlane(Offset position) {
    _expandCanvasForPoint(position);
    final scale = 3.0;
    // _planeValues: [dimCount, negX, posX, negY, posY, ...]
    final dimCount = _planeValues[0].toInt();
    final axisVals = _planeValues.skip(1).map((v) => v * scale).toList();
    double maxX = 0, maxY = 0;
    for (int i = 0; i < dimCount; i++) {
      if (i == 0) {
        maxX = axisVals[i * 2].abs() + axisVals[i * 2 + 1].abs();
      }
      if (i == 1) {
        maxY = axisVals[i * 2].abs() + axisVals[i * 2 + 1].abs();
      }
    }
    _expandCanvasForPoint(Offset(position.dx + maxX, position.dy + maxY));
    _expandCanvasForPoint(Offset(position.dx - maxX, position.dy - maxY));
    setState(() {
      _strokes.add(DrawingStroke(
        points: [position],
        color: _selectedColor,
        width: _strokeWidth,
        shapeType: 'plane',
        text: '$dimCount|${axisVals.join('|')}',
      ));
      _redoStrokes.clear();
      _undoNotes.clear();
    });
    _showMessage("$dimCount" "D axes placed", true);
  }

  /// Builds a closed [Path] for a stroke (for hit-testing and fill rendering).
  /// Returns null if the stroke type cannot form a closed shape.
  Path? _buildShapePath(DrawingStroke stroke) {
    final pts = stroke.points;
    if (pts.isEmpty) return null;
    final start = pts.first;
    final end = pts.last;
    final rect = Rect.fromPoints(start, end);
    final sp = stroke.activeShape;
    if (sp == 'rectangle') return Path()..addRect(rect);
    if (sp == 'circle') return Path()..addOval(rect);
    if (sp == 'triangle') {
      return (Path()
            ..moveTo((start.dx + end.dx) / 2, start.dy)
            ..lineTo(end.dx, end.dy)
            ..lineTo(start.dx, end.dy)
            ..close())
          as Path?;
    }
    if (sp == 'polygon') {
      final center = rect.center;
      final rx = rect.width / 2, ry = rect.height / 2;
      final path = Path();
      for (int i = 0; i < 6; i++) {
        final a = (i * 2 * pi / 6) - (pi / 2);
        final x = center.dx + rx * cos(a), y = center.dy + ry * sin(a);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
      return path;
    }
    if (sp == 'diamond') {
      final cx = (start.dx + end.dx) / 2, cy = (start.dy + end.dy) / 2;
      return (Path()
            ..moveTo(cx, start.dy)
            ..lineTo(end.dx, cy)
            ..lineTo(cx, end.dy)
            ..lineTo(start.dx, cy)
            ..close())
          as Path?;
    }
    if (sp == 'parallelogram') {
      final skew = rect.width * 0.25;
      return (Path()
            ..moveTo(start.dx + skew, start.dy)
            ..lineTo(end.dx, start.dy)
            ..lineTo(end.dx - skew, end.dy)
            ..lineTo(start.dx, end.dy)
            ..close())
          as Path?;
    }
    if (sp == 'star') {
      final center = rect.center;
      final rx = rect.width / 2, ry = rect.height / 2;
      final path = Path();
      for (int i = 0; i < 10; i++) {
        final rrx = i % 2 == 0 ? rx : rx / 2.2;
        final rry = i % 2 == 0 ? ry : ry / 2.2;
        final a = (i * pi / 5) - (pi / 2);
        final x = center.dx + rrx * cos(a), y = center.dy + rry * sin(a);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
      return path;
    }
    if (sp == 'heart') {
      final w = rect.width, h = rect.height;
      final path = Path();
      path.moveTo(rect.left + w / 2, rect.top + h * 0.25);
      path.cubicTo(rect.left + w * 0.15, rect.top - h * 0.1,
          rect.left - w * 0.15, rect.top + h * 0.5,
          rect.left + w / 2, rect.bottom);
      path.moveTo(rect.left + w / 2, rect.top + h * 0.25);
      path.cubicTo(rect.right - w * 0.15, rect.top - h * 0.1,
          rect.right + w * 0.15, rect.top + h * 0.5,
          rect.left + w / 2, rect.bottom);
      return path;
    }
    if (sp == 'speech_bubble') {
      return (Path()
            ..addRRect(
                RRect.fromRectAndRadius(rect, const Radius.circular(12)))
            ..moveTo(rect.left + rect.width * 0.2, rect.bottom)
            ..lineTo(rect.left + rect.width * 0.15, rect.bottom + 12)
            ..lineTo(rect.left + rect.width * 0.3, rect.bottom)
            ..close())
          as Path?;
    }
    if (sp == 'curve' || sp == 'dotted_line' || sp == 'blur' || sp == 'protractor' || sp == 'compass') return null;
    if (sp == 'free' && pts.length >= 3) {
      final path = Path();
      path.moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      path.close();
      return path;
    }
    return null; // line, arrow, ruler, plane — cannot fill
  }

  /// Fill the shape under [position] with [_selectedColor].
  void _fillAt(Offset position) {
    // Walk strokes topmost-first so we fill the topmost eligible shape.
    for (int i = _strokes.length - 1; i >= 0; i--) {
      final stroke = _strokes[i];
      if (stroke.fillColor != null) continue; // already filled
      final path = _buildShapePath(stroke);
      if (path == null) continue;
      if (path.contains(position)) {
        setState(() {
          stroke.fillColor = _selectedColor;
          _redoStrokes.clear();
        });
        _showMessage("Shape filled with color", true);
        return;
      }
    }
    _showMessage("No closed shape found at this point", false);
  }

  void _handleProtractorTap(Offset pos) {
    if (_protractorPhase == 0) {
      _protractorPoints.add(pos);
      _protractorPhase = 1;
      _showMessage("Protractor: tap second point (start arm)", true);
    } else if (_protractorPhase == 1) {
      _protractorPoints.add(pos);
      _protractorPhase = 2;
      _showMessage("Protractor: tap third point (end arm)", true);
    } else if (_protractorPhase == 2) {
      _protractorPoints.add(pos);
      final v = _protractorPoints[0];
      final a = _protractorPoints[1];
      final b = _protractorPoints[2];
      final angleA = atan2(a.dy - v.dy, a.dx - v.dx);
      final angleB = atan2(b.dy - v.dy, b.dx - v.dx);
      double deg = (angleB - angleA) * 180 / pi;
      if (deg < 0) deg += 360;
      _addStroke(DrawingStroke(
        points: [v, a, b],
        color: _selectedColor,
        width: _strokeWidth,
        shapeType: 'protractor',
        text: deg.toStringAsFixed(1),
      ));
      _expandCanvasForPoint(v);
      _expandCanvasForPoint(a);
      _expandCanvasForPoint(b);
      setState(() {
        _protractorPhase = 0;
        _protractorPoints.clear();
        _redoStrokes.clear();
      });
      _showMessage("Angle: ${deg.toStringAsFixed(1)}° — locked", true);
    }
  }

  /// Detects which crop handle [pos] is touching.
  String _detectCropHandle(Offset pos, Offset cs, Offset ce) {
    const double t = 18.0; // touch threshold
    final rect = Rect.fromPoints(cs, ce);
    final corners = {
      'tl': rect.topLeft, 'tr': rect.topRight,
      'bl': rect.bottomLeft, 'br': rect.bottomRight,
    };
    for (final e in corners.entries) {
      if ((e.value - pos).distance < t) return e.key;
    }
    // Edges
    const double et = 14.0; // edge threshold
    if ((pos.dx - rect.left).abs() < et &&
        pos.dy >= rect.top && pos.dy <= rect.bottom) return 'left';
    if ((pos.dx - rect.right).abs() < et &&
        pos.dy >= rect.top && pos.dy <= rect.bottom) return 'right';
    if ((pos.dy - rect.top).abs() < et &&
        pos.dx >= rect.left && pos.dx <= rect.right) return 'top';
    if ((pos.dy - rect.bottom).abs() < et &&
        pos.dx >= rect.left && pos.dx <= rect.right) return 'bottom';
    // Inside — move
    if (rect.contains(pos)) return 'move';
    return 'none';
  }

  /// Snaps [pos] to nearest grid intersection, shape vertex, or midpoint.
  Offset _snapPosition(Offset pos, {double threshold = 15}) {
    if (!_snapEnabled) return pos;
    Offset best = pos;
    double bestDist = threshold;

    // Snap to grid intersections
    const double gridStep = 20.0;
    final gx = (pos.dx / gridStep).round() * gridStep;
    final gy = (pos.dy / gridStep).round() * gridStep;
    final gridSnap = Offset(gx, gy);
    if ((gridSnap - pos).distance < bestDist) {
      bestDist = (gridSnap - pos).distance;
      best = gridSnap;
    }
    if (_isIsometricGrid) {
      // Isometric grid snap points
      final isoStep = 40.0;
      for (double ix = 0; ix <= 2; ix++) {
        for (double iy = 0; iy <= 2; iy++) {
          final sx = (pos.dx / isoStep).round() * isoStep + (ix - 1) * isoStep * 0.866;
          final sy = (pos.dy / isoStep).round() * isoStep + (iy - 1) * isoStep * 0.5;
          final p = Offset(sx, sy);
          final d = (p - pos).distance;
          if (d < bestDist) { bestDist = d; best = p; }
        }
      }
    }

    // Snap to shape vertices and midpoints
    for (var stroke in _strokes) {
      for (int i = 0; i < stroke.points.length; i++) {
        final d = (stroke.points[i] - pos).distance;
        if (d < bestDist) { bestDist = d; best = stroke.points[i]; }
        if (i > 0) {
          final mid = Offset(
            (stroke.points[i - 1].dx + stroke.points[i].dx) / 2,
            (stroke.points[i - 1].dy + stroke.points[i].dy) / 2,
          );
          final md = (mid - pos).distance;
          if (md < bestDist) { bestDist = md; best = mid; }
        }
      }
    }
    return best;
  }

  @override
  void initState() {
    super.initState();
    _currentBgBytes = widget.backgroundImageBytes;
  }

  void _showMessage(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isSuccess ? Colors.green : Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _applyCropAndZoom() {
    if (_cropStart == null || _cropEnd == null) return;

    try {
      final rect = Rect.fromPoints(_cropStart!, _cropEnd!);
      if (rect.width < 10 || rect.height < 10) {
        _showMessage("Crop area is too small!", false);
        return;
      }

      // Convert local coordinates from the dynamic canvas to perform precise crop
      final double canvasWidth = _canvasSize.width;
      final double canvasHeight = _canvasSize.height;

      // 1. Scale and shift all existing drawing strokes to "zoom in" on the cropped part!
      final double scaleX = canvasWidth / rect.width;
      final double scaleY = canvasHeight / rect.height;
      final double scale =
          scaleX < scaleY ? scaleX : scaleY; // Keep aspect ratio

      setState(() {
        for (var stroke in _strokes) {
          final List<Offset> zoomedPoints = [];
          for (var pt in stroke.points) {
            // Shift left and up, then scale
            final shiftedX = (pt.dx - rect.left) * scale;
            final shiftedY = (pt.dy - rect.top) * scale;
            zoomedPoints.add(Offset(shiftedX, shiftedY));
          }
          stroke.points.clear();
          stroke.points.addAll(zoomedPoints);
        }

        // 2. Crop and zoom the background image natively if present!
        if (_currentBgBytes != null) {
          final img.Image? srcImage = img.decodeImage(_currentBgBytes!);
          if (srcImage != null) {
            double scaleImageX = srcImage.width / canvasWidth;
            double scaleImageY = srcImage.height / canvasHeight;

            int x = (rect.left * scaleImageX).round();
            int y = (rect.top * scaleImageY).round();
            int w = (rect.width * scaleImageX).round();
            int h = (rect.height * scaleImageY).round();

            final img.Image cropped =
                img.copyCrop(srcImage, x: x, y: y, width: w, height: h);
            _currentBgBytes = Uint8List.fromList(img.encodePng(cropped));
          }
        }

        // Reset crop mode
        _isCropping = false;
        _cropStart = null;
        _cropEnd = null;
      });

      _showMessage("Cropped and zoomed successfully!", true);
    } catch (e) {
      _showMessage("Crop failed: $e", false);
    }
  }

  @override
  void dispose() {
    _canvasJoystickTimer?.cancel();
    for (var n in _textNotes) n.dispose();
    _nameController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  String _getColorName(Color color) {
    if (color == Colors.black) return "Black";
    if (color == Colors.blue.shade900) return "Deep Blue";
    if (color == Colors.teal.shade700) return "Teal";
    if (color == Colors.red.shade700) return "Crimson";
    if (color == Colors.purple.shade700) return "Purple";
    return "Custom";
  }

  void _showShapesDialog() {
    final List<Map<String, dynamic>> shapes = [
      {'icon': Icons.gesture_rounded, 'label': 'Freehand', 'type': 'free'},
      {'icon': Icons.horizontal_rule_rounded, 'label': 'Line', 'type': 'line'},
      {
        'icon': Icons.crop_square_rounded,
        'label': 'Rectangle',
        'type': 'rectangle'
      },
      {
        'icon': Icons.radio_button_unchecked_rounded,
        'label': 'Circle/Oval',
        'type': 'circle'
      },
      {
        'icon': Icons.change_history_rounded,
        'label': 'Triangle',
        'type': 'triangle'
      },
      {'icon': Icons.hexagon_rounded, 'label': 'Hexagon', 'type': 'polygon'},
      {
        'icon': Icons.arrow_right_alt_rounded,
        'label': 'Arrow',
        'type': 'arrow'
      },
      {
        'icon': Icons.crop_rotate_rounded,
        'label': 'Diamond',
        'type': 'diamond'
      },
      {
        'icon': Icons.view_agenda_rounded,
        'label': 'Parallelogram',
        'type': 'parallelogram'
      },
      {'icon': Icons.star_rounded, 'label': 'Star', 'type': 'star'},
      {'icon': Icons.favorite_rounded, 'label': 'Heart', 'type': 'heart'},
      {
        'icon': Icons.chat_bubble_rounded,
        'label': 'Speech',
        'type': 'speech_bubble'
      },
      {
        'icon': Icons.auto_fix_high_rounded,
        'label': 'Curve',
        'type': 'curve'
      },
      {
        'icon': Icons.more_horiz_rounded,
        'label': 'Dotted Line',
        'type': 'dotted_line'
      },
      {
        'icon': Icons.square_foot_rounded,
        'label': 'Protractor',
        'type': 'protractor'
      },
      {
        'icon': Icons.architecture_rounded,
        'label': 'Compass',
        'type': 'compass'
      },
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.category_rounded, color: Colors.indigo, size: 20),
            SizedBox(width: 8),
            Text("Select Shape to Draw",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        content: SizedBox(
          width: 260,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:
                  3, // Symmetrical 3x4 grid housing all 12 shapes perfectly!
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.0,
            ),
            itemCount: shapes.length,
            itemBuilder: (context, index) {
              final shape = shapes[index];
              final bool isSelected = _activeShape == shape['type'];
              return GestureDetector(
                onTap: () {
                  final type = shape['type'] as String;
                  if (type == 'arrow' || type == 'ruler') {
                    Navigator.pop(context);
                    _showUnitDialog(onSelected: (unit) {
                      setState(() {
                        _selectedUnit = unit;
                        _activeShape = type;
                        _isCropping = false;
                      });
                      _showMessage("${shape['label']} selected ($unit)", true);
                    });
                  } else {
                    setState(() {
                      _activeShape = type;
                      _isCropping = false;
                    });
                    _showMessage("${shape['label']} brush selected!", true);
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.indigo.withOpacity(0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            isSelected ? Colors.indigo : Colors.grey.shade200,
                        width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(shape['icon'] as IconData,
                          color: isSelected ? Colors.indigo : Colors.grey,
                          size: 24),
                      const SizedBox(height: 6),
                      Text(shape['label'] as String,
                          style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.indigo : Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showBrushSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Adjust Brush Size",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF263238))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dynamic circular brush tip preview example!
              Container(
                height: 50,
                alignment: Alignment.center,
                child: Container(
                  width: _strokeWidth,
                  height: _strokeWidth,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Stroke Width",
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                  Text("${_strokeWidth.toInt()}px",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.indigo)),
                ],
              ),
              Slider(
                value: _strokeWidth,
                min: 1.0,
                max: 15.0,
                activeColor: _selectedColor,
                onChanged: (val) {
                  setDialogState(() => _strokeWidth = val);
                  setState(
                      () => _strokeWidth = val); // Sync with main canvas state
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: StarlightTheme.primaryBlue)),
            ),
          ],
        ),
      ),
    );
  }

  void _showGlobeColorPicker() {
    final List<Color> advancedColors = [
      ..._colors,
      const Color(0xFFFEE2E2),
      const Color(0xFFFEF3C7),
      const Color(0xFFD1FAE5),
      const Color(0xFFDBEAFE),
      const Color(0xFFE0E7FF),
      const Color(0xFFF3E8FF),
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFF6366F1),
      const Color(0xFF8B5CF6),
      const Color(0xFFB91C1C),
      const Color(0xFFB45309),
      const Color(0xFF047857),
      const Color(0xFF1D4ED8),
      const Color(0xFF4338CA),
      const Color(0xFF6D28D9),
      const Color(0xFF4F46E5),
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Select Custom Color",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: SizedBox(
          width: 280,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: advancedColors.length,
            itemBuilder: (context, index) {
              final color = advancedColors[index];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = color;
                    _isColorPanelOpen = false;
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showUnitDialog({required void Function(String unit) onSelected}) {
    const units = ['mm', 'cm', 'm', 'km', 'inches', 'feet', 'yards'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Select Unit",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: units.map((unit) {
            final isSelected = _selectedUnit == unit;
            return ListTile(
              dense: true,
              title: Text(unit,
                  style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal)),
              trailing: isSelected
                  ? const Icon(Icons.check_circle_rounded,
                      color: Colors.indigo, size: 18)
                  : null,
              onTap: () {
                onSelected(unit);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showDimensionDialog() {
    showDialog(
      context: context,
      builder: (ctx1) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Dimension Type",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.horizontal_rule, color: Colors.indigo),
              title: const Text("1D - Line",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle:
                  const Text("Single length", style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx1);
                _showLengthInputDialog(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.crop_square, color: Colors.indigo),
              title: const Text("2D - Rectangle",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle:
                  const Text("Width x Height", style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx1);
                _showLengthInputDialog(2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.view_in_ar, color: Colors.indigo),
              title: const Text("3D - Cuboid",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: const Text("Width x Height x Depth",
                  style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx1);
                _showLengthInputDialog(3);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLengthInputDialog(int dimCount) {
    final axisNames = dimCount == 1
        ? ['X']
        : dimCount == 2
            ? ['X', 'Y']
            : ['X', 'Y', 'Z'];
    final negControllers =
        List.generate(dimCount, (_) => TextEditingController(text: '50'));
    final posControllers =
        List.generate(dimCount, (_) => TextEditingController(text: '80'));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$dimCount""D Axis Lengths ($_selectedUnit)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < dimCount; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text(axisNames[i],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: negControllers[i],
                        decoration: const InputDecoration(
                          labelText: 'Negative',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: posControllers[i],
                        decoration: const InputDecoration(
                          labelText: 'Positive',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final negValues = negControllers
                  .map((c) => double.tryParse(c.text) ?? 0)
                  .toList();
              final posValues = posControllers
                  .map((c) => double.tryParse(c.text) ?? 0)
                  .toList();
              if (negValues.any((v) => v < 0) || posValues.any((v) => v < 0)) {
                return;
              }
              Navigator.pop(ctx);
              // Store as: dimCount|negX|posX|negY|posY|negZ|posZ
              final allValues = [dimCount.toDouble()];
              for (int i = 0; i < dimCount; i++) {
                allValues.add(negValues[i]);
                allValues.add(posValues[i]);
              }
              setState(() {
                _planeValues = allValues;
                _activeShape = 'plane';
                _isCropping = false;
              });
              _showMessage(
                  "Tap canvas to place $dimCount" "D axis lines", true);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            child: const Text("Draw"),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog() {
    final List<Map<String, dynamic>> themes = [
      {
        'name': 'white',
        'label': 'White Canvas',
        'color': Colors.white,
        'border': Colors.grey.shade400
      },
      {
        'name': 'blueprint',
        'label': 'CAD Blueprint',
        'color': const Color(0xFF0D47A1),
        'border': Colors.blue.shade900
      },
      {
        'name': 'grid_paper',
        'label': 'Graph Draft',
        'color': const Color(0xFFFAF8F5),
        'border': Colors.orange.withOpacity(0.3)
      },
      {
        'name': 'chalkboard',
        'label': 'Black Chalkboard',
        'color': const Color(0xFF1E262B),
        'border': Colors.black
      },
      {
        'name': 'dark',
        'label': 'Dark Mode',
        'color': const Color(0xFF2D2D2D),
        'border': Colors.grey.shade800
      },
      {
        'name': 'sepia',
        'label': 'Vintage Sepia',
        'color': const Color(0xFFF5E6C8),
        'border': Colors.brown.shade300
      },
      {
        'name': 'mint',
        'label': 'Fresh Mint',
        'color': const Color(0xFFE8F5E9),
        'border': Colors.green.shade300
      },
      {
        'name': 'sky',
        'label': 'Sky Blue',
        'color': const Color(0xFFE3F2FD),
        'border': Colors.blue.shade300
      },
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Select Canvas Theme",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        content: SizedBox(
          width: 260,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: themes.length,
            itemBuilder: (context, index) {
              final theme = themes[index];
              final bool isSelected = _canvasTheme == theme['name'];
              return ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: theme['color'] as Color,
                    border:
                        Border.all(color: theme['border'] as Color, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                title: Text(theme['label'] as String,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal)),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded,
                        color: Colors.indigo, size: 18)
                    : null,
                onTap: () {
                  setState(() {
                    _canvasTheme = theme['name'] as String;
                  });
                  _showMessage("${theme['label']} theme loaded", true);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAdvancedToolsDialog() {
    final List<Map<String, dynamic>> tools = [
      {
        'icon': Icons.category_rounded,
        'color': Colors.indigo,
        'label': 'Shapes Catalog',
        'action': () {
          _showShapesDialog();
        }
      },
      {
        'icon': Icons.cleaning_services_rounded,
        'color': Colors.redAccent,
        'label': 'Vector Eraser',
        'action': () {
          setState(() {
            _activeShape = 'eraser';
            _isCropping = false;
          });
          _showMessage("Vector Stroke Eraser Active", true);
        }
      },
      {
        'icon': Icons.architecture_rounded,
        'color': Colors.cyan,
        'label': 'Dimension Ruler',
        'action': () {
          setState(() {
            _activeShape = 'ruler';
            _isCropping = false;
          });
          _showMessage("Dimension Ruler Selected (Drag to measure)", true);
        }
      },
      {
        'icon': Icons.sticky_note_2_rounded,
        'color': Colors.teal,
        'label': 'Text Note',
        'action': () {
          setState(() {
            _activeShape = 'text';
            _isCropping = false;
          });
          _showMessage("Text Label Tool Active (Tap canvas to place)", true);
        }
      },
      {
        'icon': Icons.palette_rounded,
        'color': Colors.brown,
        'label': 'Canvas Themes',
        'action': () {
          _showThemeDialog();
        }
      },
      {
        'icon': Icons.edit_rounded,
        'color': Colors.black,
        'label': 'Fine Pencil',
        'action': () {
          setState(() {
            _selectedColor = Colors.black;
            _strokeWidth = 1.5;
            _isCropping = false;
            _activeShape = 'free';
          });
          _showMessage("Fine Pencil Selected", true);
        }
      },
      {
        'icon': Icons.brush_rounded,
        'color': Colors.purple,
        'label': 'Thick Marker',
        'action': () {
          setState(() {
            _selectedColor = Colors.purple;
            _strokeWidth = 8.0;
            _isCropping = false;
            _activeShape = 'free';
          });
          _showMessage("Thick Marker Selected", true);
        }
      },
      {
        'icon': Icons.highlight_rounded,
        'color': Colors.amber,
        'label': 'Highlighter',
        'action': () {
          setState(() {
            _selectedColor = Colors.amber.withOpacity(0.3);
            _strokeWidth = 12.0;
            _isCropping = false;
            _activeShape = 'free';
          });
          _showMessage("Highlighter Tool Activated", true);
        }
      },
      {
        'icon': Icons.threed_rotation_rounded,
        'color': Colors.blueGrey,
        'label': 'Dimension Plane',
        'action': () {
          _showDimensionDialog();
        }
      },
      {
        'icon': Icons.format_paint_rounded,
        'color': Colors.orange,
        'label': 'Fill Paint',
        'action': () {
          setState(() {
            _activeShape = 'fill';
            _isCropping = false;
          });
          _showMessage("Fill Tool Active (Tap a closed shape to fill it)", true);
        }
      },
      {
        'icon': Icons.history_edu_rounded,
        'color': Colors.indigo,
        'label': 'Fountain Pen',
        'action': () {
          setState(() {
            _selectedColor = Colors.indigo;
            _strokeWidth = 4.0;
            _isCropping = false;
            _activeShape = 'free';
          });
          _showMessage("Fountain Pen Selected", true);
        }
      },
      {
        'icon': Icons.create_rounded,
        'color': Colors.deepOrange,
        'label': 'Calligraphy',
        'action': () {
          setState(() {
            _selectedColor = Colors.deepOrange;
            _strokeWidth = 5.5;
            _isCropping = false;
            _activeShape = 'free';
          });
          _showMessage("Calligraphy Selected", true);
        }
      },
      {
        'icon': Icons.bolt_rounded,
        'color': Colors.limeAccent.shade700,
        'label': 'Laser Pointer',
        'action': () {
          setState(() {
            _selectedColor = Colors.limeAccent.shade700;
            _strokeWidth = 6.0;
            _isCropping = false;
            _activeShape = 'free';
          });
          _showMessage("Laser Pointer Selected", true);
        }
      },
      {
        'icon': Icons.border_color_rounded,
        'color': Colors.green,
        'label': 'Chalk/Crayon',
        'action': () {
          setState(() {
            _selectedColor = Colors.green;
            _strokeWidth = 6.0;
            _isCropping = false;
            _activeShape = 'free';
          });
          _showMessage("Chalk/Crayon Selected", true);
        }
      },
      {
        'icon': Icons.grain_rounded,
        'color': Colors.pinkAccent,
        'label': 'Splash Spray',
        'action': () {
          setState(() {
            _selectedColor = Colors.pinkAccent.withOpacity(0.4);
            _strokeWidth = 14.0;
            _isCropping = false;
            _activeShape = 'free';
          });
          _showMessage("Spray Tool Selected", true);
        }
      },
      {
        'icon': Icons.blur_on_rounded,
        'color': Colors.black,
        'label': 'Blur / Redact',
        'action': () {
          setState(() {
            _activeShape = 'blur';
            _selectedColor = Colors.black;
            _strokeWidth = 20.0;
            _isCropping = false;
          });
          _showMessage("Blur/Redact Brush Active (drag to mask)", true);
        }
      },
      {
        'icon': _showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded,
        'color': _showGrid ? Colors.blueAccent : Colors.grey,
        'label': _showGrid ? 'Disable Grid' : 'Enable Grid',
        'action': () {
          setState(() => _showGrid = !_showGrid);
          _showMessage(
              _showGrid ? "Grid Helper Enabled" : "Grid Helper Disabled", true);
        }
      },
      {
        'icon': Icons.layers_rounded,
        'color': _isIsometricGrid ? Colors.orange : Colors.grey,
        'label': _isIsometricGrid ? 'Disable Iso Grid' : 'Isometric Grid',
        'action': () {
          setState(() {
            _isIsometricGrid = !_isIsometricGrid;
            if (_isIsometricGrid) _showGrid = true;
          });
          _showMessage(_isIsometricGrid
              ? "Isometric 30°/60° Grid Enabled"
              : "Isometric Grid Disabled", true);
        }
      },
      {
        'icon': Icons.grain_rounded,
        'color': _snapEnabled ? Colors.orange : Colors.grey,
        'label': _snapEnabled ? 'Disable Snap' : 'Snap to Grid',
        'action': () {
          setState(() => _snapEnabled = !_snapEnabled);
          _showMessage(
              _snapEnabled ? "Snap-to-Grid Enabled" : "Snap-to-Grid Disabled",
              true);
        }
      },
      {
        'icon': Icons.delete_forever_rounded,
        'color': Colors.red,
        'label': 'Reset Canvas',
        'action': () {
          setState(() {
            _strokes.clear();
            _redoStrokes.clear();
            _textNotes.clear();
            _undoNotes.clear();
            _selectedNoteIndex = null;
            _protractorPhase = 0;
            _protractorPoints.clear();
            _compassPhase = 0;
            _compassCenter = null;
            _compassRadius = 0;
            _compassAngle = 0;
            _cropStart = null;
            _cropEnd = null;
            _isCropping = false;
          });
          _showMessage("Canvas Cleared!", true);
        }
      },
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.construction_rounded, color: Colors.indigo, size: 20),
            SizedBox(width: 8),
            Text("Advanced Drawing Tools",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        content: SizedBox(
          width: 260,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:
                  4, // Symmetrical 4x4 grid housing all 16 advanced tools!
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.0,
            ),
            itemCount: tools.length,
            itemBuilder: (context, index) {
              final tool = tools[index];
              return Tooltip(
                message: tool['label'],
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // Close dialog
                    tool['action']();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.grey.shade200, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(tool['icon'] as IconData,
                        color: tool['color'] as Color, size: 24),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _saveDesign() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a design name")),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
            child: CircularProgressIndicator(color: Colors.indigo)),
      );

      final RenderRepaintBoundary boundary = _boundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Failed to export image");
      Uint8List exportedBytes = byteData.buffer.asUint8List();

      double left = 0;
      double top = 0;
      double width = _canvasSize.width;
      double height = _canvasSize.height;
      bool shouldCrop = false;

      if (_cropStart != null && _cropEnd != null) {
        left = min(_cropStart!.dx, _cropEnd!.dx);
        top = min(_cropStart!.dy, _cropEnd!.dy);
        width = (_cropStart!.dx - _cropEnd!.dx).abs();
        height = (_cropStart!.dy - _cropEnd!.dy).abs();
        shouldCrop = true;
      } else {
        try {
          final RenderBox? ivBox = _boundaryKey.currentContext
              ?.findAncestorRenderObjectOfType<RenderBox>();
          if (ivBox != null) {
            final viewportSize = ivBox.size;
            final matrix = _transformationController.value;
            final double scale = matrix.getMaxScaleOnAxis();
            final double translationX = matrix.entry(0, 3);
            final double translationY = matrix.entry(1, 3);

            left = -translationX / scale;
            top = -translationY / scale;
            width = viewportSize.width / scale;
            height = viewportSize.height / scale;
            shouldCrop = true;
          }
        } catch (_) {
          shouldCrop = false;
        }
      }

      if (shouldCrop) {
        final img.Image? srcImage = img.decodeImage(exportedBytes);
        if (srcImage != null) {
          int x = left.round().clamp(0, srcImage.width - 1);
          int y = top.round().clamp(0, srcImage.height - 1);
          int w = width.round().clamp(10, srcImage.width - x);
          int h = height.round().clamp(10, srcImage.height - y);

          final img.Image cropped =
              img.copyCrop(srcImage, x: x, y: y, width: w, height: h);
          exportedBytes = Uint8List.fromList(img.encodePng(cropped));
        }
      }

      if (mounted) {
        Navigator.pop(context); // Pop loading indicator
        Navigator.pop(context, {
          'name': _nameController.text.trim(),
          'bytes': exportedBytes,
          'color': _selectedColor,
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loading indicator if failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error saving design: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  final List<Color> _colors = [
    Colors.black,
    Colors.grey,
    Colors.red.shade900,
    Colors.red,
    Colors.pink,
    Colors.purple.shade900,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo.shade900,
    Colors.indigo,
    Colors.blue.shade900,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal.shade900,
    Colors.teal,
    Colors.green.shade900,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        title: const Text("2D DESIGN CANVAS",
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1)),
        backgroundColor: Colors.white,
        foregroundColor: StarlightTheme.primaryBlue,
        elevation: 0.5,
        centerTitle: false,
        actions: [
          // If we are actively cropping, show clear Cancel and Apply buttons!
          if (_isCropping) ...[
            IconButton(
              icon: const Icon(Icons.cancel_outlined,
                  color: Colors.redAccent, size: 22),
              onPressed: () {
                setState(() {
                  _isCropping = false;
                  _cropStart = null;
                  _cropEnd = null;
                });
                _showMessage("Crop mode cancelled.", false);
              },
              tooltip: "Cancel Crop",
            ),
            IconButton(
              icon: const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 22),
              onPressed: _applyCropAndZoom,
              tooltip: "Apply Crop",
            ),
          ],
          IconButton(
            icon:
                const Icon(Icons.undo_rounded, color: Colors.indigo, size: 20),
            onPressed: _undo,
            tooltip: "Undo Stroke",
          ),
          IconButton(
            icon:
                const Icon(Icons.redo_rounded, color: Colors.indigo, size: 20),
            onPressed: _redo,
            tooltip: "Redo Stroke",
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey, size: 20),
            onPressed: () => setState(() {
              _strokes.clear();
              _redoStrokes.clear();
              _textNotes.clear();
              _undoNotes.clear();
              _selectedNoteIndex = null;
            }),
            tooltip: "Reset Canvas",
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: StarlightTheme.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _saveDesign,
              icon: const Icon(Icons.cloud_upload_rounded, size: 14),
              label: const Text("SAVE",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Compact Horizontal Menu Bar (scrollable to avoid overflow on any screen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.01),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // 1. Compact Title input
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_note_rounded,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 2),
                      SizedBox(
                        width: 75,
                        child: TextField(
                          controller: _nameController,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF263238)),
                          decoration: const InputDecoration(
                            hintText: "Title...",
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 2, vertical: 4),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _verticalDivider(),

                  // 2. Colors trigger
                  InkWell(
                    onTap: () =>
                        setState(() => _isColorPanelOpen = !_isColorPanelOpen),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                                color: _selectedColor,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.grey.shade300)),
                          ),
                          const SizedBox(width: 6),
                          const Text("Colors",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF263238))),
                          Icon(
                            _isColorPanelOpen
                                ? Icons.arrow_drop_up_rounded
                                : Icons.arrow_drop_down_rounded,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                  _verticalDivider(),

                  // 3. Size trigger
                  InkWell(
                    onTap: _showBrushSizeDialog,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.line_weight_rounded,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text("${_strokeWidth.toInt()}px",
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          const Icon(Icons.arrow_drop_down_rounded,
                              size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  _verticalDivider(),

                  // 4. Crop trigger
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isCropping = true;
                        if (_cropStart == null) {
                          _cropStart = const Offset(100, 100);
                          _cropEnd = const Offset(700, 900);
                        }
                      });
                      _showMessage("Drag handles to adjust crop box", false);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.crop_rounded,
                              size: 14, color: Colors.indigo),
                          const SizedBox(width: 4),
                          Text("Crop",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Colors.indigo)),
                        ],
                      ),
                    ),
                  ),
                  _verticalDivider(),

                  // 5. Advanced Tools trigger (Opens dialog box filled with various drawing tools!)
                  InkWell(
                    onTap: _showAdvancedToolsDialog,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.construction_rounded,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          const Text("Tools",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: Color(0xFF263238))),
                        ],
                      ),
                    ),
                  ),
                  // 6. Pan mode indicator
                  if (_isPanMode) ...[
                    _verticalDivider(),
                    InkWell(
                      onTap: () => setState(() => _isPanMode = false),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pan_tool_rounded,
                                size: 14, color: Colors.green.shade600),
                            const SizedBox(width: 4),
                            Text("Pan ON",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Colors.green.shade600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  // 7. Deactivate active tool button (appears when any special tool or pan mode is active)
                  if (_activeShape != 'free' || _isCropping || _isPanMode) ...[
                    _verticalDivider(),
                    InkWell(
                      onTap: () => setState(() {
                        _activeShape = 'free';
                        _isCropping = false;
                        _isPanMode = false;
                        if (_cropStart != null) {
                          _cropStart = null;
                          _cropEnd = null;
                        }
                      }),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pan_tool_rounded,
                                size: 14, color: Colors.red.shade400),
                            const SizedBox(width: 4),
                            Text("Pointer",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Colors.red.shade400)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expandable Horizontal Colors Panel (atleast 24 completely different colors + globe)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _isColorPanelOpen ? 52 : 0,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: _isColorPanelOpen
                ? ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    children: [
                      ..._colors.map((color) {
                        final isSelected = color == _selectedColor;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = color),
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.indigo
                                    : Colors.grey.shade300,
                                width: isSelected ? 2.5 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                          color: color.withOpacity(0.3),
                                          blurRadius: 4,
                                          spreadRadius: 1)
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }),

                      // The Globe Custom Color Picker Button at the end of the scrollable list!
                      GestureDetector(
                        onTap: _showGlobeColorPicker,
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Icon(Icons.public_rounded,
                              size: 18, color: Colors.indigo),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          // Full-Screen interactive custom drawing canvas (unlimited scrollable vertically and horizontally!)
          Expanded(
            child: Stack(
              children: [
                Container(
                  color: Colors.white,
                  child: ClipRRect(
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      constrained: false, // 🏛️ ALLOWS UNBOUNDED CANVAS SIZE!
                      minScale: 0.5,
                      maxScale: 3.0,
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: Container(
                          width:
                              _canvasSize.width, // Dynamically expanding canvas
                          height: _canvasSize.height,
                          color: canvasBackgroundColor,
                          child: GestureDetector(
                            onTapUp: (details) {
                                    final RenderBox canvasBox = _boundaryKey
                                        .currentContext!
                                        .findRenderObject() as RenderBox;
                                    final canvasPos = _snapPosition(canvasBox
                                        .globalToLocal(
                                            details.globalPosition));
                                    if (_activeShape == 'fill') {
                                      _fillAt(canvasPos);
                                    } else if (_activeShape == 'protractor') {
                                      _handleProtractorTap(canvasPos);
                                    } else if (_activeShape == 'compass') {
                                      if (_compassPhase == 0) {
                                        setState(() {
                                          _compassCenter = canvasPos;
                                          _compassPhase = 1;
                                        });
                                        _showMessage(
                                            "Compass: now drag to set radius and angle",
                                            true);
                                      }
                                    } else {
                                      setState(() {
                                        _selectedNoteIndex = null;
                                        for (var n in _textNotes)
                                          n.isExpanded = false;
                                      });
                                    }
                                  },
                            onDoubleTap: () =>
                                setState(() => _isPanMode = !_isPanMode),
                            onPanStart: _isPanMode
                                ? null
                                : (details) {
                                    final RenderBox canvasBox = _boundaryKey
                                        .currentContext!
                                        .findRenderObject() as RenderBox;
                                    final rawPos = canvasBox
                                        .globalToLocal(details.globalPosition);
                                    final canvasPos = (_activeShape == 'free' || _activeShape == 'blur')
                                        ? rawPos
                                        : _snapPosition(rawPos);

                                    if (_activeShape != 'text' &&
                                        _activeShape != 'eraser' &&
                                        _selectedNoteIndex != null) {
                                      setState(() => _selectedNoteIndex = null);
                                    }
                                     if (_isCropping) {
                                       if (_cropStart != null && _cropEnd != null) {
                                         _cropHandle = _detectCropHandle(
                                             rawPos, _cropStart!, _cropEnd!);
                                         if (_cropHandle != 'none') {
                                           _cropDragRawStart = rawPos;
                                           _cropMoveOriginStart = _cropStart;
                                           _cropMoveOriginEnd = _cropEnd;
                                         }
                                       } else {
                                         setState(() {
                                           _cropStart = canvasPos;
                                           _cropEnd = canvasPos;
                                         });
                                       }
                                     } else if (_activeShape == 'eraser') {
                                      _eraseStrokeAt(canvasPos);
                                    } else if (_activeShape == 'text') {
                                      _addTextLabel(canvasPos);
                                    } else if (_activeShape == 'plane') {
                                      _addPlane(canvasPos);
                                    } else if (_activeShape == 'curve') {
                                      if ((_curvePhase == 1 || _curvePhase == 2) &&
                                          (_curveStrokeIndex < 0 || _curveStrokeIndex >= _strokes.length)) {
                                        _curvePhase = 0;
                                        _curveStrokeIndex = -1;
                                      }
                                      if (_curvePhase >= 3) {
                                        _curvePhase = 0;
                                        _curveStrokeIndex = -1;
                                      }
                                      if (_curvePhase == 0) {
                                        setState(() {
                                          _shapeStart = canvasPos;
                                          _shapeEnd = canvasPos;
                                        });
                                      } else if (_curvePhase == 1 || _curvePhase == 2) {
                                        setState(() {
                                          _curveDragPreview = canvasPos;
                                        });
                                      }
                                    } else if (_activeShape == 'compass' && _compassPhase == 1) {
                                      setState(() {
                                        _compassRadius = (canvasPos - _compassCenter!).distance;
                                        _compassAngle = atan2(canvasPos.dy - _compassCenter!.dy, canvasPos.dx - _compassCenter!.dx);
                                      });
                                    } else if (_activeShape == 'blur') {
                                      _addStroke(DrawingStroke(
                                        points: [canvasPos],
                                        color: _selectedColor,
                                        width: _strokeWidth,
                                        shapeType: 'blur',
                                      ));
                                    } else if (_activeShape != 'free' && _activeShape != 'fill' && _activeShape != 'protractor') {
                                      // Start drawing a shape
                                      setState(() {
                                        _shapeStart = canvasPos;
                                        _shapeEnd = canvasPos;
                                      });
                                    } else if (_activeShape == 'free') {
                                      _addStroke(DrawingStroke(
                                        points: [canvasPos],
                                        color: _selectedColor,
                                        width: _strokeWidth,
                                        shapeType: 'free',
                                      ));
                                    }
                                  },
                            onPanUpdate: _isPanMode
                                ? null
                                : (details) {
                                    final RenderBox canvasBox = _boundaryKey
                                        .currentContext!
                                        .findRenderObject() as RenderBox;
                                    final rawPos = canvasBox
                                        .globalToLocal(details.globalPosition);
                                    final canvasPos = (_activeShape == 'free' || _activeShape == 'blur')
                                        ? rawPos
                                        : _snapPosition(rawPos);

                                     if (_isCropping && _cropStart != null && _cropEnd != null) {
                                       setState(() {
                                         final s = _cropStart!;
                                         final e = _cropEnd!;
                                         final cp = rawPos;

                                         double left = s.dx < e.dx ? s.dx : e.dx;
                                         double right = s.dx > e.dx ? s.dx : e.dx;
                                         double top = s.dy < e.dy ? s.dy : e.dy;
                                         double bottom = s.dy > e.dy ? s.dy : e.dy;

                                         switch (_cropHandle) {
                                           case 'tl':
                                             left = cp.dx;
                                             top = cp.dy;
                                             break;
                                           case 'tr':
                                             right = cp.dx;
                                             top = cp.dy;
                                             break;
                                           case 'bl':
                                             left = cp.dx;
                                             bottom = cp.dy;
                                             break;
                                           case 'br':
                                             right = cp.dx;
                                             bottom = cp.dy;
                                             break;
                                           case 'top':
                                             top = cp.dy;
                                             break;
                                           case 'bottom':
                                             bottom = cp.dy;
                                             break;
                                           case 'left':
                                             left = cp.dx;
                                             break;
                                           case 'right':
                                             right = cp.dx;
                                             break;
                                           case 'move':
                                             if (_cropDragRawStart != null && _cropMoveOriginStart != null && _cropMoveOriginEnd != null) {
                                               final delta = rawPos - _cropDragRawStart!;
                                               left = _cropMoveOriginStart!.dx + delta.dx;
                                               right = _cropMoveOriginEnd!.dx + delta.dx;
                                               top = _cropMoveOriginStart!.dy + delta.dy;
                                               bottom = _cropMoveOriginEnd!.dy + delta.dy;
                                             }
                                             break;
                                           default:
                                             break;
                                         }
                                         _cropStart = Offset(left, top);
                                         _cropEnd = Offset(right, bottom);
                                       });
                                     } else if (_activeShape == 'eraser') {
                                      _eraseStrokeAt(canvasPos);
                                    } else if (_activeShape == 'text') {
                                      // No drag update needed for text placement
                                    } else if (_activeShape == 'plane') {
                                      // No drag update needed for plane placement
                                    } else if (_activeShape == 'curve') {
                                      if (_curvePhase == 0) {
                                        setState(() {
                                          _shapeEnd = canvasPos;
                                        });
                                      } else if (_curvePhase == 1 ||
                                          _curvePhase == 2) {
                                        setState(() {
                                          _curveDragPreview = canvasPos;
                                        });
                                      }
                                    } else if (_activeShape == 'compass' && _compassPhase == 1 && _compassCenter != null) {
                                      setState(() {
                                        _compassRadius = (canvasPos - _compassCenter!).distance;
                                        _compassAngle = atan2(canvasPos.dy - _compassCenter!.dy, canvasPos.dx - _compassCenter!.dx);
                                      });
                                    } else if (_activeShape == 'blur') {
                                      setState(() {
                                        if (_strokes.isNotEmpty && _strokes.last.activeShape == 'blur') {
                                          _strokes.last.points.add(canvasPos);
                                        }
                                      });
                                    } else if (_activeShape != 'free' && _activeShape != 'fill' && _activeShape != 'protractor') {
                                      // Dragging updates the shape preview
                                      setState(() {
                                        _shapeEnd = canvasPos;
                                      });
                                    } else if (_activeShape == 'free') {
                                      setState(() {
                                        if (_strokes.isNotEmpty) {
                                          _strokes.last.points.add(canvasPos);
                                        }
                                      });
                                    }
                                  },
                            onPanEnd: _isPanMode
                                ? null
                                : (details) {
                                    _cropHandle = 'none';
                                    _cropDragRawStart = null;
                                    _cropMoveOriginStart = null;
                                    _cropMoveOriginEnd = null;
                                    if (_activeShape == 'curve') {
                                      // Reset stale curve state
                                      if ((_curvePhase == 1 || _curvePhase == 2) &&
                                          (_curveStrokeIndex < 0 || _curveStrokeIndex >= _strokes.length)) {
                                        _curvePhase = 0;
                                        _curveStrokeIndex = -1;
                                      }
                                      if (_curvePhase == 0 &&
                                          _shapeStart != null &&
                                          _shapeEnd != null) {
                                        _addStroke(DrawingStroke(
                                          points: [_shapeStart!, _shapeEnd!],
                                          color: _selectedColor,
                                          width: _strokeWidth,
                                          shapeType: 'curve',
                                        ));
                                        setState(() {
                                          _curveStrokeIndex =
                                              _strokes.length - 1;
                                          _curvePhase = 1;
                                          _shapeStart = null;
                                          _shapeEnd = null;
                                          _curveDragPreview = null;
                                        });
                                        _showMessage(
                                            "Curve: now drag to add first bend",
                                            true);
                                      } else if (_curvePhase == 1 &&
                                          _curveStrokeIndex >= 0 &&
                                          _curveDragPreview != null) {
                                        setState(() {
                                          final stroke =
                                              _strokes[_curveStrokeIndex];
                                          stroke.points
                                            ..clear()
                                            ..addAll([
                                              stroke.points[0],
                                              _curveDragPreview!,
                                              stroke.points[1],
                                            ]);
                                          _curvePhase = 2;
                                          _curveDragPreview = null;
                                        });
                                        _showMessage(
                                            "Curve: now drag to add second bend",
                                            true);
                                      } else if (_curvePhase == 2 &&
                                          _curveStrokeIndex >= 0 &&
                                          _curveDragPreview != null) {
                                        setState(() {
                                          final stroke =
                                              _strokes[_curveStrokeIndex];
                                          stroke.points.addAll([
                                            _curveDragPreview!,
                                            stroke.points.removeLast(),
                                          ]);
                                          // Now: [P0, P1, drag, P3_last]
                                          // P2 = drag, P3 = former last
                                          _curvePhase = 3;
                                          _curveStrokeIndex = -1;
                                          _curveDragPreview = null;
                                        });
                                        _showMessage("Curve locked!", true);
                                      } else {
                                        setState(() {
                                          _curvePhase = 0;
                                          _curveStrokeIndex = -1;
                                          _curveDragPreview = null;
                                          _shapeStart = null;
                                          _shapeEnd = null;
                                        });
                                      }
                                    } else if (_activeShape == 'compass' &&
                                        _compassPhase == 1 &&
                                        _compassCenter != null) {
                                      _addStroke(DrawingStroke(
                                        points: [_compassCenter!],
                                        color: _selectedColor,
                                        width: _strokeWidth,
                                        shapeType: 'compass',
                                        text:
                                            '${_compassRadius.toStringAsFixed(1)}|${_compassAngle.toStringAsFixed(3)}',
                                      ));
                                      _expandCanvasForPoint(Offset(
                                        _compassCenter!.dx + _compassRadius,
                                        _compassCenter!.dy + _compassRadius,
                                      ));
                                      _expandCanvasForPoint(Offset(
                                        _compassCenter!.dx - _compassRadius,
                                        _compassCenter!.dy - _compassRadius,
                                      ));
                                      setState(() {
                                        _compassPhase = 0;
                                        _compassCenter = null;
                                        _compassRadius = 0;
                                        _compassAngle = 0;
                                      });
                                      _showMessage("Compass arc locked!", true);
                                    } else if (_activeShape != 'free' &&
                                        _activeShape != 'eraser' &&
                                        _activeShape != 'text' &&
                                        _activeShape != 'plane' &&
                                        _activeShape != 'fill' &&
                                        _activeShape != 'blur' &&
                                        _activeShape != 'protractor' &&
                                        _activeShape != 'compass' &&
                                        _shapeStart != null &&
                                        _shapeEnd != null) {
                                      final unitText =
                                          (_activeShape == 'ruler' ||
                                                  _activeShape == 'arrow')
                                              ? _selectedUnit
                                              : null;
                                      _addStroke(DrawingStroke(
                                        points: [_shapeStart!, _shapeEnd!],
                                        color: _selectedColor,
                                        width: _strokeWidth,
                                        shapeType: _activeShape,
                                        text: unitText,
                                      ));
                                      setState(() {
                                        _shapeStart = null;
                                        _shapeEnd = null;
                                      });
                                    }
                                  },
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (_currentBgBytes != null)
                                  Positioned.fill(
                                    child: Image.memory(
                                      _currentBgBytes!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                if (_showGrid)
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: GridBackgroundPainter(
                                          isIsometric: _isIsometricGrid,
                                          lineColor: gridLineColor),
                                      size: _canvasSize,
                                    ),
                                  ),
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: DrawingPainter(strokes: _strokes),
                                    size: _canvasSize,
                                  ),
                                ),
                                  // Flexible Cropping Overlay
                                if (_cropStart != null &&
                                    _cropEnd != null)
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: CropOverlayPainter(
                                        start: _cropStart!,
                                        end: _cropEnd!,
                                        showHandles: true,
                                      ),
                                      size: _canvasSize,
                                    ),
                                  ),
                                // Flexible Shape Drawing Live Preview Overlay
                                if (_activeShape != 'free' &&
                                    _shapeStart != null &&
                                    _shapeEnd != null)
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: ShapePreviewPainter(
                                        start: _shapeStart!,
                                        end: _shapeEnd!,
                                        shapeType: _activeShape,
                                        color: _selectedColor,
                                        width: _strokeWidth,
                                      ),
                                    ),
                                  ),
                                // Compass drag preview overlay
                                if (_activeShape == 'compass' &&
                                    _compassPhase == 1 &&
                                    _compassCenter != null &&
                                    _compassRadius > 0)
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: CompassPreviewPainter(
                                        center: _compassCenter!,
                                        radius: _compassRadius,
                                        angle: _compassAngle,
                                        color: _selectedColor,
                                        width: _strokeWidth,
                                      ),
                                      size: _canvasSize,
                                    ),
                                  ),
                                // Curve bend preview overlay
                                if (_activeShape == 'curve' &&
                                    _curvePhase >= 1 &&
                                    _curvePhase <= 2 &&
                                    _curveStrokeIndex >= 0 &&
                                    _curveDragPreview != null &&
                                    _strokes.length > _curveStrokeIndex)
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: CurvePreviewPainter(
                                        fixedPoints: _strokes[_curveStrokeIndex]
                                            .points,
                                        dragPreview: _curveDragPreview!,
                                        color: _selectedColor,
                                        width: _strokeWidth,
                                      ),
                                      size: _canvasSize,
                                    ),
                                  ),
                                // Interactive Text Notes overlay
                                ..._textNotes.asMap().entries.map((e) =>
                                    _buildTextNoteWidget(e.value, e.key)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Canvas joystick overlay (bottom-right)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: _buildCanvasJoystick(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextNoteWidget(_TextNote note, int index) {
    final isSelected = _selectedNoteIndex == index;
    return Positioned(
      left: note.position.dx,
      top: note.position.dy,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationZ(note.rotation),
        child: note.isExpanded
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: note.width,
                        height: note.height * 1.8,
                        child: TextField(
                          controller: note.controller,
                          autofocus: true,
                          style: TextStyle(
                              fontSize: note.fontSize,
                              color: note.color,
                              fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.indigo, width: 1.5)),
                            focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.indigo, width: 1.5)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 6),
                          ),
                          onChanged: (_) => note.syncText(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildJoystick(index, note),
                    ],
                  ),
                  _buildRotationScale(note),
                ],
              )
            : GestureDetector(
                onTap: () => setState(() {
                  note.isExpanded = true;
                }),
                onDoubleTap: () => setState(() {
                  _selectedNoteIndex = isSelected ? null : index;
                }),
                onLongPress: () => setState(() {
                  note.isExpanded = true;
                  _selectedNoteIndex = index;
                }),
                child: SizedBox(
                  width: note.width,
                  height: note.height,
                  child: Stack(
                    children: [
                      Text(
                        note.text,
                        style: TextStyle(
                            fontSize: note.fontSize,
                            color: note.color,
                            fontWeight: FontWeight.bold),
                      ),
                      if (isSelected)
                        Positioned.fill(
                          child: CustomPaint(
                              painter:
                                  _DashedBorderPainter(color: Colors.indigo)),
                        ),
                      // Invisible resize corner/edge hit areas
                      _resizeHandle(0, 0, 14, 14,
                          (dx, dy) => _resizeNote(index, 'topLeft', dx, dy)),
                      _resizeHandle((note.width - 14) / 2, 0, 14, 14,
                          (dx, dy) => _resizeNote(index, 'top', dx, dy)),
                      _resizeHandle(note.width - 14, 0, 14, 14,
                          (dx, dy) => _resizeNote(index, 'topRight', dx, dy)),
                      _resizeHandle(note.width - 14, (note.height - 14) / 2, 14,
                          14, (dx, dy) => _resizeNote(index, 'right', dx, dy)),
                      _resizeHandle(
                          note.width - 14,
                          note.height - 14,
                          14,
                          14,
                          (dx, dy) =>
                              _resizeNote(index, 'bottomRight', dx, dy)),
                      _resizeHandle((note.width - 14) / 2, note.height - 14, 14,
                          14, (dx, dy) => _resizeNote(index, 'bottom', dx, dy)),
                      _resizeHandle(0, note.height - 14, 14, 14,
                          (dx, dy) => _resizeNote(index, 'bottomLeft', dx, dy)),
                      _resizeHandle(0, (note.height - 14) / 2, 14, 14,
                          (dx, dy) => _resizeNote(index, 'left', dx, dy)),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildJoystick(int index, _TextNote note) {
    final knobCenter = _joystickKnob[index] ?? Offset.zero;
    const double joystickRadius = 22.0;
    const double knobRadius = 8.0;
    const double maxKnobOffset = 12.0;
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _selectedNoteIndex = index;
          _dragStartGlobal = details.globalPosition;
          _dragNoteStartPos = note.position;
        });
      },
      onPanUpdate: (details) {
        final totalDelta = details.globalPosition - _dragStartGlobal!;
        setState(() {
          note.position = _dragNoteStartPos! + totalDelta;
          // Clamp knob visual within joystick circle
          final localDx = (details.localPosition.dx - joystickRadius)
              .clamp(-maxKnobOffset, maxKnobOffset);
          final localDy = (details.localPosition.dy - joystickRadius)
              .clamp(-maxKnobOffset, maxKnobOffset);
          _joystickKnob[index] = Offset(localDx, localDy);
        });
      },
      onPanEnd: (_) {
        _dragStartGlobal = null;
        _dragNoteStartPos = null;
        setState(() => _joystickKnob.remove(index));
      },
      child: Container(
        width: joystickRadius * 2,
        height: joystickRadius * 2,
        decoration: BoxDecoration(
          color: Colors.indigo.withOpacity(0.08),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.indigo, width: 1.5),
        ),
        child: Center(
          child: Transform.translate(
            offset: knobCenter,
            child: Container(
              width: knobRadius * 2,
              height: knobRadius * 2,
              decoration: BoxDecoration(
                color: Colors.indigo,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRotationScale(_TextNote note) {
    const double scaleWidth = 160;
    const double scaleHeight = 20;
    return GestureDetector(
      onPanUpdate: (details) {
        final delta = details.delta.dx;
        setState(() {
          note.rotation += delta * 0.01;
        });
      },
      child: Container(
        width: scaleWidth,
        height: scaleHeight,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          color: Colors.indigo.withOpacity(0.06),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.indigo.withOpacity(0.3)),
        ),
        child: CustomPaint(
          painter: _RotationScalePainter(rotation: note.rotation),
          size: const Size(scaleWidth, scaleHeight),
        ),
      ),
    );
  }

  Widget _buildCanvasJoystick() {
    const double joystickRadius = 32.0;
    const double knobRadius = 12.0;
    const double maxDisplacement = 20.0;

    return GestureDetector(
      onPanStart: (details) {
        _canvasJoystickTimer?.cancel();
        _canvasJoystickTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
          if (_canvasJoystickDisplacement != Offset.zero) {
            final double speedFactor = 0.5;
            final double dx = _canvasJoystickDisplacement.dx * speedFactor;
            final double dy = _canvasJoystickDisplacement.dy * speedFactor;

            final matrix = _transformationController.value.clone();
            matrix.translate(-dx, -dy);
            _transformationController.value = matrix;
          }
        });
      },
      onPanUpdate: (details) {
        final localPos = details.localPosition;
        final center = const Offset(joystickRadius, joystickRadius);
        final offset = localPos - center;
        
        final double dist = offset.distance;
        Offset displacement;
        if (dist > maxDisplacement) {
          displacement = Offset.fromDirection(offset.direction, maxDisplacement);
        } else {
          displacement = offset;
        }

        setState(() {
          _canvasJoystickDisplacement = displacement;
        });
      },
      onPanEnd: (_) {
        _canvasJoystickTimer?.cancel();
        _canvasJoystickTimer = null;
        setState(() {
          _canvasJoystickDisplacement = Offset.zero;
        });
      },
      child: Container(
        width: joystickRadius * 2,
        height: joystickRadius * 2,
        decoration: BoxDecoration(
          color: Colors.indigo.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.indigo, width: 1.5),
        ),
        child: Center(
          child: Transform.translate(
            offset: _canvasJoystickDisplacement,
            child: Container(
              width: knobRadius * 2,
              height: knobRadius * 2,
              decoration: const BoxDecoration(
                color: Colors.indigo,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resizeHandle(double left, double top, double w, double h,
      void Function(double dx, double dy) onResize) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onLongPressMoveUpdate: (details) {
          final delta =
              details.offsetFromOrigin - details.localOffsetFromOrigin;
          onResize(delta.dx, delta.dy);
        },
        child: SizedBox(width: w, height: h),
      ),
    );
  }

  void _resizeNote(int index, String handle, double dx, double dy) {
    final note = _textNotes[index];
    setState(() {
      switch (handle) {
        case 'topLeft':
          note.position = Offset(note.position.dx + dx, note.position.dy + dy);
          note.width = (note.width - dx).clamp(60, 600);
          note.height = (note.height - dy).clamp(30, 400);
          break;
        case 'top':
          note.position = Offset(note.position.dx, note.position.dy + dy);
          note.height = (note.height - dy).clamp(30, 400);
          break;
        case 'topRight':
          note.position = Offset(note.position.dx, note.position.dy + dy);
          note.width = (note.width + dx).clamp(60, 600);
          note.height = (note.height - dy).clamp(30, 400);
          break;
        case 'right':
          note.width = (note.width + dx).clamp(60, 600);
          break;
        case 'bottomRight':
          note.width = (note.width + dx).clamp(60, 600);
          note.height = (note.height + dy).clamp(30, 400);
          break;
        case 'bottom':
          note.height = (note.height + dy).clamp(30, 400);
          break;
        case 'bottomLeft':
          note.position = Offset(note.position.dx + dx, note.position.dy);
          note.width = (note.width - dx).clamp(60, 600);
          note.height = (note.height + dy).clamp(30, 400);
          break;
        case 'left':
          note.position = Offset(note.position.dx + dx, note.position.dy);
          note.width = (note.width - dx).clamp(60, 600);
          break;
      }
    });
  }

  Widget _verticalDivider() {
    return SizedBox(
      height: 16,
      child:
          VerticalDivider(width: 8, thickness: 1, color: Colors.grey.shade200),
    );
  }
}
