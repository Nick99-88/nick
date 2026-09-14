import 'package:flutter/material.dart';
import '../../core/storage.dart';
import 'intro_overlay.dart';

class IntroCheck extends StatefulWidget {
  final String featureKey;
  final Widget child;
  final IconData featureIcon;
  final String featureTitle;
  final String featureSubtitle;
  final List<Map<String, dynamic>> steps;

  const IntroCheck({
    super.key,
    required this.featureKey,
    required this.child,
    required this.featureIcon,
    required this.featureTitle,
    required this.featureSubtitle,
    required this.steps,
  });

  @override
  State<IntroCheck> createState() => _IntroCheckState();
}

class _IntroCheckState extends State<IntroCheck>
    with TickerProviderStateMixin {
  late final ValueNotifier<bool> _showIntro = ValueNotifier(false);
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _checkIntro();
  }

  Future<void> _checkIntro() async {
    final seen = await StarlightStorage.getIntroSeenFor(widget.featureKey);
    if (mounted && seen != true) {
      _showIntro.value = true;
    }
    _checked = true;
  }

  Future<void> _dismissIntro() async {
    _showIntro.value = false;
    await StarlightStorage.setIntroSeenFor(widget.featureKey);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<bool>(
      valueListenable: _showIntro,
      builder: (context, showIntro, child) {
        if (showIntro) {
          return IntroOverlay(
            featureIcon: widget.featureIcon,
            featureTitle: widget.featureTitle,
            featureSubtitle: widget.featureSubtitle,
            steps: widget.steps,
            onDismiss: _dismissIntro,
          );
        }
        return child!;
      },
      child: widget.child,
    );
  }
}