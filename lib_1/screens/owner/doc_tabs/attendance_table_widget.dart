import 'package:flutter/material.dart';

class AttendanceTableWidget extends StatelessWidget {
  final List<dynamic> content;

  const AttendanceTableWidget({
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
          "No attendance logs found.",
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
                color: const Color(0xFF0288D1), // Blue 3D Header
                child: const Row(
                  children: [
                    Icon(Icons.assignment_turned_in_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "ATTENDANCE REGISTER LEDGER",
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
                  // 🏛| Logic: InteractiveViewer with constrained: false allows unlimited 2D pan & zoom!
                  constrained: false,
                  minScale: 0.5,
                  maxScale: 2.5,
                  child: Table(
                    defaultColumnWidth: const FixedColumnWidth(150.0),
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
                              child: Text('NAME & SUB-DETAILS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('IDENTIFIER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('DEPT/CLASS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('DAILY STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                        ],
                      ),

                      // Content Rows (Iterating through student/staff attendance list)
                      ...content.map((entry) {
                        if (entry is! Map) return TableRow(children: const [TableCell(child: SizedBox())]);
                        
                        // Parse student or staff names
                        final String name = entry['student_name'] ?? entry['staff_name'] ?? 'Unknown Name';
                        final String subDetail = entry['father_name'] ?? entry['role'] ?? 'N/A';
                        final String nameLabel = "$name\n($subDetail)";

                        final String id = entry['student_id'] ?? entry['staff_id'] ?? 'N/A';
                        final String idLabel = id.length > 8 ? id.substring(0, 8) + '...' : id;

                        final String deptClass = entry['department'] ?? entry['class_sec'] ?? 'General';

                        final String status = entry['status']?.toString().toUpperCase() ?? 'ABSENT';
                        
                        // Colorize status
                        Color statusColor;
                        switch (status) {
                          case 'PRESENT':
                            statusColor = Colors.green.shade700;
                            break;
                          case 'LATE':
                            statusColor = Colors.orange.shade700;
                            break;
                          case 'LEAVE':
                            statusColor = Colors.blue.shade700;
                            break;
                          case 'ABSENT':
                          default:
                            statusColor = Colors.red.shade700;
                        }

                        return TableRow(
                          children: [
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(nameLabel, style: const TextStyle(fontSize: 12, color: Color(0xFF263238), fontWeight: FontWeight.bold)),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(idLabel, style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.w500)),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(deptClass, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.3)),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  status, 
                                  style: TextStyle(
                                    fontSize: 12, 
                                    color: statusColor, 
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
