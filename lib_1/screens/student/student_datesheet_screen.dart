import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';

class StudentDatesheetScreen extends StatefulWidget {
  const StudentDatesheetScreen({super.key});

  @override
  State<StudentDatesheetScreen> createState() => _StudentDatesheetScreenState();
}

class _StudentDatesheetScreenState extends State<StudentDatesheetScreen> {
  List<Map<String, dynamic>> _datesheets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDatesheets();
  }

  Future<void> _loadDatesheets() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/document/datesheet/list'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['datesheets'] != null) {
          if (mounted) setState(() => _datesheets = List<Map<String, dynamic>>.from(data['datesheets']));
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
        title: const Text("Date Sheet", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: StarlightTheme.primaryBlue,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _datesheets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text("No datesheets available", style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDatesheets,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _datesheets.length,
                    itemBuilder: (_, i) => _buildDatesheetCard(_datesheets[i]),
                  ),
                ),
    );
  }

  Widget _buildDatesheetCard(Map<String, dynamic> d) {
    final title = d['title'] ?? 'Untitled';
    final date = d['date'] ?? '';
    final entries = d['entries'] is List ? List<Map<String, dynamic>>.from(d['entries']) : <Map<String, dynamic>>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_today, color: Colors.orange, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if (date.isNotEmpty)
                      Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text("Exam Schedule", style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            ...entries.map((entry) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry['subject_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        if ((entry['date'] ?? '').isNotEmpty || (entry['day'] ?? '').isNotEmpty)
                          Text('${entry['day'] ?? ''} ${entry['date'] ?? ''}'.trim(), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  if ((entry['time'] ?? '').isNotEmpty)
                    Text(entry['time'], style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  if ((entry['venue'] ?? '').isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(entry['venue'], style: TextStyle(fontSize: 9, color: Colors.orange[700])),
                    ),
                  ],
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}