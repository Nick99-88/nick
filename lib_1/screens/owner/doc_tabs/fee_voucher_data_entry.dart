import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/storage.dart';
import '../../../core/theme.dart';
import '../../../services/institution/dashboard_service.dart';
import 'blueprint_overlay.dart';
import 'fee_voucher_editor.dart';

class FeeVoucherDataEntry extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const FeeVoucherDataEntry({super.key, this.initialData});

  @override
  State<FeeVoucherDataEntry> createState() => _FeeVoucherDataEntryState();
}

class _FeeVoucherDataEntryState extends State<FeeVoucherDataEntry> {
  final _formKey = GlobalKey<FormState>();
  final Color primaryColor = const Color(0xFF0288D1);
  final Color secondaryColor = const Color(0xFF263238);
  final DashboardService _dashboardService = DashboardService();

  // Form controllers
  final _titleController = TextEditingController();
  final _yearController = TextEditingController();
  final _voucherNumberController = TextEditingController();

  bool _isLoading = false;
  String? _selectedSection;
  List<String> _sections = [];
  List<Map<String, dynamic>> _students = [];
  List<String> _selectedStudentIds = [];
  List<Map<String, dynamic>> _feeItems = [];
  Map<String, Map<String, dynamic>> _studentFees = {};
  
  bool isBlueprintSlideOpen = false;
  List<Map<String, dynamic>> feeBlueprints = [];
  bool isLoadingBlueprints = false;
  String? blueprintError;
  final String apiBase = "https://api.institution.site";


  @override
  void dispose() {
    for (var item in _feeItems) {
      item['controller'].dispose();
    }
    super.dispose();
  }

  Future<void> fetchFeeBlueprints() async {
    setState(() {
      isLoadingBlueprints = true;
      blueprintError = null;
    });

    try {
      final token = await StarlightStorage.getUserToken();
      final res = await http.get(
        Uri.parse('$apiBase/document/blueprint/list'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success' && data['blueprints'] != null) {
          // Filter only fee voucher blueprints
          setState(() {
            feeBlueprints = (data['blueprints'] as List)
                .where((bp) => bp['type'] == 'fee_voucher_blueprint')
                .cast<Map<String, dynamic>>()
                .toList();
            isLoadingBlueprints = false;
          });
        } else {
          setState(() {
            feeBlueprints = [];
            isLoadingBlueprints = false;
          });
        }
      } else {
        setState(() {
          blueprintError = "Failed to load: ${res.statusCode}";
          isLoadingBlueprints = false;
        });
      }
    } catch (e) {
      setState(() {
        blueprintError = "Network error: $e";
        isLoadingBlueprints = false;
      });
    }
  }

