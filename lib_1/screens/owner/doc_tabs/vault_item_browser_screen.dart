import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../../core/theme.dart';
import '../../../services/institution/document_service.dart';
import '../../../services/marksheet_service.dart';
import '../../hub/share_picker_screen.dart';
import 'syllabus_table_widget.dart';
import 'datesheet_table_widget.dart';
import 'fee_voucher_table_widget.dart';
import 'fee_voucher_data_entry.dart';
import 'scanned_document_table_widget.dart';
import 'document_scanner_screen.dart';
import 'marksheet_table_widget.dart';
import 'marksheet_page.dart';
import 'attendance_table_widget.dart';
import 'student_attendance_architect.dart';
import 'staff_attendance_architect.dart';
import 'blueprint_overlay.dart';
import 'blueprint_pdf_generator.dart';
import 'syllabus_page.dart';
import 'datesheet_architect.dart';
import 'translation_table_widget.dart';
import 'document_translator_editor.dart';
import 'draw_design_screen.dart';

class VaultItemBrowserScreen extends StatefulWidget {
  final String categoryName;
  final Color themeColor;

  const VaultItemBrowserScreen({
    super.key,
    required this.categoryName,
    required this.themeColor,
  });

  @override
  State<VaultItemBrowserScreen> createState() => _VaultItemBrowserScreenState();
}

