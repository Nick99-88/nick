import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'cell_style.dart';

/// Available font families for the cell font picker
const List<String> kAvailableFonts = [
  'Default',
  'Roboto',
  'Inter',
  'Georgia',
  'Courier New',
  'Arial',
  'Times New Roman',
  'Verdana',
  'Trebuchet MS',
];

/// Available font sizes for the cell font size picker
const List<int> kAvailableFontSizes = [
  5, 6, 7, 8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72,
];

class SpreadsheetToolbar extends StatefulWidget {
  final PlutoGridStateManager stateManager;
  final Map<String, CellStyle> cellStyles;
  final Function({
    bool? isBold,
    bool? isItalic,
    CellUnderlineStyle? underlineStyle,
    bool? hasBulletPoint,
    Object? fontFamily,
    Object? fontSize,
    Color? textColor,
    Color? backgroundColor,
    PlutoColumnTextAlign? textAlign,
  }) onStyleChanged;
  final Function(double widthDelta) onWidthAdjusted;
  final VoidCallback? onImageImported;
  final VoidCallback? onSortClicked;
  final double rowHeight;
  final Function(double heightDelta) onHeightAdjusted;

  const SpreadsheetToolbar({
    super.key,
    required this.stateManager,
    required this.cellStyles,
    required this.onStyleChanged,
    required this.onWidthAdjusted,
    this.onImageImported,
    this.onSortClicked,
    required this.rowHeight,
    required this.onHeightAdjusted,
  });

  @override
  State<SpreadsheetToolbar> createState() => _SpreadsheetToolbarState();
}

class _SpreadsheetToolbarState extends State<SpreadsheetToolbar> {
  @override
  void initState() {
    super.initState();
    widget.stateManager.addListener(_onGridChanged);
  }

  @override
  void dispose() {
    widget.stateManager.removeListener(_onGridChanged);
    super.dispose();
  }

  void _onGridChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  CellStyle _getCurrentCellStyle() {
    final sm = widget.stateManager;
    if (sm.currentCell == null || sm.currentCellPosition == null) return const CellStyle();
    final pos = sm.currentCellPosition!;
    final col = sm.columns[pos.columnIdx!];
    final key = '${col.field}:${pos.rowIdx}';
    return widget.cellStyles[key] ?? const CellStyle();
  }

