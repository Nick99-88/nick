import 'package:flutter/material.dart';
import 'package:starlight_flutter/widgets/starlight_nav_bar.dart';
import '../../widgets/navigation_handler.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 🏛️ The Material widget here provides the 'canvas' for all sub-screens
      body: Material(
        type: MaterialType.transparency,
        child: NavigationHandler(selectedIndex: _selectedIndex),
      ),
      bottomNavigationBar: StarlightNavBar(
        selectedIndex: _selectedIndex,
        onTabChange: (index) {
          setState(() => _selectedIndex = index);
        },
        role: NavBarRole.owner,
      ),
    );
  }
}