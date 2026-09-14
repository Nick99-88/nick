import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../l10n/strings.dart';
import '../../../services/institution/dashboard_service.dart';
import 'database/dashboard_cache_service.dart';

class StaffHiringScreen extends StatefulWidget {
  const StaffHiringScreen({super.key});

  @override
  State<StaffHiringScreen> createState() => _StaffHiringScreenState();
}

class _StaffHiringScreenState extends State<StaffHiringScreen> {
  final DashboardService _dashboardService = DashboardService();
  final DashboardCacheService _cache = DashboardCacheService.instance;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _cnicController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  List<String> _roles = [];
  String? _selectedRole;
  final TextEditingController _newRoleController = TextEditingController();
  bool _isAddingNewRole = false;

  final List<Map<String, TextEditingController>> _extraFields = [];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await _cache.getRoles();
      setState(() => _roles = roles);
    } catch (_) {}
  }

  void _addExtraField() {
    setState(() {
      _extraFields.add({"key": TextEditingController(), "val": TextEditingController()});
    });
  }

  Future<void> _submitHiring() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    Map<String, String> extraDetails = {};
    for (var field in _extraFields) {
      final key = field["key"]!.text.trim();
      final value = field["val"]!.text.trim();
      if (key.isNotEmpty) extraDetails[key] = value;
    }

    final roleName = _selectedRole ?? _positionController.text.trim();

    final payload = {
      "name": _nameController.text.trim(),
      "position": _positionController.text.trim(),
      "cnic": _cnicController.text.trim(),
      "contact": _contactController.text.trim(),
      "role_name": roleName,
      "extra_details": extraDetails,
    };

    try {
      final result = await _cache.hireStaff(payload);
      if (result['pending'] == true) {
        StarlightUtils.showStatusBox(context, tr('staffSavedPending'), true);
      } else {
        StarlightUtils.showStatusBox(context, tr('staffHired'), true);
      }
      _resetForm();
    } catch (e) {
      StarlightUtils.showStatusBox(context, tr('hiringFailed', {'error': e.toString()}), false);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    _nameController.clear();
    _positionController.clear();
    _cnicController.clear();
    _contactController.clear();
    _newRoleController.clear();
    setState(() {
      _extraFields.clear();
      _selectedRole = null;
      _isAddingNewRole = false;
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
          tr('staffRegistration'),
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
              _buildLabel(tr('personalDetails')),
              _buildTextField(_nameController, tr('fullName'), Icons.person_outline),
              _buildTextField(_contactController, tr('contactNumber'), Icons.phone_android_outlined, kbType: TextInputType.phone),
              _buildTextField(_cnicController, tr('cnicNumber'), Icons.subtitles_outlined, hint: tr('cnicHint')),
              _buildLabel(tr('positionRole')),
              _buildTextField(_positionController, tr('position'), Icons.badge_outlined, hint: tr('egGuardDriverClerk')),
              _buildRoleSelector(),
              const SizedBox(height: 10),
              _buildLabel(tr('additionalInformation')),
              ..._extraFields.map((field) => _buildDynamicRow(field)).toList(),
              GestureDetector(
                onTap: _addExtraField,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: StarlightTheme.primaryBlue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: StarlightTheme.primaryBlue.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, size: 18, color: StarlightTheme.primaryBlue),
                      const SizedBox(width: 6),
                      Text(tr('addField'), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: StarlightTheme.primaryBlue)),
                    ],
                  ),
                ),
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
                  onPressed: _isSubmitting ? null : _submitHiring,
                  child: _isSubmitting
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

  Widget _buildRoleSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: _isAddingNewRole
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('newRole'), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newRoleController,
                        autofocus: true,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: tr('egSecurityGuard'),
                          hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                          prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                          filled: true,
                          fillColor: Colors.grey[50],
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
                        final name = _newRoleController.text.trim();
                        if (name.isNotEmpty) {
                          setState(() {
                            _roles.add(name);
                            _selectedRole = name;
                            _isAddingNewRole = false;
                            _newRoleController.clear();
                          });
                        }
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isAddingNewRole = false;
                          _newRoleController.clear();
                        });
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.close_rounded, color: Colors.grey[600], size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: InputDecoration(
                labelText: tr('roleGroup'),
                labelStyle: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
                prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
              ),
              isExpanded: true,
              items: [
                ..._roles.map((r) => DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.poppins()))),
                DropdownMenuItem(value: "__new__", child: Text(tr('addNewRole'), style: const TextStyle(fontWeight: FontWeight.w600, color: StarlightTheme.primaryBlue))),
              ],
              onChanged: (val) {
                if (val == "__new__") {
                  setState(() => _isAddingNewRole = true);
                } else {
                  setState(() => _selectedRole = val);
                }
              },
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 10),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.2)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType kbType = TextInputType.text, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: kbType,
        validator: (v) => v!.isEmpty ? tr('required') : null,
        style: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 13),
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: Colors.grey[400]),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: StarlightTheme.primaryBlue, width: 1.5)),
        ),
      ),
    );
  }

  Widget _buildDynamicRow(Map<String, TextEditingController> field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: _buildTextField(field["key"]!, tr('field'), Icons.label_important_outline)),
          const SizedBox(width: 10),
          Expanded(child: _buildTextField(field["val"]!, tr('value'), Icons.edit_note)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _extraFields.remove(field)),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.close_rounded, size: 16, color: Colors.red[400]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _positionController.dispose();
    _cnicController.dispose();
    _contactController.dispose();
    _newRoleController.dispose();
    for (var f in _extraFields) {
      f["key"]?.dispose();
      f["val"]?.dispose();
    }
    super.dispose();
  }
}
