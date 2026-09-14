import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

// Local imports
import 'cell_style.dart';
import 'native_bridge.dart';
import 'spreadsheet_toolbar.dart';

void main() {
  runApp(const StarlightEditorApp());
}

class StarlightEditorApp extends StatelessWidget {
  const StarlightEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Starlight Sheet Editor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const SpreadsheetEditorScreen(),
    );
  }
}

/// ==========================================
/// CALLABLE CLASS (The Engine Business Logic)
/// ==========================================
class SpreadsheetEngine {
  final int maxColumnsLimit = 1000;
  final int maxRowsLimit = 1000;
  final int columnChunkSize = 250;
  final int rowChunkSize = 250;

  /// The `call` method turns instances of this class into a callable function.
  /// It accepts the state manager and a callback to report status updates back to the UI.
  Future<void> call({
    required PlutoGridStateManager stateManager,
    required Function(String status) onStatusUpdate,
    required bool Function() isMounted,
    required Widget Function(dynamic) cellRenderer,
  }) async {
    // --- LOOP 1: GENERATE COLUMNS UP TO 1000 ---
    while (stateManager.columns.length - 1 < maxColumnsLimit) {
      if (!isMounted()) return;
      await Future.delayed(Duration.zero);
      if (!isMounted()) return;

      int currentCols = stateManager.columns.length - 1; // Subtract 1 due to the index column
      List<PlutoColumn> newColumns = [];
      int growBy = (currentCols + columnChunkSize > maxColumnsLimit)
          ? (maxColumnsLimit - currentCols)
          : columnChunkSize;

      for (int i = 1; i <= growBy; i++) {
        final int nextIndex = currentCols + i;
        final String colLetter = _getExcelColumnName(nextIndex);
        final String fieldName = 'col_${colLetter.toLowerCase()}';

        newColumns.add(PlutoColumn(
          title: colLetter,
          field: fieldName,
          type: PlutoColumnType.text(),
          width: 100,
          renderer: cellRenderer,
        ));

        for (var row in stateManager.rows) {
          row.cells[fieldName] = PlutoCell(value: '');
        }
      }

      if (newColumns.isNotEmpty) {
        stateManager.insertColumns(stateManager.columns.length, newColumns);
        onStatusUpdate("Loading columns: ${(stateManager.columns.length - 1)} / $maxColumnsLimit...");
      }
    }

    // --- LOOP 2: GENERATE ROWS UP TO 1000 ---
    while (stateManager.rows.length < maxRowsLimit) {
      if (!isMounted()) return;
      await Future.delayed(Duration.zero);
      if (!isMounted()) return;

      int currentRows = stateManager.rows.length;
      final List<PlutoRow> newRows = [];
      int growBy = (currentRows + rowChunkSize > maxRowsLimit)
          ? (maxRowsLimit - currentRows)
          : rowChunkSize;

      for (int i = 0; i < growBy; i++) {
        final Map<String, PlutoCell> newRowCells = {};
        for (var col in stateManager.columns) {
          newRowCells[col.field] = PlutoCell(value: '');
        }
        newRows.add(PlutoRow(cells: newRowCells));
      }

      if (newRows.isNotEmpty) {
        stateManager.insertRows(stateManager.rows.length, newRows);
        onStatusUpdate("Loading rows: ${stateManager.rows.length} / $maxRowsLimit...");
      }
    }

    onStatusUpdate("1000x1000 Matrix Active 🚀");
  }

  /// Converts integer index to Excel alphabetical column string (Base-26)
  String _getExcelColumnName(int index) {
    if (NativeBridge.instance.isAvailable) {
      return NativeBridge.instance.columnName(index);
    }
    String name = "";
    while (index > 0) {
      int modulo = (index - 1) % 26;
      name = String.fromCharCode(65 + modulo) + name;
      index = (index - modulo) ~/ 26;
    }
    return name;
  }
}

