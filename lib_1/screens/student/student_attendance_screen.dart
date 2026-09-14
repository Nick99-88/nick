import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;
  int _presentCount = 0;
  int _absentCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/attendance/my-history'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['records'] != null) {
          final records = List<Map<String, dynamic>>.from(data['records']);
          if (mounted) {
            setState(() {
              _records = records;
              _presentCount = records.where((r) => r['status'] == 'present' || r['status'] == 'P').length;
              _absentCount = records.where((r) => r['status'] == 'absent' || r['status'] == 'A').length;
            });
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final total = _records.length;
    final rate = total > 0 ? (_presentCount / total * 100).toStringAsFixed(1) : '--';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("My Attendance", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: StarlightTheme.primaryBlue,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [StarlightTheme.primaryBlue, Colors.blue.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _summaryItem('Present', _presentCount.toString(), Icons.check_circle, Colors.greenAccent),
                      _summaryItem('Absent', _absentCount.toString(), Icons.cancel, Colors.redAccent),
                      _summaryItem('Total', total.toString(), Icons.event_note, Colors.white70),
                      _summaryItem('Rate', '$rate%', Icons.analytics, Colors.amberAccent),
                    ],
                  ),
                ),
                Expanded(
                  child: _records.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_busy, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text("No attendance records", style: TextStyle(color: Colors.grey[500])),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAttendance,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _records.length,
                            itemBuilder: (_, i) => _buildRecordCard(_records[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
      ],
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> r) {
    final isPresent = r['status'] == 'present' || r['status'] == 'P';
    final date = r['date'] ?? '';
    final subject = r['subject'] ?? '';
    final title = r['title'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPresent ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isPresent ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(isPresent ? Icons.check_circle : Icons.cancel, color: isPresent ? Colors.green : Colors.red, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                if (subject.isNotEmpty)
                  Text(subject, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                Text(date, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isPresent ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isPresent ? 'Present' : 'Absent',
              style: TextStyle(fontSize: 10, color: isPresent ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
