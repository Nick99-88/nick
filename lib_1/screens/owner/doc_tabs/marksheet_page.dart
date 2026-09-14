import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants.dart';
import '../../../core/storage.dart';
import '../../../core/theme.dart';
import '../../../services/institution/dashboard_service.dart';
import '../../../services/marksheet_service.dart';
import 'blueprint_overlay.dart';
import 'blueprint_pdf_generator.dart';

class MarksheetPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final String? initialSessionId;
  const MarksheetPage({super.key, this.initialData, this.initialSessionId});

  @override
  State<MarksheetPage> createState() => _MarksheetPageState();
}

class _MarksheetPageState extends State<MarksheetPage> {
  final DashboardService _dashboardService = DashboardService();
  final MarksheetService _marksheetService = MarksheetService();
  final _formKey = GlobalKey<FormState>();
  final Color primaryColor = const Color(0xFF0288D1);
  final Color secondaryColor = const Color(0xFF263238);

  // Form controllers
  final _examTitleController = TextEditingController();
  final _classController = TextEditingController();
  final _subjectController = TextEditingController();
  final _maxMarksController = TextEditingController();
  final _passingMarksController = TextEditingController();

  bool _isLoading = false;
  bool _showPendingVault = false;
  bool _saveAsCompleted = false;
  bool _isBlueprintOpen = false;
  String? _selectedSection;
  String? _selectedSessionId;
  String _sessionInput = '';
  List<String> _sections = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _marksData = [];
  List<Map<String, dynamic>> _pendingMarksheets = [];
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _examTitleController.dispose();
    _classController.dispose();
    _subjectController.dispose();
    _maxMarksController.dispose();
    _passingMarksController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadSections();
    await _loadPendingMarksheets();
    await _loadSessions();

    if (widget.initialSessionId != null && widget.initialSessionId!.isNotEmpty) {
      setState(() {
        _selectedSessionId = widget.initialSessionId;
        final session = _sessions.where((s) => s['id'] == widget.initialSessionId).firstOrNull;
        final sessionName = session?['name'] ?? '';
        if (_examTitleController.text.isEmpty && sessionName.isNotEmpty) {
          _examTitleController.text = sessionName;
        }
      });
    }

