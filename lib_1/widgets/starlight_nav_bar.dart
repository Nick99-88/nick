import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';

enum NavBarRole {
  owner,
  institutional,
  teacher,
  student,
  institutional_student,
  staff,
  social,
}

class StarlightNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabChange;
  final NavBarRole role;

  const StarlightNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabChange,
    this.role = NavBarRole.owner,
  });

  List<GButton> _getTabsForRole() {
    switch (role) {
      case NavBarRole.institutional:
        return [
          GButton(icon: Icons.dashboard, text: tr('navDashboard')),
          GButton(icon: Icons.analytics, text: tr('navState')),
          GButton(icon: Icons.account_balance, text: tr('navFinance')),
          GButton(icon: Icons.people, text: tr('navPeople')),
          GButton(icon: Icons.description, text: tr('navDocuments')),
          GButton(icon: Icons.chat, text: tr('navChat')),
        ];
      case NavBarRole.teacher:
        return [
          GButton(icon: Icons.grid_view_rounded, text: tr('navConsole')),
          GButton(icon: Icons.history_edu_rounded, text: tr('navPapers')),
          GButton(icon: Icons.chat_bubble_outline_rounded, text: tr('navChat')),
          GButton(icon: Icons.person_outline_rounded, text: tr('navProfile')),
        ];
      case NavBarRole.student:
        return [
          GButton(icon: Icons.home_rounded, text: tr('navHub')),
          GButton(icon: Icons.explore_rounded, text: tr('navExplore')),
          GButton(icon: Icons.account_balance_wallet_rounded, text: tr('navWallet')),
          GButton(icon: Icons.face_rounded, text: tr('navProfile')),
        ];
      case NavBarRole.institutional_student:
        return [
          GButton(icon: Icons.dashboard_rounded, text: tr('navDashboard')),
          GButton(icon: Icons.hub_rounded, text: tr('navHub')),
          GButton(icon: Icons.folder_rounded, text: tr('navDocs')),
          GButton(icon: Icons.person_rounded, text: tr('navProfile')),
        ];
      case NavBarRole.staff:
        return [
          GButton(icon: Icons.hub_rounded, text: tr('navHub')),
          GButton(icon: Icons.view_headline, text: tr('navPanel')),
          GButton(icon: Icons.person_rounded, text: tr('navProfile')),
        ];
      case NavBarRole.social:
        return [
          GButton(icon: Icons.explore_outlined, text: tr('navExplore')),
          GButton(icon: Icons.mail_outline_rounded, text: tr('navInbox')),
          GButton(icon: Icons.auto_awesome, text: tr('navAiChat')),
          GButton(icon: Icons.inventory_2_outlined, text: tr('navVault')),
          GButton(icon: Icons.dashboard_outlined, text: tr('navDashboard')),
        ];
      case NavBarRole.owner:
      default:
        return [
          GButton(icon: Icons.dashboard_customize_rounded, text: tr('navConsole')),
          GButton(icon: Icons.group_add_rounded, text: tr('navHub')),
          GButton(icon: Icons.qr_code_scanner_rounded, text: tr('navQrPortal')),
          GButton(icon: Icons.analytics_rounded, text: tr('navAnalytics')),
          GButton(icon: Icons.description_rounded, text: tr('navDocuments')),
          GButton(icon: Icons.person_rounded, text: tr('navProfile')),
        ];
    }
  }

  void _handleTabChange(int index) {
    // Haptic feedback (vibration)
    HapticFeedback.lightImpact();
    onTabChange(index);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
          child: GNav(
            selectedIndex: selectedIndex,
            onTabChange: _handleTabChange,
            gap: 4,
            activeColor: StarlightTheme.primaryBlue,
            iconSize: 20,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            tabBackgroundColor: StarlightTheme.primaryBlue.withOpacity(0.08),
            color: Colors.black45,
            duration: const Duration(milliseconds: 300),
            textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: StarlightTheme.primaryBlue
            ),
            tabs: _getTabsForRole(),
          ),
        ),
      ),
    );
  }
}