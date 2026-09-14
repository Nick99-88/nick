import 'package:flutter/material.dart';

class MarksheetTableWidget extends StatelessWidget {
  final List<dynamic> content;

  const MarksheetTableWidget({
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
          "No student marks entries found.",
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
                color: const Color(0xFFFF8F00), // Amber 3D Header
                child: const Row(
                  children: [
                    Icon(Icons.grade_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "OFFICIAL EXAMINATION MARKSHEET DIRECTORY",
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
                  // 🏛| Logic: InteractiveViewer with constrained: true fits all 4 columns on the screen cleanly!
                  constrained: true,
                  minScale: 0.8,
                  maxScale: 2.5,
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2.2), // More space for Student & Father Name
                      1: FlexColumnWidth(1.2), // Less space for Roll No
                      2: FlexColumnWidth(1.8), // Fits obtained marks & percent
                      3: FlexColumnWidth(1.8), // Fits grade & pass/fail status
                    },
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
                              child: Text('STUDENT & FATHER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('ROLL NO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('OBTAINED MARKS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('GRADE & STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                        ],
                      ),

                      // Content Rows (Iterating through student marks list)
                      ...content.map((entry) {
                        if (entry is! Map) return TableRow(children: const [TableCell(child: SizedBox())]);
                        
                        final String name = entry['student_name']?.toString() ?? 'Unknown Student';
                        final String father = entry['father_name']?.toString() ?? 'N/A';
                        final String studLabel = "$name\n($father)";

                        final String rollNo = entry['roll_number']?.toString() ?? 'N/A';

                        final String obtained = entry['marks_obtained']?.toString() ?? '0';
                        final String max = entry['max_marks']?.toString() ?? '100';
                        final String percent = (double.tryParse(entry['percentage']?.toString() ?? '0.0') ?? 0.0).toStringAsFixed(1);
                        final String marksLabel = "$obtained / $max\n($percent%)";

                        final String grade = entry['grade']?.toString() ?? 'F';
                        final String status = entry['status']?.toString().toUpperCase() ?? 'FAIL';

                        return TableRow(
                          children: [
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(studLabel, style: const TextStyle(fontSize: 12, color: Color(0xFF263238), fontWeight: FontWeight.bold)),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(rollNo, style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.w500)),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(marksLabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.3)),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  "Grade $grade\n($status)", 
                                  style: TextStyle(
                                    fontSize: 12, 
                                    color: status == 'PASS' ? Colors.green.shade700 : Colors.red.shade700, 
                                    fontWeight: FontWeight.bold
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
