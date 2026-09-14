import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class StarlightLoading extends StatefulWidget {
  const StarlightLoading({super.key});

  @override
  State<StarlightLoading> createState() => _StarlightLoadingState();
}

class _StarlightLoadingState extends State<StarlightLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isTraceComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _runAnimationSequence();
  }

  Future<void> _runAnimationSequence() async {
    while (mounted) {
      setState(() => _isTraceComplete = false);
      await _controller.forward(from: 0.0);
      setState(() => _isTraceComplete = true);
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Cosmic Background Layers
          _buildCosmicBackground(),

          // 2. The Interactive Logo (Center Glow)
          _buildGlowingLogo(),

          // 3. The Path Animation
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return ImageFiltered(
                  // Adds a "Bloom" effect to the drawing
                  imageFilter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
                  child: CustomPaint(
                    size: const Size(360, 100),
                    painter: StarlightPainter(
                      progress: _controller.value,
                      isComplete: _isTraceComplete,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCosmicBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            Color(0xFF0D1B2A), // Deep Blue
            Color(0xFF000000), // Pure Black
          ],
        ),
      ),
    );
  }

  Widget _buildGlowingLogo() {
    return AnimatedScale(
      scale: _isTraceComplete ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeInOutBack,
      child: Opacity(
        opacity: _isTraceComplete ? 0.4 : 0.1,
        child: Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(_isTraceComplete ? 0.3 : 0.1),
                blurRadius: 50,
                spreadRadius: 10,
              )
            ],
          ),
          child: Center(
            child: Image.asset(
              'assets/logo.png',
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.auto_awesome, color: Colors.cyanAccent.withOpacity(0.5), size: 80),
            ),
          ),
        ),
      ),
    );
  }
}

class StarlightPainter extends CustomPainter {
  final double progress;
  final bool isComplete;
  StarlightPainter({required this.progress, required this.isComplete});

  @override
  void paint(Canvas canvas, Size size) {
    final Path wordPath = _buildStarlightPath(size);

    // 1. Neon Shadow Paint (creates the underlying glow)
    final glowPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.3)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // 2. The Main Trace Paint
    final mainPaint = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final metric in wordPath.computeMetrics()) {
      // Draw background ghost path
      canvas.drawPath(
        metric.extractPath(0, metric.length),
        Paint()
          ..color = Colors.white.withOpacity(0.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      if (isComplete) {
        // Draw the full glowing path
        canvas.drawPath(metric.extractPath(0, metric.length), glowPaint);
        canvas.drawPath(metric.extractPath(0, metric.length), mainPaint..color = Colors.cyanAccent);
      } else {
        double currentLength = metric.length * progress;

        // Draw glow trail (slightly behind the head)
        canvas.drawPath(
          metric.extractPath(0, currentLength),
          glowPaint,
        );

        // Draw main white lead line
        canvas.drawPath(
          metric.extractPath(0, currentLength),
          mainPaint,
        );

        // 3. Leading "Comet" Head
        final tangent = metric.getTangentForOffset(currentLength);
        if (tangent != null) {
          final center = tangent.position;

          // Outer Flare
          canvas.drawCircle(
              center,
              8.0,
              Paint()..color = Colors.cyanAccent.withOpacity(0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
          );

          // Core Spark
          canvas.drawCircle(center, 3.0, Paint()..color = Colors.white);

          // Tiny Cross-flare
          final flarePaint = Paint()..color = Colors.white..strokeWidth = 1.0;
          canvas.drawLine(Offset(center.dx - 8, center.dy), Offset(center.dx + 8, center.dy), flarePaint);
          canvas.drawLine(Offset(center.dx, center.dy - 8), Offset(center.dx, center.dy + 8), flarePaint);
        }
      }
    }
  }

  Path _buildStarlightPath(Size size) {
    Path p = Path();
    // (Your existing path logic remains the same, but I've centered it slightly better)
    double x = 20, y = size.height / 2, w = 22, h = 22, s = 14;

    // S
    p.moveTo(x + w, y - h); p.lineTo(x, y - h); p.lineTo(x, y); p.lineTo(x + w, y); p.lineTo(x + w, y + h); p.lineTo(x, y + h);
    // T
    x += w + s; p.moveTo(x, y - h); p.lineTo(x + w, y - h); p.moveTo(x + w / 2, y - h); p.lineTo(x + w / 2, y + h);
    // A
    x += w + s; p.moveTo(x, y + h); p.lineTo(x + w / 2, y - h); p.lineTo(x + w, y + h); p.moveTo(x + 5, y); p.lineTo(x + w - 5, y);
    // R
    x += w + s; p.moveTo(x, y + h); p.lineTo(x, y - h); p.lineTo(x + w, y - h); p.lineTo(x + w, y); p.lineTo(x, y); p.moveTo(x + w / 2, y); p.lineTo(x + w, y + h);
    // L
    x += w + s; p.moveTo(x, y - h); p.lineTo(x, y + h); p.lineTo(x + w, y + h);
    // I
    x += w + s; p.moveTo(x + w / 2, y - h); p.lineTo(x + w / 2, y + h); p.moveTo(x, y - h); p.lineTo(x + w, y - h); p.moveTo(x, y + h); p.lineTo(x + w, y + h);
    // G
    x += w + s; p.moveTo(x + w, y - h); p.lineTo(x, y - h); p.lineTo(x, y + h); p.lineTo(x + w, y + h); p.lineTo(x + w, y); p.lineTo(x + w / 2, y);
    // H
    x += w + s; p.moveTo(x, y - h); p.lineTo(x, y + h); p.moveTo(x + w, y - h); p.lineTo(x + w, y + h); p.moveTo(x, y); p.lineTo(x + w, y);
    // T
    x += w + s; p.moveTo(x, y - h); p.lineTo(x + w, y - h); p.moveTo(x + w / 2, y - h); p.lineTo(x + w / 2, y + h);
    return p;
  }

  @override
  bool shouldRepaint(covariant StarlightPainter oldDelegate) => true;
}