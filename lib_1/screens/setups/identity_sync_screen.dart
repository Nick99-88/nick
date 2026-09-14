import 'package:flutter/material.dart';
import '../../core/storage.dart';
import '../../services/auth/auth_service.dart';

class IdentitySyncScreen extends StatefulWidget {
  const IdentitySyncScreen({super.key});

  @override
  State<IdentitySyncScreen> createState() => _IdentitySyncScreenState();
}

class _IdentitySyncScreenState extends State<IdentitySyncScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _performSync();
  }

  Future<void> _performSync() async {
    try {
      final token = await StarlightStorage.getUserToken();
      // Hardcoded or fetched Device ID for now
      final deviceId = "TEMP_HARDWARE_ID_123";

      final result = await _authService.syncIdentity(token: token!, deviceId: deviceId);

      final state = result['user_state'];
      final bool hasRole = state['has_role'];
      final bool hasIdentity = state['has_identity'];
      final String role = state['role'];

      if (!mounted) return;

      // 🏛️ NAVIGATION LOGIC (The Filter)
      if (!hasRole) {
        // Step 1: No Role? Go to Selection
        Navigator.pushReplacementNamed(context, '/role-selection');
      }
      else if (role == "owner" && !hasIdentity) {
        // Step 2: Owner but no Identity? Go to Setup
        Navigator.pushReplacementNamed(context, '/owner-setup');
      }
      else {
        // Step 3: Fully Solidified? Go to Dashboard
        Navigator.pushReplacementNamed(context, '/dashboard');
      }

    } catch (e) {
      // If sync fails, force back to login
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 20),
            Text("Syncing Identity...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}