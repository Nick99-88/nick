import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../keyboard_manager.dart';
import '../theme/keyboard_theme.dart';

class UrduLayout extends StatelessWidget {
  final KeyboardTheme theme;
  final VoidCallback onAlpha;
  final VoidCallback onBackspace;
  final VoidCallback onDone;

  const UrduLayout({
    super.key,
    required this.theme,
    required this.onAlpha,
    required this.onBackspace,
    required this.onDone,
  });

  static const List<List<String>> _rows = [
    ['ق', 'و', 'ع', 'ر', 'ت', 'ي', 'ئ', 'ء', 'ة', 'ه'],
    ['ا', 'س', 'د', 'ف', 'گ', 'ح', 'ج', 'ک', 'ل'],
    ['ز', 'خ', 'ح', 'ط', 'غ', 'ع', 'ظ', 'ص', 'ض'],
    ['ث', 'ق', 'ب', 'ن', 'م', 'ک', 'گ', 'پ', 'چ', 'ژ'],
    ['ڑ', 'ڈ', 'ں', 'ھ', 'ّ', 'ٔ', 'ٰ', '‌', '‍'],
  ];

  static const List<String> _digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  @override
  Widget build(BuildContext context) {
    final mgr = UniversalKeyboardManager();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < _rows.length; i++) _buildRow(_rows[i], mgr),
        _buildBottomRow(mgr),
      ],
    );
  }

  Widget _buildRow(List<String> keys, UniversalKeyboardManager mgr) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (keys == _rows[2]) _buildActionKey(Icons.abc, onAlpha, flex: 1),
          ...keys.map((key) => _buildKey(key, () {
            HapticFeedback.lightImpact();
            mgr.insertText(key);
          })),
          if (keys == _rows[2]) _buildActionKey(Icons.backspace, onBackspace, flex: 1),
        ],
      ),
    );
  }

  Widget _buildBottomRow(UniversalKeyboardManager mgr) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: _buildActionKey(Icons.abc, onAlpha),
          ),
          Expanded(
            flex: 2,
            child: _buildSmallKey('ا', () { HapticFeedback.lightImpact(); mgr.insertText('ا'); }),
          ),
          Expanded(
            flex: 2,
            child: _buildSmallKey('و', () { HapticFeedback.lightImpact(); mgr.insertText('و'); }),
          ),
          Expanded(
            flex: 2,
            child: _buildSmallKey('ی', () { HapticFeedback.lightImpact(); mgr.insertText('ی'); }),
          ),
          Expanded(
            flex: 2,
            child: _buildSmallKey('ب', () { HapticFeedback.lightImpact(); mgr.insertText('ب'); }),
          ),
          Expanded(
            flex: 2,
            child: _buildSmallKey('ن', () { HapticFeedback.lightImpact(); mgr.insertText('ن'); }),
          ),
          Expanded(
            flex: 2,
            child: _buildSmallKey('م', () { HapticFeedback.lightImpact(); mgr.insertText('م'); }),
          ),
          Expanded(
            flex: 1,
            child: _buildActionKey(Icons.backspace, onBackspace),
          ),
          Expanded(
            flex: 1,
            child: _buildActionKey(Icons.check, onDone),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.all(1),
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 28,
            height: 36,
            decoration: theme.buttonDecoration,
            alignment: Alignment.center,
            child: Text(label, style: theme.keyTextStyle.copyWith(fontSize: 15)),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallKey(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.all(1),
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 36,
            decoration: theme.buttonDecoration,
            alignment: Alignment.center,
            child: Text(label, style: theme.keyTextStyle.copyWith(fontSize: 14)),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey(IconData icon, VoidCallback onTap, {int flex = 1}) {
    return Padding(
      padding: const EdgeInsets.all(1),
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 36,
            decoration: theme.buttonDecoration.copyWith(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              color: null,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: theme.keyTextStyle.color, size: 18),
          ),
        ),
      ),
    );
  }
}
