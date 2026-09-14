import 'package:flutter/material.dart';

class DatesheetTableWidget extends StatelessWidget {
  final List<dynamic> content;

  const DatesheetTableWidget({
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
          "No datesheet exam schedules found.",
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
                color: const Color(0xFF1A237E), // Indigo 3D Header
                child: const Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "EXAMINATION SCHEDULE DIRECTORY",
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
                              child: Text('DATE & DAY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('SUBJECT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('TIME & DURATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('VENUE/ROOM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                        ],
                      ),

                      // Content Rows
                      ...content.map((entry) {
                        if (entry is! Map) return TableRow(children: const [TableCell(child: SizedBox())]);
                        
                        final String date = entry['date']?.toString() ?? 'N/A';
                        final String day = entry['day']?.toString() ?? '';
                        final String dateDayLabel = day.isNotEmpty ? "$date\n($day)" : date;

                        final String subject = entry['subject_name']?.toString() ?? 'Untitled';
                        
                        final String time = entry['time']?.toString() ?? 'N/A';
                        final String duration = entry['duration_mins']?.toString() ?? '0';
                        final String timeDurationLabel = "$time\n($duration mins)";

                        final String venue = entry['venue']?.toString() ?? 'Main Hall';

                        return TableRow(
                          children: [
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(dateDayLabel, style: const TextStyle(fontSize: 12, color: Color(0xFF263238), fontWeight: FontWeight.bold)),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(subject, style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(timeDurationLabel, style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3)),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(venue, style: const TextStyle(fontSize: 12, color: Color(0xFF263238), fontWeight: FontWeight.w500)),
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
