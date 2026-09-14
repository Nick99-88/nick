import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:code_text_field/code_text_field.dart';
import '../theme/editor_theme.dart';
import 'language_keywords.dart';
import 'autocomplete_overlay.dart';

class SideCodeEditor extends StatefulWidget {
  final CodeController controller;
  final String language;
  final Function(String) onChanged;
  final bool readOnly;
  final String? fileName;
  const SideCodeEditor({
    super.key,
    required this.controller,
    required this.language,
    required this.onChanged,
    this.readOnly = false,
    this.fileName,
  });

  @override
  State<SideCodeEditor> createState() => _SideCodeEditorState();
}

class _SideCodeEditorState extends State<SideCodeEditor> {
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _autocompleteOverlay;
  List<String> _suggestions = [];
  String _currentPrefix = '';
  bool _showAutocomplete = false;
  bool _isUpdatingText = false;
  String _previousText = '';

  static const _closeMap = <String, String>{
    '(': ')',
    '[': ']',
    '{': '}',
    '"': '"',
    "'": "'",
  };

  static const _selfClosingTags = <String>{
    'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
    'link', 'meta', 'param', 'source', 'track', 'wbr',
  };

  static const Map<String, Map<String, String>> _snippetExpansions = {
    'python': {
      'for': 'for {cursor} in :\n    ',
      'if': 'if {cursor}:\n    ',
      'while': 'while {cursor}:\n    ',
      'def': 'def {cursor}():\n    ',
      'class': 'class {cursor}:\n    def __init__(self):\n        ',
      'try': 'try:\n    {cursor}\nexcept  as :\n    ',
      'with': 'with {cursor} as :\n    ',
      'elif': 'elif {cursor}:\n    ',
      'else': 'else:\n    ',
      'print': 'print({cursor})',
      'import': 'import {cursor}',
      'from': 'from {cursor} import ',
      'lambda': 'lambda {cursor}: ',
      'return': 'return {cursor}',
      'pass': 'pass',
    },
    'javascript': {
      'for': 'for (let {cursor} = 0;  < ; ++) {\n    \n}',
      'if': 'if ({cursor}) {\n    \n}',
      'while': 'while ({cursor}) {\n    \n}',
      'function': 'function {cursor}() {\n    \n}',
      'const': 'const {cursor} = ',
      'let': 'let {cursor} = ',
      'var': 'var {cursor} = ',
      'class': 'class {cursor} {\n    constructor() {\n        \n    }\n}',
      'try': 'try {\n    {cursor}\n} catch () {\n    \n}',
      'switch': 'switch ({cursor}) {\n    case :\n        \n        break;\n    default:\n        \n        break;\n}',
      'arrow': '({cursor}) => ',
      'import': "import {cursor} from ''",
      'export': 'export default {cursor}',
      'console': 'console.log({cursor})',
      'foreach': '{cursor}.forEach(() => {\n    \n})',
      'else': 'else {\n    {cursor}\n}',
      'return': 'return {cursor};',
    },
    'java': {
      'for': 'for ({cursor} = 0;  < ; ++) {\n    \n}',
      'if': 'if ({cursor}) {\n    \n}',
      'while': 'while ({cursor}) {\n    \n}',
      'println': 'System.out.println({cursor});',
      'print': 'System.out.print({cursor});',
      'class': 'public class {cursor} {\n    public static void main(String[] args) {\n        \n    }\n}',
      'method': 'public void {cursor}() {\n    \n}',
      'try': 'try {\n    {cursor}\n} catch () {\n    \n}',
      'switch': 'switch ({cursor}) {\n    case :\n        \n        break;\n    default:\n        \n        break;\n}',
      'private': 'private {cursor};',
      'public': 'public {cursor}',
      'static': 'static {cursor}',
      'import': 'import {cursor};',
      'new': 'new {cursor}()',
      'return': 'return {cursor};',
      'main': 'public static void main(String[] args) {\n    {cursor}\n}',
      'sout': 'System.out.println({cursor});',
    },
    'c': {
      'for': 'for ({cursor} = 0;  < ; ++) {\n    \n}',
      'if': 'if ({cursor}) {\n    \n}',
      'while': 'while ({cursor}) {\n    \n}',
      'include': '#include <{cursor}>',
      'define': '#define {cursor} ',
      'main': 'int main({cursor}) {\n    \n    return 0;\n}',
      'printf': 'printf("{cursor}");',
      'scanf': 'scanf("{cursor}", &);',
      'malloc': '{cursor} = malloc(sizeof() * );',
      'free': 'free({cursor});',
      'struct': 'typedef struct {\n    {cursor}\n} ;',
      'return': 'return {cursor};',
      'else': 'else {\n    {cursor}\n}',
    },
  };

