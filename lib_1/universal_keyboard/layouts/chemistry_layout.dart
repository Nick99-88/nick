import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../keyboard_manager.dart';
import '../theme/keyboard_theme.dart';

class ChemistryLayout extends StatelessWidget {
  final KeyboardTheme theme;
  final VoidCallback onBackspace;
  final VoidCallback onAlpha;
  final VoidCallback onDone;

  const ChemistryLayout({
    super.key,
    required this.theme,
    required this.onBackspace,
    required this.onAlpha,
    required this.onDone,
  });

  static const List<String> _elements = [
    'H', 'He', 'Li', 'Be', 'B', 'C', 'N', 'O', 'F', 'Ne',
    'Na', 'Mg', 'Al', 'Si', 'P', 'S', 'Cl', 'Ar', 'K', 'Ca',
    'Fe', 'Cu', 'Zn', 'Ag', 'I', 'Au', 'Hg', 'Pb', 'U', 'Pu',
  ];

  @override
  Widget build(BuildContext context) {
    final mgr = UniversalKeyboardManager();
    return Column(
      children: [
        _buildSubscriptRow(mgr),
        Expanded(
          child: GridView.count(
            crossAxisCount: 6,
            padding: EdgeInsets.all(theme.keySpacing),
            mainAxisSpacing: theme.keySpacing,
            crossAxisSpacing: theme.keySpacing,
            childAspectRatio: 1.4,
            children: _elements.map((el) => _buildElementKey(el, mgr)).toList(),
          ),
        ),
        _buildBottomRow(mgr),
      ],
    );
  }

  Widget _buildSubscriptRow(UniversalKeyboardManager mgr) {
    const subs = ['₀', '₁', '₂', '₃', '₄', '₅', '₆', '₇', '₈', '₉'];
    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.keySpacing, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text('Subscript:', style: theme.modeLabelStyle),
          ),
          ...subs.map((s) => _buildSubKey(s, mgr)),
          _buildReactionArrow('→', mgr),
          _buildReactionArrow('⇌', mgr),
        ],
      ),
    );
  }

  Widget _buildSubKey(String sub, UniversalKeyboardManager mgr) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            mgr.insertText(sub);
          },
          child: Container(
            width: 28,
            height: 32,
            decoration: theme.buttonDecoration,
            alignment: Alignment.center,
            child: Text(sub, style: theme.keyTextStyle.copyWith(fontSize: 14)),
          ),
        ),
      ),
    );
  }

  Widget _buildReactionArrow(String label, UniversalKeyboardManager mgr) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            mgr.insertText(label);
          },
          child: Container(
            width: 36,
            height: 32,
            decoration: theme.buttonDecoration,
            alignment: Alignment.center,
            child: Text(label, style: theme.keyTextStyle.copyWith(fontSize: 16)),
          ),
        ),
      ),
    );
  }

  Widget _buildElementKey(String element, UniversalKeyboardManager mgr) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          mgr.insertText(element);
        },
        child: Container(
          decoration: element.length == 1
              ? theme.buttonDecoration
              : _twoLetterDecoration(),
          alignment: Alignment.center,
          child: Text(
            element,
            style: element.length == 1
                ? theme.keyTextStyle.copyWith(fontSize: 16, fontWeight: FontWeight.bold)
                : theme.keyTextStyle.copyWith(fontSize: 13),
          ),
        ),
      ),
    );
  }

  BoxDecoration _twoLetterDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      color: theme.accentColor.withValues(alpha: 0.3),
    );
  }

  Widget _buildBottomRow(UniversalKeyboardManager mgr) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: theme.keySpacing),
      child: Row(
        children: [
          _buildActionKey('ABC', onAlpha),
          const Spacer(),
          _buildActionKey('+', () { HapticFeedback.lightImpact(); mgr.insertText(' + '); }),
          _buildActionKey('→', () { HapticFeedback.lightImpact(); mgr.insertText(' → '); }),
          _buildActionKey('⇌', () { HapticFeedback.lightImpact(); mgr.insertText(' ⇌ '); }),
          _buildActionKey('(aq)', () { HapticFeedback.lightImpact(); mgr.insertText('(aq)'); }),
          _buildActionKey('(s)', () { HapticFeedback.lightImpact(); mgr.insertText('(s)'); }),
          _buildActionKey('(l)', () { HapticFeedback.lightImpact(); mgr.insertText('(l)'); }),
          _buildActionKey('(g)', () { HapticFeedback.lightImpact(); mgr.insertText('(g)'); }),
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
          padding: EdgeInsets.symmetric(horizontal: 8),
          height: theme.keyHeight,
          decoration: theme.buttonDecoration,
          alignment: Alignment.center,
          child: Text(label, style: theme.keyTextStyle.copyWith(fontSize: 12)),
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
