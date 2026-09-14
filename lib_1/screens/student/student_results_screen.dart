import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';

class StudentResultsScreen extends StatefulWidget {
  const StudentResultsScreen({super.key});

  @override
  State<StudentResultsScreen> createState() => _StudentResultsScreenState();
}

class _StudentResultsScreenState extends State<StudentResultsScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/marksheet/results'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          final all = List<Map<String, dynamic>>.from(data);
          final sessionMap = <String, Map<String, dynamic>>{};
          for (var r in all) {
            final sid = r['session_id'] ?? '';
            if (sid.isEmpty) continue;
            if (!sessionMap.containsKey(sid)) {
              sessionMap[sid] = {
                'session_id': sid,
                'session_name': r['session_name'] ?? '',
                'session_completed_at': r['session_completed_at'] ?? '',
                'subjects': <Map<String, dynamic>>[],
              };
            }
            (sessionMap[sid]!['subjects'] as List).add({
              'exam_title': r['exam_title'] ?? '',
              'subject': r['subject'] ?? '',
              'class_name': r['class_name'] ?? '',
              'marks_obtained': r['marks_obtained'] ?? 0,
              'max_marks': r['max_marks'] ?? 0,
              'percentage': r['percentage'] ?? 0,
              'grade': r['grade'] ?? '',
              'result_status': r['result_status'] ?? '',
            });
          }
          final sessions = sessionMap.values
              .map((s) {
                final subs = s['subjects'] as List;
                final totalPct = subs.fold<double>(0, (sum, sub) => sum + (sub['percentage'] ?? 0).toDouble());
                s['avg_percentage'] = subs.isNotEmpty ? totalPct / subs.length : 0.0;
                s['subject_count'] = subs.length;
                return s;
              })
              .toList();
          sessions.sort((a, b) {
            final aDate = a['session_completed_at'] ?? '';
            final bDate = b['session_completed_at'] ?? '';
            return bDate.compareTo(aDate);
          });
          if (mounted) setState(() => _sessions = sessions);
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
        title: const Text("My Results", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: StarlightTheme.primaryBlue,
        elevation: 0,
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
                      Text("No results published yet", style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadResults,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sessions.length,
                    itemBuilder: (_, i) => _buildSessionCard(_sessions[i]),
                  ),
                ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final name = session['session_name'] ?? 'Session';
    final avgPct = (session['avg_percentage'] ?? 0.0).toDouble();
    final subjectCount = session['subject_count'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => _StudentSessionDetailScreen(
            sessionName: name,
            subjects: List<Map<String, dynamic>>.from(session['subjects'] as List),
          ),
        )),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: avgPct >= 40 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.emoji_events, color: avgPct >= 40 ? Colors.green : Colors.red, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('$subjectCount subject(s) · ${avgPct.toStringAsFixed(1)}% overall',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentSessionDetailScreen extends StatefulWidget {
  final String sessionName;
  final List<Map<String, dynamic>> subjects;

  const _StudentSessionDetailScreen({
    required this.sessionName,
    required this.subjects,
  });

  @override
  State<_StudentSessionDetailScreen> createState() => _StudentSessionDetailScreenState();
}

class _StudentSessionDetailScreenState extends State<_StudentSessionDetailScreen> {
  String _studentName = '';
  String _className = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final name = await StarlightStorage.getUserName() ?? '';
    final className = widget.subjects.isNotEmpty ? (widget.subjects.first['class_name'] ?? '') as String : '';
    if (mounted) setState(() { _studentName = name; _className = className; });
  }

  @override
  Widget build(BuildContext context) {
    final passed = widget.subjects.every((s) => s['result_status'] == 'pass');
    final totalPct = widget.subjects.fold<double>(0, (sum, s) => sum + (s['percentage'] ?? 0).toDouble());
    final avgPct = widget.subjects.isNotEmpty ? totalPct / widget.subjects.length : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(widget.sessionName, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  Text(_studentName.isNotEmpty ? _studentName : widget.sessionName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (_className.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Class: $_className', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Session: ${widget.sessionName}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: (avgPct >= 40 ? Colors.green : Colors.red).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${avgPct.toStringAsFixed(1)}% Overall',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: avgPct >= 40 ? Colors.green : Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.subjects.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = widget.subjects[i];
                    final marksObtained = s['marks_obtained'] ?? 0;
                    final maxMarks = s['max_marks'] ?? 100;
                    final pct = s['percentage'] ?? 0;
                    final grade = s['grade'] ?? '-';
                    final subjectStatus = s['result_status'] == 'pass';
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
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subjectStatus ? Colors.green : Colors.red),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _chip('Marks', '$marksObtained / $maxMarks'),
                              const SizedBox(width: 8),
                              _chip('Percentage', '$pct%'),
                              const SizedBox(width: 8),
                              _chip('Grade', grade.toString()),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
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
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStamp = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final avgPct = widget.subjects.isNotEmpty
        ? widget.subjects.fold<double>(0, (sum, s) => sum + (s['percentage'] ?? 0).toDouble()) / widget.subjects.length
        : 0.0;
    final totalObtained = widget.subjects.fold<num>(0, (sum, s) => sum + (s['marks_obtained'] ?? 0));
    final totalMax = widget.subjects.fold<num>(0, (sum, s) => sum + (s['max_marks'] ?? 0));
    final grade = widget.subjects.isNotEmpty ? widget.subjects.last['grade'] ?? '-' : '-';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Center(child: pw.Text("MY RESULT CARD", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text(widget.sessionName, style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700))),
          pw.SizedBox(height: 4),
          if (_studentName.isNotEmpty)
            pw.Center(child: pw.Text(_studentName, style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700))),
          if (_className.isNotEmpty)
            pw.Center(child: pw.Text("Class: $_className", style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600))),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text("Generated: $dateStamp", style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500))),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: pw.TextStyle(fontSize: 10),
            headers: ['Subject', 'Marks', '%', 'Grade', 'Status'],
            data: widget.subjects.map((s) => [
              s['subject'] ?? s['exam_title'] ?? '-',
              '${s['marks_obtained'] ?? 0}/${s['max_marks'] ?? 100}',
              '${s['percentage'] ?? 0}%',
              s['grade'] ?? '-',
              s['result_status'] == 'pass' ? 'PASS' : 'FAIL',
            ]).toList(),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
            child: pw.Row(
              children: [
                pw.Text("Total: $totalObtained / $totalMax", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(width: 20),
                pw.Text("Grade: $grade", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(width: 20),
                pw.Text("Overall: ${avgPct.toStringAsFixed(1)}%", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              ],
            ),
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
      final fileName = "My_Result_${widget.sessionName.replaceAll(' ', '_')}_$timestamp.pdf";
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
            onPressed: () => Share.shareXFiles([XFile(filePath)], text: "My Result"),
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