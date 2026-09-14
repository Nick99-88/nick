import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/editor_theme.dart';
import 'language_keywords.dart';

class AutocompleteOverlay extends StatefulWidget {
  final List<String> suggestions;
  final String prefix;
  final Offset position;
  final Function(String) onSelected;
  final VoidCallback onDismiss;

  const AutocompleteOverlay({
    super.key,
    required this.suggestions,
    required this.prefix,
    required this.position,
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  State<AutocompleteOverlay> createState() => _AutocompleteOverlayState();
}

class _AutocompleteOverlayState extends State<AutocompleteOverlay>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late ScrollController _scrollController;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AutocompleteOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suggestions != widget.suggestions) {
      _selectedIndex = 0;
    }
  }

  void _selectItem(int index) {
    if (!mounted) return;
    if (index >= 0 && index < widget.suggestions.length) {
      widget.onSelected(widget.suggestions[index]);
    }
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    final targetOffset = _selectedIndex * 32.0;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (targetOffset > maxScroll - 120) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
    if (targetOffset < _scrollController.offset + 32) {
      _scrollController.animateTo(
        (_selectedIndex > 0 ? (_selectedIndex - 1) * 32.0 : 0),
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  KeyEventResult handleKey(KeyEvent event) {
    if (!mounted) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) %
            widget.suggestions.length;
      });
      _scrollToSelected();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + widget.suggestions.length) %
            widget.suggestions.length;
      });
      _scrollToSelected();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      _selectItem(_selectedIndex);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onDismiss();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.suggestions.isEmpty) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: 260,
        constraints: BoxConstraints(
          maxHeight: 200,
        ),
        decoration: BoxDecoration(
          color: SideEditorTheme.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: SideEditorTheme.accentPurple.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: SideEditorTheme.accentPurple.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 12, color: SideEditorTheme.accentOrange),
                  const SizedBox(width: 5),
                  Text(
                    '${widget.suggestions.length} suggestions',
                    style: const TextStyle(
                      color: SideEditorTheme.lineNumberColor,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.prefix}...',
                    style: const TextStyle(
                      color: SideEditorTheme.accentPurple,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                controller: _scrollController,
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: widget.suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = widget.suggestions[index];
                  final isSelected = index == _selectedIndex;
                  final isSnippet = suggestion.contains('(') || suggestion.contains('{') || suggestion.contains(':');

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _selectItem(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        color: isSelected
                            ? SideEditorTheme.accentPurple.withOpacity(0.15)
                            : null,
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: isSnippet
                                    ? SideEditorTheme.accentOrange.withOpacity(0.15)
                                    : SideEditorTheme.accentCyan.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                isSnippet ? Icons.code : Icons.abc,
                                size: 12,
                                color: isSnippet
                                    ? SideEditorTheme.accentOrange
                                    : SideEditorTheme.accentCyan,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                suggestion,
                                style: TextStyle(
                                  color: isSelected
                                      ? SideEditorTheme.textDark
                                      : SideEditorTheme.textDark.withOpacity(0.8),
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.keyboard_return,
                                size: 12,
                                color: SideEditorTheme.lineNumberColor,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
