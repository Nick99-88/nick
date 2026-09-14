import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/utils.dart';
import '../../services/auth/auth_service.dart';
import '../../core/identity_controller.dart';
import '../../core/router_gateway.dart';
import '../../l10n/strings.dart';
import 'role_selection.dart';

class StaffSetupScreen extends StatefulWidget {
  const StaffSetupScreen({super.key});

  @override
  State<StaffSetupScreen> createState() => _StaffSetupScreenState();
}

class _StaffSetupScreenState extends State<StaffSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cnicController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();
  String? _gender;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cnicController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _handleCompleteProfile() async {
    if (!_formKey.currentState!.validate()) {
      StarlightUtils.showErrorBox(context, tr('fillRequiredFields'));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) throw Exception(tr('sessionExpiredShort'));

      final payload = {
        "full_name": _nameController.text.trim(),
        "phone_number": _phoneController.text.trim(),
        "national_id": _cnicController.text.trim(),
        "address": _addressController.text.trim(),
        "bio": _bioController.text.trim(),
        "gender": _gender ?? "Other",
        "dob": "1990-01-01",
      };

      await _authService.createIdentity(token: token, payload: payload);

      await IdentityController.updateRoleInfo(role: 'staff', roleId: "0");
      await StarlightStorage.setUserRole('staff');
      await StarlightStorage.setIdentity(true);

      if (mounted) {
        StarlightUtils.showSuccessBox(context, tr('staffProfileCreated'));
        await UniversalRouter.routeUser(context);
      }
    } catch (e) {
      if (mounted) StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showIdentityForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
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
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(tr('staffIdentity'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue)),
                const SizedBox(height: 8),
                Text(tr('fillProfessionalDetails'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildTextField(_nameController, tr('fullName'), prefixIcon: Icons.person_outline),
                        _buildTextField(_phoneController, tr('phoneNumber'), keyboardType: TextInputType.phone, prefixIcon: Icons.phone_android),
                        _buildDropdown(),
                        _buildTextField(_cnicController, tr('cnicNationalId'), prefixIcon: Icons.badge_outlined),
                        _buildTextField(_addressController, tr('residentialAddress'), maxLines: 2, prefixIcon: Icons.map_outlined),
                        _buildTextField(_bioController, tr('professionalBioSkills'), maxLines: 4, prefixIcon: Icons.info_outline),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleCompleteProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StarlightTheme.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(tr('solidifyIdentity'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const RoleSelectionScreen(currentRole: "staff")),
                      );
                    },
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: Text(tr('changeRole')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.badge_outlined, size: 100, color: StarlightTheme.primaryBlue),
              const SizedBox(height: 30),
              Text(
                tr('welcomeStaff'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue),
              ),
              const SizedBox(height: 16),
              Text(
                tr('staffIdentityIntro'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
              const SizedBox(height: 60),
              ElevatedButton.icon(
                onPressed: _showIdentityForm,
                icon: const Icon(Icons.assignment_ind),
                label: Text(tr('createIdentity')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: StarlightTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const RoleSelectionScreen(currentRole: "staff")),
                  );
                },
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: Text(tr('changeRole')),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.grey),
                  foregroundColor: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {TextInputType? keyboardType, int maxLines = 1, IconData? prefixIcon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black54),
          prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.black54) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
        ),
        validator: (value) => value == null || value.isEmpty ? tr('fieldRequired') : null,
      ),
    );
  }

  String _genderLabel(String gender) {
    switch (gender) {
      case 'Male':
        return tr('genderMale');
      case 'Female':
        return tr('genderFemale');
      default:
        return tr('genderOther');
    }
  }

  Widget _buildDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: _gender,
        style: const TextStyle(color: Colors.black),
        dropdownColor: Colors.white,
        items: ['Male', 'Female', 'Other']
            .map((g) => DropdownMenuItem(value: g, child: Text(_genderLabel(g), style: const TextStyle(color: Colors.black))))
            .toList(),
        onChanged: (val) => setState(() => _gender = val),
        decoration: InputDecoration(
          labelText: tr('gender'),
          labelStyle: const TextStyle(color: Colors.black54),
          prefixIcon: const Icon(Icons.wc, color: Colors.black54),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
        ),
        validator: (value) => value == null ? tr('selectGenderRequired') : null,
      ),
    );
  }
}
