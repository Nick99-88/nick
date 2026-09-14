import 'package:flutter/material.dart';
import '../models/language_model.dart';
import '../theme/editor_theme.dart';

class SideLanguageSelector extends StatelessWidget {
  final String selectedLanguage;
  final Function(String) onLanguageSelected;

  const SideLanguageSelector({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: List.generate(SupportedLanguages.languages.length, (index) {
            final lang = SupportedLanguages.languages[index];
            final isSelected = lang.id == selectedLanguage;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => onLanguageSelected(lang.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? lang.color.withOpacity(0.15)
                        : SideEditorTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? lang.color.withOpacity(0.4)
                          : Colors.white.withOpacity(0.06),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        lang.icon,
                        size: 13,
                        color: isSelected
                            ? lang.color
                            : SideEditorTheme.lineNumberColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        lang.name,
                        style: TextStyle(
                          color: isSelected
                              ? lang.color
                              : SideEditorTheme.lineNumberColor,
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}