    if (widget.initialData != null) {
      final data = widget.initialData!;
      setState(() {
        _examTitleController.text = data['name'] ?? data['exam_title'] ?? '';
        _subjectController.text = data['subject'] ?? '';
        _maxMarksController.text = data['max_marks']?.toString() ?? '100';
        _passingMarksController.text = data['passing_marks']?.toString() ?? '33';

        final String classSec = data['class_name'] ?? (data['targets'] is List && (data['targets'] as List).isNotEmpty ? data['targets'].first.toString() : '');
        if (classSec.isNotEmpty && _sections.contains(classSec)) {
          _selectedSection = classSec;
        }

        // Hydrate Student Marks Data list with correct mapped values
        final List<dynamic> rawMarks = data['content'] ?? data['marks_data'] ?? [];
        _marksData = rawMarks.map((m) {
          if (m is Map) {
            return {
              'student_id': m['student_id'] ?? '',
              'student_name': m['student_name'] ?? 'Unknown Student',
              'father_name': m['father_name'] ?? 'N/A',
              'roll_number': m['roll_number']?.toString() ?? 'N/A',
              'marks_obtained': double.tryParse(m['marks_obtained']?.toString() ?? '0.0') ?? 0.0,
              'max_marks': int.tryParse(m['max_marks']?.toString() ?? '100') ?? 100,
              'grade': m['grade'] ?? 'F',
              'percentage': double.tryParse(m['percentage']?.toString() ?? '0.0') ?? 0.0,
              'status': m['status']?.toString().toLowerCase() ?? 'fail',
            };
          }
          return <String, dynamic>{};
        }).where((e) => e.isNotEmpty).toList();

        // Map text controllers for student fields as well
        for (var student in _students) {
          final matchedMarks = _marksData.firstWhere(
            (m) => m['student_id'] == student['id'],
            orElse: () => <String, dynamic>{},
          );
          if (matchedMarks.isNotEmpty) {
            student['marks'].text = matchedMarks['marks_obtained']?.toInt().toString() ?? '0';
            student['grade'] = matchedMarks['grade'] ?? '';
            student['status'] = matchedMarks['status'] ?? 'fail';
          }
        }
      });
    }
  }

  Future<void> _loadSections() async {
    setState(() => _isLoading = true);
    try {
      final sections = await _dashboardService.getSections();
      setState(() {
        _sections = sections;
        if (_sections.isNotEmpty && widget.initialData == null) {
          _selectedSection = _sections.first;
          _classController.text = _sections.first;
          _loadStudentsBySection(_sections.first);
        } else if (_sections.isNotEmpty && widget.initialData != null) {
          final String classSec = widget.initialData!['class_name'] ?? (widget.initialData!['targets'] is List && (widget.initialData!['targets'] as List).isNotEmpty ? widget.initialData!['targets'].first.toString() : '');
          if (classSec.isNotEmpty && _sections.contains(classSec)) {
            _selectedSection = classSec;
            _classController.text = classSec;
            _loadStudentsBySection(classSec);
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage("Failed to load sections", false);
    }
  }

  Future<void> _loadStudentsBySection(String section) async {
    setState(() => _isLoading = true);
    try {
      final students = await _dashboardService.getStudentsBySection(section);
      if (students.isEmpty) {
        setState(() {
          _students = [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _students = students.map((student) => {
          'id': student['id'],
          'name': student['name'] ?? 'Unknown Name',
          'father_name': student['father_name'] ?? 'Not specified',
          'roll_number': student['roll_number']?.toString() ?? 'N/A',
          'marks': TextEditingController(text: '0'),
          'grade': '',
          'status': 'present',
        }).toList();

        _initializeMarksData();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('Error loading students: $e', false);
    }
  }

  void _initializeMarksData() {
    _marksData = _students.map((student) => {
      'student_id': student['id'],
      'student_name': student['name'],
      'father_name': student['father_name'],
      'roll_number': student['roll_number'],
      'marks_obtained': 0,
      'max_marks': int.tryParse(_maxMarksController.text) ?? 100,
      'grade': '',
      'percentage': 0.0,
      'status': 'pass',
    }).toList();
  }

  void _updateMarks(int studentIndex, String marks) {
    final marksValue = double.tryParse(marks) ?? 0.0;
    final maxMarks = double.tryParse(_maxMarksController.text) ?? 100.0;
    final passingMarks = double.tryParse(_passingMarksController.text) ?? 33.0;
    final percentage = maxMarks > 0 ? (marksValue / maxMarks) * 100 : 0.0;
    
    String grade = _calculateGrade(percentage);
    String status = marksValue >= passingMarks ? 'pass' : 'fail';

    setState(() {
      _students[studentIndex]['marks'].text = marks;
      _marksData[studentIndex]['marks_obtained'] = marksValue;
      _marksData[studentIndex]['percentage'] = percentage;
      _marksData[studentIndex]['grade'] = grade;
      _marksData[studentIndex]['status'] = status;
    });
  }

  String _calculateGrade(double percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B';
    if (percentage >= 60) return 'C';
    if (percentage >= 50) return 'D';
    if (percentage >= 33) return 'E';
    return 'F';
  }

  void _showMessage(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveMarksheet({bool asCompleted = false}) async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Auto-create session if name was typed manually
        String? sessionId = _selectedSessionId;
        if ((sessionId == null || sessionId.isEmpty) && _sessionInput.trim().isNotEmpty) {
          await _createSession(_sessionInput.trim());
          sessionId = _selectedSessionId;
        }

        print("🔍 [MARKSHEET SAVE] sessionId: '$sessionId', _selectedSessionId: '$_selectedSessionId', _sessionInput: '${_sessionInput.trim()}'");
        final payload = {
          'exam_title': _examTitleController.text.trim(),
          'class_name': _selectedSection,
          'subject': _subjectController.text.trim(),
          'max_marks': int.tryParse(_maxMarksController.text) ?? 100,
          'passing_marks': int.tryParse(_passingMarksController.text) ?? 33,
          'marks_data': _marksData,
          'session_id': sessionId ?? '',
          'created_at': DateTime.now().toIso8601String(),
        };

        final shouldComplete = asCompleted || _saveAsCompleted;
        if (shouldComplete) {
          _showCompletionDialog();
          return;
        }

        await _marksheetService.createMarksheet(payload);
        _showMessage('Marksheet saved to pending vault!', true);
        _clearForm();
        _loadPendingMarksheets();
      } catch (e) {
        _showMessage('Error: $e', false);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _completeMarksheet(String marksheetId) async {
    setState(() => _isLoading = true);
    try {
      print("🔍 [MARKSHEET COMPLETE] marksheetId=$marksheetId, _selectedSessionId='$_selectedSessionId'");
      final payload = {
        'exam_title': _examTitleController.text.trim(),
        'class_name': _selectedSection,
        'subject': _subjectController.text.trim(),
        'max_marks': int.tryParse(_maxMarksController.text) ?? 100,
        'passing_marks': int.tryParse(_passingMarksController.text) ?? 33,
        'marks_data': _marksData,
        'session_id': _selectedSessionId ?? '',
        'completed_at': DateTime.now().toIso8601String(),
      };

      await _marksheetService.completeMarksheet(marksheetId, payload);
      _showMessage('Marksheet completed successfully!', true);
      _clearForm();
      _loadPendingMarksheets();
    } catch (e) {
      _showMessage('Error: $e', false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPendingMarksheets() async {
    try {
      final pendingMarksheets = await _marksheetService.getPendingMarksheets();
      setState(() {
        _pendingMarksheets = pendingMarksheets;
      });
    } catch (e) {
      print('Error loading pending marksheets: $e');
    }
  }

  void _clearForm() {
    _examTitleController.clear();
    _subjectController.clear();
    _maxMarksController.clear();
    _passingMarksController.clear();
    setState(() {
      _marksData.clear();
      for (var student in _students) {
        student['marks'].text = '0';
      }
    });
  }

  Future<void> _createSession(String name) async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/marksheet/session/create'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'name': name}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _selectedSessionId = data['id']);
        await _loadSessions();
      }
    } catch (_) {}
  }

  Future<void> _loadSessions() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/marksheet/sessions'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          if (mounted) setState(() => _sessions = List<Map<String, dynamic>>.from(data));
        }
      }
    } catch (_) {}
  }

  void _showCreateSessionDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Create New Session"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "e.g. Mid Term 2026",
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                await _createSession(name);
              }
            },
            child: const Text("Create", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Complete Marksheet"),
          content: const Text("Are you sure you want to save this marksheet as completed? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (_saveAsCompleted) {
                  _createCompletedMarksheet();
                } else {
                  _saveMarksheet(asCompleted: true);
                }
              },
              child: const Text("Complete", style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createCompletedMarksheet() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        String? sessionId = _selectedSessionId;
        print("🔍 [MARKSHEET CREATE COMPLETED] initial _selectedSessionId='$_selectedSessionId', _sessionInput='${_sessionInput.trim()}'");
        if ((sessionId == null || sessionId.isEmpty) && _sessionInput.trim().isNotEmpty) {
          await _createSession(_sessionInput.trim());
          sessionId = _selectedSessionId;
          print("🔍 [MARKSHEET CREATE COMPLETED] after auto-create sessionId='$sessionId'");
        }

        final payload = {
          'exam_title': _examTitleController.text.trim(),
          'class_name': _selectedSection,
          'subject': _subjectController.text.trim(),
          'max_marks': int.tryParse(_maxMarksController.text) ?? 100,
          'passing_marks': int.tryParse(_passingMarksController.text) ?? 33,
          'marks_data': _marksData,
          'session_id': sessionId ?? '',
          'status': 'completed',
          'completed_at': DateTime.now().toIso8601String(),
        };

        await _marksheetService.createMarksheet(payload);
        _showMessage('Completed marksheet saved successfully!', true);
        _clearForm();
        _loadPendingMarksheets();
      } catch (e) {
        _showMessage('Error: $e', false);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildBookSection(int index, Map<String, dynamic> book) {
    if (book['chapters'] == null) {
      book['chapters'] = [];
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            color: const Color(0xFFF8F9FA),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: book['title']),
                    onChanged: (v) => book['title'] = v,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                    decoration: const InputDecoration(border: InputBorder.none),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => _pendingMarksheets.removeAt(index))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text("MARKSHEET MANAGER", 
          style: TextStyle(color: secondaryColor, fontWeight: FontWeight.w900, fontSize: 14)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.pending_actions, color: _showPendingVault ? primaryColor : Colors.grey),
            onPressed: () {
              setState(() {
                _showPendingVault = !_showPendingVault;
              });
            },
            tooltip: "Pending Vault",
          ),
          IconButton(
            icon: Icon(Icons.save, color: primaryColor),
            onPressed: _isLoading ? null : _saveMarksheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Exam Details Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("EXAM DETAILS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 15),
                        if (widget.initialSessionId == null || widget.initialSessionId!.isEmpty)
                          TextFormField(
                            controller: _examTitleController,
                            decoration: const InputDecoration(
                              labelText: "Exam Title",
                              hintText: "e.g. Midterm, Final, Quiz",
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => value?.trim().isEmpty ?? true ? "Required" : null,
                          ),
                        if (widget.initialSessionId != null && widget.initialSessionId!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.title, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _examTitleController.text.isNotEmpty ? _examTitleController.text : '(autofilled)',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: _subjectController,
                          decoration: const InputDecoration(
                            labelText: "Subject",
                            hintText: "e.g. Mathematics, Physics, English",
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value?.trim().isEmpty ?? true ? "Required" : null,
                        ),
                        const SizedBox(height: 15),
                        // Save as completed checkbox
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _saveAsCompleted,
                                onChanged: (value) {
                                  setState(() {
                                    _saveAsCompleted = value ?? false;
                                  });
                                },
                                activeColor: primaryColor,
                              ),
                              Expanded(
                                child: Text(
                                  "Save as completed (final marksheet)",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _saveAsCompleted ? primaryColor : Colors.grey.shade600,
                                    fontWeight: _saveAsCompleted ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _maxMarksController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "Max Marks",
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) => value?.trim().isEmpty ?? true ? "Required" : null,
                                onChanged: (value) => _initializeMarksData(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _passingMarksController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "Passing Marks",
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) => value?.trim().isEmpty ?? true ? "Required" : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (widget.initialSessionId != null && widget.initialSessionId!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event_note, size: 16, color: Colors.blue[600]),
                                const SizedBox(width: 8),
                                Text(
                                  _sessions.where((s) => s['id'] == widget.initialSessionId).firstOrNull?['name'] ?? 'Session',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.blue[800]),
                                ),
                              ],
                            ),
                          ),
                        if (widget.initialSessionId == null || widget.initialSessionId!.isEmpty)
                          DropdownButtonFormField<String>(
                            value: _selectedSessionId,
                            decoration: const InputDecoration(
                              labelText: "Session",
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              ..._sessions.map((s) => DropdownMenuItem(
                                value: s['id'],
                                child: Text(s['name'] ?? 'Unnamed'),
                              )),
                              const DropdownMenuItem(
                                value: '__new__',
                                child: Text('+ Create New', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == '__new__') {
                                _showCreateSessionDialog();
                              } else {
                                setState(() => _selectedSessionId = value);
                              }
                            },
                          ),
                        if (widget.initialSessionId == null || widget.initialSessionId!.isEmpty)
                          if (_selectedSessionId == null || _selectedSessionId!.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextFormField(
                                decoration: const InputDecoration(
                                  labelText: "Or type session name",
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (v) => _sessionInput = v,
                              ),
                            ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedSection,
                          decoration: const InputDecoration(
                            labelText: "Class/Section",
                            border: OutlineInputBorder(),
                          ),
                          items: _sections.map((section) => DropdownMenuItem(
                            value: section,
                            child: Text(section),
                          )).toList(),
                          onChanged: (value) {
                            setState(() => _selectedSection = value);
                            _classController.text = value ?? '';
                            if (value != null) {
                              _loadStudentsBySection(value);
                            }
                          },
                          validator: (value) => value == null ? "Required" : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Pending Vault Section
                  if (_showPendingVault) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("PENDING MARKSHEETS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                              Text(
                                "${_pendingMarksheets.length} items",
                                style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          if (_pendingMarksheets.isEmpty) ...[
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                                    SizedBox(height: 10),
                                    Text("No pending marksheets", style: TextStyle(fontSize: 14, color: Colors.grey)),
                                    Text("Create a new marksheet or load existing ones", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            ..._pendingMarksheets.asMap().entries.map((entry) => _buildBookSection(entry.key, entry.value)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Student Marks Section
                  if (_students.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("STUDENT MARKS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 15),
                          ..._students.asMap().entries.map((entry) {
                            final index = entry.key;
                            final student = entry.value;
                            final markData = _marksData.firstWhere(
                              (m) => m['student_id'] == student['id'],
                              orElse: () => <String, dynamic>{},
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 15),
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              student['name'] ?? 'Unknown Student',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "Father: ${student['father_name'] ?? 'N/A'}",
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                            Text(
                                              "Roll: ${student['roll_number'] ?? 'N/A'}",
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: TextFormField(
                                          controller: student['marks'],
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: "Marks",
                                            border: OutlineInputBorder(),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          onChanged: (value) => _updateMarks(index, value),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (markData != null && markData.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          "Percentage: ${markData['percentage']?.toDouble()?.toStringAsFixed(1) ?? '0.0'}%",
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                        const Spacer(),
                                        Text(
                                          "Status: ${markData['status']?.toString().toUpperCase()}",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: markData['status'] == 'pass' ? Colors.green : Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // 🏛️ Slide-Out Blueprint Overlay Panel
          BlueprintOverlay(
            isOpen: _isBlueprintOpen,
            onClose: () => setState(() => _isBlueprintOpen = false),
            blueprintType: 'marksheet_blueprint',
            onSelected: (bp) async {
              if (_examTitleController.text.trim().isNotEmpty) {
                await BlueprintPdfGenerator.generateAndInstallDocument(
                  context: context,
                  documentTitle: _examTitleController.text.trim(),
                  categoryName: "MarkSheets and Tests",
                  blueprint: bp,
                  content: _marksData,
                );
              } else {
                _showMessage("Please enter an exam title first!", false);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _isBlueprintOpen = !_isBlueprintOpen),
        backgroundColor: secondaryColor,
        icon: const Icon(Icons.account_tree_rounded, color: Colors.white),
        label: const Text("Blueprints", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}