  @override
  void initState() {
    super.initState();
    _previousText = widget.controller.text;
    _focusNode.addListener(_onFocusChange);
    _focusNode.onKeyEvent = _handleKeyEvent;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _autocompleteOverlay?.remove();
    _autocompleteOverlay = null;
    _focusNode.removeListener(_onFocusChange);
    _focusNode.onKeyEvent = null;
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    if (!_focusNode.hasFocus) {
      _removeAutocomplete();
    }
  }

  String? _matchingClose(String ch) => _closeMap[ch];

  void _onTextChanged() {
    if (!mounted) return;
    if (widget.readOnly) return;
    if (_isUpdatingText) {
      _isUpdatingText = false;
      return;
    }

    final text = widget.controller.text;
    final sel = widget.controller.selection;

    if (sel.isCollapsed && text.length == _previousText.length + 1) {
      final pos = sel.start;
      if (pos > 0) {
        final ch = text[pos - 1];

        if (widget.language == 'html' && ch == '>') {
          final beforeTag = text.substring(0, pos - 1);
          final lastOpen = beforeTag.lastIndexOf('<');
          if (lastOpen >= 0 && (lastOpen == 0 || beforeTag[lastOpen - 1] != '/')) {
            final afterLess = beforeTag.substring(lastOpen + 1);
            final tagName = afterLess.split(RegExp(r'[\s>]')).first;
            if (tagName.isNotEmpty && !tagName.startsWith('/') && !tagName.startsWith('!') && !_selfClosingTags.contains(tagName.toLowerCase())) {
              _isUpdatingText = true;
              final closeTag = '</$tagName>';
              final newText = '${text.substring(0, pos)}$closeTag${text.substring(pos)}';
              widget.controller.text = newText;
              widget.controller.selection = TextSelection.collapsed(offset: pos);
              _previousText = newText;
              widget.onChanged(newText);
              _updateSuggestions();
              return;
            }
          }
        }

        final close = _matchingClose(ch);
        if (close != null) {
          if (pos >= text.length || text[pos] != close) {
            _isUpdatingText = true;
            final newText = '${text.substring(0, pos)}$close${text.substring(pos)}';
            widget.controller.text = newText;
            widget.controller.selection = TextSelection.collapsed(offset: pos);
            _previousText = newText;
            widget.onChanged(newText);
            _updateSuggestions();
            return;
          }
        }
      }
    }

    _previousText = text;
    _updateSuggestions();
    widget.onChanged(text);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _handleEnterKey();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (_showAutocomplete && _suggestions.isNotEmpty) {
        _onAutocompleteSelected(_suggestions[0]);
        return KeyEventResult.handled;
      }
      _handleTabKey();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _handleBackspace();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _handleEnterKey() {
    final text = widget.controller.text;
    final pos = widget.controller.selection.start;

    final before = text.substring(0, pos);
    final lastNl = before.lastIndexOf('\n');
    final lineStart = lastNl < 0 ? 0 : lastNl + 1;
    final currentLine = text.substring(lineStart, pos);

    final indent = RegExp(r'^(\s*)').firstMatch(currentLine)?.group(1) ?? '';

    final trimmed = currentLine.trimRight();
    final extraIndent = (trimmed.endsWith('{') || (widget.language == 'python' && trimmed.endsWith(':'))) ? '    ' : '';

    final newText = '${text.substring(0, pos)}\n$indent$extraIndent${text.substring(pos)}';
    final newPos = pos + 1 + indent.length + extraIndent.length;

    widget.controller.text = newText;
    widget.controller.selection = TextSelection.collapsed(offset: newPos);
    _previousText = newText;
    widget.onChanged(newText);
  }

  void _handleTabKey() {
    final text = widget.controller.text;
    final pos = widget.controller.selection.start;
    final newText = '${text.substring(0, pos)}    ${text.substring(pos)}';
    widget.controller.text = newText;
    widget.controller.selection = TextSelection.collapsed(offset: pos + 4);
    _previousText = newText;
    widget.onChanged(newText);
  }

  void _handleBackspace() {
    final text = widget.controller.text;
    final pos = widget.controller.selection.start;
    if (pos <= 0 || !widget.controller.selection.isCollapsed) {
      _previousText = text;
      return;
    }

    final ch = text[pos - 1];
    final close = _matchingClose(ch);
    if (close != null && pos < text.length && text[pos] == close) {
      final newText = '${text.substring(0, pos - 1)}${text.substring(pos + 1)}';
      widget.controller.text = newText;
      widget.controller.selection = TextSelection.collapsed(offset: pos - 1);
      _previousText = newText;
      widget.onChanged(newText);
    } else {
      final newText = '${text.substring(0, pos - 1)}${text.substring(pos)}';
      widget.controller.text = newText;
      widget.controller.selection = TextSelection.collapsed(offset: pos - 1);
      _previousText = newText;
      widget.onChanged(newText);
    }
  }

  void _updateSuggestions() {
    if (!mounted) return;
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.start;
    if (cursorPos <= 0 || cursorPos > text.length) {
      _removeAutocomplete();
      return;
    }

    // HTML: typing < after a non-< character shows all HTML tags
    if (widget.language == 'html' && text[cursorPos - 1] == '<' && (cursorPos < 2 || text[cursorPos - 2] != '<')) {
      final suggestions = LanguageKeywords.getSuggestions(widget.language, '');
      if (suggestions.isNotEmpty) {
        setState(() {
          _suggestions = suggestions;
          _currentPrefix = '';
          _showAutocomplete = true;
        });
        _showAutocompleteOverlay();
        return;
      }
    }

    final wordBefore = _getWordBefore(text, cursorPos);
    if (wordBefore.length < 1) {
      _removeAutocomplete();
      return;
    }

    final suggestions = LanguageKeywords.getSuggestions(widget.language, wordBefore);
    if (suggestions.isEmpty || (suggestions.length == 1 && suggestions[0] == wordBefore)) {
      _removeAutocomplete();
      return;
    }

    setState(() {
      _suggestions = suggestions;
      _currentPrefix = wordBefore;
      _showAutocomplete = true;
    });

    _showAutocompleteOverlay();
  }

  String _getWordBefore(String text, int cursorPos) {
    int start = cursorPos - 1;
    while (start >= 0) {
      final ch = text[start];
      if (!RegExp(r'[a-zA-Z0-9_]').hasMatch(ch)) break;
      start--;
    }
    return text.substring(start + 1, cursorPos);
  }

  void _showAutocompleteOverlay() {
    if (!mounted) return;
    _removeAutocomplete();

    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.start;

    final textBeforeCursor = text.substring(0, cursorPos);
    final lineIndex = textBeforeCursor.split('\n').length - 1;
    final lastNewline = textBeforeCursor.lastIndexOf('\n');
    final colIndex = cursorPos - (lastNewline + 1);

    final overlay = Overlay.of(context);
    final renderObject = context.findRenderObject() as RenderBox?;
    if (renderObject == null) return;

    final editorPos = renderObject.localToGlobal(Offset.zero);
    final editorSize = renderObject.size;
    final lineHeight = 21.0;
    final lineNumberWidth = 48.0;

    final topOffset = (lineIndex + 1) * lineHeight + 40 + editorPos.dy;
    final leftOffset = lineNumberWidth + (colIndex * 8.4) - (_currentPrefix.length * 8.4) + editorPos.dx;

    _autocompleteOverlay = OverlayEntry(
      builder: (overlayContext) {
        if (!mounted) return const SizedBox.shrink();
        final viewSize = MediaQuery.of(overlayContext).size;
        final clampTop = (viewSize.height - 220.0).clamp(10.0, viewSize.height);
        final clampLeft = (viewSize.width - 270.0).clamp(10.0, viewSize.width);
        return Positioned(
          top: topOffset.clamp(10.0, clampTop),
          left: leftOffset.clamp(10.0, clampLeft),
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (event) {
              if (mounted && _autocompleteOverlay != null && _showAutocomplete) {
                _handleAutocompleteKey(event);
              }
            },
            child: AutocompleteOverlay(
              suggestions: _suggestions,
              prefix: _currentPrefix,
              position: Offset(leftOffset, topOffset),
              onSelected: _onAutocompleteSelected,
              onDismiss: _removeAutocomplete,
            ),
          ),
        );
      },
    );

    overlay.insert(_autocompleteOverlay!);
  }

