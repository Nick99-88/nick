import 'package:flutter/material.dart';
import 'package:pluto_grid/pluto_grid.dart';

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
    String name = "";
    while (index > 0) {
      int modulo = (index - 1) % 26;
      name = String.fromCharCode(65 + modulo) + name;
      index = (index - modulo) ~/ 26;
    }
    return name;
  }
}
