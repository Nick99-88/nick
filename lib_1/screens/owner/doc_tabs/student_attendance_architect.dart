import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../../core/storage.dart';
import '../../../core/theme.dart';
import '../../../services/institution/dashboard_service.dart';
import 'attendance_blueprint_vault.dart';
import 'blueprint_overlay.dart';
import 'blueprint_pdf_generator.dart';
import 'blueprint_editor.dart';
import '../../../core/storage.dart';
import '../../../services/institution/dashboard_service.dart';

// --- DATA MODELS ---
class AttendanceRecord {
  String studentId;
  String studentName;
  String status; // 'P', 'A', 'L'
  bool isManual;
  String fatherName;

  AttendanceRecord({
    required this.studentId,
    required this.studentName,
    required this.status,
    required this.isManual,
    required this.fatherName,
  });
}

class StudentAttendanceArchitect extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const StudentAttendanceArchitect({super.key, this.initialData});

  @override
  State<StudentAttendanceArchitect> createState() => _StudentAttendanceArchitectState();
}

class _StudentAttendanceArchitectState extends State<StudentAttendanceArchitect> {
  final _uuid = const Uuid();
  final DashboardService _dashboardService = DashboardService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // --- ARCHITECT STATE ---
  String currentType = 'class'; // 'class' or 'test'
  String sectionName = "Section-A";
  String testSubject = "";
  String attDate = DateTime.now().toString().split(' ')[0];
  bool _isBlueprintOpen = false;
  
  List<AttendanceRecord> students = [];
  List<String> _sections = [];
  String? _selectedSection;
  bool _isLoading = false;
  
  List<Map<String, dynamic>> _blueprints = [];
  bool _isBpLoading = false;

  // Input Controllers
  final TextEditingController _manualName = TextEditingController();
  final TextEditingController _manualFather = TextEditingController();
  final TextEditingController _bpTitle = TextEditingController();

