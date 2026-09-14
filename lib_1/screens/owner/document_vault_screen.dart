import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'package:starlight_flutter/screens/owner/doc_tabs/syllabus_page.dart';
import 'doc_tabs/testArchitect.dart';
import 'doc_tabs/dictionary_page.dart';
import 'doc_tabs/staff_attendance_architect.dart';
import 'doc_tabs/student_attendance_architect.dart';
import 'doc_tabs/question_vault_generator.dart';
import 'doc_tabs/datesheet_architect.dart';
import 'doc_tabs/notice_architect.dart';
import 'doc_tabs/document_structural_scanner.dart';
import 'doc_tabs/document_translator.dart';
import 'doc_tabs/fee_voucher_editor.dart';
import 'doc_tabs/fee_voucher_data_entry.dart';
import 'doc_tabs/marksheet_page.dart';
import 'doc_tabs/paper_scanner_architect.dart';
import 'doc_tabs/enhanced_paper_scanner.dart';
import 'doc_tabs/question_vault_manager.dart';
import 'doc_tabs/paper_architect.dart';
import 'doc_tabs/my_files_screen.dart';
import 'doc_tabs/document_scanner_screen.dart';
import 'tabs/dictionary_screen.dart';
import 'doc_tabs/advanced_notes_screen.dart';
import '../hub/shared_docs_screen.dart';
import 'doc_tabs/owner_results_screen.dart';
import 'doc_tabs/scan_quiz_paper.dart';
import 'doc_tabs/quiz.dart';
import '../../l10n/strings.dart';

