import 'package:flutter/material.dart';
import 'dart:convert';
import '../../core/router_gateway.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/utils.dart';
import '../../services/auth/auth_service.dart';
import '../../core/identity_controller.dart';
import '../../l10n/strings.dart';

class RoleSelectionScreen extends StatefulWidget {
  final String? currentRole;
  const RoleSelectionScreen({super.key, this.currentRole});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  /// 🏛️ Solidify Role Protocol
  /// Links the user to a specific polymorphic identity (Owner/Teacher/Student)
  /// 🏛️ Solidify Role Protocol
  /// Links the user to a specific polymorphic identity (Owner/Teacher/Student)
  Future<void> _solidifyRole(String role) async {
    setState(() => _isLoading = true);
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) throw Exception(tr('sessionExpired'));

      // 1. 🏛️ Backend Solidification Handshake
      // This rebrands the ID and creates the sub-table entry on the server
      final result = await _authService.initializeRole(token: token, role: role);

      // 2. 🏛️ Extract Response Data
      String finalizedRole = result['role'] ?? role;
      String rawRoleId = result['role_id']?.toString() ?? "0";

      // 3. 🏛️ LOCAL DB PERSISTENCE (The Starlight Vault)
      // Update the singleton identity row with the new role and ID
      await IdentityController.updateRoleInfo(
        role: finalizedRole,
        roleId: rawRoleId,
      );

      // 4. 🏛️ SECURE STORAGE PERSISTENCE (For the Router)
      await StarlightStorage.setUserRole(finalizedRole);

      // If the server returned institution data during solidification
      if (result['institution'] != null) {
        final inst = result['institution'];
        await IdentityController.linkInstitution(
          name: inst['name'],
          ref: inst['ref'],
          id: inst['id'],
        );
        await StarlightStorage.setInstitutionalToken(inst['id'].toString());
      }

      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showSuccessBox(context, tr('identitySecured', {'role': finalizedRole.toUpperCase()}));

        // 5. 🏛️ TRIGGER UNIVERSAL ROUTER
        // Evaluation happens based on the newly stored local data
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.shield_outlined, size: 50, color: StarlightTheme.primaryBlue),
                const SizedBox(height: 12),
                Text(
                  tr('chooseYourPath'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('roleDefinesConsole'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 24),

                _buildRoleCard(
                  title: tr('roleStudent'),
                  subtitle: tr('roleStudentDesc'),
                  icon: Icons.school,
                  color: Colors.orange,
                  roleKey: "student",
                  onTap: () => _solidifyRole("student"),
                ),
                const SizedBox(height: 12),
                _buildRoleCard(
                  title: tr('roleTeacher'),
                  subtitle: tr('roleTeacherDesc'),
                  icon: Icons.auto_stories,
                  color: Colors.green,
                  roleKey: "teacher",
                  onTap: () => _solidifyRole("teacher"),
                ),
                const SizedBox(height: 12),
                _buildRoleCard(
                  title: tr('roleOwner'),
                  subtitle: tr('roleOwnerDesc'),
                  icon: Icons.account_balance,
                  color: StarlightTheme.primaryBlue,
                  roleKey: "owner",
                  onTap: () => _solidifyRole("owner"),
                ),
                const SizedBox(height: 12),
                _buildRoleCard(
                  title: tr('roleStaff'),
                  subtitle: tr('roleStaffDesc'),
                  icon: Icons.work,
                  color: Colors.purple,
                  roleKey: "staff",
                  onTap: () => _solidifyRole("staff"),
                ),
                const SizedBox(height: 12),
                _buildRoleCard(
                  title: tr('roleParent'),
                  subtitle: tr('roleParentDesc'),
                  icon: Icons.family_restroom,
                  color: Colors.teal,
                  roleKey: "parent",
                  onTap: () => _solidifyRole("parent"),
                ),

                const SizedBox(height: 24),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator(color: StarlightTheme.primaryBlue))
                else
                  const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String roleKey,
    required VoidCallback onTap,
  }) {
    final isCurrent = widget.currentRole == roleKey;
    return InkWell(
      onTap: (_isLoading || isCurrent) ? null : onTap,
      borderRadius: BorderRadius.circular(15),
      child: Opacity(
        opacity: isCurrent ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
            color: color.withOpacity(0.05),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                radius: 25,
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                            child: Text(tr('currentBadge'), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  ],
                ),
              ),
              if (!isCurrent) const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }


}