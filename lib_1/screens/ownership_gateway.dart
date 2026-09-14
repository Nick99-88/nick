import 'package:flutter/material.dart';
import 'package:starlight_flutter/core/router_gateway.dart';
import '../../core/storage.dart';
import '../../services/institution/institution_service.dart';
import '../core/theme.dart';
import '../core/app_routes.dart';

class OwnershipGateway extends StatefulWidget {
  const OwnershipGateway({super.key});

  @override
  State<OwnershipGateway> createState() => _OwnershipGatewayState();
}

class _OwnershipGatewayState extends State<OwnershipGateway> {
  final InstitutionService _instService = InstitutionService();

  @override
  void initState() {
    super.initState();
    _checkOwnership();
  }

  Future<void> _checkOwnership() async {
    try {
      final result = await _instService.checkOwnership();
      final status = result['status'];

      if (!mounted) return;

      if (status == "verified") {
        // 🏛️ Step 4: Fully Verified -> Move to Dashboard
        await StarlightStorage.setOwnerVerifyToken("OWNERSHIP_VERIFIED");
        await UniversalRouter.routeUser(context);
      }
      else if (status == "unlinked") {
        // 🏛️ Step 2/3 Check: Check if user has Identity before Institution
        final hasIdentity = await StarlightStorage.getIdentity();

        if (hasIdentity != true) {
          // If no identity, must create it first
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.ownerIdentity, (route) => false);
        } else {
          // Has identity but no institution -> Move to Create Institution
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.institutionSetup, (route) => false);
        }
      }
      else if (status == "pending") {
        // Stay on this gateway or show pending verification message
        // Usually, the router would handle this by seeing the lack of VerifyToken
        debugPrint("🏛️ Ownership: Pending manual verification by Starlight.");
      }

    } catch (e) {
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, AppRoutes.roleSelection, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: StarlightTheme.primaryBlue),
            SizedBox(height: 20),
            Text("Verifying Institutional Access...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}