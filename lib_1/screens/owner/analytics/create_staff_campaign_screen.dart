import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import '../../../core/constants.dart';
import '../../../core/storage.dart';
import '../../../services/api_service.dart';

class CreateStaffCampaignScreen extends StatefulWidget {
  const CreateStaffCampaignScreen({super.key});

  @override
  State<CreateStaffCampaignScreen> createState() => _CreateStaffCampaignScreenState();
}

class _CreateStaffCampaignScreenState extends State<CreateStaffCampaignScreen> {
  final _titleCtrl = TextEditingController();
  final _localAuth = LocalAuthentication();
  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _staff = [];
  Map<String, bool> _paidStatus = {};
  bool _loading = true;
  bool _submitting = false;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadPersonnel();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<String?> _token() async => StarlightStorage.getUserToken();

  double _parseDouble(dynamic val) {
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0;
    return 0;
  }

  Future<void> _loadPersonnel() async {
    final token = await _token();
    if (token == null) return;
    setState(() => _loading = true);
    try {
      final teacherRes = await http.get(
        Uri.parse("${StarlightConstants.apiBaseUrl}/dashboard/teacher-list"),
        headers: {'Authorization': 'Bearer $token'},
      );
      final staffRes = await http.get(
        Uri.parse("${StarlightConstants.apiBaseUrl}/dashboard/Staff_list"),
        headers: {'Authorization': 'Bearer $token'},
      );

      List<Map<String, dynamic>> teachers = [];
      List<Map<String, dynamic>> staff = [];

      if (teacherRes.statusCode == 200) {
        final data = jsonDecode(teacherRes.body);
        if (data is Map && data['rows'] != null) {
          teachers = List<Map<String, dynamic>>.from(data['rows']);
        }
      }

      if (staffRes.statusCode == 200) {
        final data = jsonDecode(staffRes.body);
        if (data is Map && data['rows'] != null) {
          staff = List<Map<String, dynamic>>.from(data['rows']);
        }
      }

      if (mounted) {
        final paid = <String, bool>{};
        for (final t in teachers) {
          paid['teacher_${t['id']}'] = false;
        }
        for (final s in staff) {
          paid['staff_${s['id']}'] = false;
        }
        setState(() {
          _teachers = teachers;
          _staff = staff;
          _paidStatus = paid;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _authenticate() async {
    try {
      return await _localAuth.authenticate(localizedReason: "Authenticate to toggle payment status");
    } catch (_) {
      return false;
    }
  }

  Future<void> _togglePaid(String key) async {
    final authed = await _authenticate();
    if (!authed) return;
    setState(() {
      _paidStatus[key] = !(_paidStatus[key] ?? false);
    });
  }

  List<Map<String, dynamic>> get _allPersonnel {
    final all = <Map<String, dynamic>>[];
    for (final t in _teachers) {
      all.add({
        'key': 'teacher_${t['id']}',
        'id': t['id'],
        'name': t['name'] ?? 'Unknown',
        'role': t['designation'] ?? 'Teacher',
        'phone': t['phone'] ?? 'N/A',
        'salary': _parseDouble(t['salary']),
        'type': 'teacher',
      });
    }
    for (final s in _staff) {
      all.add({
        'key': 'staff_${s['id']}',
        'id': s['id'],
        'name': s['name'] ?? 'Unknown',
        'role': s['position'] ?? 'Staff',
        'phone': s['contact'] ?? 'N/A',
        'salary': 0.0,
        'type': 'staff',
      });
    }
    return all;
  }

  List<Map<String, dynamic>> get _filteredPersonnel {
    final all = _allPersonnel;
    if (_filter == 'teachers') return all.where((p) => p['type'] == 'teacher').toList();
    if (_filter == 'staff') return all.where((p) => p['type'] == 'staff').toList();
    return all;
  }

  double get _totalSalary {
    double sum = 0;
    for (final p in _filteredPersonnel) {
      sum += p['salary'] as double;
    }
    return sum;
  }

  double get _paidSalary {
    double sum = 0;
    for (final p in _filteredPersonnel) {
      if (_paidStatus[p['key']] == true) {
        sum += p['salary'] as double;
      }
    }
    return sum;
  }

  int get _paidCount => _filteredPersonnel.where((p) => _paidStatus[p['key']] == true).length;

  Future<void> _createCampaign() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a campaign title")));
      return;
    }
    if (_allPersonnel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No personnel found")));
      return;
    }

    setState(() => _submitting = true);
    try {
      final personnelData = _allPersonnel.map((p) => {
        'id': p['id'],
        'name': p['name'],
        'role': p['role'],
        'phone': p['phone'],
        'salary': p['salary'],
        'type': p['type'],
        'paid': _paidStatus[p['key']] ?? false,
      }).toList();

      await ApiService.post('/finance/campaigns', {
        'title': _titleCtrl.text.trim(),
        'campaign_type': 'staff',
        'personnel': personnelData,
        'total_amount': _totalSalary,
        'paid_amount': _paidSalary,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Staff campaign created successfully")),
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
    final filtered = _filteredPersonnel;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF263238)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("CREATE STAFF CAMPAIGN", style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold, fontSize: 15)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: "Campaign Title",
                hintText: "e.g. May 2026 Salary",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip("All", 'all'),
                const SizedBox(width: 8),
                _filterChip("Teachers", 'teachers'),
                const SizedBox(width: 8),
                _filterChip("Staff", 'staff'),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _summaryChip("${filtered.length} People", Icons.people, const Color(0xFF0288D1)),
                const SizedBox(width: 10),
                _summaryChip("$_paidCount Paid", Icons.check_circle, const Color(0xFF2E7D32)),
                const SizedBox(width: 10),
                _summaryChip("${filtered.length - _paidCount} Due", Icons.pending, const Color(0xFFE65100)),
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
                      const Text("Total Salary", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(_totalSalary.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text("Paid", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(_paidSalary.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2E7D32))),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("Remaining", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text((_totalSalary - _paidSalary).toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFE65100))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text("No personnel found", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) => _buildPersonnelCard(filtered[i]),
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
              backgroundColor: const Color(0xFF7B1FA2),
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

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF7B1FA2) : const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? const Color(0xFF7B1FA2) : Colors.grey.shade300),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : Colors.grey,
              ),
            ),
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

  Widget _buildPersonnelCard(Map<String, dynamic> person) {
    final key = person['key'] as String;
    final name = person['name'] as String;
    final role = person['role'] as String;
    final phone = person['phone'] as String;
    final salary = person['salary'] as double;
    final type = person['type'] as String;
    final isPaid = _paidStatus[key] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: type == 'teacher' ? const Color(0xFF0288D1).withValues(alpha: 0.1) : const Color(0xFF7B1FA2).withValues(alpha: 0.1),
              child: Icon(
                type == 'teacher' ? Icons.school : Icons.work,
                size: 16,
                color: type == 'teacher' ? const Color(0xFF0288D1) : const Color(0xFF7B1FA2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.badge, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(role, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(phone, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _togglePaid(key),
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
                          isPaid ? "PAID" : (salary > 0 ? salary.toStringAsFixed(0) : 'Mark'),
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
