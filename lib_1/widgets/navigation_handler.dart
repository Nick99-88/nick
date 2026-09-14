// navigation_handler.dart
import 'package:flutter/material.dart';
import '../screens/owner/owner_console_screen.dart';
import '../screens/owner/HubDashboard.dart';
import '../screens/owner/profile_screen.dart';
import '../screens/owner/document_vault_screen.dart';
import '../qr_portal/qr_portal_screen.dart';
import '../screens/hub/wallet_screen.dart';
import '../screens/owner/analytics/analytics_screen.dart';

class NavigationHandler extends StatelessWidget {
  final int selectedIndex;

  const NavigationHandler({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    // 🏛️ The list of screens is defined once.
    // We use OwnerConsoleScreen here to break the loop with OwnerDashboard (Shell).
    final List<Widget> screens = [
      const OwnerConsoleScreen(),  // Index 0: Console
      const HubDashboard(),        // Index 1: Hub
      const QRPortalScreen(),      // Index 2: QR Portal
      const AnalyticsScreen(),
      const DocumentVaultScreen(), // Index 4: Documents
      const ProfileScreen(),       // Index 5: Profile
      const WalletScreen(),         // Index 6: Wallet
    ];

    return IndexedStack(
      index: selectedIndex,
      children: screens,
    );
  }
}