import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../services/platform_api_service.dart';

class WebsiteCreatorScreen extends StatefulWidget {
  const WebsiteCreatorScreen({super.key});

  @override
  State<WebsiteCreatorScreen> createState() => _WebsiteCreatorScreenState();
}

class _WebsiteCreatorScreenState extends State<WebsiteCreatorScreen> {
  final _api = PlatformApiService();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();

  String _framework = 'html';
  bool _isCreating = false;
  final List<Map<String, String>> _files = [];

  static const _frameworks = ['html', 'react', 'flutter'];
  static const _entryFiles = {
    'html': 'index.html',
    'react': 'main.jsx',
    'flutter': 'main.dart',
  };

  String get _defaultEntry => _entryFiles[_framework]!;

  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty && _files.isNotEmpty && !_isCreating;

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || !mounted) return;

    final newFiles = <Map<String, String>>[];
    for (final f in result.files) {
      if (f.path == null) continue;
      final content = await File(f.path!).readAsString();
      newFiles.add({'path': f.name, 'content': content});
    }

    setState(() => _files.addAll(newFiles));
  }

  void _addEntryFile() {
    final entry = _defaultEntry;
    if (_files.any((f) => f['path'] == entry)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$entry already added')),
      );
      return;
    }
    final template = _templateFor(_framework, entry);
    setState(() => _files.add({'path': entry, 'content': template}));
  }

  String _templateFor(String framework, String entry) {
    switch (framework) {
      case 'html':
        return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Starlight App</title>
</head>
<body>
  <h1>Hello from Starlight!</h1>
</body>
</html>''';
      case 'react':
        return '''import React from 'react';

function App() {
  return <h1>Hello from Starlight React!</h1>;
}

export default App;''';
      case 'flutter':
        return '''import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Hello from Starlight Flutter!')),
      ),
    );
  }
}''';
      default:
        return '';
    }
  }

  void _removeFile(int index) {
    setState(() => _files.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isCreating = true);

    try {
      final name = _nameController.text.trim().toLowerCase().replaceAll(' ', '-');
      final title = _titleController.text.trim().isEmpty ? name : _titleController.text.trim();

      await _api.createWebsite(
        name: name,
        title: title,
        framework: _framework,
        files: _files,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Website created: starlight.project.$name.html')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Create Website'),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Framework', [
              DropdownButtonFormField<String>(
                value: _framework,
                dropdownColor: const Color(0xFF21262D),
                items: _frameworks.map((f) => DropdownMenuItem(
                  value: f,
                  child: Text(f.toUpperCase(), style: const TextStyle(color: Colors.white)),
                )).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _framework = v);
                },
                decoration: _inputDecoration(),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Website Name', [
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(hint: 'my-project'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Text(
                'URL: starlight.project.${_nameController.text.trim().isNotEmpty ? _nameController.text.trim().toLowerCase().replaceAll(' ', '-') : 'name'}.html',
                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Title (optional)', [
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(hint: 'My Awesome Project'),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSection('Source Files', [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFiles,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Pick from Phone'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF58A6FF),
                        side: BorderSide(color: const Color(0xFF58A6FF).withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addEntryFile,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('Add $_defaultEntry'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2EA043),
                        side: BorderSide(color: const Color(0xFF2EA043).withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_files.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: const Text(
                    'No files selected',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF484F58)),
                  ),
                )
              else
                ...List.generate(_files.length, (i) {
                  final f = _files[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF21262D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.insert_drive_file, size: 16,
                            color: const Color(0xFF58A6FF)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f['path'] ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _removeFile(i),
                          child: const Icon(Icons.close, size: 16, color: Color(0xFFDA3633)),
                        ),
                      ],
                    ),
                  );
                }),
            ]),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _canSubmit ? _submit : null,
                icon: _isCreating
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload, size: 20),
                label: Text(_isCreating ? 'Creating...' : 'Deploy Website'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF21262D),
                  disabledForegroundColor: const Color(0xFF484F58),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF484F58)),
      filled: true,
      fillColor: const Color(0xFF21262D),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: const Color(0xFF30363D)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: const Color(0xFF30363D)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF58A6FF)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }
}