  Future<void> deleteBlueprint(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF263238),
        title: const Text("Delete Blueprint?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This action cannot be undone. The blueprint will be permanently removed.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await StarlightStorage.getUserToken();
      final res = await http.delete(
        Uri.parse('$apiBase/document/blueprint/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          _showNotify("Blueprint deleted", true);
          fetchFeeBlueprints(); // Refresh list
        } else {
          _showNotify("Error: ${data['message'] ?? 'Failed to delete'}", false);
        }
      } else {
        _showNotify("Server error: ${res.statusCode}", false);
      }
    } catch (e) {
      _showNotify("Network error: $e", false);
    }
  }

  void _showNotify(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await fetchFeeBlueprints();
    await _loadSections();

    if (widget.initialData != null) {
      final data = widget.initialData!;
      setState(() {
        _titleController.text = data['name'] ?? data['voucher_title'] ?? '';
        _yearController.text = data['year']?.toString() ?? DateTime.now().year.toString();
        _voucherNumberController.text = data['voucher_number']?.toString() ?? '';

        // Hydrate selected student section if provided
        final String classSec = data['class_sec']?.toString() ?? '';
        if (classSec.isNotEmpty && _sections.contains(classSec)) {
          _selectedSection = classSec;
        }

        final List<dynamic> rawFeeItems = data['content'] is List 
            ? data['content'] 
            : (data['content'] is Map && data['content']['fee_items'] is List
                ? data['content']['fee_items']
                : []);
        
        _feeItems = rawFeeItems.map((item) {
          if (item is Map) {
            final String label = item['fee_type']?.toString() ?? item['subject_name']?.toString() ?? 'Fee Item';
            final double amount = double.tryParse(item['amount']?.toString() ?? '0.0') ?? 0.0;
            return {
              'label': label,
              'key': label.toLowerCase().replaceAll(' ', '_'),
              'amount': amount,
              'controller': TextEditingController(text: amount.toInt().toString()),
            };
          }
          return <String, dynamic>{};
        }).where((e) => e.isNotEmpty).toList();
      });
    }
  }

  Future<void> _loadSections() async {
    setState(() => _isLoading = true);
    try {
      final sections = await _dashboardService.getSections();
      setState(() {
        _sections = sections;
        
        if (_sections.isNotEmpty) {
          _selectedSection = _sections.first;
          // Trigger student loading for the default selection
          _loadStudentsBySection(_sections.first);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage("Network Link Failed", false);
      print('Error loading sections: $e');
    }
  }

  Future<void> _loadStudentsBySection(String section) async {
    print('Loading students for section: $section');
    setState(() => _isLoading = true);
    try {
      final students = await _dashboardService.getStudentsBySection(section);
      print('Students loaded from server: ${students.length}');
      
      if (students.isEmpty) {
        print('No students found in section: $section');
        setState(() {
          _students = [];
          _feeItems = [
            {'label': 'Tuition Fee', 'key': 'tuition_fee', 'amount': 0.0, 'controller': TextEditingController(text: '0')},
            {'label': 'Admission Fee', 'key': 'admission_fee', 'amount': 0.0, 'controller': TextEditingController(text: '0')},
          ];
          _selectedStudentIds.clear();
          _isLoading = false;
        });
        return;
      }
      
      // Use student fee data from database response
      final Map<String, Map<String, dynamic>> studentFeesWithDetails = {};
      
      for (final student in students) {
        final studentFee = student['fee'] ?? 0;
        print('Student fee from database for ${student['name']}: $studentFee');
        
        // Create fee structure for each student
        studentFeesWithDetails[student['id'].toString()] = {
          'tuition_fee': studentFee,
        };
      }
      
      setState(() {
        _students = students.map((student) => {
          'id': student['id'],
          'name': student['name'] ?? 'Unknown Name',
          'full_name': student['name'] ?? 'Unknown Name',
          'father_name': student['father_name'] ?? 'Not specified',
          'grade': student['section'] ?? student['grade'] ?? 'N/A',
          'class': student['section'] ?? student['grade'] ?? 'N/A',
          'roll_number': student['roll_number']?.toString() ?? 'N/A',
          'phone_number': student['phone_number'] ?? '',
          'national_id': student['national_id'] ?? '',
          'address': student['address'] ?? '',
          'gender': student['gender'] ?? '',
          'dob': student['dob'] ?? '',
          'status': student['status'] ?? 'active',
          'fee': student['fee'] ?? 0,
          'section': student['section'] ?? section,
          'extra_fields': student['extra_fields'] ?? {},
          'created_at': student['created_at'],
          'updated_at': student['updated_at'],
        }).toList();
        
        // Set fee items from the first student's fees (if available)
        if (studentFeesWithDetails.isNotEmpty) {
          final firstStudentId = studentFeesWithDetails.keys.first;
          final firstStudentFees = studentFeesWithDetails[firstStudentId];
          if (firstStudentFees != null && firstStudentFees.isNotEmpty) {
            _feeItems = firstStudentFees.entries.map((entry) {
              final feeData = entry.value;
              return {
                'label': _formatFeeLabel(entry.key),
                'key': entry.key,
                'amount': feeData is Map ? feeData['amount']?.toDouble() ?? (feeData as num).toDouble() : (feeData as num).toDouble(),
                'controller': TextEditingController(text: feeData is Map ? feeData['amount']?.toString() ?? feeData.toString() : feeData.toString())
              };
            }).toList();
          } else {
            // Initialize with default fee items if no fees found
            _feeItems = [
              {'label': 'Tuition Fee', 'key': 'tuition_fee', 'amount': 0.0, 'controller': TextEditingController(text: '0')},
              {'label': 'Admission Fee', 'key': 'admission_fee', 'amount': 0.0, 'controller': TextEditingController(text: '0')},
            ];
          }
        } else {
          // Initialize with default fee items if no fees found
          _feeItems = [
            {'label': 'Tuition Fee', 'key': 'tuition_fee', 'amount': 0.0, 'controller': TextEditingController(text: '0')},
            {'label': 'Admission Fee', 'key': 'admission_fee', 'amount': 0.0, 'controller': TextEditingController(text: '0')},
          ];
        }
        
        _selectedStudentIds.clear();
        _isLoading = false;
        print('Students loaded successfully: ${_students.length}');
        print('Fee items initialized: ${_feeItems.length} items');
      });
    } catch (e) {
      print('Error loading students: $e');
      setState(() => _isLoading = false);
      _showMessage('Error loading students: $e', false);
    }
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

  void _toggleStudentSelection(String studentId) {
    setState(() {
      if (_selectedStudentIds.contains(studentId)) {
        _selectedStudentIds.remove(studentId);
      } else {
        _selectedStudentIds.add(studentId);
        // Load individual student fees when selected
        _loadStudentFees(studentId);
      }
    });
  }

  void _selectAllStudents() {
    setState(() {
      _selectedStudentIds = _students.map((student) => student['id'].toString()).toList();
      // Load fees for all selected students
      for (final studentId in _selectedStudentIds) {
        _loadStudentFees(studentId);
      }
    });
  }

  void _deselectAllStudents() {
    setState(() {
      _selectedStudentIds.clear();
    });
  }

  Future<void> _loadStudentFees(String studentId) async {
    try {
      print('Loading fees for student ID: $studentId');
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        print('No authentication token found for student fees');
        return;
      }
      
      final res = await http.get(
        Uri.parse('https://api.institution.site/fee/voucher/$studentId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (res.statusCode == 200) {
        final Map<String, dynamic> feeData = jsonDecode(res.body);
        print('Student fees loaded: $feeData');
        
        setState(() {
          // Extract base_fee and vouchers from the response
          final baseFee = feeData['base_fee'] ?? 0;
          _studentFees[studentId] = {'tuition_fee': baseFee};
          
          // Update fee items based on student's actual fees
          _feeItems = [
            {
              'label': 'Tuition Fee',
              'key': 'tuition_fee',
              'amount': double.tryParse(baseFee.toString()) ?? 0.0,
              'controller': TextEditingController(text: baseFee.toString())
            }
          ];
        });
      } else {
        print('Failed to load student fees: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      print('Error loading student fees: $e');
    }
  }
  
  String _formatFeeLabel(String key) {
    switch (key) {
      case 'tuition_fee': return 'Tuition Fee';
      case 'admission_fee': return 'Admission Fee';
      case 'late_fee': return 'Late Fine';
      case 'library_fee': return 'Library Fee';
      case 'sports_fee': return 'Sports Fee';
      case 'lab_fee': return 'Lab Fee';
      case 'examination_fee': return 'Examination Fee';
      default: return key.replaceAll('_', ' ').split(' ').map((word) => 
        word[0].toUpperCase() + word.substring(1)
      ).join(' ');
    }
  }

  void _addFeeItem() {
    setState(() {
      _feeItems.add({
        'label': 'New Fee Item',
        'key': 'fee_custom_${DateTime.now().millisecondsSinceEpoch}',
        'amount': 0.0,
        'controller': TextEditingController(text: '0')
      });
    });
  }

  void _removeFeeItem(int index) {
    if (_feeItems.length > 1) {
      setState(() {
        _feeItems[index]['controller'].dispose();
        _feeItems.removeAt(index);
      });
    }
  }

  double _calculateStudentFeesTotal() {
    return _selectedStudentIds.fold(0.0, (total, studentId) {
      final student = _students.firstWhere((s) => s['id'].toString() == studentId);
      return total + (double.tryParse(student['fee']?.toString() ?? '0') ?? 0.0);
    });
  }

  double _calculateExtraChargesTotal() {
    return _feeItems.fold(0.0, (total, item) {
      return total + (double.tryParse(item['controller'].text) ?? 0.0);
    });
  }

  double _calculateGrandTotal() {
    return _calculateStudentFeesTotal() + _calculateExtraChargesTotal();
  }

  double _calculateTotal() {
    return _calculateGrandTotal();
  }

  Future<void> _saveVoucher() async {
    if (_selectedStudentIds.isEmpty) {
      _showMessage("Please select at least one student", false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await StarlightStorage.getUserToken();
      
      // Create vouchers for each selected student
      for (final studentId in _selectedStudentIds) {
        final student = _students.firstWhere((s) => s['id'].toString() == studentId);
        
        // Combine individual student fee with extra charges
        final List<Map<String, dynamic>> feeItemsList = [];
        
        // Add student's individual fee
        feeItemsList.add({
          "label": "Tuition Fee",
          "key": "tuition_fee",
          "amount": double.tryParse(student['fee']?.toString() ?? '0') ?? 0.0
        });
        
        // Add extra charges
        feeItemsList.addAll(_feeItems.map((item) => {
          "label": item['label'],
          "key": item['key'],
          "amount": double.tryParse(item['controller'].text) ?? 0.0
        }).toList());

        final totalAmount = feeItemsList.fold(0.0, (total, item) => total + (item['amount'] ?? 0.0));

        final payload = {
          "voucher_title": _titleController.text.trim(),
          "student_id": student['id']?.toString() ?? '', // 🏛️ ADDED: This connects it perfectly!
          "student_name": student['full_name'] ?? '',
          "father_name": student['father_name'] ?? '',
          "class_sec": student['grade'] ?? '',
          "roll_no": student['roll_number']?.toString() ?? '',
          "year": _yearController.text.trim(),
          "fee_items": feeItemsList,
          "total_amount": totalAmount,
          "paid_amount": 0.0,
          "due_amount": totalAmount,
          "due_date": "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
          "status": "unpaid",
          "voucher_number": _voucherNumberController.text.trim().isEmpty ? null : _voucherNumberController.text.trim(),
          "institution_name": "Starlight Institution",
        };

        final res = await http.post(
          Uri.parse('https://api.institution.site/fee/voucher/create'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json'
          },
          body: jsonEncode(payload),
        );

        if (res.statusCode != 200) {
          throw Exception('Server Error: ${res.statusCode}');
        }
      }

      _showMessage("Fee vouchers created successfully for ${_selectedStudentIds.length} students", true);
      _clearForm();
    } catch (e) {
      _showMessage("Error: Failed to save vouchers", false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _titleController.clear();
    _yearController.clear();
    _voucherNumberController.clear();
    _selectedStudentIds.clear();
    _deselectAllStudents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text("FEE VOUCHER DATA ENTRY", 
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Blueprint Button
          IconButton(
            icon: const Icon(Icons.account_tree_outlined, color: Color(0xFF263238)),
            onPressed: () => setState(() => isBlueprintSlideOpen = !isBlueprintSlideOpen),
            tooltip: "Blueprints",
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Voucher Details Section
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
                    const Text("VOUCHER DETAILS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: "Voucher Title",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.trim().isEmpty ?? true ? "Required" : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _voucherNumberController,
                      decoration: const InputDecoration(
                        labelText: "Voucher Number (Optional)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedSection,
                      decoration: InputDecoration(
                        labelText: "Section/Class",
                        border: const OutlineInputBorder(),
                        // Show a loading hint if sections aren't ready
                        hintText: _isLoading ? "Loading sections..." : "Select Section",
                      ),
                      // Disable dropdown if loading or empty
                      items: _isLoading
                          ? []
                          : _sections.map((section) => DropdownMenuItem(value: section, child: Text(section))).toList(),
                      onChanged: _isLoading ? null : (value) {
                        setState(() => _selectedSection = value);
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

              // Students Selection Section
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("STUDENTS SELECTION", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              "Selected: ${_selectedStudentIds.length} of ${_students.length}",
                              style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: _selectAllStudents,
                              child: const Text("Select All", style: TextStyle(fontSize: 12)),
                            ),
                            TextButton(
                              onPressed: _deselectAllStudents,
                              child: const Text("Deselect All", style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    if (_students.isEmpty)
                      const Text("No students found. Please select a section first.", 
                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                    if (_students.isNotEmpty)
                      ..._students.map((student) => 
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: _selectedStudentIds.contains(student['id'].toString()) ? primaryColor.withOpacity(0.1) : Colors.white,
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _selectedStudentIds.contains(student['id'].toString()),
                                  onChanged: (bool? value) {
                                    _toggleStudentSelection(student['id'].toString());
                                  },
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student['full_name'] ?? 'Unknown Name',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        "Father: ${student['father_name'] ?? 'Not specified'}",
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      Text(
                                        "Grade: ${student['grade'] ?? 'N/A'} | Roll: ${student['roll_number'] ?? 'N/A'}",
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          "Fee: PKR ${student['fee'] ?? '0'}",
                                          style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Fee Details Section
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
                    const Text("FEE SUMMARY", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 15),
                    
                    // Show individual student fees summary
                    if (_selectedStudentIds.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Individual Student Fees (${_selectedStudentIds.length} students)",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue),
                            ),
                            const SizedBox(height: 8),
                            ..._selectedStudentIds.map((studentId) {
                              final student = _students.firstWhere((s) => s['id'] == studentId);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "${student['full_name']} (${student['father_name']})",
                                        style: const TextStyle(fontSize: 11, color: Colors.black87),
                                      ),
                                    ),
                                    Text(
                                      "PKR ${student['fee'] ?? '0'}",
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            const SizedBox(height: 8),
                            Divider(color: Colors.grey.shade300),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Subtotal (Student Fees)",
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "PKR ${_calculateStudentFeesTotal().toStringAsFixed(2)}",
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],
                    
                    // Extra Charges Section
                    const Text("EXTRA CHARGES", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    ..._feeItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: item['label'],
                                decoration: const InputDecoration(
                                  labelText: "Charge Label",
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _feeItems[index]['label'] = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: item['controller'],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: "Amount",
                                  border: OutlineInputBorder(),
                                  prefixText: "PKR ",
                                ),
                                validator: (value) => value?.trim().isEmpty ?? true ? "Required" : null,
                              ),
                            ),
                            if (_feeItems.length > 1)
                              IconButton(
                                onPressed: () => _removeFeeItem(index),
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _addFeeItem,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("Add Extra Charge", style: TextStyle(fontSize: 12)),
                    ),
                    
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Student Fees Total",
                                style: TextStyle(fontSize: 14, color: Colors.black87),
                              ),
                              Text(
                                "PKR ${_calculateStudentFeesTotal().toStringAsFixed(2)}",
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Extra Charges",
                                style: TextStyle(fontSize: 14, color: Colors.black87),
                              ),
                              Text(
                                "PKR ${_calculateExtraChargesTotal().toStringAsFixed(2)}",
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.orange),
                              ),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "TOTAL AMOUNT",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                "PKR ${_calculateGrandTotal().toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveVoucher,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("CREATE FEE VOUCHERS FOR SELECTED STUDENTS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
      // Blueprint Slide Overlay
      _buildBlueprintSlide(),
        ],
      ),
    );
  }

  Widget _buildBlueprintSlide() {
    final slideWidth = MediaQuery.of(context).size.width * 0.75;
    
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: 0,
      bottom: 0,
      right: isBlueprintSlideOpen ? 0 : -slideWidth,
      child: Container(
        width: slideWidth,
        decoration: const BoxDecoration(
          color: Color(0xFF263238),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 20,
              offset: Offset(-5, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "BLUEPRINTS",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => isBlueprintSlideOpen = false),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              
              // Create Blueprint Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() => isBlueprintSlideOpen = false);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FeeVoucherEditor()),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    "CREATE BLUEPRINT",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              
              // Blueprint List
              Expanded(
                child: isLoadingBlueprints
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white54),
                            SizedBox(height: 16),
                            Text("Loading Blueprints...", style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      )
                    : blueprintError != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                                const SizedBox(height: 16),
                                Text(blueprintError!, style: const TextStyle(color: Colors.red)),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: fetchFeeBlueprints,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text("Retry"),
                                ),
                              ],
                            ),
                          )
                        : feeBlueprints.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.folder_open, color: Colors.white24, size: 64),
                                    SizedBox(height: 16),
                                    Text(
                                      "No Fee Blueprints Yet",
                                      style: TextStyle(color: Colors.white54, fontSize: 16),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      "Create your first fee blueprint",
                                      style: TextStyle(color: Colors.white38, fontSize: 12),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                itemCount: feeBlueprints.length,
                                itemBuilder: (context, i) {
                                  final bp = feeBlueprints[i];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: ListTile(
                                      leading: const Icon(Icons.receipt_long_outlined, color: Colors.white54, size: 20),
                                      title: Text(bp['title'] ?? 'Untitled Blueprint', 
                                        style: const TextStyle(
                                          color: Colors.white, 
                                          fontSize: 13, 
                                          fontWeight: FontWeight.w500
                                        )
                                      ),
                                      subtitle: Text(
                                        "Created: ${bp['created_at']?.toString().split('T').first ?? 'Unknown'}",
                                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Edit Button
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.white54, size: 18),
                                            onPressed: () {
                                              setState(() => isBlueprintSlideOpen = false);
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => FeeVoucherEditor(),
                                                ),
                                              );
                                            },
                                            tooltip: "Edit Blueprint",
                                          ),
                                          // Delete Button
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                            onPressed: () => deleteBlueprint(bp['id']),
                                            tooltip: "Delete Blueprint",
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
              
              const Spacer(),
              
              // Footer
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    "STARLIGHT FEE SYSTEM",
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
