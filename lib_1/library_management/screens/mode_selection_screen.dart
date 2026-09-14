import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sqlite_service.dart';
import 'field_setup_screen.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_library, size: 90, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Library Management', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Starting in offline mode...', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _start(context),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16)),
            ),
          ],
        ),
      ),
    );
  }

  void _start(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_mode');
    await prefs.remove('jwt_token');
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => FieldSetupScreen(service: SqliteService())),
    );
  }
}
