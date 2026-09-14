import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';

class StudentMarksheetScreen extends StatefulWidget {
  const StudentMarksheetScreen({super.key});

  @override
  State<StudentMarksheetScreen> createState() => _StudentMarksheetScreenState();
}

class _StudentMarksheetScreenState extends State<StudentMarksheetScreen> {
  List<Map<String, dynamic>> _marksheets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMarksheets();
  }

  Future<void> _loadMarksheets() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/marksheet/my-marksheets'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          if (mounted) setState(() => _marksheets = List<Map<String, dynamic>>.from(data));
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
        title: const Text("My Marksheets", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: StarlightTheme.primaryBlue,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _marksheets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.grade, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text("No marksheets found", style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMarksheets,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _marksheets.length,
                    itemBuilder: (_, i) => _buildMarksheetCard(_marksheets[i]),
                  ),
                ),
    );
  }

  Widget _buildMarksheetCard(Map<String, dynamic> m) {
    final examTitle = m['exam_title'] ?? 'Untitled';
    final subject = m['subject'] ?? '';
    final className = m['class_name'] ?? '';
    final marksObtained = m['marks_obtained'] ?? 0;
    final maxMarks = m['max_marks'] ?? 0;
    final percentage = m['percentage'] ?? 0;
    final grade = m['grade'] ?? '';
    final resultStatus = m['result_status'] ?? '';
    final passed = resultStatus == 'pass';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: passed ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: passed ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(passed ? Icons.check_circle : Icons.cancel, color: passed ? Colors.green : Colors.red, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(examTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if (subject.isNotEmpty)
                      Text(subject, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              if (grade.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: passed ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(grade, style: TextStyle(fontSize: 10, color: passed ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat('Marks', '$marksObtained / $maxMarks', passed ? Colors.green : Colors.red),
              _stat('Percentage', '${percentage.toStringAsFixed(1)}%', StarlightTheme.primaryBlue),
              _stat('Class', className, Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
      ],
    );
  }
}
