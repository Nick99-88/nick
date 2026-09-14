import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../core/theme.dart';
import '../../qr_portal/qr_portal_screen.dart';
import '../owner/HubDashboard.dart';
import 'staff_profile_screen.dart';
import 'staff_dashboard.dart';
import 'staff_panel_screen.dart';

class StaffMainScreen extends StatefulWidget {
  const StaffMainScreen({super.key});

  @override
  State<StaffMainScreen> createState() => _StaffMainScreenState();
}

class _StaffMainScreenState extends State<StaffMainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const StaffDashboard(),
    const QRPortalScreen(),
    const HubDashboard(),
    const StaffPanelScreen(),
    const StaffProfileScreen(),
  ];

  final List<String> _titles = [
    "STAFF DASHBOARD",
    "QR PORTAL",
    "HUB",
    "ACCESS PANEL",
    "PROFILE",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedIndex >= _screens.length) {
        setState(() => _selectedIndex = 0);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: GNav(
            selectedIndex: _selectedIndex,
            onTabChange: (index) => setState(() => _selectedIndex = index),
            gap: 4,
            activeColor: StarlightTheme.primaryBlue,
            iconSize: 20,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tabBackgroundColor: StarlightTheme.primaryBlue.withOpacity(0.08),
            color: Colors.black45,
            duration: const Duration(milliseconds: 300),
            textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue),
            tabs: const [
              GButton(icon: Icons.dashboard, text: 'Dashboard'),
              GButton(icon: Icons.qr_code, text: 'QR Portal'),
              GButton(icon: Icons.hub, text: 'Hub'),
              GButton(icon: Icons.view_headline, text: 'Panel'),
              GButton(icon: Icons.person, text: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}