class DocumentVaultScreen extends StatelessWidget {
  const DocumentVaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(tr('dvTitle'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
        backgroundColor: Colors.white,
        foregroundColor: StarlightTheme.primaryBlue,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 25),
            Text(tr('dvArchitectTools'),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
            const SizedBox(height: 15),
            _buildFeatureGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)]),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('dvHeaderTitle'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 5),
                Text(tr('dvHeaderSub'),
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 40),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context) {
    // 🏛️ Logic: Categorized 14+ Features with high-fidelity icons
    // routeKey = stable identifier used for routing, titleKey = localized label
    final List<Map<String, dynamic>> features = [
      {'routeKey': 'Syllabus', 'titleKey': 'dvSyllabus', 'icon': Icons.menu_book_rounded, 'color': Colors.blue},
      {'routeKey': 'DateSheet', 'titleKey': 'dvDateSheet', 'icon': Icons.calendar_month_rounded, 'color': Colors.indigo},
      {'routeKey': 'Notice', 'titleKey': 'dvNotice', 'icon': Icons.campaign_rounded, 'color': Colors.orange},
      {'routeKey': 'Fees Voucher', 'titleKey': 'dvFeesVoucher', 'icon': Icons.receipt_long_rounded, 'color': Colors.green},
      {'routeKey': 'Scan Doc', 'titleKey': 'dvScanDoc', 'icon': Icons.document_scanner_rounded, 'color': Colors.teal},
      {'routeKey': 'My Files', 'titleKey': 'dvMyFiles', 'icon': Icons.folder_copy_rounded, 'color': Colors.blueGrey},
      {'routeKey': 'MarkSheet', 'titleKey': 'dvMarkSheet', 'icon': Icons.grade_rounded, 'color': Colors.amber},
      {'routeKey': 'Test Architect', 'titleKey': 'dvTestArchitect', 'icon': Icons.architecture_rounded, 'color': Colors.deepPurple},
      {'routeKey': 'Student Attendance', 'titleKey': 'dvStudentAttendance', 'icon': Icons.how_to_reg_rounded, 'color': Colors.cyan},
      {'routeKey': 'Staff Attendance', 'titleKey': 'dvStaffAttendance', 'icon': Icons.assignment_turned_in_rounded, 'color': Colors.lightBlue},
      {'routeKey': 'Translate Doc', 'titleKey': 'dvTranslateDoc', 'icon': Icons.g_translate_rounded, 'color': Colors.pinkAccent},
      {'routeKey': 'Paper Scanner', 'titleKey': 'dvPaperScanner', 'icon': Icons.scanner_rounded, 'color': Colors.deepOrange},
      {'routeKey': 'Paper Architect', 'titleKey': 'dvPaperArchitect', 'icon': Icons.history_edu_rounded, 'color': Colors.brown},
      {'routeKey': 'Paper Vault', 'titleKey': 'dvPaperVault', 'icon': Icons.inventory_2_rounded, 'color': Colors.blueGrey},
      {'routeKey': 'Dictionary', 'titleKey': 'dvDictionary', 'icon': Icons.menu_book_rounded, 'color': Colors.indigo},
      {'routeKey': 'Notes', 'titleKey': 'dvNotes', 'icon': Icons.note_alt_rounded, 'color': Colors.amber},
      {'routeKey': 'Results', 'titleKey': 'dvResults', 'icon': Icons.emoji_events_rounded, 'color': Colors.deepOrange},
      {'routeKey': 'Shared Documents', 'titleKey': 'dvSharedDocuments', 'icon': Icons.share_rounded, 'color': Colors.purple},
      {'routeKey': 'Scan Quiz Paper', 'titleKey': 'dvScanQuizPaper', 'icon': Icons.document_scanner_rounded, 'color': Colors.indigo},
      {'routeKey': 'Quiz', 'titleKey': 'dvQuiz', 'icon': Icons.quiz_rounded, 'color': Colors.orange},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: features.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 🏛️ Keep 2 for readability on smaller screens
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1.4, // Slightly wider for longer titles
      ),
      itemBuilder: (context, index) {
        final item = features[index];
        final String routeKey = item['routeKey'] as String;
        final String title = tr(item['titleKey'] as String);

        return _vaultCard(
          context,
          title: title,
          icon: item['icon'] as IconData,
          color: item['color'] as Color,
          onTap: () {
            // 🏛️ Logic: Routing based on the feature route key
            switch (routeKey) {
              case 'My Files':
                Navigator.push(context, MaterialPageRoute(builder: (context) => const MyFilesScreen()));
                break;
              case 'Syllabus':
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SyllabusPage()),);
                break;
              case 'DateSheet':
                Navigator.push(context, MaterialPageRoute(builder: (context) => const DatesheetArchitect()),);
                break;
              case 'Notice':
                Navigator.push(context, MaterialPageRoute(builder: (context) => const NoticeArchitect()),);
                break;
              case 'Scan Doc':
                Navigator.push(context, MaterialPageRoute(builder: (context) => const DocumentScannerScreen()));
                break;

              case 'Fees Voucher':
                Navigator.push(context, MaterialPageRoute(builder: (context) => FeeVoucherDataEntry()));
                break;

              case 'Paper Vault':
                Navigator.push(context, MaterialPageRoute(builder: (context) => const QuestionVaultManager()));
                break;

              case 'Paper Architect':
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PaperArchitect()));
                break;

              case 'MarkSheet':
                Navigator.push(context, MaterialPageRoute(builder: (context) => const MarksheetPage()));
                break;
              case 'Test Architect':
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TestArchitect()));
                break;
              case 'Student Attendance':
                Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentAttendanceArchitect()));
                break;
              case 'Staff Attendance':
                Navigator.push(context, MaterialPageRoute(builder: (context) => const StaffAttendanceArchitect()));
                break;
              case 'Paper Scanner':
                Navigator.push(context, MaterialPageRoute(builder: (context) => const EnhancedPaperScanner()));
                break;
              case 'Dictionary':
                Navigator.push(context, MaterialPageRoute(builder: (context) => DictionaryScreen()));
                break;
              case 'Notes':
                Navigator.push(context, MaterialPageRoute(builder: (context) => AdvancedNotesScreen()));
                break;
              case 'Translate Doc':
                Navigator.push(context, MaterialPageRoute(builder: (context) => const DocumentTranslator()));
                break;

              case 'Results':
                Navigator.push(context, MaterialPageRoute(builder: (context) => const OwnerResultsScreen()));
                break;

              case 'Shared Documents':
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SharedDocsScreen()));
                break;

              case 'Scan Quiz Paper':
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanQuizPaper()));
                break;

              case 'Quiz':
                Navigator.push(context, MaterialPageRoute(builder: (context) => const QuizPage()));
                break;

              default:
              // Generic debug for unimplemented features
                debugPrint("Starlight Logic: $routeKey module selected.");
                break;
            }
          },
        );
      },
    );
  }

  Widget _vaultCard(BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }
}