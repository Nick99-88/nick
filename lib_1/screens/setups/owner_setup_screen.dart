import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart'; // 🏛️ Added for Database Conflict Rules
import '../../core/router_gateway.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/utils.dart';
import '../../core/database_helper.dart';
import '../../services/auth/auth_service.dart';
import '../../l10n/strings.dart';
import 'role_selection.dart';

class OwnerSetupScreen extends StatefulWidget {
  const OwnerSetupScreen({super.key});

  @override
  State<OwnerSetupScreen> createState() => _OwnerSetupScreenState();
}

class _OwnerSetupScreenState extends State<OwnerSetupScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();
  String _selectedGender = "Male";

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _idController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// 🏛️ Vault Sync: Locks the finalized identity into the hardware layer
  Future<void> _updateVaultIdentity(String fullName) async {
    final db = await StarlightVault.instance.database;
    await db.update(
      'user_identity',
      {'name': fullName},
      where: 'id = ?',
      whereArgs: [1],
    );
    debugPrint("🏛️ System: Identity updated in Hardware Vault.");
  }

  Future<void> _submitIdentity() async {
    if (_nameController.text.isEmpty || _idController.text.isEmpty) {
      StarlightUtils.showErrorBox(context, tr('nameAndIdRequired'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) throw Exception(tr('sessionExpiredRelogin'));

      final payload = {
        "full_name": _nameController.text.trim(),
        "phone_number": _phoneController.text.trim(),
        "gender": _selectedGender,
        "dob": "2000-01-01",
        "national_id": _idController.text.trim(),
        "address": _addressController.text.trim(),
        "bio": _bioController.text.trim(),
      };

      // 1. 🏛️ API Handshake
      await _authService.createIdentity(token: token, payload: payload);

      // 2. 🏛️ TOTAL PERSISTENCE
      // -> Preferences
      await StarlightStorage.setIdentity(true);
      await StarlightStorage.setIdentityVerifyToken("IDENTITY_LOCKED");

      // -> Hardware Vault (SQLite)
      await _updateVaultIdentity(_nameController.text.trim());

      if (mounted) {
        StarlightUtils.showSuccessBox(context, tr('profileVerified'));
        // 3. 🏛️ Trigger Universal Gateway
      }
      await UniversalRouter.routeUser(context);
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains("Identity already exists")) {
        await StarlightStorage.setIdentity(true);
        await StarlightStorage.setIdentityVerifyToken("IDENTITY_LOCKED");
        if (mounted) {
          StarlightUtils.showSuccessBox(context, tr('identityAlreadyVerified'));
          await UniversalRouter.routeUser(context);
        }
      } else {
        if (mounted) StarlightUtils.showErrorBox(context, errorMsg.replaceAll("Exception: ", ""));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  // 🏛️ Step 2: The Identity Form Sheet
  void _showIdentityForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 24, right: 24, top: 24
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Text(tr('professionalIdentity'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue)),
              const SizedBox(height: 20),
              TextField(controller: _nameController, style: const TextStyle(color: Colors.black), decoration: InputDecoration(labelText: tr('fullNameAsPerCnic'), labelStyle: const TextStyle(color: Colors.black54), prefixIcon: const Icon(Icons.person_outline, color: Colors.black54))),
              const SizedBox(height: 12),
              TextField(controller: _phoneController, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.black), decoration: InputDecoration(labelText: tr('contactNumber'), labelStyle: const TextStyle(color: Colors.black54), prefixIcon: const Icon(Icons.phone_android, color: Colors.black54))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                style: const TextStyle(color: Colors.black),
                dropdownColor: Colors.white,
                items: ["Male", "Female", "Other"].map((g) => DropdownMenuItem(value: g, child: Text(_genderLabel(g), style: const TextStyle(color: Colors.black)))).toList(),
                onChanged: (val) => setState(() => _selectedGender = val!),
                decoration: InputDecoration(labelText: tr('gender'), labelStyle: const TextStyle(color: Colors.black54), prefixIcon: const Icon(Icons.wc, color: Colors.black54)),
              ),
              const SizedBox(height: 12),
              TextField(controller: _idController, style: const TextStyle(color: Colors.black), decoration: InputDecoration(labelText: tr('nationalIdCnic'), labelStyle: const TextStyle(color: Colors.black54), prefixIcon: const Icon(Icons.badge_outlined, color: Colors.black54))),
              const SizedBox(height: 12),
              TextField(controller: _addressController, style: const TextStyle(color: Colors.black), decoration: InputDecoration(labelText: tr('residentialAddress'), labelStyle: const TextStyle(color: Colors.black54), prefixIcon: const Icon(Icons.map_outlined, color: Colors.black54))),
              const SizedBox(height: 12),
              TextField(
                  controller: _bioController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(labelText: tr('shortBio'), hintText: tr('educationalVisionHint'), labelStyle: const TextStyle(color: Colors.black54), hintStyle: const TextStyle(color: Colors.black38))
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitIdentity,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(tr('solidifyIdentity'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🏛️ Step 1: The Landing Page
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
              const Icon(Icons.admin_panel_settings_outlined, size: 100, color: StarlightTheme.primaryBlue),
              const SizedBox(height: 30),
              Text(
                tr('welcomeOwner'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue),
              ),
              const SizedBox(height: 16),
              Text(
                tr('ownerIdentityIntro'),
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
                    MaterialPageRoute(
                      builder: (_) => const RoleSelectionScreen(currentRole: "owner"),
                    ),
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
}