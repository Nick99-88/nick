import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../keyboard_manager.dart';
import '../theme/keyboard_theme.dart';

class SymbolsLayout extends StatelessWidget {
  final KeyboardTheme theme;
  final VoidCallback onAlpha;
  final VoidCallback onBackspace;
  final VoidCallback onDone;

  const SymbolsLayout({
    super.key,
    required this.theme,
    required this.onAlpha,
    required this.onBackspace,
    required this.onDone,
  });

  static const List<List<String>> _rows = [
    ['!', '@', '#', r'$', '%', '^', '&', '*', '(', ')'],
    ['-', '_', '=', '+', '{', '}', '[', ']', '|', r'\'],
    [':', ';', '"', "'", '<', '>', ',', '.', '?', '/'],
    ['~', '`', '±', '÷', '×', '∴', '∵', '∞', '∑', 'π'],
  ];

  @override
  Widget build(BuildContext context) {
    final mgr = UniversalKeyboardManager();
    return Column(
      children: [
        for (int i = 0; i < _rows.length; i++) _buildRow(_rows[i], mgr),
        _buildBottomRow(mgr),
      ],
    );
  }

  Widget _buildRow(List<String> keys, UniversalKeyboardManager mgr) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.keySpacing / 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: keys.map((key) => _buildKey(key, () {
          HapticFeedback.lightImpact();
          mgr.insertText(key);
        })).toList(),
      ),
    );
  }

  Widget _buildBottomRow(UniversalKeyboardManager mgr) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.keySpacing / 2, horizontal: 8),
      child: Row(
        children: [
          _buildActionKey('ABC', onAlpha),
          const Spacer(),
          _buildKey('#', () { HapticFeedback.lightImpact(); mgr.insertText('#'); }),
          _buildKey('&', () { HapticFeedback.lightImpact(); mgr.insertText('&'); }),
          _buildKey('@', () { HapticFeedback.lightImpact(); mgr.insertText('@'); }),
          const Spacer(),
          _buildActionIcon(Icons.backspace, onBackspace),
          _buildActionIcon(Icons.check, onDone),
        ],
      ),
    );
  }

  Widget _buildKey(String label, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.all(theme.keySpacing / 2),
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 30,
            height: theme.keyHeight,
            decoration: theme.buttonDecoration,
            alignment: Alignment.center,
            child: Text(label, style: theme.keyTextStyle),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey(String label, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.all(theme.keySpacing / 2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
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
