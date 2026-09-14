import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import '../../../core/constants.dart';
import '../../../core/storage.dart';
import '../../../services/api_service.dart';

class CreateStudentCampaignScreen extends StatefulWidget {
  const CreateStudentCampaignScreen({super.key});

  @override
  State<CreateStudentCampaignScreen> createState() => _CreateStudentCampaignScreenState();
}

class _CreateStudentCampaignScreenState extends State<CreateStudentCampaignScreen> {
  final _titleCtrl = TextEditingController();
  final _localAuth = LocalAuthentication();
  List<String> _sections = [];
  String? _selectedSection;
  List<dynamic> _students = [];
  Map<int, bool> _paidStatus = {};
  bool _loadingSections = true;
  bool _loadingStudents = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<String?> _token() async => StarlightStorage.getUserToken();

  int _parseId(dynamic val) {
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  double _parseDouble(dynamic val) {
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0;
    return 0;
  }

  Future<void> _loadSections() async {
    final token = await _token();
    if (token == null) return;
    try {
      final res = await http.get(
        Uri.parse("${StarlightConstants.apiBaseUrl}/dashboard/sections"),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        if (mounted) {
          setState(() {
            _sections = data.map((s) => s.toString()).toList();
            _loadingSections = false;
          });
          if (_sections.isNotEmpty) _selectSection(_sections.first);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSections = false);
    }
  }

  Future<void> _selectSection(String section) async {
    setState(() {
      _selectedSection = section;
      _loadingStudents = true;
      _students = [];
      _paidStatus = {};
    });
    final token = await _token();
    if (token == null) return;
    try {
      final res = await http.get(
        Uri.parse("${StarlightConstants.apiBaseUrl}/dashboard/students/$section"),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        if (mounted) {
          final paid = <int, bool>{};
          for (final s in data) {
            paid[_parseId(s['id'])] = false;
          }
          setState(() {
            _students = data;
            _paidStatus = paid;
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingStudents = false);
  }

  double get _totalFee {
    double sum = 0;
    for (final s in _students) {
      sum += _parseDouble(s['fee']);
    }
    return sum;
  }

  double get _paidFee {
    double sum = 0;
    for (final s in _students) {
      final id = _parseId(s['id']);
      if (_paidStatus[id] == true) {
        sum += _parseDouble(s['fee']);
      }
    }
    return sum;
  }

  int get _paidCount => _paidStatus.values.where((v) => v).length;

  Future<bool> _authenticate() async {
    try {
      return await _localAuth.authenticate(localizedReason: "Authenticate to toggle payment status");
    } catch (_) {
      return false;
    }
  }

  Future<void> _togglePaid(int id) async {
    final authed = await _authenticate();
    if (!authed) return;
    setState(() {
      _paidStatus[id] = !(_paidStatus[id] ?? false);
    });
  }

  Future<void> _createCampaign() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a campaign title")));
      return;
    }
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No students in this section")));
      return;
    }

    setState(() => _submitting = true);
    try {
      final studentData = _students.map((s) {
        final id = _parseId(s['id']);
        return {
          'id': id,
          'name': s['name'] ?? '',
          'father_name': s['father_name'] ?? '',
          'phone': s['phone_number'] ?? s['extra_fields']?['phone_number'] ?? '',
          'fee': _parseDouble(s['fee']),
          'paid': _paidStatus[id] ?? false,
        };
      }).toList();

      await ApiService.post('/finance/campaigns', {
        'title': _titleCtrl.text.trim(),
        'campaign_type': 'student',
        'section': _selectedSection,
        'students': studentData,
        'total_amount': _totalFee,
        'paid_amount': _paidFee,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Campaign created successfully")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF263238)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("CREATE FEE CAMPAIGN", style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold, fontSize: 15)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: "Campaign Title",
                    hintText: "e.g. May 2026 Fee Collection",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                if (_loadingSections)
                  const SizedBox(height: 50, child: Center(child: CircularProgressIndicator()))
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSection,
                        isExpanded: true,
                        hint: const Text("Select Section"),
                        items: _sections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) {
                          if (val != null) _selectSection(val);
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _summaryChip("${_students.length} Students", Icons.people, const Color(0xFF0288D1)),
                const SizedBox(width: 10),
                _summaryChip("$_paidCount Paid", Icons.check_circle, const Color(0xFF2E7D32)),
                const SizedBox(width: 10),
                _summaryChip("${(_students.length - _paidCount)} Due", Icons.pending, const Color(0xFFE65100)),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Total Fee", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(_totalFee.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text("Collected", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(_paidFee.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2E7D32))),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("Remaining", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text((_totalFee - _paidFee).toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFE65100))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loadingStudents
                ? const Center(child: CircularProgressIndicator())
                : _students.isEmpty
                    ? const Center(child: Text("No students in this section", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _students.length,
                        itemBuilder: (ctx, i) => _buildStudentCard(_students[i]),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _submitting ? null : _createCampaign,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0288D1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Create Campaign", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _summaryChip(String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final id = _parseId(student['id']);
    final name = student['name'] ?? 'Unknown';
    final fatherName = student['father_name'] ?? 'N/A';
    final phone = student['phone_number'] ?? student['extra_fields']?['phone_number'] ?? 'N/A';
    final fee = _parseDouble(student['fee']);
    final isPaid = _paidStatus[id] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text("Father: $fatherName", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text("Phone: $phone", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _togglePaid(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isPaid ? const Color(0xFF2E7D32) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isPaid ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (isPaid)
                      BoxShadow(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPaid ? Icons.check_circle : Icons.payment,
                      size: 14,
                      color: isPaid ? Colors.white : const Color(0xFFE65100),
                    ),
                    const SizedBox(width: 4),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPaid ? "PAID" : fee.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isPaid ? Colors.white : const Color(0xFF1A237E),
                          ),
                        ),
                        Text(
                          isPaid ? "Tap to undo" : "Tap to pay",
                          style: TextStyle(
                            fontSize: 8,
                            color: isPaid ? Colors.white.withValues(alpha: 0.8) : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
