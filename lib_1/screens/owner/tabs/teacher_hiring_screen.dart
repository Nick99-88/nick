import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../l10n/strings.dart';
import '../../../services/institution/dashboard_service.dart';
import 'database/dashboard_cache_service.dart';

class TeacherHiringScreen extends StatefulWidget {
  const TeacherHiringScreen({super.key});

  @override
  State<TeacherHiringScreen> createState() => _TeacherHiringScreenState();
}

class _TeacherHiringScreenState extends State<TeacherHiringScreen> {
  final DashboardService _dashboardService = DashboardService();
  final DashboardCacheService _cache = DashboardCacheService.instance;
  final _formKey = GlobalKey<FormState>();

  // 🏛️ Fixed Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();

  // 🏛️ Subject Selection
  List<String> _subjects = [];
  String? _selectedSubject;
  final TextEditingController _newSubjectController = TextEditingController();
  bool _isAddingNewSubject = false;

  // 🏛️ Flexible Field Storage
  List<Map<String, TextEditingController>> _extraFields = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final subjects = await _cache.getSubjects();
      setState(() => _subjects = subjects);
    } catch (_) {}
  }

  void _addExtraField() {
    setState(() {
      _extraFields.add({
        "key": TextEditingController(),
        "val": TextEditingController(),
      });
    });
  }

  /// 🏛️ Submit Logic for Teacher Onboarding
  Future<void> _handleHiring() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    Map<String, String> extraDetails = {};
    for (var field in _extraFields) {
      if (field["key"]!.text.isNotEmpty) {
        extraDetails[field["key"]!.text] = field["val"]!.text;
      }
    }

    final subjectName = _selectedSubject ?? _designationController.text.trim();

    final payload = {
      "name": _nameController.text.trim(),
      "designation": _designationController.text.trim(),
      "phone": _phoneController.text.trim(),
      "salary": double.tryParse(_salaryController.text) ?? 0.0,
      "joining_date": DateTime.now().toIso8601String().split('T')[0],
      "subject_name": subjectName,
      "extra_details": extraDetails,
    };

    try {
      final result = await _cache.hireTeacher(payload);
      if (result['pending'] == true) {
        StarlightUtils.showStatusBox(context, tr('teacherSavedPending'), true);
      } else {
        StarlightUtils.showStatusBox(context, tr('teacherOnboarded'), true);
      }
      _resetForm();
    } catch (e) {
      StarlightUtils.showStatusBox(context, tr('hiringFailed', {'error': e.toString()}), false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _nameController.clear();
    _phoneController.clear();
    _designationController.clear();
    _salaryController.clear();
    _newSubjectController.clear();
    setState(() {
      _extraFields.clear();
      _selectedSubject = null;
      _isAddingNewSubject = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tr('teacherOnboarding'),
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: StarlightTheme.primaryBlue),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[100], height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel(tr('facultyIdentity')),
              _buildTextField(
                  _nameController, tr('fullName'), Icons.person_outline),
              _buildTextField(_phoneController, tr('phoneNumber'),
                  Icons.phone_android_outlined,
                  kbType: TextInputType.phone),
              _buildLabel(tr('professionalDetails')),
              _buildTextField(_designationController, tr('designationSubject'),
                  Icons.work_outline),
              _buildSubjectSelector(),
              _buildTextField(
                  _salaryController, tr('monthlySalary'), Icons.payments_outlined,
                  kbType: TextInputType.number),
              const SizedBox(height: 10),
              _buildLabel(tr('flexibleRecords')),
              ..._extraFields.map((field) => _buildDynamicRow(field)).toList(),
              TextButton.icon(
                onPressed: _addExtraField,
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: Text(tr('addFlexibleField'),
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StarlightTheme.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _handleHiring,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(tr('confirmHiring'), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: _isAddingNewSubject
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('newSubject'),
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newSubjectController,
                        autofocus: true,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: tr('egMathematics'),
                          hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                          prefixIcon: const Icon(Icons.book_outlined, size: 18),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: StarlightTheme.primaryBlue, width: 1.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        final name = _newSubjectController.text.trim();
                        if (name.isNotEmpty) {
                          setState(() {
                            _subjects.add(name);
                            _selectedSubject = name;
                            _isAddingNewSubject = false;
                            _newSubjectController.clear();
                          });
                        }
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isAddingNewSubject = false;
                          _newSubjectController.clear();
                        });
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.close_rounded, color: Colors.grey[600], size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : DropdownButtonFormField<String>(
              value: _selectedSubject,
              decoration: InputDecoration(
                labelText: tr('subjectLabel'),
                prefixIcon: const Icon(Icons.book_outlined, size: 18),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              isExpanded: true,
              items: [
                ..._subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                DropdownMenuItem(value: "__new__", child: Text(tr('addNewSubject'), style: const TextStyle(fontWeight: FontWeight.w600, color: StarlightTheme.primaryBlue))),
              ],
              onChanged: (val) {
                if (val == "__new__") {
                  setState(() => _isAddingNewSubject = true);
                } else {
                  setState(() => _selectedSubject = val);
                }
              },
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 10),
      child: Text(text,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.grey,
              letterSpacing: 1.2)),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {TextInputType kbType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: kbType,
        validator: (v) => v!.isEmpty ? tr('required') : null,
        style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20, color: StarlightTheme.primaryBlue),
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildDynamicRow(Map<String, TextEditingController> field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
              child: _buildTextField(
                  field["key"]!, tr('field'), Icons.label_important_outline)),
          const SizedBox(width: 10),
          Expanded(
              child: _buildTextField(field["val"]!, tr('value'), Icons.edit_note)),
          IconButton(
            onPressed: () => setState(() => _extraFields.remove(field)),
            icon: const Icon(Icons.remove_circle_outline,
                color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _designationController.dispose();
    _salaryController.dispose();
    for (var f in _extraFields) {
      f["key"]?.dispose();
      f["val"]?.dispose();
    }
    super.dispose();
  }
}