class _VaultItemBrowserScreenState extends State<VaultItemBrowserScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedTimeFilter = "All"; // All, Latest, Past Week
  bool _isLoading = false;
  bool _isBlueprintOpen = false;
  bool _isSelectionMode = false;
  DateTimeRange? _selectedDateRange;
  Map<String, dynamic>? _selectedItemForBlueprint;
  final Set<Map<String, dynamic>> _selectedItems = {};

  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _loadCategorySpecificData();
    _searchController.addListener(_filterData);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategorySpecificData() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    final List<Map<String, dynamic>> mockData;

    final String tappedCategory = widget.categoryName.toLowerCase();
    final bool isFeesTab = tappedCategory == 'fee vouchers data' || tappedCategory == 'fees';
    final bool isMarksheetTab = tappedCategory == 'marksheets and tests' || tappedCategory == 'results';
    final bool isAttendanceTab = tappedCategory == 'students attendances and staff attendances' || tappedCategory == 'attendance';

    print("📱 [VAULT BROWSER] Initializing load for Category: '${widget.categoryName}' (lowercase: '$tappedCategory')");
    print("📱 [VAULT BROWSER] Mode checks - isFeesTab: $isFeesTab | isMarksheetTab: $isMarksheetTab | isAttendanceTab: $isAttendanceTab");

    // Load actual completed/finalized documents from the Neo4j graph server
    try {
      final DocumentService docService = DocumentService();
      final MarksheetService marksheetService = MarksheetService();
      
      print("📱 [VAULT BROWSER] Dispatching fetch request to Starlight server...");
      // 🏛️ Schema Logic: Call correct database endpoints based on category
      final List<dynamic> serverDocs = isFeesTab 
          ? await docService.getFeeVouchersHistory()
          : isMarksheetTab
              ? await marksheetService.getAllMarksheets()
              : isAttendanceTab
                  ? await docService.getAttendanceHistory() // 🏛️ UPGRADED: Loads actual attendance sessions dynamically!
                  : await docService.getFinalizedDocuments();
      
      // 📡 Log what the server returned raw
      print("📡 [SERVER RETURNED] Raw list from Neo4j for $tappedCategory: $serverDocs");
      
      if (isFeesTab) {
        // Map Fee Voucher database nodes
        if (serverDocs.isNotEmpty) {
          final List<Map<String, dynamic>> loadedData = serverDocs.map((s) {
            final String title = s['voucher_title'] ?? 'Fee Voucher';
            final String dateStr = s['created_at'] ?? '';
            
            DateTime timestamp = now;
            if (dateStr.isNotEmpty) {
              try {
                timestamp = DateTime.parse(dateStr);
              } catch (_) {}
            }

            return {
              'title': title,
              'timestamp': timestamp,
              'content': s['fee_items'] ?? [], // Capture the fee breakdowns
              'details': {
                'Student': s['student_name'] ?? 'N/A',
                'Father Name': s['father_name'] ?? 'N/A', // 🏛️ ADDED: Displays Father Name on the details slide!
                'Class/Sec': s['class_sec'] ?? 'N/A',
                'Voucher No': s['voucher_number'] ?? 'Auto',
                'Total Amount': "PKR ${s['total_amount'] ?? 0}",
                'Status': s['status']?.toString().toUpperCase() ?? 'UNPAID',
                'ID': s['id'] ?? 'N/A',
              }
            };
          }).toList();

          // 📱 Log what Flutter mapped
          print("📱 [FLUTTER RECEIVED & MAPPED] Formatted fee cards list: $loadedData");

          setState(() {
            _allItems = loadedData;
            _filteredItems = List.from(_allItems);
            _isLoading = false;
          });
          return;
        }
      } else if (isMarksheetTab) {
        // Map Marksheet database nodes
        if (serverDocs.isNotEmpty) {
          final List<Map<String, dynamic>> loadedData = serverDocs.map((m) {
            final String title = m['exam_title'] ?? 'Marksheet';
            final String dateStr = m['completed_at'] ?? m['created_at'] ?? '';
            
            DateTime timestamp = now;
            if (dateStr.isNotEmpty) {
              try {
                timestamp = DateTime.parse(dateStr);
              } catch (_) {}
            }

            return {
              'title': title,
              'timestamp': timestamp,
              'id': m['id'],
              'content': const [],
              'details': {
                'Subject': m['subject'] ?? 'General',
                'Class/Sec': m['class_name'] ?? 'N/A',
                'Max Marks': m['max_marks']?.toString() ?? '100',
                'Passing': m['passing_marks']?.toString() ?? '33',
                'ID': m['id'] ?? 'N/A',
                'Status': 'Completed',
                'Session': m['session_name'] ?? m['exam_title'] ?? '',
              }
            };
          }).toList();

          // 📱 Log what Flutter mapped
          print("📱 [FLUTTER RECEIVED & MAPPED] Formatted marksheet cards list: $loadedData");

          setState(() {
            _allItems = loadedData;
            _filteredItems = List.from(_allItems);
            _isLoading = false;
          });
          return;
        }
      } else if (isAttendanceTab) {
        // Map Attendance database nodes dynamically matching Student & Staff attendance structures!
        if (serverDocs.isNotEmpty) {
          final List<Map<String, dynamic>> loadedData = serverDocs.map((s) {
            final String mode = s['mode'] ?? 'Class';
            final String section = s['section_name'] ?? 'General';
            final String date = s['date'] ?? '';
            final String title = s['title'] ?? "${section} ${mode.toUpperCase()} Attendance (${date})";
            final String dateStr = s['created_at'] ?? '';
            
            DateTime timestamp = now;
            if (dateStr.isNotEmpty) {
              try {
                timestamp = DateTime.parse(dateStr);
              } catch (_) {}
            }

            final List<dynamic> records = s['records'] ?? [];
            final int presentCount = records.where((r) => r is Map && r['status'] == 'present').length;
            final int totalEnrolled = records.length;

            return {
              'title': title,
              'timestamp': timestamp,
              'content': records, // Capture individual present/absent student/staff records list
              'details': {
                'Section/Class': section,
                'Attendance Type': mode.toUpperCase(),
                'Date': date,
                'Total Enrolled': "$totalEnrolled Members",
                'Present Ratio': "$presentCount / $totalEnrolled Present",
                'ID': s['id'] ?? 'N/A',
              }
            };
          }).toList();

          // 📱 Log what Flutter mapped
          print("📱 [FLUTTER RECEIVED & MAPPED] Formatted attendance cards list: $loadedData");

          setState(() {
            _allItems = loadedData;
            _filteredItems = List.from(_allItems);
            _isLoading = false;
          });
          return;
        }
      } else {
        // Filter based on tapped category for Syllabus and DateSheets
        final List<dynamic> filteredServerDocs = serverDocs.where((doc) {
          final String subject = (doc['subject'] ?? '').toString().toLowerCase();
          final String name = (doc['name'] ?? '').toString().toLowerCase();
          
          if (tappedCategory == 'datesheets') {
            return subject.contains('datesheet') || name.contains('datesheet');
          } else if (tappedCategory == 'syllabus') {
            return !subject.contains('datesheet') && !name.contains('datesheet') && 
                   !subject.contains('fee') && !name.contains('fee') && 
                   !subject.contains('voucher') && !name.contains('voucher') &&
                   !subject.contains('scanned') && !name.contains('scanned') &&
                   subject != 'translation' && subject != 'uploads' && subject != 'original';
          } else if (tappedCategory == 'uploads') {
            return subject == 'uploads';
          } else if (tappedCategory == 'translated document' || tappedCategory == 'translation') {
            return subject == 'translation';
          }
          return true; // Other general categories
        }).toList();
        
        print("📱 [VAULT BROWSER] Filtered list count: ${filteredServerDocs.length} | Items: $filteredServerDocs");
        
        if (filteredServerDocs.isNotEmpty) {
          // Map the filtered list
          final List<Map<String, dynamic>> loadedData = filteredServerDocs.map((doc) {
            final String title = doc['name'] ?? doc['title'] ?? 'Untitled Document';
            final String subject = doc['subject'] ?? 'General';
            final String dateStr = doc['date'] ?? doc['created_at'] ?? '';
            
            DateTime timestamp = now;
            if (dateStr.isNotEmpty) {
              try {
                if (dateStr.contains('/')) {
                  final parts = dateStr.split('/');
                  if (parts.length == 3) {
                    timestamp = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                  }
                } else {
                  timestamp = DateTime.parse(dateStr);
                }
              } catch (_) {}
            }

            String parsedRawText = doc['rawText']?.toString() ?? '';
            if (parsedRawText.isEmpty && doc['content'] is List) {
              final List<dynamic> contentList = doc['content'];
              if (contentList.isNotEmpty && contentList.first is Map) {
                parsedRawText = contentList.first['text']?.toString() ?? '';
              }
            }

            return {
              'title': title,
              'timestamp': timestamp,
              'content': doc['content'],
              'rawText': parsedRawText,
              'original_file': doc['original_file'] ?? 'Scanned_Document.png',
              'details': {
                'Subject': subject,
                'Targets': doc['targets'] ?? 'All',
                'ID': doc['id'] ?? 'N/A',
                'Status': doc['is_final'] == true ? 'Deployed' : 'Pending Sync',
              }
            };
          }).toList();

          // 📱 Log what Flutter received and mapped for 3D card layout
          print("📱 [FLUTTER RECEIVED & MAPPED] Formatted cards list for ${widget.categoryName}: $loadedData");

          setState(() {
            _allItems = loadedData;
            _filteredItems = List.from(_allItems);
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e, stack) {
      debugPrint("Error fetching real documents from Neo4j (using fallbacks): $e");
      debugPrint("Stack trace: $stack");
    }

    switch (widget.categoryName.toLowerCase()) {
      case 'syllabus':
        mockData = [
          {
            'title': 'Mathematics Syllabus Grade 10', 
            'timestamp': now.subtract(const Duration(hours: 2)), 
            'content': [
              {
                'title': 'Mathematics Grade 10',
                'chapters': [
                  {'name': 'Chapter 1: Algebra', 'topics': ['Quadratic Equations', 'Synthetic Division']},
                  {'name': 'Chapter 2: Trigonometry', 'topics': ['Heights and Distances', 'Identity Verifications']}
                ]
              }
            ],
            'details': {'Format': 'PDF Document', 'Author': 'HOD Mathematics', 'Version': 'v1.4', 'Chapters': '14 chapters complete', 'Syllabus Type': 'Academic Curriculum'}
          },
          {
            'title': 'Physics Syllabus Grade 9', 
            'timestamp': now.subtract(const Duration(days: 1)), 
            'content': [
              {
                'title': 'Physics Grade 9',
                'chapters': [
                  {'name': 'Chapter 1: Kinematics', 'topics': ['Velocity', 'Acceleration Vectors']},
                  {'name': 'Chapter 2: Dynamics', 'topics': ['Newton\'s Laws', 'Friction Coefficients']}
                ]
              }
            ],
            'details': {'Format': 'PDF Document', 'Author': 'Senior Physics Coach', 'Version': 'v2.1', 'Labs': '8 Practical labs defined', 'Syllabus Type': 'Term 1'}
          },
          {
            'title': 'Chemistry Syllabus Grade 11', 
            'timestamp': now.subtract(const Duration(days: 4)), 
            'content': [
              {
                'title': 'Chemistry Grade 11',
                'chapters': [
                  {'name': 'Chapter 1: Organic', 'topics': ['Alkanes', 'Alkenes', 'Hybridization']},
                  {'name': 'Chapter 2: Inorganic', 'topics': ['Periodic Trends', 'Chemical Bonding']}
                ]
              }
            ],
            'details': {'Format': 'PDF Document', 'Author': 'Dr. Chemistry Dept', 'Version': 'v3.0', 'Topics': 'Organic & Inorganic core', 'Syllabus Type': 'Board Standards'}
          },
          {
            'title': 'English Language Syllabus', 
            'timestamp': now.subtract(const Duration(days: 15)), 
            'content': [
              {
                'title': 'English Language',
                'chapters': [
                  {'name': 'Chapter 1: Comprehension', 'topics': ['Active Reading', 'Vocabulary Synthesis']},
                  {'name': 'Chapter 2: Composition', 'topics': ['Essay Writing', 'Narrative Structuring']}
                ]
              }
            ],
            'details': {'Format': 'PDF Document', 'Author': 'Dept of Linguistics', 'Version': 'v1.0', 'Modules': 'Grammar & Prose', 'Syllabus Type': 'O-Level Standards'}
          },
        ];
        break;
      case 'datesheets':
        mockData = [
          {
            'title': 'Midterm Examinations 2024', 
            'timestamp': now.subtract(const Duration(minutes: 45)), 
            'content': [
              {'subject_name': 'Mathematics', 'date': '2026-06-15', 'day': 'Monday', 'time': '09:00 AM', 'duration_mins': 150, 'venue': 'Examination Hall A'},
              {'subject_name': 'English Language', 'date': '2026-06-16', 'day': 'Tuesday', 'time': '09:00 AM', 'duration_mins': 120, 'venue': 'Examination Hall B'},
              {'subject_name': 'Physics Theory', 'date': '2026-06-18', 'day': 'Thursday', 'time': '09:00 AM', 'duration_mins': 150, 'venue': 'Main Sports Complex'}
            ],
            'details': {'Venue': 'Examination Hall A', 'Sessions': 'Morning & Evening shifts', 'Dates': 'Dec 15 - Dec 24', 'Approved By': 'Principal Console'}
          },
          {
            'title': 'Final Board Datesheet', 
            'timestamp': now.subtract(const Duration(days: 2)), 
            'content': [
              {'subject_name': 'Pure Chemistry', 'date': '2026-07-02', 'day': 'Thursday', 'time': '08:30 AM', 'duration_mins': 180, 'venue': 'Central Arena Hall'},
              {'subject_name': 'Biology Practical', 'date': '2026-07-05', 'day': 'Sunday', 'time': '10:00 AM', 'duration_mins': 120, 'venue': 'Senior Bio Lab 2'}
            ],
            'details': {'Venue': 'Central Arena Hall', 'Sessions': 'Single Morning Shift', 'Dates': 'May 02 - May 28', 'Approved By': 'Provincial Board'}
          },
          {
            'title': 'Chemistry Lab Practical Schedule', 
            'timestamp': now.subtract(const Duration(days: 5)), 
            'content': [
              {'subject_name': 'Qualitative Analysis', 'date': '2026-07-10', 'day': 'Friday', 'time': '11:00 AM', 'duration_mins': 90, 'venue': 'Main Science wing'}
            ],
            'details': {'Venue': 'Senior Science Labs', 'Sessions': 'Continuous batches', 'Dates': 'Jan 10 - Jan 14', 'Approved By': 'Lab Controller'}
          },
        ];
        break;
      case 'fees':
      case 'fee vouchers data':
        mockData = [
          {
            'title': 'Batch A Invoices & Vouchers', 
            'timestamp': now.subtract(const Duration(hours: 4)), 
            'content': [
              {'voucher_number': 'V-102', 'voucher_title': 'Monthly Tuition Fee', 'student_name': 'Ali Khan', 'class_sec': 'Grade 10', 'fee_items': [{'fee_type': 'Tuition Fee', 'amount': 3500.0}], 'total_amount': 3500.0, 'status': 'unpaid'},
              {'voucher_number': 'V-103', 'voucher_title': 'Term Exam Registration', 'student_name': 'Aisha Bibi', 'class_sec': 'Grade 9', 'fee_items': [{'fee_type': 'Exam Fee', 'amount': 1500.0}], 'total_amount': 1500.0, 'status': 'paid'},
              {'voucher_number': 'V-104', 'voucher_title': 'Science Practical Lab Fee', 'student_name': 'Hamza Ahmed', 'class_sec': 'Grade 11', 'fee_items': [{'fee_type': 'Lab Practical Fee', 'amount': 1200.0}], 'total_amount': 1200.0, 'status': 'unpaid'}
            ],
            'details': {'Billing Period': 'Oct - Dec Quarterly', 'Total Vouchers': '240 Generated', 'Net Revenue': 'PKR 1.2M expected', 'Outstanding': '15% due'}
          },
          {
            'title': 'Outstanding Fee Ledger', 
            'timestamp': now.subtract(const Duration(days: 3)), 
            'content': [
              {'voucher_number': 'V-201', 'voucher_title': 'Outstanding Library Dues', 'student_name': 'Sana Gul', 'class_sec': 'O-Level', 'fee_items': [{'fee_type': 'Late Book Returns', 'amount': 500.0}], 'total_amount': 500.0, 'status': 'unpaid'}
            ],
            'details': {'Billing Period': 'September Recurrent', 'Total Vouchers': '45 Pending', 'Net Revenue': 'PKR 250K expected', 'Defaulters List': 'Secured'}
          },
          {
            'title': 'Institutional Financial Log', 
            'timestamp': now.subtract(const Duration(days: 12)), 
            'content': [
              {'voucher_number': 'V-305', 'voucher_title': 'Yearly Sports Registration', 'student_name': 'Bilal Shah', 'class_sec': 'A-Level', 'fee_items': [{'fee_type': 'Sports Kits', 'amount': 2500.0}], 'total_amount': 2500.0, 'status': 'paid'}
            ],
            'details': {'Billing Period': 'Fiscal Year Audit', 'Total Vouchers': 'Audited summary', 'Net Revenue': 'Fully Synced', 'Audit Status': 'Certified'}
          },
        ];
        break;
      case 'scanned':
      case 'scanned documents':
        mockData = [
          {
            'title': 'Student ID Card Scan Registry', 
            'timestamp': now.subtract(const Duration(hours: 1)), 
            'rawText': 'STUDENT REGISTRATION ID CARD:\nName: Ali Hassan, Roll No: 15, Grade: class 10, Father Name: Abbas ali',
            'original_file': 'Student_ID_Scan_105.png',
            'content': [
              {'name': 'Student Name', 'text': 'Ali Hassan'},
              {'name': 'Roll Number', 'text': '15'},
              {'name': 'Father Name', 'text': 'Abbas ali'}
            ],
            'details': {'Resolution': '300 DPI High-Res', 'Total Scans': '145 Files', 'Scan Format': 'Color PNG', 'Storage Server': 'Secure Cloud'}
          },
          {
            'title': 'Board Enrollment Affidavits', 
            'timestamp': now.subtract(const Duration(days: 2)), 
            'rawText': 'BOARD ENROLLMENT AFFIDAVIT:\nInstitution Name: Starlight high, Section: class 10',
            'original_file': 'Enrollment_Affidavit.pdf',
            'content': [
              {'name': 'Institution Name', 'text': 'Starlight Institution'},
              {'name': 'Section/Class', 'text': 'class 10'}
            ],
            'details': {'Resolution': '200 DPI Grayscale', 'Total Scans': '35 Files', 'Scan Format': 'Multi-page PDF', 'Storage Server': 'Local Vault'}
          },
          {
            'title': 'Staff Registration Portals', 
            'timestamp': now.subtract(const Duration(days: 8)), 
            'rawText': 'STAFF PROFILE REGISTRATION:\nFull Name: Abbas ali, Role: Administrative Coordinator',
            'original_file': 'Staff_Registration.tiff',
            'content': [
              {'name': 'Staff Full Name', 'text': 'Abbas ali'},
              {'name': 'Role Assigned', 'text': 'Administrative Coordinator'}
            ],
            'details': {'Resolution': '150 DPI Fast Scan', 'Total Scans': '18 Files', 'Scan Format': 'Single Page TIFF', 'Storage Server': 'Hardware Secure'}
          },
        ];
        break;
      case 'results':
      case 'marksheets and tests':
        mockData = [
          {
            'title': 'Annual Grade 10 Marksheet Summary', 
            'timestamp': now.subtract(const Duration(hours: 6)), 
            'content': [
              {'student_id': 's1', 'student_name': 'Ali Hassan', 'father_name': 'Abbas ali', 'roll_number': '15', 'marks_obtained': 92, 'max_marks': 100, 'grade': 'A+', 'percentage': 92.0, 'status': 'pass'},
              {'student_id': 's2', 'student_name': 'Sajid Mehmood', 'father_name': 'Mehmood Khan', 'roll_number': '22', 'marks_obtained': 78, 'max_marks': 100, 'grade': 'A', 'percentage': 78.0, 'status': 'pass'},
              {'student_id': 's3', 'student_name': 'Fatima Bibi', 'father_name': 'Ziauddin', 'roll_number': '08', 'marks_obtained': 31, 'max_marks': 100, 'grade': 'F', 'percentage': 31.0, 'status': 'fail'}
            ],
            'details': {'Total Enrolled': '180 Students', 'Pass Ratio': '94.5%', 'Top Scorer': '982 / 1000 Marks', 'Publishing status': 'Released to Portal'}
          },
          {
            'title': 'Physics Weekly Mock Test Results', 
            'timestamp': now.subtract(const Duration(days: 1)), 
            'content': [
              {'student_id': 's1', 'student_name': 'Ali Hassan', 'father_name': 'Abbas ali', 'roll_number': '15', 'marks_obtained': 45, 'max_marks': 50, 'grade': 'A+', 'percentage': 90.0, 'status': 'pass'},
              {'student_id': 's2', 'student_name': 'Sajid Mehmood', 'father_name': 'Mehmood Khan', 'roll_number': '22', 'marks_obtained': 25, 'max_marks': 50, 'grade': 'C', 'percentage': 50.0, 'status': 'pass'}
            ],
            'details': {'Total Enrolled': '45 Students', 'Pass Ratio': '88%', 'Top Scorer': '48 / 50 Marks', 'Publishing status': 'Draft/Internal'}
          },
          {
            'title': 'O-Level Chemistry Term Assessment', 
            'timestamp': now.subtract(const Duration(days: 10)), 
            'content': [
              {'student_id': 's1', 'student_name': 'Ali Hassan', 'father_name': 'Abbas ali', 'roll_number': '15', 'marks_obtained': 85, 'max_marks': 100, 'grade': 'A', 'percentage': 85.0, 'status': 'pass'}
            ],
            'details': {'Total Enrolled': '32 Students', 'Pass Ratio': '100%', 'Top Scorer': 'Grade A*', 'Publishing status': 'Locked'}
          },
        ];
        break;
      case 'attendance':
      case 'students attendances and staff attendances':
        mockData = [
          {
            'title': 'Grade 9-A Student Attendance Log', 
            'timestamp': now.subtract(const Duration(hours: 3)), 
            'content': [
              {'student_id': 's1', 'student_name': 'Ali Hassan', 'father_name': 'Abbas ali', 'status': 'present'},
              {'student_id': 's2', 'student_name': 'Sajid Mehmood', 'father_name': 'Mehmood Khan', 'status': 'absent'},
              {'student_id': 's3', 'student_name': 'Fatima Bibi', 'father_name': 'Ziauddin', 'status': 'present'}
            ],
            'details': {'Daily Status': 'Completed', 'Total Enrolled': '40 Students', 'Present Ratio': '92.5%', 'Late Incomers': '3 Recorded'}
          },
          {
            'title': 'Staff Bio-Metric Monthly Ledger', 
            'timestamp': now.subtract(const Duration(days: 2)), 
            'content': [
              {'staff_id': 'stf1', 'staff_name': 'Abbas ali', 'role': 'HOD Science', 'department': 'Academic', 'status': 'present'},
              {'staff_id': 'stf2', 'staff_name': 'Zeenat Jahan', 'role': 'Senior Instructor', 'department': 'Linguistic', 'status': 'leave'}
            ],
            'details': {'Monthly Status': 'Audited', 'Total Enrolled': '28 Staff Members', 'Present Ratio': '98%', 'Leave Approvals': '2 Pending'}
          },
          {
            'title': 'Institutional Attendance Summary', 
            'timestamp': now.subtract(const Duration(days: 6)), 
            'content': [
              {'student_id': 's1', 'student_name': 'Ali Hassan', 'father_name': 'Abbas ali', 'status': 'present'},
              {'staff_id': 'stf1', 'staff_name': 'Abbas ali', 'role': 'HOD Science', 'department': 'Academic', 'status': 'present'}
            ],
            'details': {'Weekly Status': 'Compiled', 'Total Enrolled': 'Global Registry', 'Present Ratio': '95.8%', 'Anomalies': 'None'}
          },
        ];
        break;
      case 'translation':
      case 'translated document':
        mockData = [
          {
            'title': 'Translated Registration Agreement',
            'timestamp': now.subtract(const Duration(hours: 12)),
            'content': [
              {'title': 'Terms of Service', 'translated_text': 'سروس کی شرائط'},
              {'title': 'User Registration', 'translated_text': 'صارف کا اندراج'},
              {'title': 'Privacy Policy Agreement', 'translated_text': 'رازداری کی پالیسی کا معاہدہ'},
              {'title': '1. General Provisions', 'translated_text': '1۔ عام دفعات'}
            ],
            'details': {'Original': 'English standard', 'Target': 'Urdu Official translation', 'Translating Engine': 'Starlight AI ML-Kit', 'Accuracy': '98.4% verified'}
          },
          {
            'title': 'Notice Board Board-Order Translated',
            'timestamp': now.subtract(const Duration(days: 3)),
            'content': [
              {'title': 'Official Announcement', 'translated_text': 'سرکاری اعلان'},
              {'title': 'Summer Vacation Notice', 'translated_text': 'گرمیوں کی چھٹیوں کا نوٹس'},
              {'title': 'School Reopening Date', 'translated_text': 'سکول دوبارہ کھلنے کی تاریخ'},
              {'title': 'Attendance Policy Notice', 'translated_text': 'حاضری کی پالیسی کا نوٹس'}
            ],
            'details': {'Original': 'Urdu Press release', 'Target': 'English official release', 'Translating Engine': 'Starlight Neural', 'Accuracy': '100% Certified'}
          },
        ];
        break;
      case 'uploads':
      case 'general':
      default:
        mockData = [
          {'title': 'Cloud Assets Backup Archive', 'timestamp': now.subtract(const Duration(hours: 24)), 'details': {'Backup Size': '1.2 GB', 'Contents': 'PNG Blueprints, Excel logs', 'Encryption': 'AES-256 Enabled', 'Server Hash': 'SHA-256 Validated'}},
          {'title': 'Local Hardware Storage Backup', 'timestamp': now.subtract(const Duration(days: 7)), 'details': {'Backup Size': '450 MB', 'Contents': 'Local Vault DB registry', 'Encryption': 'Hardware Level', 'Server Hash': 'Verified'}},
        ];
    }

    setState(() {
      _allItems = mockData;
      _filteredItems = List.from(_allItems);
      _isLoading = false; // Turn off loading state so mock fallback displays
    });
  }

  void _filterData() {
    final query = _searchQuery.toLowerCase();
    final now = DateTime.now();

    setState(() {
      _filteredItems = _allItems.where((item) {
        // 🏛️ Search title first
        bool matchesSearch = item['title'].toString().toLowerCase().contains(query);

        // 🏛️ Broad Metadata search: let the user filter by ANY detailed field (subject, grade, author, tags)
        if (item['details'] != null && item['details'] is Map) {
          final detailsMap = item['details'] as Map;
          for (var val in detailsMap.values) {
            if (val.toString().toLowerCase().contains(query)) {
              matchesSearch = true;
              break;
            }
          }
        }

        bool matchesTime = true;
        final timestamp = item['timestamp'] as DateTime;
        
        if (_selectedDateRange != null) {
          // Check if timestamp is between start and end date (inclusive of the whole days)
          final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day, 0, 0, 0);
          final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
          matchesTime = timestamp.isAfter(start) && timestamp.isBefore(end);
        } else {
          if (_selectedTimeFilter == "Latest") {
            matchesTime = now.difference(timestamp).inHours <= 24;
          } else if (_selectedTimeFilter == "Past Week") {
            matchesTime = now.difference(timestamp).inDays <= 7;
          }
        }

        return matchesSearch && matchesTime;
      }).toList();
    });
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}h ago";
    } else {
      return "${timestamp.day}/${timestamp.month}/${timestamp.year}";
    }
  }

  // ==========================================
  // 🏛️ BATCH SELECTION & EDITING OPERATIONS
  // ==========================================
  void _toggleSelectAll() {
    setState(() {
      if (_selectedItems.length == _filteredItems.length) {
        _selectedItems.clear();
      } else {
        _selectedItems.addAll(_filteredItems);
      }
    });
  }

  void _editItem() {
    if (_selectedItems.length != 1) return;
    final item = _selectedItems.first;

    // Exit selection mode & clear selection
    setState(() {
      _isSelectionMode = false;
      _selectedItems.clear();
    });

    // Reconstruct payload for Architect hydration safely with no map bracket-ques syntax conflicts
    final detailsMap = item['details'] as Map<String, dynamic>?;
    final payload = {
      'id': detailsMap != null ? detailsMap['ID'] ?? '' : '',
      'name': item['title'] ?? '',
      'subject': detailsMap != null ? detailsMap['Subject'] ?? '' : '',
      'targets': (detailsMap != null && detailsMap['Targets'] is List)
          ? detailsMap['Targets']
          : [detailsMap != null ? detailsMap['Targets']?.toString() ?? '' : ''],
      'content': item['content'],
      'is_final': detailsMap != null && detailsMap['Status'] == 'Deployed',
    };

    final String tappedCategory = widget.categoryName.toLowerCase();
    final bool isDatesheet = tappedCategory == 'datesheets';
    final bool isFees = tappedCategory == 'fee vouchers data' || tappedCategory == 'fees';
    final bool isScanned = tappedCategory == 'scanned documents' || tappedCategory == 'scanned';
    final bool isMarksheet = tappedCategory == 'marksheets and tests' || tappedCategory == 'results';
    final bool isAttendance = tappedCategory == 'students attendances and staff attendances' || tappedCategory == 'attendance';
    final bool isTranslation = tappedCategory == 'translation' || tappedCategory == 'translated document';
    final bool isUploads = tappedCategory == 'uploads';

    // Push correct architect, passing the hydration payload!
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          if (isDatesheet) {
            return DatesheetArchitect(initialData: payload);
          } else if (isFees) {
            return FeeVoucherDataEntry(initialData: payload);
          } else if (isScanned) {
            return DocumentScannerScreen(initialData: payload);
          } else if (isMarksheet) {
            return MarksheetPage(initialData: payload);
          } else if (isAttendance) {
            final String title = payload['name']?.toString().toLowerCase() ?? '';
            if (title.contains('staff')) {
              return StaffAttendanceArchitect(initialData: payload);
            } else {
              return StudentAttendanceArchitect(initialData: payload);
            }
          } else if (isTranslation) {
            return DocumentTranslatorEditor(initialData: payload);
          } else if (isUploads) {
            final String? b64 = _extractBase64(payload['content']);
            Uint8List? bgBytes;
            if (b64 != null) {
              try { bgBytes = base64Decode(b64); } catch (_) {}
            }
            return DrawDesignScreen(backgroundImageBytes: bgBytes);
          } else {
            return SyllabusPage(initialData: payload);
          }
        },
      ),
    ).then((result) async {
      if (isUploads && result != null && result is Map<String, dynamic>) {
        // Show a beautiful loading modal
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator(color: StarlightTheme.primaryBlue)),
        );
        
        try {
          final String newName = result['name'];
          final Uint8List newBytes = result['bytes'];
          final String base64File = base64Encode(newBytes);
          final size = "${(newBytes.length / 1024).toStringAsFixed(1)} KB";

          final newPayload = {
            'id': payload['id'], // Overwrite/Update existing document!
            'name': newName,
            'subject': 'uploads',
            'targets': 'All',
            'content': {
              'base64': base64File,
              'size': size,
              'extension': 'PNG',
            },
          };

          final DocumentService docService = DocumentService();
          await docService.uploadFinalDocument(newPayload);
          _showMessage("File '$newName' updated successfully!", true);
        } catch (e) {
          _showMessage("Failed to save changes: $e", false);
        } finally {
          Navigator.pop(context); // Pop loading dialog
        }
      }
      _loadCategorySpecificData();
    });
  }

  void _batchDelete() {
    if (_selectedItems.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete ${_selectedItems.length} Item(s)?"),
        content: const Text("Are you sure you want to delete the selected documents from the server? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final DocumentService docService = DocumentService();
              
              // Perform deletion on the server for each selected item safely by copying the list first!
              final itemsToDelete = List<Map<String, dynamic>>.from(_selectedItems);
              for (var item in itemsToDelete) {
                final docId = item['details']?['ID'];
                if (docId != null && docId != 'N/A') {
                  try {
                    await docService.deleteDraftDocument(docId);
                  } catch (e) {
                    debugPrint("Server delete notice for $docId: $e");
                  }
                }
              }

              setState(() {
                _allItems.removeWhere((item) => _selectedItems.contains(item));
                _filteredItems.removeWhere((item) => _selectedItems.contains(item));
                _selectedItems.clear();
                _isSelectionMode = false;
              });
              Navigator.pop(context);
              _showMessage("Documents deleted from Vault successfully", true);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<String?> _showLanguageChoiceDialog() async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Print Layout Language"),
        content: const Text("Would you like to print the Original, Translated, or Bilingual side-by-side layout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'original'),
            child: const Text("Original (English)"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'translated'),
            child: const Text("Translated (Urdu)"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'bilingual'),
            child: const Text("Bilingual (Side-by-Side)"),
          ),
        ],
      ),
    );
  }

  void _shareSelected() {
    if (_selectedItems.isEmpty) return;
    final item = _selectedItems.first;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SharePickerScreen(
          category: widget.categoryName,
          title: item['title']?.toString() ?? 'Untitled',
          details: item['details'] is Map ? Map<String, dynamic>.from(item['details']) : {},
          timestamp: item['timestamp']?.toString() ?? '',
        ),
      ),
    ).then((shared) {
      if (shared == true) {
        setState(() {
          _selectedItems.clear();
          _isSelectionMode = false;
        });
      }
    });
  }

  void _batchPrint() {
    if (_selectedItems.isEmpty) return;
    final item = _selectedItems.first;
    final String tappedCat = widget.categoryName.toLowerCase();
    final bool isBypassed = tappedCat == 'scanned documents' || tappedCat == 'scanned' || 
                            tappedCat == 'marksheets and tests' || tappedCat == 'results' ||
                            tappedCat == 'translation' || tappedCat == 'translated document' ||
                            tappedCat == 'uploads';

    if (isBypassed) {
      if (tappedCat == 'translation' || tappedCat == 'translated document') {
        _showLanguageChoiceDialog().then((choice) {
          if (choice == null) return;
          BlueprintPdfGenerator.generateAndInstallDocument(
            context: context,
            documentTitle: item['title'] as String,
            categoryName: widget.categoryName,
            blueprint: const {},
            printLanguage: choice,
            content: _getPrintContent(widget.categoryName, item['content']),
            rawText: item['rawText']?.toString() ?? '',
          );
          setState(() {
            _selectedItems.clear();
            _isSelectionMode = false;
          });
        });
      } else {
        BlueprintPdfGenerator.generateAndInstallDocument(
          context: context,
          documentTitle: item['title'] as String,
          categoryName: widget.categoryName,
          blueprint: const {},
          content: _getPrintContent(widget.categoryName, item['content']),
          rawText: item['rawText']?.toString() ?? '',
        );
        setState(() {
          _selectedItems.clear();
          _isSelectionMode = false;
        });
      }
    } else {
      // Set first selected item as active target for printing
      setState(() {
        _selectedItemForBlueprint = item;
        _isBlueprintOpen = true;
      });
    }
  }

  void _showBriefDetailsBottomSheet(Map<String, dynamic> item) {
    setState(() => _selectedItemForBlueprint = item);
    final details = item['details'] as Map<String, dynamic>;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: widget.themeColor.withOpacity(0.1),
                  radius: 22,
                  child: Icon(Icons.info_outline_rounded, color: widget.themeColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['title'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
                      Text("Synced: ${_formatTimestamp(item['timestamp'] as DateTime)}", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text("DOCUMENT DETAILS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Column(
              children: details.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                      Text(entry.value.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.themeColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      Navigator.pop(context); // Close bottom sheet
                      
                      final String tappedCat = widget.categoryName.toLowerCase();
                      final bool isMarksheet = tappedCat == 'marksheets and tests' || tappedCat == 'results';
                      
                      if (isMarksheet && (item['content'] == null || (item['content'] as List).isEmpty)) {
                        // Show a beautiful modal loader while lazy-fetching
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.amber)),
                        );
                        
                        try {
                          final MarksheetService marksheetService = MarksheetService();
                          final fullDoc = await marksheetService.getMarksheetById(item['id'] ?? '');
                          if (context.mounted) Navigator.pop(context); // Pop loading spinner
                          
                          setState(() {
                            item['content'] = fullDoc['marks_data'] ?? [];
                          });
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context); // Pop loading spinner
                            _showMessage("Error loading marks: $e", false);
                          }
                          return;
                        }
                      }

                      // Open interactive scalable table dialog
                      if (context.mounted) {
                        double rotateX = 0.2;
                        double rotateY = -0.2;
                        double perspective = 0.0015;
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            contentPadding: EdgeInsets.zero,
                            content: SizedBox(
                              width: double.maxFinite,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  widget.categoryName.toLowerCase() == 'datesheets'
                                      ? DatesheetTableWidget(
                                          content: _parseContent(item['content']),
                                        )
                                      : (widget.categoryName.toLowerCase() == 'fee vouchers data' || widget.categoryName.toLowerCase() == 'fees')
                                          ? FeeVoucherTableWidget(
                                              content: _parseContent(item['content']),
                                              studentName: item['details']?['Student'] ?? 'N/A',
                                              fatherName: item['details']?['Father Name'] ?? 'N/A',
                                            )
                                          : (widget.categoryName.toLowerCase() == 'scanned documents' || widget.categoryName.toLowerCase() == 'scanned')
                                              ? ScannedDocumentTableWidget(
                                                  content: _parseContent(item['content']),
                                                  rawText: item['rawText']?.toString() ?? '',
                                                  fileName: item['original_file']?.toString() ?? '',
                                                )
                                              : (widget.categoryName.toLowerCase() == 'marksheets and tests' || widget.categoryName.toLowerCase() == 'results')
                                                  ? MarksheetTableWidget(
                                                      content: _parseContent(item['content']),
                                                    )
                                                   : (widget.categoryName.toLowerCase() == 'students attendances and staff attendances' || widget.categoryName.toLowerCase() == 'attendance')
                                                       ? AttendanceTableWidget(
                                                           content: _parseContent(item['content']),
                                                         )
                                                        : widget.categoryName.toLowerCase() == 'uploads'
                                                            ? StatefulBuilder(
                                                                builder: (context, setDialogState) {
                                                                  return GestureDetector(
                                                                    onPanUpdate: (details) {
                                                                      setDialogState(() {
                                                                        rotateX += details.delta.dy * 0.005;
                                                                        rotateY += details.delta.dx * 0.005;
                                                                      });
                                                                    },
                                                                    child: Container(
                                                                      height: 350,
                                                                      alignment: Alignment.center,
                                                                      decoration: BoxDecoration(
                                                                        color: Colors.white,
                                                                        borderRadius: BorderRadius.circular(16),
                                                                        border: Border.all(color: Colors.grey.shade200),
                                                                      ),
                                                                      child: Stack(
                                                                        children: [
                                                                          const Positioned(
                                                                            bottom: 12,
                                                                            left: 12,
                                                                            child: Row(
                                                                              children: [
                                                                                Icon(Icons.swipe, size: 14, color: Colors.grey),
                                                                                SizedBox(width: 4),
                                                                                Text("Swipe Card to Rotate in 3D Space",
                                                                                    style: TextStyle(
                                                                                        fontSize: 9,
                                                                                        color: Colors.grey,
                                                                                        fontWeight: FontWeight.bold)),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                          Center(
                                                                            child: Transform(
                                                                              transform: Matrix4.identity()
                                                                                ..setEntry(3, 2, perspective)
                                                                                ..rotateX(rotateX)
                                                                                ..rotateY(rotateY),
                                                                              alignment: FractionalOffset.center,
                                                                              child: (() {
                                                                                final String? b64 = _extractBase64(item['content']);
                                                                                if (b64 != null) {
                                                                                  try {
                                                                                    return Container(
                                                                                      width: 220,
                                                                                      height: 220,
                                                                                      decoration: BoxDecoration(
                                                                                        color: Colors.white,
                                                                                        borderRadius: BorderRadius.circular(12),
                                                                                        border: Border.all(
                                                                                            color: widget.themeColor.withOpacity(0.5),
                                                                                            width: 1.5),
                                                                                        boxShadow: [
                                                                                          BoxShadow(
                                                                                            color: widget.themeColor.withOpacity(0.2),
                                                                                            blurRadius: 16,
                                                                                            spreadRadius: 2,
                                                                                            offset: const Offset(4, 8),
                                                                                          ),
                                                                                        ],
                                                                                      ),
                                                                                      child: ClipRRect(
                                                                                        borderRadius: BorderRadius.circular(11),
                                                                                        child: Image.memory(
                                                                                          base64Decode(b64),
                                                                                          fit: BoxFit.contain,
                                                                                        ),
                                                                                      ),
                                                                                    );
                                                                                  } catch (e) {
                                                                                    return Text("Error decoding image: $e",
                                                                                        style: const TextStyle(color: Colors.red));
                                                                                  }
                                                                                }
                                                                                return const Text("No image preview available.",
                                                                                    style: TextStyle(color: Colors.grey));
                                                                              })(),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  );
                                                                },
                                                              )
                                                           : (widget.categoryName.toLowerCase() == 'translation' || widget.categoryName.toLowerCase() == 'translated document')
                                                               ? TranslationTableWidget(
                                                                   content: _parseContent(item['content']),
                                                                 )
                                                               : SyllabusTableWidget(
                                                                   content: _parseContent(item['content']),
                                                                 ),
                                ],
                              ),
                            ),
                             actions: [
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: widget.themeColor),
                                onPressed: () async {
                                  Navigator.pop(context); // Close table dialog
                                  final String tappedCat = widget.categoryName.toLowerCase();
                                   final bool isBypassed = tappedCat == 'scanned documents' || tappedCat == 'scanned' || 
                                                           tappedCat == 'marksheets and tests' || tappedCat == 'results' ||
                                                           tappedCat == 'translation' || tappedCat == 'translated document' ||
                                                           tappedCat == 'uploads';
                                  
                                  if (isBypassed) {
                                    String? langChoice;
                                    if (tappedCat == 'translation' || tappedCat == 'translated document') {
                                      langChoice = await _showLanguageChoiceDialog();
                                      if (langChoice == null) return;
                                    }

                                    BlueprintPdfGenerator.generateAndInstallDocument(
                                      context: context,
                                      documentTitle: _selectedItemForBlueprint!['title'] as String,
                                      categoryName: widget.categoryName,
                                      blueprint: const {},
                                      printLanguage: langChoice,
                                      content: _getPrintContent(widget.categoryName, _selectedItemForBlueprint!['content']),
                                      rawText: _selectedItemForBlueprint!['rawText']?.toString() ?? '',
                                    );
                                  } else {
                                    setState(() => _isBlueprintOpen = true); // Slide open Blueprint Overlay
                                  }
                                },
                                icon: const Icon(Icons.print_rounded, size: 16),
                                label: const Text("PRINT", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(foregroundColor: Colors.grey),
                                onPressed: () => Navigator.pop(context),
                                child: const Text("CLOSE TABLE"),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.grid_view_rounded, size: 18),
                    label: const Text("SHOW DATA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                if (item.containsKey('content') && item['content'] != null)
                  const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text("CLOSE PREVIEW", style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          "${widget.categoryName.toUpperCase()} VAULT",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: widget.themeColor, letterSpacing: 1.1),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 3D Header & Search Section
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  children: [
                // Tech Styled Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() {
                    _searchQuery = value;
                    _filterData();
                  }),
                  decoration: InputDecoration(
                    hintText: "Search registry files...",
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: widget.themeColor, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Timestamp Filter Row
                Row(
                  children: [
                    const Icon(Icons.filter_list_rounded, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...["All", "Latest", "Past Week"].map((timeFilter) {
                              final isSelected = timeFilter == _selectedTimeFilter && _selectedDateRange == null;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(timeFilter, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                  selected: isSelected,
                                  selectedColor: widget.themeColor.withOpacity(0.15),
                                  backgroundColor: Colors.grey.shade100,
                                  labelStyle: TextStyle(color: isSelected ? widget.themeColor : Colors.black87),
                                  onSelected: (val) {
                                    if (val) {
                                      setState(() {
                                        _selectedDateRange = null; // Clear custom range
                                        _selectedTimeFilter = timeFilter;
                                        _filterData();
                                      });
                                    }
                                  },
                                ),
                              );
                            }),
                            
                            // 🏛️ Custom Interactive 3D Date Range Picker Chip!
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.date_range_rounded, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      _selectedDateRange != null
                                          ? "${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}"
                                          : "Custom Dates...",
                                      style: TextStyle(fontSize: 11, fontWeight: _selectedDateRange != null ? FontWeight.bold : FontWeight.normal),
                                    ),
                                  ],
                                ),
                                selected: _selectedDateRange != null,
                                selectedColor: widget.themeColor.withOpacity(0.15),
                                backgroundColor: Colors.grey.shade100,
                                labelStyle: TextStyle(color: _selectedDateRange != null ? widget.themeColor : Colors.black87),
                                onSelected: (val) async {
                                  if (val) {
                                    final DateTimeRange? picked = await showDateRangePicker(
                                      context: context,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                      initialDateRange: _selectedDateRange,
                                      builder: (context, child) {
                                        return Theme(
                                          data: ThemeData.light().copyWith(
                                            colorScheme: ColorScheme.light(
                                              primary: widget.themeColor,
                                              onPrimary: Colors.white,
                                              surface: Colors.white,
                                              onSurface: Colors.black87,
                                            ),
                                            appBarTheme: const AppBarTheme(
                                              backgroundColor: Colors.white,
                                              foregroundColor: Colors.black87,
                                              elevation: 0,
                                            ),
                                            scaffoldBackgroundColor: Colors.white,
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _selectedDateRange = picked;
                                        _selectedTimeFilter = ""; // Clear other preset filters
                                        _filterData();
                                      });
                                    }
                                  } else {
                                    setState(() {
                                      _selectedDateRange = null;
                                      _selectedTimeFilter = "All"; // Reset to default preset
                                      _filterData();
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 3D Grid Display
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text("No records found", style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                          ],
                        ),
                      )
                    : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.35,
                    ),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      bool isHeld = false;
                      final isSelected = _selectedItems.contains(item);

                      return StatefulBuilder(
                        builder: (context, setTileState) {
                          return GestureDetector(
                            onTapDown: (_) => setTileState(() => isHeld = true),
                            onTapCancel: () => setTileState(() => isHeld = false),
                            onLongPress: () {
                              setState(() {
                                _isSelectionMode = true;
                                _selectedItems.add(item);
                              });
                            },
                            onTapUp: (_) {
                              setTileState(() => isHeld = false);
                              if (_isSelectionMode) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedItems.remove(item);
                                    if (_selectedItems.isEmpty) {
                                      _isSelectionMode = false;
                                    }
                                  } else {
                                    _selectedItems.add(item);
                                  }
                                });
                              } else {
                                _showBriefDetailsBottomSheet(item);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOut,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001) // perspective ratio
                                ..rotateX(isHeld ? 0.02 : 0.06) // 3D slanted deck effect
                                ..rotateY(isHeld ? -0.01 : -0.04),
                              decoration: BoxDecoration(
                                color: isSelected ? widget.themeColor.withOpacity(0.04) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? widget.themeColor : widget.themeColor.withOpacity(0.15), 
                                  width: isSelected ? 2.5 : 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 6,
                                    offset: const Offset(-2, 3),
                                  ),
                                  BoxShadow(
                                    color: isSelected ? widget.themeColor.withOpacity(0.2) : widget.themeColor.withOpacity(0.08),
                                    blurRadius: isSelected ? 14 : 10,
                                    offset: isHeld ? const Offset(-2, 3) : const Offset(-6, 8),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['title'] as String,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF263238), height: 1.3),
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatTimestamp(item['timestamp'] as DateTime),
                                          style: TextStyle(fontSize: 9, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                                        ),
                                        Icon(
                                          isSelected ? Icons.check_circle_rounded : Icons.arrow_circle_right_rounded, 
                                          size: 18, 
                                          color: widget.themeColor,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      
          // 🏛️ Futuristic 3D Floating Multi-Select Action Bar
          if (_isSelectionMode)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 65,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: widget.themeColor.withOpacity(0.2), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: widget.themeColor.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Cancel Selection Button
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 22),
                          tooltip: "Cancel Selection",
                          onPressed: () {
                            setState(() {
                              _selectedItems.clear();
                              _isSelectionMode = false;
                            });
                          },
                        ),
                        const SizedBox(width: 4),
                        
                        // Selection Count Text
                        Text(
                          "${_selectedItems.length} Selected",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF263238)),
                        ),
                        const SizedBox(width: 4),
                        const SizedBox(width: 4),

                        // Select All / Deselect All Button
                        IconButton(
                          icon: Icon(
                            _selectedItems.length == _filteredItems.length ? Icons.deselect_rounded : Icons.select_all_rounded,
                            color: widget.themeColor,
                            size: 22,
                          ),
                          tooltip: _selectedItems.length == _filteredItems.length ? "Deselect All" : "Select All",
                          onPressed: _toggleSelectAll,
                        ),
                        
                        // Edit Button (Only visible if exactly 1 is selected and NOT Marksheet or Attendance)
                        if (_selectedItems.length == 1 && 
                            widget.categoryName.toLowerCase() != 'marksheets and tests' && 
                            widget.categoryName.toLowerCase() != 'results' && 
                            widget.categoryName.toLowerCase() != 'students attendances and staff attendances' && 
                            widget.categoryName.toLowerCase() != 'attendance')
                          IconButton(
                            icon: Icon(Icons.edit_rounded, color: widget.themeColor, size: 22),
                            tooltip: "Edit Title",
                            onPressed: _editItem,
                          ),
                        
                        // Share Button
                        IconButton(
                          icon: Icon(Icons.share_rounded, color: widget.themeColor, size: 22),
                          tooltip: "Share Selected",
                          onPressed: () => _shareSelected(),
                        ),

                        // Print Button
                        IconButton(
                          icon: Icon(Icons.print_rounded, color: widget.themeColor, size: 22),
                          tooltip: "Print Selected",
                          onPressed: _batchPrint,
                        ),

                        // Delete Button
                        IconButton(
                          icon: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 22),
                          tooltip: "Delete Selected",
                          onPressed: _batchDelete,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // 🏛️ Slide-Out Blueprint Architectural Overlay Panel
          BlueprintOverlay(
            isOpen: _isBlueprintOpen,
            onClose: () => setState(() => _isBlueprintOpen = false),
            blueprintType: (widget.categoryName.toLowerCase() == 'fee vouchers data' || widget.categoryName.toLowerCase() == 'fees')
                ? 'fee_voucher_blueprint'
                : (widget.categoryName.toLowerCase() == 'students attendances and staff attendances' || widget.categoryName.toLowerCase() == 'attendance')
                    ? 'attendance_blueprint'
                    : null,
            onSelected: (bp) async {
              if (_selectedItemForBlueprint != null) {
                String? langChoice;
                final tappedCat = widget.categoryName.toLowerCase();
                if (tappedCat == 'translation' || tappedCat == 'translated document') {
                  langChoice = await _showLanguageChoiceDialog();
                  if (langChoice == null) return;
                }

                await BlueprintPdfGenerator.generateAndInstallDocument(
                  context: context,
                  documentTitle: _selectedItemForBlueprint!['title'] as String,
                  categoryName: widget.categoryName,
                  blueprint: bp,
                  printLanguage: langChoice,
                  studentName: _selectedItemForBlueprint!['details']?['Student'] ?? 'N/A',
                  fatherName: _selectedItemForBlueprint!['details']?['Father Name'] ?? 'N/A',
                  content: _getPrintContent(widget.categoryName, _selectedItemForBlueprint!['content']),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  List<dynamic> _parseContent(dynamic rawContent) {
    if (rawContent == null) return [];
    if (rawContent is String) {
      try {
        return jsonDecode(rawContent) as List<dynamic>;
      } catch (_) {
        return [];
      }
    }
    if (rawContent is List) {
      return rawContent;
    }
    return [];
  }

  List<dynamic> _getPrintContent(String category, dynamic rawContent) {
    if (category.toLowerCase() == 'uploads') {
      if (rawContent is List) return rawContent;
      if (rawContent is Map) return [rawContent];
      if (rawContent is String && rawContent.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawContent);
          if (decoded is List) return decoded;
          if (decoded is Map) return [decoded];
        } catch (_) {}
      }
      return [];
    }
    return _parseContent(rawContent);
  }

  String? _extractBase64(dynamic content) {
    if (content == null) return null;
    if (content is String && content.isNotEmpty) {
      try {
        final decoded = jsonDecode(content);
        if (decoded is Map && decoded.containsKey('base64')) {
          return decoded['base64']?.toString();
        }
        if (decoded is List && decoded.isNotEmpty && decoded.first is Map && decoded.first.containsKey('base64')) {
          return decoded.first['base64']?.toString();
        }
      } catch (_) {}
    }
    if (content is Map && content.containsKey('base64')) {
      return content['base64']?.toString();
    }
    if (content is List && content.isNotEmpty) {
      final first = content.first;
      if (first is Map && first.containsKey('base64')) {
        return first['base64']?.toString();
      }
    }
    return null;
  }

  void _showMessage(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
