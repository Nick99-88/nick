import 'package:flutter/material.dart';
import '../../../core/storage.dart';
import '../../../core/sign.dart';
import '../../../services/institution/institution_profile_service.dart';

class ProfessionalBioScreen extends StatefulWidget {
  final VoidCallback onBack;
  const ProfessionalBioScreen({super.key, required this.onBack});

  @override
  State<ProfessionalBioScreen> createState() => _ProfessionalBioScreenState();
}

class _ProfessionalBioScreenState extends State<ProfessionalBioScreen> {
  final InstitutionProfileService _profileService = InstitutionProfileService();

  // Base Controllers
  final _instNameController = TextEditingController();
  final _instAddressController = TextEditingController();
  String? _instType;

  // Polymorphic Controllers
  final _principalController = TextEditingController();
  final _campusController = TextEditingController();
  final _websiteController = TextEditingController();
  final _eduTypeController = TextEditingController();
  final _campusNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _deanController = TextEditingController();
  final _uniController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isLoading = true;
  bool _isInstitutionSetup = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final data = await _profileService.getInstitutionProfile();
      if (mounted) {
        setState(() {
          _isInstitutionSetup = data['is_institution_setup'] ?? false;
          _instNameController.text = data['institution_name'] ?? '';
          _instAddressController.text = data['institution_address'] ?? '';
          _instType = data['institution_type'];

          // Pre-fill polymorphic fields
          _principalController.text = data['principal_name'] ?? '';
          _campusController.text = data['campus'] ?? '';
          _websiteController.text = data['website'] ?? '';
          _eduTypeController.text = data['edu_type'] ?? '';
          _campusNameController.text = data['campus_name'] ?? '';
          _contactController.text = data['contact'] ?? '';
          _deanController.text = data['dean_name'] ?? '';
          _uniController.text = data['uni'] ?? '';
          _codeController.text = data['code'] ?? '';

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        StarlightUtils.showErrorBox(
            context, "Could not sync profile from cloud.");
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSave() async {
    if (_instNameController.text.isEmpty || _instType == null) {
      StarlightUtils.showErrorBox(
          context, "Institution Name and Type are required.");
      return;
    }

    setState(() => _isLoading = true);

    final payload = {
      "institution_name": _instNameController.text,
      "institution_address": _instAddressController.text,
      "institution_type": _instType,
      "principal_name": _principalController.text,
      "campus": _campusController.text,
      "website": _websiteController.text,
      "edu_type": _eduTypeController.text,
      "campus_name": _campusNameController.text,
      "contact": _contactController.text,
      "dean_name": _deanController.text,
      "uni": _uniController.text,
      "code": _codeController.text,
    };

    try {
      await _profileService.updateInstitutionProfile(payload);
      await StarlightStorage.setInstitutionalToken(
          "INSTITUTION_SETUP_COMPLETE");

      if (mounted) {
        StarlightUtils.showSuccessBox(context, "Institution Profile Synced");
        _loadProfile();
      }
    } catch (e) {
      if (mounted) StarlightUtils.showErrorBox(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Color(0xFF1E293B)),
            onPressed: widget.onBack,
          ),
        ),
        title: Text(
          _isInstitutionSetup ? "MANAGE INSTITUTION" : "ESTABLISH INSTITUTION",
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Color(0xFF1E293B),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // Hero Header Banner matching Starlight Vault/Dashboard style
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF012563),
                          Color(0xFF1D4ED8),
                          Color(0xFF2563EB)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isInstitutionSetup
                                    ? "Institution Vault"
                                    : "Global Setup Hub",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isInstitutionSetup
                                    ? "Update your institutional credentials and secure data parameters instantly."
                                    : "Establish the core identity of your digital campus inside the Starlight network.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.85),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Form Card Container
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          _isInstitutionSetup
                              ? "Edit Details"
                              : "Establish New Campus",
                          "Configure formal identity parameters for your digital platform.",
                        ),
                        const SizedBox(height: 8),
                        _buildTextField(_instNameController, "Institution Name",
                            Icons.account_balance_rounded),
                        _buildTextField(_instAddressController,
                            "Institution Address", Icons.location_on_rounded),
                        _buildDropdown(),
                        if (_instType != null) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Divider(
                                color: Color(0xFFF1F5F9), thickness: 1.5),
                          ),
                          ..._buildPolymorphicFields(),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: const Color(0xFF2563EB).withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _isInstitutionSetup
                            ? "UPDATE VAULT"
                            : "SAVE & ESTABLISH",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildPolymorphicFields() {
    switch (_instType) {
      case 'school':
        return [
          _buildTextField(
              _principalController, "Principal Name", Icons.person_rounded),
          _buildTextField(
              _campusController, "Campus / Branch", Icons.domain_rounded),
          _buildTextField(
              _websiteController, "Website", Icons.language_rounded),
        ];
      case 'academy':
        return [
          _buildTextField(_eduTypeController,
              "Education Type (e.g., Arts, Tech)", Icons.lightbulb_rounded),
          _buildTextField(
              _campusNameController, "Academy Name", Icons.school_rounded),
          _buildTextField(
              _contactController, "Contact Number", Icons.phone_rounded),
        ];
      case 'college':
        return [
          _buildTextField(_deanController, "Dean's Name",
              Icons.supervised_user_circle_rounded),
          _buildTextField(
              _uniController, "Affiliated University", Icons.business_rounded),
          _buildTextField(
              _codeController, "Institutional Code", Icons.qr_code_rounded),
        ];
      default:
        return [];
    }
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500),
          prefixIcon: Icon(icon, color: const Color(0xFF2563EB), size: 20),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: DropdownButtonFormField<String>(
        value: _instType,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B)),
        dropdownColor: Colors.white,
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF2563EB)),
        decoration: InputDecoration(
          labelText: "Institution Type",
          labelStyle: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500),
          prefixIcon: const Icon(Icons.category_rounded,
              color: Color(0xFF2563EB), size: 20),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
          ),
        ),
        items: ['school', 'academy', 'college']
            .map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t.toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B))),
                ))
            .toList(),
        onChanged: (val) => setState(() => _instType = val),
      ),
    );
  }
}
