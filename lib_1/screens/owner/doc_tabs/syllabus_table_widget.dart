import 'package:flutter/material.dart';
import '../../../core/theme.dart';

class SyllabusTableWidget extends StatelessWidget {
  final List<dynamic> content;

  const SyllabusTableWidget({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    // Flatten the syllabus hierarchical content into tabular rows
    final List<Map<String, String>> rows = [];

    for (var classObj in content) {
      if (classObj is Map) {
        final String classTitle = classObj['title'] ?? classObj['name'] ?? 'General Class';
        final List<dynamic> chapters = classObj['chapters'] ?? [];
        
        for (var chapter in chapters) {
          if (chapter is Map) {
            final String chapterName = chapter['name'] ?? 'Untitled Chapter';
            final List<dynamic> topics = chapter['topics'] ?? [];
            final String topicsJoined = topics.join(', ');

            rows.add({
              'class': classTitle,
              'chapter': chapterName,
              'topics': topicsJoined.isNotEmpty ? topicsJoined : 'N/A',
            });
          }
        }
      }
    }

    if (rows.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: const Text(
          "No syllabus chapter data structure found.",
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
                color: StarlightTheme.primaryBlue,
                child: const Row(
                  children: [
                    Icon(Icons.table_chart_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "STRUCTURED SYLLABUS DIRECTORY",
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
                  // 🏛️ Logic: InteractiveViewer with constrained: false allows unlimited 2D pan & zoom!
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
                              child: Text('CLASS/LEVEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('CHAPTER/UNIT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('TOPICS & KEYWORDS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
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
                                child: Text(row['class']!, style: const TextStyle(fontSize: 12, color: Color(0xFF263238), fontWeight: FontWeight.bold)),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(row['chapter']!, style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.w500)),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(row['topics']!, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3)),
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