  @override
  Widget build(BuildContext context) {
    final style = _getCurrentCellStyle();
    final currentColumn = widget.stateManager.currentColumn;
    final columnWidth = currentColumn?.width ?? 100.0;
    final currentFont = style.fontFamily ?? 'Default';
    final currentFontSize = style.fontSize ?? 11;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // ── Font Family Picker ──────────────────────────
            PopupMenuButton<String>(
              tooltip: 'Font Family',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentFont,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: currentFont == 'Default' ? null : currentFont,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
              itemBuilder: (context) => kAvailableFonts
                  .map((font) => PopupMenuItem<String>(
                        value: font,
                        height: 36,
                        child: Text(
                          font,
                          style: TextStyle(
                            fontFamily: font == 'Default' ? null : font,
                            fontSize: 13,
                          ),
                        ),
                      ))
                  .toList(),
              onSelected: (font) => widget.onStyleChanged(
                fontFamily: font == 'Default' ? null : font,
              ),
            ),

            const SizedBox(width: 4),

            // ── Font Size Picker ────────────────────────────
            PopupMenuButton<int>(
              tooltip: 'Font Size',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${currentFontSize}pt',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 16),
                  ],
                ),
              ),
              itemBuilder: (context) => kAvailableFontSizes
                  .map((size) => PopupMenuItem<int>(
                        value: size,
                        height: 32,
                        child: Text(
                          '${size}pt',
                          style: TextStyle(fontSize: 13.0, fontWeight: size == currentFontSize ? FontWeight.bold : FontWeight.normal),
                        ),
                      ))
                  .toList(),
              onSelected: (size) => widget.onStyleChanged(
                fontSize: size == 11 ? null : size.toDouble(),
              ),
            ),

            const _ToolbarDivider(),

            // ── Text Styles ─────────────────────────────────
            _ToolbarToggleButton(
              icon: Icons.format_bold,
              isSelected: style.isBold,
              tooltip: 'Bold',
              onPressed: () => widget.onStyleChanged(isBold: !style.isBold),
            ),
            _ToolbarToggleButton(
              icon: Icons.format_italic,
              isSelected: style.isItalic,
              tooltip: 'Italic',
              onPressed: () => widget.onStyleChanged(isItalic: !style.isItalic),
            ),

            // Underline style popup
            _UnderlinePickerButton(
              currentStyle: style.underlineStyle,
              onSelected: (s) => widget.onStyleChanged(underlineStyle: s),
            ),

            // Bullet point toggle
            _ToolbarToggleButton(
              icon: Icons.format_list_bulleted,
              isSelected: style.hasBulletPoint,
              tooltip: 'Bullet Point',
              onPressed: () => widget.onStyleChanged(hasBulletPoint: !style.hasBulletPoint),
            ),

            const _ToolbarDivider(),

            // ── Alignment ───────────────────────────────────
            _ToolbarToggleButton(
              icon: Icons.format_align_left,
              isSelected: style.textAlign == PlutoColumnTextAlign.left,
              tooltip: 'Align Left',
              onPressed: () => widget.onStyleChanged(textAlign: PlutoColumnTextAlign.left),
            ),
            _ToolbarToggleButton(
              icon: Icons.format_align_center,
              isSelected: style.textAlign == PlutoColumnTextAlign.center,
              tooltip: 'Align Center',
              onPressed: () => widget.onStyleChanged(textAlign: PlutoColumnTextAlign.center),
            ),
            _ToolbarToggleButton(
              icon: Icons.format_align_right,
              isSelected: style.textAlign == PlutoColumnTextAlign.right,
              tooltip: 'Align Right',
              onPressed: () => widget.onStyleChanged(textAlign: PlutoColumnTextAlign.right),
            ),

            const _ToolbarDivider(),

            // ── Image Import ─────────────────────────────────
            _ToolbarToggleButton(
              icon: Icons.image,
              isSelected: false,
              tooltip: 'Insert Image',
              onPressed: () => widget.onImageImported?.call(),
            ),

            // ── Sort ─────────────────────────────────────────
            _ToolbarToggleButton(
              icon: Icons.sort,
              isSelected: false,
              tooltip: 'Sort Selected Cells',
              onPressed: () => widget.onSortClicked?.call(),
            ),

            const _ToolbarDivider(),

            // ── Colors ──────────────────────────────────────
            _ToolbarColorButton(
              icon: Icons.format_color_text,
              currentColor: style.textColor,
              tooltip: 'Text Color',
              onColorSelected: (c) => widget.onStyleChanged(textColor: c),
              colors: const [
                Colors.black, Colors.red, Colors.blue,
                Colors.green, Colors.amber, Colors.purple, Colors.teal,
              ],
            ),
            _ToolbarColorButton(
              icon: Icons.format_color_fill,
              currentColor: style.backgroundColor,
              tooltip: 'Fill Color',
              onColorSelected: (c) => widget.onStyleChanged(backgroundColor: c),
              colors: [
                Colors.transparent,
                Colors.amber.shade100, Colors.teal.shade100,
                Colors.blue.shade100, Colors.red.shade100,
                Colors.green.shade100, Colors.purple.shade100,
              ],
            ),

            const _ToolbarDivider(),

            // ── Column Width & Row Height ────────────────────
            if (currentColumn != null && currentColumn.field != 'row_index_number') ...[
              const Icon(Icons.swap_horiz, size: 16, color: Colors.black54),
              const SizedBox(width: 4),
              Text(
                '${currentColumn.title}: ${columnWidth.toStringAsFixed(0)}px',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 2),
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                tooltip: 'Decrease Width',
                onPressed: columnWidth > 40 ? () => widget.onWidthAdjusted(-15) : null,
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                tooltip: 'Increase Width',
                onPressed: columnWidth < 500 ? () => widget.onWidthAdjusted(15) : null,
              ),
              const SizedBox(width: 8),
              const Icon(Icons.swap_vert, size: 16, color: Colors.black54),
              const SizedBox(width: 4),
              Text(
                '${widget.rowHeight.toStringAsFixed(0)}px',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 2),
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                tooltip: 'Decrease Row Height',
                onPressed: widget.rowHeight > 20 ? () => widget.onHeightAdjusted(-5) : null,
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                tooltip: 'Increase Row Height',
                onPressed: () => widget.onHeightAdjusted(5),
              ),
            ] else ...[
              const Text(
                'Select a column to adjust size',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black45),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Underline Picker Button
// ─────────────────────────────────────────────────────────────────────────────
class _UnderlinePickerButton extends StatelessWidget {
  final CellUnderlineStyle currentStyle;
  final Function(CellUnderlineStyle) onSelected;

  const _UnderlinePickerButton({
    required this.currentStyle,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentStyle != CellUnderlineStyle.none;
    return PopupMenuButton<CellUnderlineStyle>(
      tooltip: 'Underline Style',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? Colors.teal.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.format_underlined, size: 18,
                color: isActive ? Colors.teal.shade800 : Colors.black87),
            Icon(Icons.arrow_drop_down, size: 12,
                color: isActive ? Colors.teal.shade800 : Colors.black54),
          ],
        ),
      ),
      itemBuilder: (context) => [
        _underlineItem(CellUnderlineStyle.none, 'None', ''),
        _underlineItem(CellUnderlineStyle.single, 'Single', '───────'),
        _underlineItem(CellUnderlineStyle.double, 'Double', '═══════'),
        _underlineItem(CellUnderlineStyle.dotted, 'Dotted', '·······'),
        _underlineItem(CellUnderlineStyle.dashed, 'Dashed', '- - - -'),
      ],
      onSelected: onSelected,
    );
  }

  PopupMenuItem<CellUnderlineStyle> _underlineItem(
      CellUnderlineStyle value, String label, String preview) {
    final isSelected = currentStyle == value;
    return PopupMenuItem<CellUnderlineStyle>(
      value: value,
      height: 38,
      child: Row(
        children: [
          if (isSelected)
            Icon(Icons.check, size: 14, color: Colors.teal.shade700)
          else
            const SizedBox(width: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                if (preview.isNotEmpty)
                  Text(preview,
                      style: const TextStyle(fontSize: 11, color: Colors.black54, letterSpacing: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper widgets
// ─────────────────────────────────────────────────────────────────────────────
class _ToolbarToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final String tooltip;
  final VoidCallback onPressed;

  const _ToolbarToggleButton({
    required this.icon,
    required this.isSelected,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal.shade100 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: IconButton(
          icon: Icon(icon, size: 18, color: isSelected ? Colors.teal.shade800 : Colors.black87),
          onPressed: onPressed,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _ToolbarColorButton extends StatelessWidget {
  final IconData icon;
  final Color currentColor;
  final String tooltip;
  final Function(Color) onColorSelected;
  final List<Color> colors;

  const _ToolbarColorButton({
    required this.icon,
    required this.currentColor,
    required this.tooltip,
    required this.onColorSelected,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Color>(
      tooltip: tooltip,
      icon: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          Container(
            height: 3,
            width: 16,
            color: currentColor == Colors.transparent ? Colors.transparent : currentColor,
            margin: const EdgeInsets.only(bottom: 2),
          ),
        ],
      ),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
      onSelected: onColorSelected,
      itemBuilder: (context) => colors.map((color) {
        final isClear = color == Colors.transparent;
        return PopupMenuItem<Color>(
          value: color,
          height: 36,
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: isClear
                    ? const Center(child: Icon(Icons.close, size: 12, color: Colors.red))
                    : null,
              ),
              const SizedBox(width: 8),
              Text(isClear ? 'Clear' : _colorName(color),
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _colorName(Color color) {
    if (color == Colors.black) return 'Black';
    if (color == Colors.red) return 'Red';
    if (color == Colors.blue) return 'Blue';
    if (color == Colors.green) return 'Green';
    if (color == Colors.amber) return 'Amber';
    if (color == Colors.purple) return 'Purple';
    if (color == Colors.teal) return 'Teal';
    if (color.value == Colors.amber.shade100.value) return 'Soft Amber';
    if (color.value == Colors.teal.shade100.value) return 'Soft Teal';
    if (color.value == Colors.blue.shade100.value) return 'Soft Blue';
    if (color.value == Colors.red.shade100.value) return 'Soft Red';
    if (color.value == Colors.green.shade100.value) return 'Soft Green';
    if (color.value == Colors.purple.shade100.value) return 'Soft Purple';
    return 'Color';
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: Colors.grey.shade300,
      margin: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}
