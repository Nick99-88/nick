import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'student_syllabus_screen.dart';
import 'student_datesheet_screen.dart';
import 'student_results_screen.dart';
import 'student_attendance_screen.dart';
import '../owner/doc_tabs/my_files_screen.dart';
import '../owner/doc_tabs/advanced_notes_screen.dart';
import '../owner/doc_tabs/dictionary_page.dart';
import '../owner/doc_tabs/document_translator.dart';
import '../hub/shared_docs_screen.dart';

class StudentDoc extends StatefulWidget {
  const StudentDoc({super.key});

  @override
  State<StudentDoc> createState() => _StudentDocState();
}

class _StudentDocState extends State<StudentDoc> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildHeaderSection(),
          const SizedBox(height: 24),
          _buildFeatureGrid(),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Student Documents",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                SizedBox(height: 4),
                Text("View documents published by your institution.",
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.description, color: Colors.amberAccent, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid() {
    final features = [
      {'title': 'Syllabus', 'icon': Icons.menu_book_rounded, 'color': Colors.blue, 'screen': const StudentSyllabusScreen()},
      {'title': 'DateSheet', 'icon': Icons.calendar_month_rounded, 'color': Colors.indigo, 'screen': const StudentDatesheetScreen()},
      {'title': 'Results', 'icon': Icons.emoji_events_rounded, 'color': Colors.amber, 'screen': const StudentResultsScreen()},
      {'title': 'My Files', 'icon': Icons.folder_copy_rounded, 'color': Colors.blueGrey, 'screen': const MyFilesScreen(studentMode: true)},
      {'title': 'Advanced Notes', 'icon': Icons.note_alt_rounded, 'color': Colors.teal, 'screen': const AdvancedNotesScreen()},
      {'title': 'Shared Docs', 'icon': Icons.folder_shared_rounded, 'color': Colors.purple, 'screen': const SharedDocsScreen()},
      {'title': 'Dictionary', 'icon': Icons.translate_rounded, 'color': Colors.deepOrange, 'screen': const LinguisticConsole()},
      {'title': 'Document Translation', 'icon': Icons.g_translate_rounded, 'color': Colors.cyan, 'screen': const DocumentTranslator()},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: features.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (_, index) {
        final item = features[index];
        return _vaultCard(
          title: item['title'] as String,
          icon: item['icon'] as IconData,
          color: item['color'] as Color,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item['screen'] as Widget)),
        );
      },
    );
  }

  Widget _vaultCard({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