/// ==========================================
/// FLUTTER USER INTERFACE LAYER
/// ==========================================
/// Simple model for an image placed over the grid
class _ImageOverlay {
  final String dataUrl;
  double x;
  double y;
  double width;
  double height;

  _ImageOverlay({
    required this.dataUrl,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class SpreadsheetEditorScreen extends StatefulWidget {
  const SpreadsheetEditorScreen({super.key});

  @override
  State<SpreadsheetEditorScreen> createState() => _SpreadsheetEditorScreenState();
}

class _SpreadsheetEditorScreenState extends State<SpreadsheetEditorScreen> {
  // Instantiating our callable engine instance
  final SpreadsheetEngine _matrixLoader = SpreadsheetEngine();

  PlutoGridStateManager? stateManager;
  static const double _defaultRowHeight = 35.0;
  final Map<int, double> _rowHeights = {};

  double get _effectiveRowHeight {
    if (_rowHeights.isEmpty) return _defaultRowHeight;
    return _rowHeights.values.reduce((a, b) => a > b ? a : b);
  }

  // Image overlays placed over the grid
  final List<_ImageOverlay> _overlays = [];

  // ValueNotifiers to update only specific widgets without rebuilding the entire grid
  final ValueNotifier<String> _currentCellValueNotifier = ValueNotifier<String>("");
  final ValueNotifier<String> _currentCellCoordinateNotifier = ValueNotifier<String>("A1");
  final ValueNotifier<String> _loadingStatusNotifier = ValueNotifier<String>("Ready");
  final ValueNotifier<int> _styleVersionNotifier = ValueNotifier<int>(0);

  final List<PlutoColumn> columns = [];
  final List<PlutoRow> rows = [];

  // Map to store styling metadata for cells (key format: 'columnField:rowIdx')
  final Map<String, CellStyle> _cellStyles = {};

  CellStyle _getCellStyle(String field, int rowIdx) {
    return _cellStyles['$field:$rowIdx'] ?? const CellStyle();
  }

  void _applyStyleToSelected({
    bool? isBold,
    bool? isItalic,
    CellUnderlineStyle? underlineStyle,
    bool? hasBulletPoint,
    Object? fontFamily,
    Object? fontSize,
    Color? textColor,
    Color? backgroundColor,
    PlutoColumnTextAlign? textAlign,
  }) {
    if (stateManager == null) return;

    final selectedPositions = stateManager!.currentSelectingPositionList;

    void applyToCell(String field, int rowIdx) {
      final key = '$field:$rowIdx';
      final currentStyle = _getCellStyle(field, rowIdx);
      _cellStyles[key] = currentStyle.copyWith(
        isBold: isBold,
        isItalic: isItalic,
        underlineStyle: underlineStyle,
        hasBulletPoint: hasBulletPoint,
        fontFamily: fontFamily,
        fontSize: fontSize,
        textColor: textColor,
        backgroundColor: backgroundColor,
        textAlign: textAlign,
      );
    }

    if (selectedPositions.isNotEmpty) {
      for (var pos in selectedPositions) {
        if (pos.rowIdx != null && pos.field != null) {
          applyToCell(pos.field!, pos.rowIdx!);
        }
      }
    } else if (stateManager!.currentCell != null && stateManager!.currentCellPosition != null) {
      final pos = stateManager!.currentCellPosition!;
      if (pos.rowIdx != null && pos.columnIdx != null) {
        final field = stateManager!.columns[pos.columnIdx!].field;
        applyToCell(field, pos.rowIdx!);
      }
    }

    // Force redraw of cell renderers
    _styleVersionNotifier.value++;
    stateManager!.notifyListeners();
  }

  void _changeCurrentColumnWidth(double widthDelta) {
    if (stateManager == null || stateManager!.currentColumn == null) return;
    stateManager!.resizeColumn(stateManager!.currentColumn!, widthDelta);
  }

  double _getCurrentRowHeight() {
    final rowIdx = stateManager?.currentRowIdx;
    if (rowIdx != null && _rowHeights.containsKey(rowIdx)) {
      return _rowHeights[rowIdx]!;
    }
    return _defaultRowHeight;
  }

  void _adjustSelectedRowHeight(double heightDelta) {
    final rowIdx = stateManager?.currentRowIdx;
    if (rowIdx == null) return;
    final current = _rowHeights[rowIdx] ?? _defaultRowHeight;
    final clamped = (current + heightDelta).clamp(20.0, 500.0);
    _rowHeights[rowIdx] = clamped;
    setState(() {});
    stateManager!.notifyListeners();
  }

  EdgeInsets _cellPadding(int rowIdx) {
    final rowH = _rowHeights[rowIdx];
    if (rowH == null) return const EdgeInsets.symmetric(horizontal: 8);
    final globalH = _effectiveRowHeight;
    if (rowH >= globalH) return const EdgeInsets.symmetric(horizontal: 8);
    final totalV = globalH - rowH;
    return EdgeInsets.symmetric(horizontal: 8, vertical: totalV / 2);
  }

  void _importImage() {
    final input = html.FileUploadInputElement();
    input.accept = 'image/*';
    input.click();
    input.onChange.listen((_) {
      final files = input.files;
      if (files == null || files.isEmpty) return;
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoadEnd.listen((_) {
        final dataUrl = reader.result as String?;
        if (dataUrl == null || stateManager == null) return;
        final colIdx = stateManager!.currentCellPosition?.columnIdx ?? 0;
        final rowIdx = stateManager!.currentCellPosition?.rowIdx ?? 0;
        final x = colIdx * 100.0;
        final y = rowIdx * _effectiveRowHeight;
        setState(() {
          _overlays.add(_ImageOverlay(
            dataUrl: dataUrl,
            x: x,
            y: y,
            width: 150,
            height: 100,
          ));
        });
      });
    });
  }

  Widget _buildOverlayLayer() {
    if (_overlays.isEmpty) return const SizedBox.shrink();
    return Stack(
      children: _overlays.map((o) {
        return Positioned(
          left: o.x,
          top: o.y,
          child: GestureDetector(
            onDoubleTap: () {
              setState(() {
                _overlays.remove(o);
              });
            },
            onPanUpdate: (details) {
              setState(() {
                o.x += details.delta.dx;
                o.y += details.delta.dy;
              });
            },
            child: Container(
              width: o.width,
              height: o.height,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Image.network(o.dataUrl, fit: BoxFit.contain),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Sorting ────────────────────────────────────────────────
  void _showSortDialog(BuildContext context) {
    if (stateManager == null) return;
    showDialog(
      context: context,
      builder: (ctx) => _SortDialog(
        onSort: (ascending, byRows) => _performSort(ascending, byRows),
      ),
    );
  }

  void _performSort(bool ascending, bool byRows) {
    if (stateManager == null) return;
    final sm = stateManager!;

    if (byRows) {
      // Row-wise sort: sort rows by the first selected column's values
      final posList = sm.currentSelectingPositionList;
      String? sortField;
      if (posList.isNotEmpty) {
        sortField = posList.first.field;
      } else if (sm.currentCellPosition != null) {
        final colIdx = sm.currentCellPosition!.columnIdx!;
        sortField = sm.columns[colIdx].field;
      }
      if (sortField == null || sortField == 'row_index_number') return;

      sm.refRows.sort((a, b) {
        final va = a.cells[sortField]?.value?.toString() ?? '';
        final vb = b.cells[sortField]?.value?.toString() ?? '';
        final cmp = _compareValues(va, vb);
        return ascending ? cmp : -cmp;
      });
    } else {
      // Column-wise sort: sort columns by the first selected row's values
      int? sortRowIdx;
      final posList = sm.currentSelectingPositionList;
      if (posList.isNotEmpty) {
        sortRowIdx = posList.first.rowIdx;
      } else if (sm.currentCellPosition != null) {
        sortRowIdx = sm.currentCellPosition!.rowIdx;
      }
      if (sortRowIdx == null) return;

      // Collect data columns (exclude row_index_number)
      final dataCols = <_SortCol>[];
      for (var col in sm.refColumns) {
        if (col.field == 'row_index_number') continue;
        final val = sm.refRows[sortRowIdx]
            .cells[col.field]?.value?.toString() ?? '';
        dataCols.add(_SortCol(col, val));
      }

      dataCols.sort((a, b) {
        final cmp = _compareValues(a.sortKey, b.sortKey);
        return ascending ? cmp : -cmp;
      });

      // Move columns to sorted positions
      // Process from last to first to keep earlier indices stable
      for (int i = dataCols.length - 1; i >= 0; i--) {
        final targetPos = i + 1; // +1 to skip row_index_number at index 0
        final col = dataCols[i].column;
        final currentPos = sm.refColumns.indexOf(col);
        if (currentPos != targetPos) {
          sm.moveColumn(
            column: col,
            targetColumn: sm.refColumns[targetPos],
          );
        }
      }
      return; // moveColumn already calls notifyListeners internally
    }

    setState(() {});
    sm.notifyListeners();
  }

  int _compareValues(String a, String b) {
    if (NativeBridge.instance.isAvailable) {
      return NativeBridge.instance.compareValues(a, b);
    }
    final da = double.tryParse(a);
    final db = double.tryParse(b);
    if (da != null && db != null) return da.compareTo(db);
    return a.compareTo(b);
  }

  Widget _buildCellRenderer(dynamic rendererContext) {
    final cell = rendererContext.cell;
    final rowIdx = rendererContext.rowIdx;
    final column = rendererContext.column;
    final rawValue = cell.value?.toString() ?? '';
    final PlutoGridStateManager sm = rendererContext.stateManager;
    final bool isCurrent = sm.isCurrentCell(cell);

    return ValueListenableBuilder<int>(
      valueListenable: _styleVersionNotifier,
      builder: (context, version, _) {
        final style = _getCellStyle(column.field, rowIdx);

        final displayValue = style.hasBulletPoint && rawValue.isNotEmpty
            ? '• $rawValue'
            : rawValue;

        Alignment alignment = Alignment.center;
        if (style.textAlign == PlutoColumnTextAlign.left) {
          alignment = Alignment.centerLeft;
        } else if (style.textAlign == PlutoColumnTextAlign.right) {
          alignment = Alignment.centerRight;
        }

        TextDecoration decoration = TextDecoration.none;
        TextDecorationStyle decorationStyle = TextDecorationStyle.solid;
        if (style.underlineStyle != CellUnderlineStyle.none) {
          decoration = TextDecoration.underline;
          switch (style.underlineStyle) {
            case CellUnderlineStyle.double:
              decorationStyle = TextDecorationStyle.double;
              break;
            case CellUnderlineStyle.dotted:
              decorationStyle = TextDecorationStyle.dotted;
              break;
            case CellUnderlineStyle.dashed:
              decorationStyle = TextDecorationStyle.dashed;
              break;
            default:
              decorationStyle = TextDecorationStyle.solid;
          }
        }

        Widget cellContent = Container(
          width: double.infinity,
          height: double.infinity,
          alignment: alignment,
          padding: _cellPadding(rowIdx),
          color: style.backgroundColor,
          child: Text(
            displayValue,
            style: TextStyle(
              fontFamily: style.fontFamily,
              fontSize: style.fontSize,
              fontWeight: style.isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle: style.isItalic ? FontStyle.italic : FontStyle.normal,
              decoration: decoration,
              decorationStyle: decorationStyle,
              color: style.textColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );

        if (isCurrent) {
          cellContent = Container(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: [
                cellContent,
                Positioned(
                  right: 0,
                  bottom: 0,
                  child:                   Listener(
                    onPointerDown: (event) {
                      sm.setCurrentCell(cell, rowIdx);
                      sm.eventManager!.addEvent(
                        PlutoGridCellGestureEvent(
                          gestureType: PlutoGridGestureType.onLongPressStart,
                          offset: event.position,
                          cell: cell,
                          column: column,
                          rowIdx: rowIdx,
                        ),
                      );
                    },
                    onPointerMove: (event) {
                      sm.eventManager!.addEvent(
                        PlutoGridCellGestureEvent(
                          gestureType: PlutoGridGestureType.onLongPressMoveUpdate,
                          offset: event.position,
                          cell: cell,
                          column: column,
                          rowIdx: rowIdx,
                        ),
                      );
                    },
                    onPointerUp: (event) {
                      sm.eventManager!.addEvent(
                        PlutoGridCellGestureEvent(
                          gestureType: PlutoGridGestureType.onLongPressEnd,
                          offset: event.position,
                          cell: cell,
                          column: column,
                          rowIdx: rowIdx,
                        ),
                      );
                    },
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A73E8),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return cellContent;
      },
    );
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  @override
  void initState() {
    super.initState();
    _initializeSpreadsheet(initialColumns: 26, initialRows: 50);
  }

  @override
  void dispose() {
    _currentCellValueNotifier.dispose();
    _currentCellCoordinateNotifier.dispose();
    _loadingStatusNotifier.dispose();
    super.dispose();
  }

  void _initializeSpreadsheet({required int initialColumns, required int initialRows}) {
    // Uses a dynamic custom cell renderer to safely print row indexes
    columns.add(
      PlutoColumn(
        title: '',
        field: 'row_index_number',
        type: PlutoColumnType.text(),
        readOnly: true,
        width: 55,
        enableContextMenu: false,
        enableDropToResize: false,
        enableColumnDrag: false,
        enableEditingMode: false,
        frozen: PlutoColumnFrozen.start,
        textAlign: PlutoColumnTextAlign.center,
        renderer: (rendererContext) {
          return Container(
            alignment: Alignment.center,
            child: Text(
              '${rendererContext.rowIdx + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          );
        },
      ),
    );

    // Generate clean alphabetic column collection definitions using temporary string logic
    // Generate clean alphabetic column collection definitions using temporary string logic
    for (int i = 1; i <= initialColumns; i++) {
      final colLetter = _getExcelColumnNameFromIndex(i);
      columns.add(
        PlutoColumn(
          title: colLetter,
          field: 'col_${colLetter.toLowerCase()}',
          type: PlutoColumnType.text(),
          width: 100,
          textAlign: PlutoColumnTextAlign.center, // <-- CENTER VIEW MODE TEXT
          cellPadding: EdgeInsets.zero,           // <-- REMOVE PADDING FOR EDIT MODE
          renderer: _buildCellRenderer,
        ),
      );
    }

    // Build the underlying data matrix maps
    for (int r = 1; r <= initialRows; r++) {
      final Map<String, PlutoCell> rowCells = {};
      for (var col in columns) {
        rowCells[col.field] = PlutoCell(value: '');
      }
      rows.add(PlutoRow(cells: rowCells));
    }
  }

  String _getExcelColumnNameFromIndex(int index) {
    if (NativeBridge.instance.isAvailable) {
      return NativeBridge.instance.columnName(index);
    }
    String name = "";
    while (index > 0) {
      int modulo = (index - 1) % 26;
      name = String.fromCharCode(65 + modulo) + name;
      index = (index - modulo) ~/ 26;
    }
    return name;
  }

  void _exportCurrentSheet() {
    if (stateManager == null) return;
    final xlsio.Workbook workbook = xlsio.Workbook();
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.showGridlines = true;

    final currentColumns = stateManager!.columns.where((c) => c.field != 'row_index_number').toList();
    final currentRows = stateManager!.rows;

    // Export column widths
    for (int colIndex = 0; colIndex < currentColumns.length; colIndex++) {
      final column = currentColumns[colIndex];
      final double excelWidth = column.width / 7.5;
      sheet.getRangeByIndex(1, colIndex + 1).columnWidth = excelWidth;
    }

    for (int rowIndex = 0; rowIndex < currentRows.length; rowIndex++) {
      final row = currentRows[rowIndex];
      for (int colIndex = 0; colIndex < currentColumns.length; colIndex++) {
        final fieldName = currentColumns[colIndex].field;
        final cellValue = row.cells[fieldName]?.value?.toString() ?? "";
        
        final cellRange = sheet.getRangeByIndex(rowIndex + 1, colIndex + 1);
        if (cellValue.isNotEmpty) {
          cellRange.setValue(cellValue);
        }

        // Apply formatting (styles) to the exported Excel workbook
        final style = _getCellStyle(fieldName, rowIndex);
        final bool hasStyle = style.isBold ||
            style.isItalic ||
            style.underlineStyle != CellUnderlineStyle.none ||
            style.textColor != Colors.black ||
            style.backgroundColor != Colors.transparent ||
            style.textAlign != PlutoColumnTextAlign.center;

        if (hasStyle) {
          final xlsio.Style cellStyle = workbook.styles.add('style_${fieldName}_$rowIndex');
          
          if (style.isBold) cellStyle.bold = true;
          if (style.isItalic) cellStyle.italic = true;
          if (style.underlineStyle != CellUnderlineStyle.none) cellStyle.underline = true;
          
          if (style.textColor != Colors.black) {
            cellStyle.fontColor = _colorToHex(style.textColor);
          }
          if (style.backgroundColor != Colors.transparent) {
            cellStyle.backColor = _colorToHex(style.backgroundColor);
          }
          
          if (style.textAlign == PlutoColumnTextAlign.left) {
            cellStyle.hAlign = xlsio.HAlignType.left;
          } else if (style.textAlign == PlutoColumnTextAlign.right) {
            cellStyle.hAlign = xlsio.HAlignType.right;
          } else if (style.textAlign == PlutoColumnTextAlign.center) {
            cellStyle.hAlign = xlsio.HAlignType.center;
          }
          
          cellRange.cellStyle = cellStyle;
        }
      }
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute("download", "StarlightSheet.starlight")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Starlight Sheet Editor 📊'),
        backgroundColor: Colors.teal.shade100,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt),
            tooltip: 'Export .starlight File',
            onPressed: _exportCurrentSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Formula bar / Progress indicator layout strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: _currentCellCoordinateNotifier,
                  builder: (context, coordinate, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Text(
                        coordinate,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                const Text('fx', style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ValueListenableBuilder<String>(
                      valueListenable: _currentCellValueNotifier,
                      builder: (context, cellValue, _) {
                        return Text(
                          cellValue,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ValueListenableBuilder<String>(
                  valueListenable: _loadingStatusNotifier,
                  builder: (context, status, _) {
                    return Chip(
                      label: Text(status, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      backgroundColor: Colors.amber.shade100,
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                    );
                  },
                ),
              ],
            ),
          ),

          // Formatting Toolbar
          if (stateManager != null)
            SpreadsheetToolbar(
              stateManager: stateManager!,
              cellStyles: _cellStyles,
              onStyleChanged: ({
                bool? isBold,
                bool? isItalic,
                CellUnderlineStyle? underlineStyle,
                bool? hasBulletPoint,
                Object? fontFamily,
                Object? fontSize,
                Color? textColor,
                Color? backgroundColor,
                PlutoColumnTextAlign? textAlign,
              }) {
                _applyStyleToSelected(
                  isBold: isBold,
                  isItalic: isItalic,
                  underlineStyle: underlineStyle,
                  hasBulletPoint: hasBulletPoint,
                  fontFamily: fontFamily,
                  fontSize: fontSize,
                  textColor: textColor,
                  backgroundColor: backgroundColor,
                  textAlign: textAlign,
                );
              },
              onWidthAdjusted: (widthDelta) {
                _changeCurrentColumnWidth(widthDelta);
              },
              onImageImported: _importImage,
              onSortClicked: () => _showSortDialog(context),
              rowHeight: _getCurrentRowHeight(),
              onHeightAdjusted: (heightDelta) {
                _adjustSelectedRowHeight(heightDelta);
              },
            ),

          // Main data spreadsheet engine widget
          Expanded(
            child: Stack(
              children: [
                PlutoGrid(
                  columns: columns,
                  rows: rows,
              onChanged: (PlutoGridOnChangedEvent event) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _currentCellValueNotifier.value = event.value.toString();
                });
              },
              onLoaded: (PlutoGridOnLoadedEvent event) {
                setState(() {
                  stateManager = event.stateManager;
                });
                stateManager!.setSelectingMode(PlutoGridSelectingMode.cell);

                stateManager!.addListener(() {
                  if (stateManager!.currentCell != null) {
                    final int colIdx = stateManager!.currentCellPosition!.columnIdx!;
                    final int rowIdx = stateManager!.currentCellPosition!.rowIdx!;
                    final String columnName = stateManager!.columns[colIdx].title;

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _currentCellCoordinateNotifier.value = '$columnName${rowIdx + 1}';
                      _currentCellValueNotifier.value = stateManager!.currentCell!.value?.toString() ?? "";
                    });
                  }
                });

                // Here we call the instance of our class directly like a function!
                _matrixLoader(
                  stateManager: stateManager!,
                  onStatusUpdate: (status) {
                    _loadingStatusNotifier.value = status;
                  },
                  isMounted: () => mounted,
                  cellRenderer: _buildCellRenderer,
                );
              },
              configuration: PlutoGridConfiguration(
                scrollbar: const PlutoGridScrollbarConfig(
                  isAlwaysShown: true,
                  draggableScrollbar: true,
                  scrollbarThickness: 8,
                  scrollbarThicknessWhileDragging: 12,
                ),
                style: PlutoGridStyleConfig(
                  gridBorderColor: Colors.black12,
                  borderColor: Colors.black12,
                  activatedColor: const Color(0x221A73E8),
                  activatedBorderColor: const Color(0xFF1A73E8),
                  rowHeight: _effectiveRowHeight,
                  columnHeight: 32,
                ),
              ),
            ),
            _buildOverlayLayer(),
          ],
        ),
      ),
      ],
    ),
  );
  }
}

/// Model for column-wise sorting
class _SortCol {
  final PlutoColumn column;
  final String sortKey;
  _SortCol(this.column, this.sortKey);
}

/// Dialog for choosing sort options
class _SortDialog extends StatelessWidget {
  final void Function(bool ascending, bool byRows) onSort;

  const _SortDialog({required this.onSort});

  @override
  Widget build(BuildContext context) {
    bool ascending = true;
    bool byRows = true;
    return StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Sort Selected Cells'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sort type:'),
            RadioListTile<bool>(
              title: const Text('Ascending'),
              value: true,
              groupValue: ascending,
              onChanged: (v) => setDialogState(() => ascending = v!),
            ),
            RadioListTile<bool>(
              title: const Text('Descending'),
              value: false,
              groupValue: ascending,
              onChanged: (v) => setDialogState(() => ascending = v!),
            ),
            const Divider(),
            const Text('Sort direction:'),
            RadioListTile<bool>(
              title: const Text('Row-wise (by column)'),
              value: true,
              groupValue: byRows,
              onChanged: (v) => setDialogState(() => byRows = v!),
            ),
            RadioListTile<bool>(
              title: const Text('Column-wise (by row)'),
              value: false,
              groupValue: byRows,
              onChanged: (v) => setDialogState(() => byRows = v!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onSort(ascending, byRows);
            },
            child: const Text('Sort'),
          ),
        ],
      ),
    );
  }
}
