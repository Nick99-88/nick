import 'package:flutter/material.dart';
// Importing our spreadsheet interface module safely
import 'main_screen.dart';

void main() {
  runApp(const StarlightEditorApp());
}

class StarlightEditorApp extends StatelessWidget {
  const StarlightEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Starlight Sheet Editor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // FIXED: Points accurately to the SpreadsheetEditorScreen layout on load
      home: const SpreadsheetEditorScreen(),
    );
  }
}