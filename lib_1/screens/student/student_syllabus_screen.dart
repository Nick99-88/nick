import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';

class StudentSyllabusScreen extends StatefulWidget {
  const StudentSyllabusScreen({super.key});

  @override
  State<StudentSyllabusScreen> createState() => _StudentSyllabusScreenState();
}

class _StudentSyllabusScreenState extends State<StudentSyllabusScreen> {
  List<Map<String, dynamic>> _syllabuses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSyllabuses();
  }

  Future<void> _loadSyllabuses() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/document/syllabus/list'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['syllabuses'] != null) {
          if (mounted) setState(() => _syllabuses = List<Map<String, dynamic>>.from(data['syllabuses']));
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
        title: const Text("Syllabus", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: StarlightTheme.primaryBlue,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _syllabuses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text("No syllabuses available", style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSyllabuses,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _syllabuses.length,
                    itemBuilder: (_, i) => _buildSyllabusCard(_syllabuses[i]),
                  ),
                ),
    );
  }

  Widget _buildSyllabusCard(Map<String, dynamic> s) {
    final title = s['title'] ?? 'Untitled';
    final subject = s['subject'] ?? '';
    final grade = s['grade'] ?? '';
    final rawChapters = s['chapters'] is List ? s['chapters'] : <dynamic>[];

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
                  color: StarlightTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_book, color: StarlightTheme.primaryBlue, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if (subject.isNotEmpty)
                      Text(subject, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              if (grade.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(grade, style: TextStyle(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          if (rawChapters.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text("Chapters", style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            ...rawChapters.map((ch) {
              String chName;
              String chTopics = '';
              if (ch is Map) {
                chName = ch['name']?.toString() ?? ch['title']?.toString() ?? 'Untitled';
                final topics = ch['topics'];
                if (topics is List) chTopics = topics.join(', ');
              } else {
                chName = ch.toString();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 4, color: StarlightTheme.primaryBlue.withOpacity(0.5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(chName, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                          if (chTopics.isNotEmpty)
                            Text(chTopics, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
