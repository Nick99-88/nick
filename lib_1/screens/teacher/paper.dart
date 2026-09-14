import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../owner/document_vault_screen.dart';
import '../owner/doc_tabs/my_files_screen.dart';
import '../owner/doc_tabs/paper_architect.dart';
import '../owner/doc_tabs/testArchitect.dart';
import '../owner/doc_tabs/question_vault_manager.dart';
import '../owner/doc_tabs/syllabus_page.dart';
import '../owner/doc_tabs/datesheet_architect.dart';
import '../owner/doc_tabs/notice_architect.dart';
import '../owner/doc_tabs/marksheet_page.dart';
import '../owner/doc_tabs/advanced_notes_screen.dart';

class TeacherPaper extends StatefulWidget {
  const TeacherPaper({super.key});

  @override
  State<TeacherPaper> createState() => _TeacherPaperState();
}

class _TeacherPaperState extends State<TeacherPaper> {
  String _teacherName = "Teacher";

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final name = await StarlightStorage.getUserName();
    if (mounted) setState(() => _teacherName = name ?? "Teacher");
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildMyRecentDocs(),
          const SizedBox(height: 20),
          _buildDocumentTools(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: Colors.white.withOpacity(0.8), size: 24),
              const SizedBox(width: 8),
              const Text(
                "My Documents",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "All documents created and managed by $_teacherName",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRecentDocs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Recent Documents",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyFilesScreen()),
              ),
              child: const Text("View All"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _recentDocItem(Icons.description, "No documents yet", "Your created documents will appear here", Colors.grey),
      ],
    );
  }

  Widget _recentDocItem(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTools() {
    final tools = [
      {'title': 'Paper Architect', 'icon': Icons.history_edu, 'color': Colors.brown, 'screen': const PaperArchitect()},
      {'title': 'Test Architect', 'icon': Icons.architecture, 'color': Colors.deepPurple, 'screen': const TestArchitect()},
      {'title': 'Paper Vault', 'icon': Icons.inventory_2, 'color': Colors.blueGrey, 'screen': const QuestionVaultManager()},
      {'title': 'Syllabus', 'icon': Icons.menu_book, 'color': Colors.blue, 'screen': const SyllabusPage()},
      {'title': 'DateSheet', 'icon': Icons.calendar_month, 'color': Colors.indigo, 'screen': const DatesheetArchitect()},
      {'title': 'Notice', 'icon': Icons.campaign, 'color': Colors.orange, 'screen': const NoticeArchitect()},
      {'title': 'MarkSheet', 'icon': Icons.grade, 'color': Colors.amber, 'screen': const MarksheetPage()},
      {'title': 'Notes', 'icon': Icons.note_alt, 'color': Colors.teal, 'screen': AdvancedNotesScreen()},
      {'title': 'My Files', 'icon': Icons.folder_copy, 'color': Colors.blueGrey, 'screen': const MyFilesScreen()},
      {'title': 'All Tools', 'icon': Icons.apps, 'color': StarlightTheme.primaryBlue, 'screen': const DocumentVaultScreen()},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Document Tools",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          "Create, scan, and manage institution documents",
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tools.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.9,
          ),
          itemBuilder: (context, index) {
            final tool = tools[index];
            return _toolCard(
              icon: tool['icon'] as IconData,
              title: tool['title'] as String,
              color: tool['color'] as Color,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => tool['screen'] as Widget),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _toolCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
