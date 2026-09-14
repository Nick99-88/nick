// main_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:starlight_flutter/widgets/starlight_nav_bar.dart';
import 'package:starlight_flutter/widgets/navigation_handler.dart';

class MainEntryScreen extends StatefulWidget {
  const MainEntryScreen({super.key});

  @override
  State<MainEntryScreen> createState() => _MainEntryScreenState();
}

class _MainEntryScreenState extends State<MainEntryScreen> {
  int _selectedIndex = 1; // 🏛️ Default to hub section (index 1) for owner entry

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 🏛️ This calls the handler (the screens)
      body: NavigationHandler(selectedIndex: _selectedIndex),

      // 🏛️ This calls the bar (the controls)
      bottomNavigationBar: StarlightNavBar(
        selectedIndex: _selectedIndex,
        onTabChange: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        role: NavBarRole.owner,
      ),
    );
  }
}