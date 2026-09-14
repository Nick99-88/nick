import 'package:flutter/material.dart';
import '../../core/theme.dart';

class OnboardingOverlay extends StatefulWidget {
  final bool isLoginMode;
  final VoidCallback? onDismiss;

  const OnboardingOverlay({super.key, this.isLoginMode = false, this.onDismiss});

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  bool _dismissed = false;

  void _dismiss() {
    if (_dismissed) return;
    setState(() => _dismissed = true);
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final screenSize = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                color: Colors.black.withOpacity(0.55),
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: 24,
            right: 24,
            child: _buildInstructionCard(),
          ),
          Positioned(
            top: isLoginMode
                ? screenSize.height * 0.62
                : screenSize.height * 0.62,
            left: screenSize.width * 0.5 - 12,
            child: _buildArrowDown(),
          ),
        ],
      ),
    );
  }

  bool get isLoginMode => widget.isLoginMode;

  Widget _buildInstructionCard() {
    final title = isLoginMode
        ? 'Login with Google'
        : 'Welcome to Starlight';
    final subtitle = isLoginMode
        ? 'Tap the Google button below to sign in and get started.'
        : 'Tap the Students Features card below to begin your journey.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: StarlightTheme.primaryBlue.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  StarlightTheme.primaryBlue,
                  StarlightTheme.primaryBlue.withOpacity(0.6),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: StarlightTheme.primaryBlue.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              isLoginMode ? Icons.login_rounded : Icons.school_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: StarlightTheme.primaryBlue,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _dismiss,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _dismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StarlightTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArrowDown() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: Color(0xFF1A237E),
        size: 20,
      ),
    );
  }
}
