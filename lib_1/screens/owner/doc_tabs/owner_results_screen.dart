import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/constants.dart';
import '../../../core/storage.dart';
import '../../../core/theme.dart';
import 'marksheet_page.dart';

class OwnerResultsScreen extends StatefulWidget {
  const OwnerResultsScreen({super.key});

  @override
  State<OwnerResultsScreen> createState() => _OwnerResultsScreenState();
}

class _OwnerResultsScreenState extends State<OwnerResultsScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  bool _showHistory = false;

  List<Map<String, dynamic>> get _filteredSessions =>
      _sessions.where((s) => (s['is_completed'] == true) == _showHistory).toList();

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/marksheet/sessions'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          if (mounted) setState(() => _sessions = List<Map<String, dynamic>>.from(data));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(_showHistory ? "Completed Sessions" : "Results", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: StarlightTheme.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showHistory ? Icons.arrow_back : Icons.history),
            tooltip: _showHistory ? "Back to active" : "History",
            onPressed: () => setState(() => _showHistory = !_showHistory),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.emoji_events, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(_showHistory ? "No completed sessions" : "No active sessions", style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSessions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredSessions.length,
                    itemBuilder: (_, i) => _buildSessionCard(_filteredSessions[i]),
                  ),
                ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final name = session['name'] ?? 'Unnamed';
    final isCompleted = session['is_completed'] == true;
    final marksheetCount = session['marksheet_count'] ?? 0;
    final sessionId = session['id'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onLongPress: () => _confirmDeleteSession(sessionId, name),
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => _SessionResultsScreen(sessionId: sessionId, sessionName: name))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
               isCompleted
                  ? Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
                    )
                  : Checkbox(
                      value: false,
                      activeColor: Colors.green,
                      onChanged: (_) => _confirmCompleteSession(sessionId, name),
                    ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      '$marksheetCount marksheet(s) · ${isCompleted ? "Completed" : "In Progress"}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (isCompleted)
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
                onSelected: (value) async {
                  if (value == 'print') await _printSession(session);
                  if (value == 'delete') _confirmDeleteSession(sessionId, name);
                },
                itemBuilder: (_) => [
                  if (isCompleted)
                    const PopupMenuItem(value: 'print', child: Row(
                      children: [Icon(Icons.print, color: Colors.blue, size: 18), SizedBox(width: 8), Text('Print')],
                    )),
                  const PopupMenuItem(value: 'delete', child: Row(
                    children: [Icon(Icons.delete_outline, color: Colors.red, size: 18), SizedBox(width: 8), Text('Delete')],
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmCompleteSession(String sessionId, String sessionName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Complete Session"),
        content: Text("Mark \"$sessionName\" as completed?\n\nOnce completed, students will be able to see their results from this session."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _completeSession(sessionId);
            },
            child: const Text("Complete", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Future<void> _completeSession(String sessionId) async {
    try {
      final token = await StarlightStorage.getUserToken();
      await http.put(
        Uri.parse('${StarlightConstants.apiBaseUrl}/marksheet/session/$sessionId/complete'),
        headers: {'Authorization': 'Bearer $token'},
      );
      await _loadSessions();
    } catch (_) {}
  }

  void _confirmDeleteSession(String sessionId, String sessionName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Session"),
        content: Text("Delete \"$sessionName\"? This will remove the session and its marksheets from results. Students will no longer see them."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteSession(sessionId);
            },
            child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSession(String sessionId) async {
    try {
      final token = await StarlightStorage.getUserToken();
      await http.delete(
        Uri.parse('${StarlightConstants.apiBaseUrl}/marksheet/session/$sessionId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      await _loadSessions();
    } catch (_) {}
  }

  Future<void> _printSession(Map<String, dynamic> session) async {
    final sessionId = session['id'] ?? '';
    final name = session['name'] ?? 'Session';
    final marksheetCount = session['marksheet_count'] ?? 0;

    // Fetch full results data
    List students = [];
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/marksheet/session/$sessionId/results'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        students = data['students'] ?? [];
      }
    } catch (_) {}

    // Compute per-student summary data
    final studentSummaries = students.map((student) {
      final subs = student['subjects'] as List;
      final totalObtained = subs.fold<num>(0, (sum, s) => sum + (s['marks_obtained'] ?? 0));
      final totalMax = subs.fold<num>(0, (sum, s) => sum + (s['max_marks'] ?? 0));
      final avg = subs.isNotEmpty
          ? subs.fold<double>(0, (sum, s) => sum + (s['percentage'] ?? 0).toDouble()) / subs.length
          : 0.0;
      return {'totalObtained': totalObtained, 'totalMax': totalMax, 'avg': avg, 'grade': subs.isNotEmpty ? subs.last['grade'] ?? '-' : '-'};
    }).toList();
    final overallAvg = studentSummaries.isNotEmpty
        ? studentSummaries.fold<double>(0, (sum, s) => sum + s['avg']) / studentSummaries.length
        : 0.0;

    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStamp = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Center(child: pw.Text("SESSION REPORT", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text(name, style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700))),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text("Generated: $dateStamp", style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500))),
          pw.SizedBox(height: 16),
          pw.Text("Total Students: ${students.length}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          if (students.isEmpty)
            pw.Text("No results available for this session.", style: pw.TextStyle(fontSize: 11, color: PdfColors.grey500))
          else
            ..._buildStudentPdfSection(students, studentSummaries),
          pw.Divider(thickness: 2),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                "Session Performance: ${overallAvg.toStringAsFixed(1)}%",
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text("--- End of Report ---", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
        ],
      ),
    );

    final bytes = await pdf.save();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = "Session_${name.replaceAll(' ', '_')}_$timestamp.pdf";
      final filePath = "${dir.path}/$fileName";
      await File(filePath).writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("PDF saved: $fileName"),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: "SHARE",
            textColor: Colors.white,
            onPressed: () => Share.shareXFiles([XFile(filePath)], text: "Session Report"),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  List<pw.Widget> _buildStudentPdfSection(List students, List summaries) {
    final widgets = <pw.Widget>[];
    for (int si = 0; si < students.length; si++) {
      final student = students[si];
      final summary = summaries[si];
      widgets.addAll([
        pw.Row(children: [
          pw.Expanded(child: pw.Text(student['student_name'] ?? 'Unknown', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
          pw.Text(student['roll_number'] ?? 'N/A', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ]),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: PdfColors.blue800),
          cellStyle: pw.TextStyle(fontSize: 9),
          headers: ['Subject', 'Marks', '%', 'Grade', 'Status'],
          data: (student['subjects'] as List).map((s) => [
            s['subject'] ?? s['exam_title'] ?? '-',
            '${s['marks_obtained'] ?? 0}/${s['max_marks'] ?? 100}',
            '${s['percentage'] ?? 0}%',
            s['grade'] ?? '-',
            s['status'] == 'pass' ? 'PASS' : 'FAIL',
          ]).toList(),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
          child: pw.Row(children: [
            pw.Text("Total: ${summary['totalObtained']} / ${summary['totalMax']}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 16),
            pw.Text("Avg: ${(summary['avg'] as double).toStringAsFixed(1)}%", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 16),
            pw.Text("Grade: ${summary['grade']}", style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ]),
        ),
        pw.SizedBox(height: 12),
      ]);
    }
    return widgets;
  }
}

class _SessionResultsScreen extends StatefulWidget {
  final String sessionId;
  final String sessionName;

  const _SessionResultsScreen({required this.sessionId, required this.sessionName});

  @override
  State<_SessionResultsScreen> createState() => _SessionResultsScreenState();
}

class _SessionResultsScreenState extends State<_SessionResultsScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  Map<String, dynamic>? _selectedStudent;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/marksheet/session/${widget.sessionId}/results'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (mounted) setState(() { _data = jsonDecode(response.body); _isLoading = false; });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _printSessionResults() async {
    if (_data == null) return;
    final students = _data!['students'] as List? ?? [];
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStamp = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    // Compute per-student summary data
    final studentSummaries = students.map((student) {
      final subs = student['subjects'] as List;
      final totalObtained = subs.fold<num>(0, (sum, s) => sum + (s['marks_obtained'] ?? 0));
      final totalMax = subs.fold<num>(0, (sum, s) => sum + (s['max_marks'] ?? 0));
      final avg = subs.isNotEmpty
          ? subs.fold<double>(0, (sum, s) => sum + (s['percentage'] ?? 0).toDouble()) / subs.length
          : 0.0;
      return {'totalObtained': totalObtained, 'totalMax': totalMax, 'avg': avg, 'grade': subs.isNotEmpty ? subs.last['grade'] ?? '-' : '-'};
    }).toList();
    final overallAvg = studentSummaries.isNotEmpty
        ? studentSummaries.fold<double>(0, (sum, s) => sum + s['avg']) / studentSummaries.length
        : 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Center(child: pw.Text("SESSION RESULTS", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text(widget.sessionName, style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700))),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text("Generated: $dateStamp", style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500))),
          pw.SizedBox(height: 16),
          pw.Text("Total Students: ${students.length}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          ..._buildStudentPdfSection(students, studentSummaries),
          pw.Divider(thickness: 2),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                "Session Performance: ${overallAvg.toStringAsFixed(1)}%",
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text("--- End of Report ---", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
        ],
      ),
    );

    final bytes = await pdf.save();
    await _saveAndSharePdf(bytes, "Session_Results_${widget.sessionName.replaceAll(' ', '_')}");
  }

  Future<void> _saveAndSharePdf(Uint8List bytes, String baseName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = "${baseName}_$timestamp.pdf";
      final filePath = "${dir.path}/$fileName";
      await File(filePath).writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("PDF saved: $fileName"),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: "SHARE",
            textColor: Colors.white,
            onPressed: () => Share.shareXFiles([XFile(filePath)], text: baseName),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(widget.sessionName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: StarlightTheme.primaryBlue,
        elevation: 0,
        actions: [
          if (_selectedStudent != null)
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.blue),
              tooltip: "Add Subject for ${_selectedStudent!['student_name']}",
              onPressed: () async {
                final name = '${_selectedStudent!['student_name'] ?? ''} - ${widget.sessionName}';
                await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => MarksheetPage(initialSessionId: widget.sessionId, initialData: {'exam_title': name}),
                ));
                setState(() => _selectedStudent = null);
                _loadResults();
              },
            ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 22),
            onSelected: (value) async {
              if (value == 'print') await _printSessionResults();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'print', child: Row(
                children: [Icon(Icons.print, color: Colors.blue, size: 18), SizedBox(width: 8), Text('Print All Results')],
              )),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text("No data"))
              : RefreshIndicator(
                  onRefresh: _loadResults,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: (_data!['students'] as List).length,
                      itemBuilder: (_, i) {
                        final student = (_data!['students'] as List)[i] as Map<String, dynamic>;
                        final isSelected = _selectedStudent?['student_id'] == student['student_id'];
                        return GestureDetector(
                          onTap: () {
                            if (_selectedStudent != null) {
                              setState(() => _selectedStudent = null);
                            } else {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => _StudentResultDetailScreen(
                                  sessionName: widget.sessionName,
                                  student: student,
                                ),
                              ));
                            }
                          },
                          onLongPress: () {
                            setState(() {
                              _selectedStudent = isSelected ? null : student;
                            });
                          },
                          child: _buildStudentCard(student, isSelected: isSelected),
                        );
                      },
                  ),
                ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, {bool isSelected = false}) {
    final subjects = student['subjects'] as List? ?? [];
    final passed = subjects.every((s) => s['status'] == 'pass');
    final totalPct = subjects.fold<double>(0, (sum, s) => sum + (s['percentage'] ?? 0).toDouble());
    final avgPct = subjects.isNotEmpty ? totalPct / subjects.length : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? Colors.blue : (passed ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: passed ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                child: Icon(Icons.person, size: 16, color: passed ? Colors.green : Colors.red),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  student['student_name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if ((student['roll_number'] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Roll: ${student['roll_number']}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: avgPct >= 40 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${avgPct.toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16,
                color: avgPct >= 40 ? Colors.green : Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('${subjects.length} subject(s)',
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }

  List<pw.Widget> _buildStudentPdfSection(List students, List summaries) {
    final widgets = <pw.Widget>[];
    for (int si = 0; si < students.length; si++) {
      final student = students[si];
      final summary = summaries[si];
      widgets.addAll([
        pw.Row(children: [
          pw.Expanded(child: pw.Text(student['student_name'] ?? 'Unknown', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
          pw.Text(student['roll_number'] ?? 'N/A', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ]),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: pw.BoxDecoration(color: PdfColors.blue800),
          cellStyle: pw.TextStyle(fontSize: 9),
          headers: ['Subject', 'Marks', '%', 'Grade', 'Status'],
          data: (student['subjects'] as List).map((s) => [
            s['subject'] ?? s['exam_title'] ?? '-',
            '${s['marks_obtained'] ?? 0}/${s['max_marks'] ?? 100}',
            '${s['percentage'] ?? 0}%',
            s['grade'] ?? '-',
            s['status'] == 'pass' ? 'PASS' : 'FAIL',
          ]).toList(),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
          child: pw.Row(children: [
            pw.Text("Total: ${summary['totalObtained']} / ${summary['totalMax']}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 16),
            pw.Text("Avg: ${(summary['avg'] as double).toStringAsFixed(1)}%", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 16),
            pw.Text("Grade: ${summary['grade']}", style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ]),
        ),
        pw.SizedBox(height: 12),
      ]);
    }
    return widgets;
  }
}

class _StudentResultDetailScreen extends StatelessWidget {
  final String sessionName;
  final Map<String, dynamic> student;

  const _StudentResultDetailScreen({
    required this.sessionName,
    required this.student,
  });

  @override
  Widget build(BuildContext context) {
    final subjects = student['subjects'] as List? ?? [];
    final passed = subjects.every((s) => s['status'] == 'pass');
    final totalPct = subjects.fold<double>(0, (sum, s) => sum + (s['percentage'] ?? 0).toDouble());
    final avgPct = subjects.isNotEmpty ? totalPct / subjects.length : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(student['student_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: StarlightTheme.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printResult(context),
            tooltip: "Print",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Student Info Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: passed ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    child: Icon(Icons.person, size: 30, color: passed ? Colors.green : Colors.red),
                  ),
                  const SizedBox(height: 10),
                  Text(student['student_name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Session: $sessionName', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  if ((student['roll_number'] ?? '').isNotEmpty)
                    Text('Roll No: ${student['roll_number']}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: (avgPct >= 40 ? Colors.green : Colors.red).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${avgPct.toStringAsFixed(1)}% Overall',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16,
                        color: avgPct >= 40 ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Subjects Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: subjects.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = subjects[i] as Map<String, dynamic>;
                          final marksObtained = s['marks_obtained'] ?? 0;
                          final maxMarks = s['max_marks'] ?? 100;
                          final pct = s['percentage'] ?? 0;
                          final grade = s['grade'] ?? '-';
                          final subjectStatus = s['status'] == 'pass';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s['subject'] ?? s['exam_title'] ?? '-',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: subjectStatus ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        subjectStatus ? 'PASS' : 'FAIL',
                                        style: TextStyle(
                                          fontSize: 11, fontWeight: FontWeight.bold,
                                          color: subjectStatus ? Colors.green : Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _detailChip('Marks', '$marksObtained / $maxMarks'),
                                    const SizedBox(width: 8),
                                    _detailChip('Percentage', '$pct%'),
                                    const SizedBox(width: 8),
                                    _detailChip('Grade', grade.toString()),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Future<void> _printResult(BuildContext context) async {
    final subjects = student['subjects'] as List? ?? [];
    final totalPct = subjects.fold<double>(0, (sum, s) => sum + (s['percentage'] ?? 0).toDouble());
    final avgPct = subjects.isNotEmpty ? totalPct / subjects.length : 0.0;

    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStamp = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Center(child: pw.Text("RESULT CARD", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Text("Session: ", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text(sessionName, style: pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.Row(
            children: [
              pw.Text("Student: ", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text(student['student_name'] ?? '', style: pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.Row(
            children: [
              pw.Text("Roll No: ", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text(student['roll_number'] ?? '-', style: pw.TextStyle(fontSize: 11)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text("Generated: $dateStamp", style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500))),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: pw.TextStyle(fontSize: 10),
            headers: ['Subject', 'Marks', '%', 'Grade', 'Status'],
            data: subjects.map((s) => [
              s['subject'] ?? s['exam_title'] ?? '-',
              '${s['marks_obtained'] ?? 0}/${s['max_marks'] ?? 100}',
              '${s['percentage'] ?? 0}%',
              s['grade'] ?? '-',
              s['status'] == 'pass' ? 'PASS' : 'FAIL',
            ]).toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text("Overall: ${avgPct.toStringAsFixed(1)}%", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Center(child: pw.Text("--- End of Report ---", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500))),
        ],
      ),
    );

    final bytes = await pdf.save();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = "Result_${student['student_name']?.replaceAll(' ', '_')}_$timestamp.pdf";
      final filePath = "${dir.path}/$fileName";
      await File(filePath).writeAsBytes(bytes, flush: true);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("PDF saved: $fileName"),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: "SHARE",
            textColor: Colors.white,
            onPressed: () => Share.shareXFiles([XFile(filePath)], text: "Student Result"),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }
}