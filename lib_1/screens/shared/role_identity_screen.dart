import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/constants.dart';

class RoleIdentityScreen extends StatefulWidget {
  const RoleIdentityScreen({super.key});

  @override
  State<RoleIdentityScreen> createState() => _RoleIdentityScreenState();
}

class _RoleIdentityScreenState extends State<RoleIdentityScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String _role = "";

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _genderCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _nationalIdCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchIdentity();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _genderCtrl.dispose();
    _dobCtrl.dispose();
    _nationalIdCtrl.dispose();
    _addressCtrl.dispose();
    _bioCtrl.dispose();
    _subjectCtrl.dispose();
    _designationCtrl.dispose();
    _departmentCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchIdentity() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse("${StarlightConstants.apiBaseUrl}/profile/identity"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _role = data['role'] ?? '';
          _nameCtrl.text = data['full_name'] ?? data['name'] ?? '';
          _phoneCtrl.text = data['phone_number'] ?? data['phone'] ?? '';
          _genderCtrl.text = data['gender'] ?? '';
          _dobCtrl.text = data['dob'] ?? '';
          _nationalIdCtrl.text = data['national_id'] ?? '';
          _addressCtrl.text = data['address'] ?? '';
          _bioCtrl.text = data['bio'] ?? '';
          _subjectCtrl.text = data['subject_name'] ?? '';
          _designationCtrl.text = data['designation'] ?? data['position'] ?? data['role_name'] ?? '';
          _departmentCtrl.text = data['department'] ?? '';
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveIdentity() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final body = <String, dynamic>{};
      if (_nameCtrl.text.isNotEmpty) body['full_name'] = _nameCtrl.text;
      if (_phoneCtrl.text.isNotEmpty) body['phone_number'] = _phoneCtrl.text;
      if (_genderCtrl.text.isNotEmpty) body['gender'] = _genderCtrl.text;
      if (_dobCtrl.text.isNotEmpty) body['dob'] = _dobCtrl.text;
      if (_nationalIdCtrl.text.isNotEmpty) body['national_id'] = _nationalIdCtrl.text;
      if (_addressCtrl.text.isNotEmpty) body['address'] = _addressCtrl.text;
      if (_bioCtrl.text.isNotEmpty) body['bio'] = _bioCtrl.text;
      if (_subjectCtrl.text.isNotEmpty) body['subject_name'] = _subjectCtrl.text;
      if (_designationCtrl.text.isNotEmpty) body['designation'] = _designationCtrl.text;
      if (_departmentCtrl.text.isNotEmpty) body['department'] = _departmentCtrl.text;

      final response = await http.post(
        Uri.parse("${StarlightConstants.apiBaseUrl}/profile/identity/update"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Identity updated"), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        } else {
          final err = jsonDecode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err['detail'] ?? "Update failed"), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("My Identity")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final accent = _role == 'student' ? Colors.green.shade700 : StarlightTheme.primaryBlue;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Identity"),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveIdentity,
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, color: Colors.white),
            label: Text(_isSaving ? "Saving..." : "Save", style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader("Personal Information", accent),
            const SizedBox(height: 8),
            _field("Full Name", _nameCtrl, Icons.person, accent),
            _field("Phone Number", _phoneCtrl, Icons.phone, accent),
            _genderDropdown(accent),
            _field("Date of Birth", _dobCtrl, Icons.cake, accent, hint: "YYYY-MM-DD"),
            _field("National ID", _nationalIdCtrl, Icons.badge, accent),
            _field("Address", _addressCtrl, Icons.location_on, accent),
            _field("Bio", _bioCtrl, Icons.info_outline, accent, maxLines: 3),

            const SizedBox(height: 24),
            _sectionHeader("Professional Details", accent),
            const SizedBox(height: 8),

            if (_role == 'teacher') ...[
              _field("Subject", _subjectCtrl, Icons.subject, accent),
              _field("Designation", _designationCtrl, Icons.work, accent),
              _field("Department", _departmentCtrl, Icons.business, accent),
            ] else if (_role == 'staff') ...[
              _field("Designation / Position", _designationCtrl, Icons.work, accent),
            ] else if (_role == 'student') ...[
              _field("Section", _subjectCtrl, Icons.group, accent),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, Color accent) {
    return Row(
      children: [
        Icon(Icons.circle, size: 8, color: accent),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: accent)),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon, Color accent, {int maxLines = 1, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: accent, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accent, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _genderDropdown(Color accent) {
    final options = ["", "male", "female", "other"];
    final labels = ["Not set", "Male", "Female", "Other"];
    final current = _genderCtrl.text.toLowerCase();
    int idx = options.indexOf(current);
    if (idx < 0) idx = 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        value: idx,
        decoration: InputDecoration(
          labelText: "Gender",
          prefixIcon: Icon(Icons.wc, color: accent, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accent, width: 2),
          ),
        ),
        items: List.generate(labels.length, (i) => DropdownMenuItem(value: i, child: Text(labels[i]))),
        onChanged: (val) {
          if (val != null) _genderCtrl.text = options[val];
        },
      ),
    );
  }
}
