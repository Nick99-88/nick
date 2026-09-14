import 'package:flutter/material.dart';

class ScannedDocumentTableWidget extends StatelessWidget {
  final List<dynamic> content; // This will actually be the main details/sections/metadata of the scanned document
  final String rawText;
  final String fileName;

  const ScannedDocumentTableWidget({
    super.key,
    required this.content,
    required this.rawText,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    // We will represent extracted sections/text in tabular row formats
    final List<Map<String, String>> rows = [];

    // Add general file details first
    rows.add({
      'field': 'Scanned File Name',
      'value': fileName.isNotEmpty ? fileName : 'No Image File Linked',
      'type': 'Core Property',
    });

    if (rawText.isNotEmpty) {
      rows.add({
        'field': 'OCR Extracted Text',
        'value': rawText.length > 80 ? "${rawText.substring(0, 80)}..." : rawText,
        'type': 'OCR Output',
      });
    }

    // Add structural sections if they exist in content list
    for (var section in content) {
      if (section is Map) {
        rows.add({
          'field': section['name']?.toString() ?? 'Section Header',
          'value': section['text']?.toString() ?? section['content']?.toString() ?? 'Empty Section',
          'type': 'Extracted Structure',
        });
      } else if (section is String) {
        rows.add({
          'field': 'Recognized Line',
          'value': section,
          'type': 'Segment',
        });
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 3D Header Bar of Table
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFF00695C), // Teal 3D Header
                child: const Row(
                  children: [
                    Icon(Icons.document_scanner_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "SCANNED DOCUMENT OCR RECONSTRUCTION",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.1),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Interactive Scalable/Scrollable Canvas Area
              Container(
                height: 350,
                padding: const EdgeInsets.all(12),
                child: InteractiveViewer(
                  // 🏛| Logic: InteractiveViewer with constrained: false allows unlimited 2D pan & zoom!
                  constrained: false,
                  minScale: 0.5,
                  maxScale: 2.5,
                  child: Table(
                    defaultColumnWidth: const FixedColumnWidth(160.0),
                    border: TableBorder.all(color: Colors.grey.shade200, width: 1.5, borderRadius: BorderRadius.circular(8)),
                    children: [
                      // Header Row
                      TableRow(
                        decoration: BoxDecoration(color: Colors.grey.shade100),
                        children: const [
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('STRUCTURE/FIELD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('EXTRACTED DATA VALUE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('CLASSIFICATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                        ],
                      ),

                      // Content Rows
                      ...rows.map((row) {
                        return TableRow(
                          children: [
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(row['field']!, style: const TextStyle(fontSize: 12, color: Color(0xFF263238), fontWeight: FontWeight.bold)),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(row['value']!, style: TextStyle(fontSize: 12, color: Colors.teal.shade700, height: 1.3)),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(row['type']!, style: const TextStyle(fontSize: 11, color: Colors.indigo, fontWeight: FontWeight.w500)),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
