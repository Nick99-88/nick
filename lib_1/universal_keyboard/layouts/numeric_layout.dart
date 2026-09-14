import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../keyboard_manager.dart';
import '../theme/keyboard_theme.dart';

class NumericLayout extends StatelessWidget {
  final KeyboardTheme theme;
  final VoidCallback onBackspace;
  final VoidCallback onDone;

  const NumericLayout({
    super.key,
    required this.theme,
    required this.onBackspace,
    required this.onDone,
  });

  static const List<String> _keys = [
    '7', '8', '9',
    '4', '5', '6',
    '1', '2', '3',
    '.', '0',
  ];

  @override
  Widget build(BuildContext context) {
    final mgr = UniversalKeyboardManager();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int row = 0; row < 4; row++) _buildRow(row, mgr),
      ],
    );
  }

  Widget _buildRow(int row, UniversalKeyboardManager mgr) {
    final start = row * 3;
    final end = start + 3;
    final items = _keys.sublist(start, end > _keys.length ? _keys.length : end);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.keySpacing / 2, horizontal: 32),
      child: Row(
        children: [
          ...items.map((key) => Expanded(child: _buildKey(key, () {
            HapticFeedback.lightImpact();
            mgr.insertText(key);
          }))),
          if (row == 3) ...[
            Expanded(child: _buildKey('00', () {
              HapticFeedback.lightImpact();
              mgr.insertText('00');
            })),
          ] else if (row == 1) ...[
            _buildActionKey(Icons.backspace, onBackspace),
          ] else if (row == 0) ...[
            _buildActionKey(Icons.check, onDone),
          ],
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
            height: theme.keyHeight,
            decoration: theme.buttonDecoration,
            alignment: Alignment.center,
            child: Text(label, style: theme.keyTextStyle.copyWith(fontSize: 22)),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey(IconData icon, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.all(theme.keySpacing / 2),
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: theme.keyHeight,
            decoration: theme.buttonDecoration,
            alignment: Alignment.center,
            child: Icon(icon, color: theme.keyTextStyle.color, size: 20),
          ),
        ),
      ),
    );
  }
}
