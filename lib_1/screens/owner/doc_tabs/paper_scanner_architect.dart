import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

// --- DATA MODEL ---
class ScannedQuestion {
  final String id;
  final String type; // 'mcq', 'short', 'long'
  final String text;
  bool isSelected;

  ScannedQuestion({
    required this.id,
    required this.type,
    required this.text,
    this.isSelected = true,
  });
}

class PaperScannerArchitect extends StatefulWidget {
  const PaperScannerArchitect({super.key});

  @override
  State<PaperScannerArchitect> createState() => _PaperScannerArchitectState();
}

class _PaperScannerArchitectState extends State<PaperScannerArchitect> {
  // --- STATE ---
  File? selectedFile;
  bool isScanning = false;
  String currentFilter = 'all'; // 'all', 'mcq', 'short', 'long'
  List<ScannedQuestion> extractedQuestions = [];

  // --- LOGIC: FILE INGESTION & AI EXTRACTION ---
  Future<void> _pickAndScan() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'pdf'],
    );

    if (result != null) {
      setState(() {
        selectedFile = File(result.files.single.path!);
        isScanning = true;
        extractedQuestions = [];
      });

      // Simulated AI Extraction (Matching your HTML logic)
      await Future.delayed(const Duration(seconds: 3));

      setState(() {
        isScanning = false;
        extractedQuestions = [
          ScannedQuestion(id: '1', type: 'mcq', text: "What is the capital of Pakistan?"),
          ScannedQuestion(id: '2', type: 'mcq', text: "Which planet is known as the Red Planet?"),
          ScannedQuestion(id: '3', type: 'short', text: "Define the term 'Inertia' in physics."),
          ScannedQuestion(id: '4', type: 'short', text: "Explain the importance of DNA replication."),
          ScannedQuestion(id: '5', type: 'long', text: "Discuss the socio-economic impacts of the Industrial Revolution in detail."),
        ];
      });
      _showSignBox("AI Extraction Complete: ${extractedQuestions.length} Questions Found", true);
    }
  }

  void _showSignBox(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  List<ScannedQuestion> get filteredQuestions {
    if (currentFilter == 'all') return extractedQuestions;
    return extractedQuestions.where((q) => q.type == currentFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("AI PAPER SCANNER", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
        backgroundColor: const Color(0xFF1A237E), // Primary Institutional Blue
        elevation: 4,
      ),
      body: Column(
        children: [
          if (selectedFile == null) _buildUploadTerminal(),
          if (selectedFile != null) ...[
            _buildFilterBar(),
            Expanded(child: isScanning ? _buildScannerLoader() : _buildResultsList()),
          ],
          if (extractedQuestions.isNotEmpty) _buildActionFooter(),
        ],
      ),
    );
  }

  // --- COMPONENT: UPLOAD TERMINAL ---
  Widget _buildUploadTerminal() {
    return Expanded(
      child: Center(
        child: InkWell(
          onTap: _pickAndScan,
          child: Container(
            margin: const EdgeInsets.all(40),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.black12, style: BorderStyle.solid),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_upload_outlined, size: 80, color: Color(0xFF1A237E)),
                const SizedBox(height: 20),
                const Text("UPLOAD EXAM PAPER", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const Text("Select JPG, PNG or PDF to extract questions", style: TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- COMPONENT: SCANNER LOADER ---
  Widget _buildScannerLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFF1A237E)),
          const SizedBox(height: 20),
          Text("AI ENGINE: SEGMENTING QUESTIONS...", style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // --- COMPONENT: FILTER BAR ---
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _filterBtn("ALL", 'all'),
          _filterBtn("MCQS", 'mcq'),
          _filterBtn("SHORT", 'short'),
          _filterBtn("LONG", 'long'),
        ],
      ),
    );
  }

  Widget _filterBtn(String label, String filter) {
    bool active = currentFilter == filter;
    return InkWell(
      onTap: () => setState(() => currentFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1A237E) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.black54, fontWeight: FontWeight.bold, fontSize: 10)),
      ),
    );
  }

  // --- COMPONENT: RESULTS LIST ---
  Widget _buildResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filteredQuestions.length,
      itemBuilder: (context, index) {
        final q = filteredQuestions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.black12)),
          child: CheckboxListTile(
            value: q.isSelected,
            onChanged: (v) => setState(() => q.isSelected = v!),
            activeColor: const Color(0xFF1A237E),
            title: Text(q.text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            subtitle: Text(q.type.toUpperCase(), style: TextStyle(color: _getTypeColor(q.type), fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  Color _getTypeColor(String type) {
    if (type == 'mcq') return Colors.blue;
    if (type == 'short') return Colors.orange;
    return Colors.red;
  }

  // --- COMPONENT: ACTION FOOTER ---
  Widget _buildActionFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => setState(() {
                selectedFile = null;
                extractedQuestions = [];
              }),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black, minimumSize: const Size(0, 55)),
              child: const Text("RESET", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => _showSignBox("Selected Questions Saved to Vault", true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), minimumSize: const Size(0, 55)),
              child: const Text("SAVE TO VAULT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}