  void _handleAutocompleteKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    // Let the overlay widget handle arrow keys, enter, tab, escape
  }

  void _onAutocompleteSelected(String suggestion) {
    if (!mounted) return;

    final expansions = _snippetExpansions[widget.language];
    final template = expansions?[suggestion];
    if (template != null) {
      _expandSnippet(suggestion, template);
      return;
    }

    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.start;
    final wordStart = cursorPos - _currentPrefix.length;

    final before = text.substring(0, wordStart);
    final after = text.substring(cursorPos);

    final newText = '$before$suggestion$after';
    final newCursorPos = wordStart + suggestion.length;

    widget.controller.text = newText;
    widget.controller.selection = TextSelection.collapsed(offset: newCursorPos);
    _previousText = newText;
    widget.onChanged(newText);

    _removeAutocomplete();
    _focusNode.requestFocus();
  }

  void _expandSnippet(String trigger, String template) {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.start;
    final wordStart = cursorPos - _currentPrefix.length;

    final before = text.substring(0, wordStart);
    final after = text.substring(cursorPos);

    final cursorIdx = template.indexOf('{cursor}');
    final expanded = template.replaceAll('{cursor}', '');
    final newText = '$before$expanded$after';
    final newPos = wordStart + (cursorIdx >= 0 ? cursorIdx : expanded.length);

    widget.controller.text = newText;
    widget.controller.selection = TextSelection.collapsed(offset: newPos);
    _previousText = newText;
    widget.onChanged(newText);

    _removeAutocomplete();
    _focusNode.requestFocus();
  }

  void _removeAutocomplete() {
    _autocompleteOverlay?.remove();
    _autocompleteOverlay = null;
    if (mounted) {
      setState(() {
        _showAutocomplete = false;
        _suggestions = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SideEditorTheme.backgroundDark,
        borderRadius: BorderRadius.circular(SideEditorTheme.borderRadius),
        boxShadow: SideEditorTheme.editorShadow,
      ),
      child: Column(
        children: [
          _buildEditorHeader(),
          Expanded(child: _buildEditorBody()),
        ],
      ),
    );
  }

  Widget _buildEditorHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SideEditorTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SideEditorTheme.borderRadius),
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.06),
            width: SideEditorTheme.borderWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: SideEditorTheme.errorRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: SideEditorTheme.accentOrange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: SideEditorTheme.successGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            widget.fileName ?? 'main${_getExtension(widget.language)}',
            style: const TextStyle(
              color: SideEditorTheme.lineNumberColor,
              fontSize: SideEditorTheme.tabBarFontSize,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          if (_showAutocomplete)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: SideEditorTheme.accentPurple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lightbulb, size: 10, color: SideEditorTheme.accentOrange),
                  SizedBox(width: 3),
                  Text(
                    'IntelliSense',
                    style: TextStyle(
                      color: SideEditorTheme.accentPurple,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            color: SideEditorTheme.lineNumberColor,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.controller.text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Code copied to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Copy code',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            color: SideEditorTheme.lineNumberColor,
            onPressed: widget.readOnly
                ? null
                : () {
                    widget.controller.clear();
                    widget.onChanged('');
                    _removeAutocomplete();
                  },
            tooltip: 'Clear code',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            width: constraints.maxWidth,
            child: CodeField(
              controller: widget.controller,
              focusNode: _focusNode,
              readOnly: widget.readOnly,
              lineNumberStyle: LineNumberStyle(
                width: 48,
                textAlign: TextAlign.right,
                margin: 8,
                textStyle: const TextStyle(
                  color: SideEditorTheme.lineNumberColor,
                  fontSize: SideEditorTheme.lineNumberFontSize,
                  fontFamily: 'monospace',
                ),
              ),
              textStyle: const TextStyle(
                color: SideEditorTheme.textDark,
                fontSize: SideEditorTheme.editorFontSize,
                fontFamily: 'monospace',
                height: 1.5,
              ),
              cursorColor: SideEditorTheme.accentGreen,
              background: SideEditorTheme.backgroundDark,
              decoration: BoxDecoration(
                color: SideEditorTheme.backgroundDark,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(SideEditorTheme.borderRadius),
                ),
              ),
              onChanged: (_) => _onTextChanged(),
              wrap: false,
              lineNumbers: true,
            ),
          ),
        );
      },
    );
  }

  String _getExtension(String language) {
    switch (language) {
      case 'python':
        return '.py';
      case 'javascript':
        return '.js';
      case 'html':
        return '.html';
      case 'cpp':
      case 'c':
        return '.c';
      case 'java':
        return '.java';
      default:
        return '.txt';
    }
  }
}
