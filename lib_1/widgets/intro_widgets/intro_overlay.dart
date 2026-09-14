import 'package:flutter/material.dart';
import '../../core/theme.dart';

class IntroOverlay extends StatefulWidget {
  final IconData featureIcon;
  final String featureTitle;
  final String featureSubtitle;
  final List<Map<String, dynamic>> steps;
  final VoidCallback onDismiss;

  const IntroOverlay({
    super.key,
    required this.featureIcon,
    required this.featureTitle,
    required this.featureSubtitle,
    required this.steps,
    required this.onDismiss,
  });

  @override
  State<IntroOverlay> createState() => _IntroOverlayState();
}

class _IntroOverlayState extends State<IntroOverlay> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < widget.steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onDismiss();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipAll() {
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: StarlightTheme.primaryBlue.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: _buildCloseButton(),
                ),
                const SizedBox(height: 24),
                // Page view with icons
                SizedBox(
                  height: 200,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemCount: widget.steps.length,
                    itemBuilder: (context, index) {
                      return _buildStepPage(index);
                    },
                  ),
                ),
                const SizedBox(height: 24),
                // Page indicators
                _buildPageIndicators(),
                const SizedBox(height: 24),
                // Action buttons
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Material(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: _skipAll,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: const Icon(Icons.close, size: 20, color: Color(0xFF1A237E)),
        ),
      ),
    );
  }

  Widget _buildStepPage(int index) {
    final step = widget.steps[index];
    final icon = step['icon'] as IconData;
    final color = step['color'] as Color;
    final title = step['title'] as String;
    final desc = step['description'] as String;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.1, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey(index),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.15),
                    color.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: color.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, size: 42, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A237E),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.steps.length,
        (index) {
          final isActive = index == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? StarlightTheme.primaryBlue
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentStepText() {
    if (_currentPage >= widget.steps.length) return const SizedBox.shrink();
    final step = widget.steps[_currentPage];
    return Column(
      children: [
        Text(
          step['title'] as String,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A237E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          step['description'] as String,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _previousPage,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A237E),
              side: const BorderSide(color: Color(0xFF1A237E)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _currentPage > 0
                ? const Text('Back',
                    style: TextStyle(fontWeight: FontWeight.w600))
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              _currentPage == widget.steps.length - 1 ? 'Get Started' : 'Next',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}