  Future<void> _fetchBlueprints() async {
    setState(() => _isBpLoading = true);
    try {
      final token = await StarlightStorage.getUserToken();
      final res = await http.get(
        Uri.parse('https://api.institution.site/document/blueprint/list'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success' && data['blueprints'] != null) {
          final List<dynamic> rawList = data['blueprints'] as List;
          setState(() {
            _blueprints = rawList
                .map((item) => Map<String, dynamic>.from(item))
                .where((bp) => bp['type'] == 'attendance_blueprint')
                .toList();
          });
        }
      }
    } catch (e) {
      print('Error fetching blueprints: $e');
    } finally {
      setState(() => _isBpLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSections();
    _fetchBlueprints();
  }

  @override
  void dispose() {
    _manualName.dispose();
    _manualFather.dispose();
    _bpTitle.dispose();
    super.dispose();
  }

  Future<void> _loadSections() async {
    setState(() => _isLoading = true);
    try {
      print('Loading sections from server...');
      final sections = await _dashboardService.getSections();
      print('Sections loaded from server: ${sections.length}');
      setState(() {
        _sections = sections;
        if (_sections.isNotEmpty) {
          _selectedSection = _sections.first;
          sectionName = _sections.first;
          _loadStudentsBySection(_sections.first);
        } else {
          print('No sections found');
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading sections: $e');
      setState(() => _isLoading = false);
      _showSignBox("Network Link Failed", false);
    }
  }

  Future<void> _loadStudentsBySection(String section) async {
    print('Loading students for section: $section');
    setState(() => _isLoading = true);
    try {
      final studentsData = await _dashboardService.getStudentsBySection(section);
      print('Students loaded from server: ${studentsData.length}');

      if (studentsData.isEmpty) {
        print('No students found in section: $section');
        setState(() {
          students = [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        students = studentsData.map((student) => AttendanceRecord(
          studentId: student['id'].toString(),
          studentName: student['name'] ?? 'Unknown Name',
          fatherName: student['father_name'] ?? 'Not specified',
          status: 'P', // Default to Present
          isManual: false,
        )).toList();
        _isLoading = false;
        print('Students loaded successfully: ${students.length}');
      });
    } catch (e) {
      print('Error loading students: $e');
      setState(() => _isLoading = false);
      _showSignBox('Error loading students: $e', false);
    }
  }

  Future<void> _syncAttendance() async {
    if (students.isEmpty) {
      _showSignBox("No students to sync", false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        _showSignBox("Authentication failed", false);
        setState(() => _isLoading = false);
        return;
      }

      final payload = {
        'mode': currentType, // 'class' or 'test'
        'section_name': sectionName,
        'subject': currentType == 'test' ? testSubject : null,
        'date': attDate,
        'title': _bpTitle.text.trim().isEmpty ? null : _bpTitle.text.trim(),
        'records': students.map((s) => {
          'student_id': s.studentId,
          'student_name': s.studentName,
          'father_name': s.fatherName,
          'status': s.status,
          'is_manual': s.isManual,
        }).toList(),
      };

      print('Sending attendance payload: ${jsonEncode(payload)}');

      final res = await http.post(
        Uri.parse('https://api.institution.site/attendance/sync'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        print('Attendance sync successful');
        _showSignBox("Attendance Synced to Starlight Cloud", true);
      } else {
        print('Server error: ${res.statusCode} - ${res.body}');
        _showSignBox("Sync Failed: ${res.statusCode}", false);
      }
    } catch (e) {
      print('Error syncing attendance: $e');
      _showSignBox("Sync Failed: $e", false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- ANALYTICS LOGIC ---
  int get countPresent => students.where((s) => s.status == 'P').length;
  int get countAbsent => students.where((s) => s.status == 'A').length;
  int get countLate => students.where((s) => s.status == 'L').length;

  void _setStatus(String id, String status) {
    setState(() {
      final index = students.indexWhere((s) => s.studentId == id);
      if (index != -1) students[index].status = status;
    });
  }

  void _addManualGuest() {
    if (_manualName.text.isEmpty) {
      _showSignBox("Enter Student Name", false);
      return;
    }
    setState(() {
      students.add(AttendanceRecord(
        studentId: _uuid.v4(),
        studentName: _manualName.text,
        fatherName: _manualFather.text.isEmpty ? "N/A" : _manualFather.text,
        status: 'P', // Default to Present on add
        isManual: true,
      ));
      _manualName.clear();
      _manualFather.clear();
    });
    _showSignBox("Guest Added Dynamically", true);
  }

  void _showSignBox(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("STUDENT ATTENDANCE ARCHITECT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.architecture_rounded, color: Colors.cyanAccent),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: _buildBlueprintDrawer(),
      body: Column(
        children: [
          _buildLiveLogs(), // Real-time Stats
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildTypeSelector(),
                const SizedBox(height: 20),
                _buildConfigHeader(),
                const SizedBox(height: 20),
                _buildStudentGrid(), // Dynamic Table
                const SizedBox(height: 20),
                _buildGuestEntryTerminal(),
                const SizedBox(height: 100), // Bottom Padding for scroll
              ],
            ),
          ),
          _buildActionFooter(),
        ],
      ),
    );
  }

  // --- COMPONENT: LIVE LOGS ---
  Widget _buildLiveLogs() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _logStat("TOTAL", students.length.toString(), Colors.white),
          _logStat("PRESENT", countPresent.toString(), Colors.greenAccent),
          _logStat("ABSENT", countAbsent.toString(), Colors.redAccent),
          _logStat("LATE", countLate.toString(), Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _logStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        _selectorBtn("CLASS MODE", 'class', Icons.room_preferences),
        const SizedBox(width: 10),
        _selectorBtn("TEST MODE", 'test', Icons.quiz),
      ],
    );
  }

  Widget _selectorBtn(String label, String type, IconData icon) {
    bool active = currentType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => currentType = type),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: active ? Colors.cyanAccent : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? Colors.black : Colors.white38),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: active ? Colors.black : Colors.white, fontWeight: FontWeight.w900, fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfigHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
      child: Column(
        children: [
          TextField(
            controller: _bpTitle,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: "Attendance Session Title (Optional)",
              labelStyle: TextStyle(color: Colors.white38, fontSize: 10),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
            ),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: _selectedSection,
            decoration: InputDecoration(
              labelText: "Institution Section",
              labelStyle: const TextStyle(color: Colors.white38, fontSize: 10),
              hintText: _isLoading ? "Loading sections..." : "Select Section",
              border: const OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
            ),
            dropdownColor: const Color(0xFF1A1A2E),
            items: _isLoading
                ? []
                : _sections.map((section) => DropdownMenuItem(
                    value: section,
                    child: Text(section, style: const TextStyle(color: Colors.white)),
                  )).toList(),
            onChanged: _isLoading ? null : (value) {
              setState(() {
                _selectedSection = value;
                sectionName = value ?? '';
              });
              if (value != null) {
                _loadStudentsBySection(value);
              }
            },
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          if (currentType == 'test')
            TextField(
              onChanged: (v) => testSubject = v,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(labelText: "Subject / Paper Title", labelStyle: TextStyle(color: Colors.cyanAccent, fontSize: 10)),
            ),
        ],
      ),
    );
  }

  Widget _buildStudentGrid() {
    if (students.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Text("NO STUDENTS IN ARCHITECT - ADD GUESTS BELOW", style: TextStyle(color: Colors.white24, fontSize: 10)),
        ),
      );
    }
    return Column(
      children: students.map((s) => _studentRow(s)).toList(),
    );
  }

  Widget _studentRow(AttendanceRecord s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: s.isManual ? Border.all(color: Colors.orangeAccent.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.studentName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text("S/O ${s.fatherName}", style: const TextStyle(color: Colors.white38, fontSize: 9)),
              ],
            ),
          ),
          Row(
            children: ['P', 'A', 'L'].map((status) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => _setStatus(s.studentId, status),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 35, height: 35,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: s.status == status ? _getStatusColor(status) : Colors.white10,
                  ),
                  child: Center(
                    child: Text(status, style: TextStyle(color: s.status == status ? Colors.black : Colors.white38, fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ),
              ),
            )).toList(),
          )
        ],
      ),
    );
  }

  Color _getStatusColor(String s) {
    if (s == 'P') return Colors.greenAccent;
    if (s == 'A') return Colors.redAccent;
    return Colors.orangeAccent;
  }

  Widget _buildGuestEntryTerminal() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withOpacity(0.02),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.2), style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("DYNAMIC GUEST INJECTION", style: TextStyle(color: Colors.cyanAccent, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: _manualName, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: const InputDecoration(hintText: "Student Name", hintStyle: TextStyle(color: Colors.white10)))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _manualFather, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: const InputDecoration(hintText: "Father Name", hintStyle: TextStyle(color: Colors.white10)))),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _addManualGuest, 
                icon: const Icon(Icons.add_box, color: Colors.cyanAccent, size: 30)
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _syncAttendance,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.cyanAccent,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : const Text("SYNC ARCHITECTURE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ),
    );
  }

  void _navigateToBlueprintVault() {
    Navigator.pop(context); // Close drawer
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AttendanceBlueprintVault()),
    ).then((_) => _fetchBlueprints()); // Refresh on return
    _showSignBox("Entering Blueprint Architect Mode", true);
  }

  Widget _buildBlueprintDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1A1A2E), // Starlight Deep Midnight
      child: SafeArea(
        child: Column(
          children: [
            // Header: Identity of the Architecture
            Container(
              padding: const EdgeInsets.all(25),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white10,
                border: Border(bottom: BorderSide(color: Colors.cyanAccent, width: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.architecture_rounded, color: Colors.cyanAccent, size: 30),
                      SizedBox(height: 10),
                      Text("STUDENT\nBLUEPRINT",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
                    onPressed: _fetchBlueprints,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // THE PRIMARY ACTION: CREATE NEW
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: ElevatedButton.icon(
                onPressed: _navigateToBlueprintVault,
                icon: const Icon(Icons.add_circle_outline, color: Colors.black),
                label: const Text("CREATE NEW BLUEPRINT",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 25),

            // VAULT SECTION LABEL
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.storage_rounded, color: Colors.white30, size: 14),
                  SizedBox(width: 8),
                  Text("INSTALLED BLUEPRINTS",
                    style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                ],
              ),
            ),

            // LIST OF EXISTING BLUEPRINTS (Student Specific Templates)
            Expanded(
              child: _isBpLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                  : _blueprints.isEmpty
                      ? const Center(
                          child: Text("NO INSTALLED BLUEPRINTS",
                              style: TextStyle(color: Colors.white24, fontSize: 11)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(15),
                          itemCount: _blueprints.length,
                          itemBuilder: (context, index) {
                            final bp = _blueprints[index];
                            return _blueprintCard(bp);
                          },
                        ),
            ),

            const Divider(color: Colors.white10),

            // FOOTER SAVE
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: Colors.white24)
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("CLOSE CONSOLE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _blueprintCard(Map<String, dynamic> bp) {
    final String title = bp['title'] ?? 'Untitled Blueprint';
    final String created = bp['created_at']?.toString().split('T').first ?? 'N/A';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        subtitle: Text("Created: $created", style: const TextStyle(color: Colors.white54, fontSize: 10)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.cyanAccent, size: 16),
              onPressed: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttendanceBlueprintVault(
                      existingBlueprint: bp,
                    ),
                  ),
                ).then((_) => _fetchBlueprints()); // Refresh on return
              },
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.cyanAccent, size: 10),
          ],
        ),
        onTap: () {
          Navigator.pop(context); // Close drawer
          _showSignBox("Blueprint '$title' loaded.", true);
        },
      ),
    );
  }
}