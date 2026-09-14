import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'keyboard_mode.dart';
import 'keyboard_manager.dart';
import 'theme/keyboard_theme.dart';
import 'layouts/alpha_layout.dart';
import 'layouts/numeric_layout.dart';
import 'layouts/symbols_layout.dart';
import 'layouts/scientific_layout.dart';
import 'layouts/chemistry_layout.dart';
import 'layouts/urdu_layout.dart';

class UniversalKeyboardUI extends StatefulWidget {
  final KeyboardTheme theme;
  final ValueChanged<String>? onTextInput;
  final VoidCallback? onDone;

  const UniversalKeyboardUI({
    super.key,
    this.theme = const KeyboardTheme(),
    this.onTextInput,
    this.onDone,
  });

  @override
  State<UniversalKeyboardUI> createState() => _UniversalKeyboardUIState();
}

class _UniversalKeyboardUIState extends State<UniversalKeyboardUI> {
  KeyboardMode _currentMode = KeyboardMode.alpha;
  bool _isShifted = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.theme.backgroundColor,
      height: 300,
      child: Column(
        children: [
          _buildModeBar(),
          Expanded(
            child: IndexedStack(
              index: _currentMode.index,
              children: [
                AlphaLayout(
                  theme: widget.theme,
                  isShifted: _isShifted,
                  onShift: () => setState(() => _isShifted = !_isShifted),
                  onSymbols: () => setState(() => _currentMode = KeyboardMode.symbols),
                  onBackspace: () {
                    HapticFeedback.lightImpact();
                    UniversalKeyboardManager().deleteBackward();
                  },
                  onDone: () {
                    HapticFeedback.lightImpact();
                    UniversalKeyboardManager().performAction(TextInputAction.done);
                    widget.onDone?.call();
                  },
                ),
                NumericLayout(
                  theme: widget.theme,
                  onBackspace: () {
                    HapticFeedback.lightImpact();
                    UniversalKeyboardManager().deleteBackward();
                  },
                  onDone: () {
                    HapticFeedback.lightImpact();
                    UniversalKeyboardManager().performAction(TextInputAction.done);
                    widget.onDone?.call();
                  },
                ),
                SymbolsLayout(
                  theme: widget.theme,
                  onAlpha: () => setState(() => _currentMode = KeyboardMode.alpha),
                  onBackspace: () {
                    HapticFeedback.lightImpact();
                    UniversalKeyboardManager().deleteBackward();
                  },
                  onDone: () {
                    HapticFeedback.lightImpact();
                    UniversalKeyboardManager().performAction(TextInputAction.done);
                    widget.onDone?.call();
                  },
                ),
                ScientificLayout(
                  theme: widget.theme,
                  onAlpha: () => setState(() => _currentMode = KeyboardMode.alpha),
                  onBackspace: () {
                    HapticFeedback.lightImpact();
                    UniversalKeyboardManager().deleteBackward();
                  },
                  onDone: () {
                    HapticFeedback.lightImpact();
                    UniversalKeyboardManager().performAction(TextInputAction.done);
                    widget.onDone?.call();
                  },
                ),
                ChemistryLayout(
                  theme: widget.theme,
                  onAlpha: () => setState(() => _currentMode = KeyboardMode.alpha),
                  onBackspace: () {
                    HapticFeedback.lightImpact();
                    UniversalKeyboardManager().deleteBackward();
                  },
                  onDone: () {
                    HapticFeedback.lightImpact();
                    UniversalKeyboardManager().performAction(TextInputAction.done);
                    widget.onDone?.call();
                  },
                ),
                UrduLayout(
                  theme: widget.theme,
                  onAlpha: () => setState(() => _currentMode = KeyboardMode.alpha),
                  onBackspace: () {
                    HapticFeedback.lightImpact();
                    UniversalKeyboardManager().deleteBackward();
                  },
                  onDone: () {
                    HapticFeedback.lightImpact();
                    UniversalKeyboardManager().performAction(TextInputAction.done);
                    widget.onDone?.call();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeBar() {
    final modes = KeyboardMode.values;
    return Container(
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (final mode in modes) _buildModeTab(mode),
        ],
      ),
    );
  }

  Widget _buildModeTab(KeyboardMode mode) {
    final isActive = _currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _currentMode = mode;
            if (mode == KeyboardMode.alpha) _isShifted = false;
          });
        },
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(6)),
            color: isActive ? widget.theme.accentColor : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Text(
            _labelForMode(mode),
            style: widget.theme.modeLabelStyle.copyWith(
              color: isActive ? Colors.white : widget.theme.modeLabelStyle.color,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  String _labelForMode(KeyboardMode mode) {
    switch (mode) {
      case KeyboardMode.alpha:
        return 'ABC';
      case KeyboardMode.numeric:
        return '123';
      case KeyboardMode.symbols:
        return '#+=';
      case KeyboardMode.scientific:
        return 'π ∑';
      case KeyboardMode.chemistry:
        return 'H₂O';
      case KeyboardMode.urdu:
        return 'ا ب';
    }
  }
}
