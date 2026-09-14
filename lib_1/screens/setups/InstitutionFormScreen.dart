import 'package:flutter/material.dart';
import '../../core/router_gateway.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../services/institution/institution_service.dart';

class InstitutionSetupScreen extends StatefulWidget {
  const InstitutionSetupScreen({super.key});

  @override
  State<InstitutionSetupScreen> createState() => _InstitutionSetupScreenState();
}

class _InstitutionSetupScreenState extends State<InstitutionSetupScreen> {
  final InstitutionService _instService = InstitutionService();
  String? _selectedType;
  bool _isLoading = false;

  // 🏛️ Controllers
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _descController = TextEditingController();
  final _extra1Controller = TextEditingController(); // Principal / EduType / Dean
  final _extra2Controller = TextEditingController(); // Campus / CampusName / Uni
  final _extra3Controller = TextEditingController(); // Website / Contact / Code

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _descController.dispose();
    _extra1Controller.dispose();
    _extra2Controller.dispose();
    _extra3Controller.dispose();
    super.dispose();
  }

  /// 🏛️ Logic: Establish the Institution in the Backend
  Future<void> _establish() async {
    // Basic Validation
    if (_nameController.text.isEmpty || _selectedType == null) {
      StarlightUtils.showErrorBox(context, "Institution Name and Type are mandatory.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Build Base Payload
      Map<String, dynamic> payload = {
        "name": _nameController.text.trim(),
        "address": _addressController.text.trim(),
        "email": _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        "description": _descController.text.trim().isEmpty ? "A Starlight Institution" : _descController.text.trim(),
        "type": _selectedType,
      };

      // 2. Add Polymorphic Required Fields based on Pydantic Schemas
      if (_selectedType == "school") {
        payload.addAll({
          "principal_name": _extra1Controller.text.trim(), // Required
          "campus": _extra2Controller.text.trim(),
          "website": _extra3Controller.text.trim(),
        });
      } else if (_selectedType == "academy") {
        payload.addAll({
          "edu_type": _extra1Controller.text.trim(), // Required
          "campus_name": _extra2Controller.text.trim(),
          "contact": _extra3Controller.text.trim().isEmpty ? "Not Provided" : _extra3Controller.text.trim(), // Required
        });
      } else if (_selectedType == "college") {
        payload.addAll({
          "dean_name": _extra1Controller.text.trim(), // Required
          "uni": _extra2Controller.text.trim(),
          "code": _extra3Controller.text.trim(),
        });
      }

      // 3. Backend Call
      final result = await _instService.createInstitution(
          type: _selectedType!,
          payload: payload
      );

      // 4. Persistence: Lock the Token
      if (result['institution_token'] != null) {
        await StarlightStorage.setInstitutionalToken(result['institution_token']);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showSuccessBox(context, "System Established Successfully!");
        // 5. Hand over to Universal Router
        await UniversalRouter.routeUser(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _selectedType == null ? "ESTABLISHMENT" : "NEW ${_selectedType!.toUpperCase()}",
          style: const TextStyle(letterSpacing: 1.2, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        leading: _selectedType != null
            ? IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => setState(() => _selectedType = null))
            : null,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _selectedType == null ? _buildTypeSelection() : _buildForm(),
      ),
    );
  }

  Widget _buildTypeSelection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.architecture_rounded, size: 80, color: StarlightTheme.primaryBlue),
          const SizedBox(height: 20),
          const Text("Digital Frontier", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text("Select the architecture of your institution.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          _typeCard("School", "Primary / Secondary Education", Icons.school_rounded, "school"),
          _typeCard("Academy", "Technical / Arts / Coaching", Icons.auto_awesome_mosaic_rounded, "academy"),
          _typeCard("College", "Higher Education / University", Icons.account_balance_rounded, "college"),
        ],
      ),
    );
  }

  Widget _typeCard(String title, String subtitle, IconData icon, String val) {
    return GestureDetector(
      onTap: () => setState(() => _selectedType = val),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: StarlightTheme.primaryBlue, size: 30),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.add_circle_outline, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("General Information"),
          _customField(_nameController, "Institution Name", Icons.business),
          _customField(_addressController, "Physical Address", Icons.location_on),
          _customField(_emailController, "Institutional Email", Icons.email, kbType: TextInputType.emailAddress),
          _customField(_descController, "Short Description", Icons.info_outline),

          const SizedBox(height: 20),
          _buildSectionTitle("Administrative Details"),

          // 🏛️ Dynamic Polymorphic Fields
          _customField(
              _extra1Controller,
              _selectedType == "school" ? "Principal Name" : _selectedType == "college" ? "Dean Name" : "Education Type (e.g. Arts)",
              Icons.person_pin_rounded
          ),

          _customField(
              _extra2Controller,
              _selectedType == "college" ? "Affiliated University" : "Campus / Branch Name",
              Icons.map_rounded
          ),

          _customField(
              _extra3Controller,
              _selectedType == "school" ? "Official Website" : _selectedType == "college" ? "Institutional Code" : "Contact Number",
              _selectedType == "school" ? Icons.language : _selectedType == "college" ? Icons.qr_code : Icons.phone
          ),

          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: StarlightTheme.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              onPressed: _isLoading ? null : _establish,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("INITIALIZE SYSTEM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue, letterSpacing: 1.5)),
    );
  }

  Widget _customField(TextEditingController controller, String label, IconData icon, {TextInputType kbType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        keyboardType: kbType,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20),
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}