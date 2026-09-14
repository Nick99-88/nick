import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../keyboard_manager.dart';
import '../theme/keyboard_theme.dart';

class ScientificLayout extends StatelessWidget {
  final KeyboardTheme theme;
  final VoidCallback onBackspace;
  final VoidCallback onAlpha;
  final VoidCallback onDone;

  const ScientificLayout({
    super.key,
    required this.theme,
    required this.onBackspace,
    required this.onAlpha,
    required this.onDone,
  });

  static const List<_SciKey> _keys = [
    _SciKey('π', '3.14159'),
    _SciKey('g', '9.81'),
    _SciKey('G', '6.674e-11'),
    _SciKey('c', '299792458'),
    _SciKey('h', '6.626e-34'),
    _SciKey('e', '2.71828'),
    _SciKey('μ', 'μ'),
    _SciKey('α', 'α'),
    _SciKey('β', 'β'),
    _SciKey('θ', 'θ'),
    _SciKey('x²', '²'),
    _SciKey('√', '√('),
    _SciKey('∛', '∛('),
    _SciKey('∫', '∫('),
    _SciKey('∑', '∑('),
    _SciKey('Δ', 'Δ'),
    _SciKey('λ', 'λ'),
    _SciKey('ω', 'ω'),
    _SciKey('∞', '∞'),
    _SciKey('xⁿ', '^'),
    _SciKey('sin', 'sin('),
    _SciKey('cos', 'cos('),
    _SciKey('tan', 'tan('),
    _SciKey('log', 'log('),
    _SciKey('ln', 'ln('),
  ];

  @override
  Widget build(BuildContext context) {
    final mgr = UniversalKeyboardManager();
    return Column(
      children: [
        Expanded(
          child: GridView.count(
            crossAxisCount: 5,
            padding: EdgeInsets.all(theme.keySpacing),
            mainAxisSpacing: theme.keySpacing,
            crossAxisSpacing: theme.keySpacing,
            childAspectRatio: 1.4,
            children: _keys.map((k) => _buildKey(k, mgr)).toList(),
          ),
        ),
        _buildBottomRow(mgr),
      ],
    );
  }

  Widget _buildKey(_SciKey k, UniversalKeyboardManager mgr) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          mgr.insertText(k.output);
        },
        child: Container(
          decoration: theme.buttonDecoration,
          alignment: Alignment.center,
          child: Text(k.label, style: theme.keyTextStyle.copyWith(fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildBottomRow(UniversalKeyboardManager mgr) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: theme.keySpacing),
      child: Row(
        children: [
          _buildActionKey('ABC', onAlpha),
          const Spacer(),
          _buildActionKey('( )', () { HapticFeedback.lightImpact(); mgr.insertText('()'); }),
          _buildActionKey('+', () { HapticFeedback.lightImpact(); mgr.insertText('+'); }),
          _buildActionKey('-', () { HapticFeedback.lightImpact(); mgr.insertText('-'); }),
          _buildActionKey('×', () { HapticFeedback.lightImpact(); mgr.insertText('×'); }),
          _buildActionKey('÷', () { HapticFeedback.lightImpact(); mgr.insertText('÷'); }),
          _buildActionKey('=', () { HapticFeedback.lightImpact(); mgr.insertText('='); }),
          const Spacer(),
          _buildActionIcon(Icons.backspace, onBackspace),
          _buildActionIcon(Icons.check, onDone),
        ],
      ),
    );
  }

  Widget _buildActionKey(String label, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10),
          height: theme.keyHeight,
          decoration: theme.buttonDecoration,
          alignment: Alignment.center,
          child: Text(label, style: theme.keyTextStyle.copyWith(fontSize: 14)),
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.all(theme.keySpacing / 2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: theme.keyHeight,
          decoration: theme.buttonDecoration,
          alignment: Alignment.center,
          child: Icon(icon, color: theme.keyTextStyle.color, size: 20),
        ),
      ),
    );
  }
}

class _SciKey {
  final String label;
  final String output;
  const _SciKey(this.label, this.output);
}
