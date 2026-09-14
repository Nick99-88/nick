import 'package:flutter/material.dart';
import '../theme/editor_theme.dart';

class SideRunButton extends StatefulWidget {
  final bool isRunning;
  final VoidCallback onPressed;

  const SideRunButton({
    super.key,
    required this.isRunning,
    required this.onPressed,
  });

  @override
  State<SideRunButton> createState() => _SideRunButtonState();
}

class _SideRunButtonState extends State<SideRunButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _controller.forward(),
            onTapUp: (_) {
              _controller.reverse();
              widget.onPressed();
            },
            onTapCancel: () => _controller.reverse(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isRunning
                    ? SideEditorTheme.accentOrange
                    : SideEditorTheme.accentGreen,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: (widget.isRunning
                            ? SideEditorTheme.accentOrange
                            : SideEditorTheme.accentGreen)
                        .withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isRunning)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SideEditorTheme.backgroundDark,
                      ),
                    )
                  else
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: SideEditorTheme.backgroundDark,
                      size: 18,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isRunning ? 'Running' : 'Run',
                    style: const TextStyle(
                      color: SideEditorTheme.backgroundDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
