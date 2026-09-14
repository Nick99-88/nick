import 'package:flutter/material.dart';
import '../../../core/sign.dart';
import '../../../core/identity_controller.dart';
import '../../../core/storage.dart';
import '../../../services/auth/user_profile_service.dart';

class PersonalInformationScreen extends StatefulWidget {
  final VoidCallback onBack;
  const PersonalInformationScreen({super.key, required this.onBack});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final UserProfileService _profileService = UserProfileService();
  Map<String, dynamic>? identity;
  bool isLoading = true;

  // Editing States
  String? editingField;
  final TextEditingController _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchIdentity();
  }

  Future<void> _fetchIdentity() async {
    setState(() => isLoading = true);
    try {
      // Load identity data from local storage first
      final localData = await IdentityController.getIdentity();

      // Try to sync with server if online
      try {
        final serverData = await _profileService.getIdentity();
        if (mounted) {
          setState(() {
            identity = {...localData ?? {}, ...serverData};
            isLoading = false;
          });
        }
      } catch (e) {
        // Fall back to local data if server sync fails
        if (mounted) {
          setState(() {
            identity = localData ?? {};
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        StarlightUtils.showErrorBox(context, "Could not load profile data.");
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _updateField(String field, String value) async {
    StarlightUtils.showSuccessBox(context, "Updating $field...");

    try {
      // Update local storage first
      await IdentityController.updateField(field, value);

      // Try to sync with server
      try {
        await _profileService.updateIdentity({field: value});
        if (mounted) {
          StarlightUtils.showSuccessBox(context, "Profile Updated");
          setState(() => editingField = null);
          _fetchIdentity();
        }
      } catch (e) {
        // Local update succeeded even if server sync failed
        if (mounted) {
          StarlightUtils.showSuccessBox(context, "Profile Updated Locally");
          setState(() => editingField = null);
          _fetchIdentity();
        }
      }
    } catch (e) {
      if (mounted) StarlightUtils.showErrorBox(context, "Update Failed");
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
        title: const Text(
          "PERSONAL INFORMATION",
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  const Text(
                    "CORE IDENTITY",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    bool isVerified = identity?['verified'] ?? false;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8), Color(0xFF2563EB)],
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isVerified
                        ? Colors.white.withOpacity(0.2)
                        : Colors.amber.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isVerified ? "VERIFIED IDENTITY" : "PENDING VERIFICATION",
                    style: TextStyle(
                      color: isVerified ? Colors.white : Colors.amber.shade100,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Institutional Identity Vault",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Manage your verified institutional records and official profile data securely.",
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
              Icons.fingerprint_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
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
        children: [
          _infoRow("Full Name", "full_name", identity?['full_name'],
              Icons.person_rounded),
          _infoRow("CNIC / ID", "national_id", identity?['national_id'],
              Icons.badge_rounded),
          _infoRow("Phone Number", "phone_number", identity?['phone_number'],
              Icons.phone_rounded),
          _infoRow("Gender", "gender", identity?['gender'], Icons.wc_rounded),
          _infoRow("Date of Birth", "dob", identity?['dob'],
              Icons.calendar_month_rounded),
          _infoRow("Address", "address", identity?['address'],
              Icons.location_on_rounded),
          _infoRow("Bio", "bio", identity?['bio'], Icons.info_rounded,
              isLast: true),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String key, String? value, IconData icon,
      {bool isLast = false, bool canEdit = true}) {
    bool isEditing = editingField == key;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: isEditing
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF2563EB), width: 1.5),
                        ),
                        child: TextField(
                          controller: _editController,
                          autofocus: true,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B)),
                          decoration: const InputDecoration(
                              isDense: true, border: InputBorder.none),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: Text(
                          value ?? "Not Set",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: value == null
                                ? Colors.grey.shade400
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
              ),
              if (canEdit)
                IconButton(
                  onPressed: () {
                    if (isEditing) {
                      _updateField(key, _editController.text);
                    } else {
                      setState(() {
                        editingField = key;
                        _editController.text = value ?? "";
                      });
                    }
                  },
                  icon: Icon(
                    isEditing
                        ? Icons.check_circle_rounded
                        : Icons.edit_note_rounded,
                    color: const Color(0xFF2563EB),
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
