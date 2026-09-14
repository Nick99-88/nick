import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class TranslationTableWidget extends StatelessWidget {
  final List<dynamic> content;

  const TranslationTableWidget({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: const Text(
          "No translated text rows found.",
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
        ),
      );
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
                color: Colors.pink.shade700, // Tech Pink Header
                child: const Row(
                  children: [
                    Icon(Icons.g_translate_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "BILINGUAL TRANSLATION REGISTRY",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.1),
                    ),
                  ],
                ),
              ),

              // Interactive Scalable/Scrollable Canvas Area
              Container(
                height: 350,
                padding: const EdgeInsets.all(12),
                child: InteractiveViewer(
                  constrained: false,
                  minScale: 0.5,
                  maxScale: 2.5,
                  child: Table(
                    defaultColumnWidth: const FixedColumnWidth(240.0),
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
                              child: Text('TRANSLATED CODES & SPECIFICATIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('URDU / TRANSLATED TEXT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                        ],
                      ),

                      // Content Rows
                      ...content.map((entry) {
                        if (entry is! Map) return TableRow(children: const [TableCell(child: SizedBox()), TableCell(child: SizedBox())]);
                        final String title = entry['title']?.toString() ?? 'Document Text';
                        final String translatedText = entry['translated_text']?.toString() ?? 'N/A';

                        return TableRow(
                          children: [
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF263238), fontWeight: FontWeight.bold)),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  translatedText, 
                                  style: const TextStyle(
                                    fontSize: 13, 
                                    fontFamily: 'NotoNastaliqUrdu', 
                                    color: Colors.indigo, 
                                    fontWeight: FontWeight.w500,
                                    height: 1.6,
                                  )
                                ),
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
