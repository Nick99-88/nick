import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../keyboard_manager.dart';
import '../theme/keyboard_theme.dart';

class AlphaLayout extends StatelessWidget {
  final KeyboardTheme theme;
  final VoidCallback onShift;
  final bool isShifted;
  final VoidCallback onSymbols;
  final VoidCallback onBackspace;
  final VoidCallback onDone;

  const AlphaLayout({
    super.key,
    required this.theme,
    required this.onShift,
    required this.isShifted,
    required this.onSymbols,
    required this.onBackspace,
    required this.onDone,
  });

  static const List<List<String>> _keysLower = [
    ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
    ['z', 'x', 'c', 'v', 'b', 'n', 'm'],
  ];

  static const List<List<String>> _keysUpper = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
  ];

  List<List<String>> get _keys => isShifted ? _keysUpper : _keysLower;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int row = 0; row < _keys.length; row++) _buildRow(row),
      ],
    );
  }

  Widget _buildRow(int row) {
    final mgr = UniversalKeyboardManager();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.keySpacing / 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (row == 2) _buildActionKey(Icons.arrow_upward, onShift, flex: 2),
          if (row == 1) _buildActionKey(Icons.abc, onSymbols, flex: 1),
          ..._keys[row].map((key) => _buildKey(key, () {
            HapticFeedback.lightImpact();
            mgr.insertText(key);
          })),
          if (row == 1) _buildActionKey(Icons.backspace, onBackspace, flex: 1),
          if (row == 2) _buildActionKey(Icons.check, onDone, flex: 2),
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
            width: 28,
            height: theme.keyHeight,
            decoration: theme.buttonDecoration,
            alignment: Alignment.center,
            child: Text(label, style: theme.keyTextStyle),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey(IconData icon, VoidCallback onTap, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.all(theme.keySpacing / 2),
        child: RepaintBoundary(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: theme.keyHeight,
              decoration: theme.buttonDecoration.copyWith(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                color: null,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: theme.keyTextStyle.color, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
