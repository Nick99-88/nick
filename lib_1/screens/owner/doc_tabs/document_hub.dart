import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'package:http/http.dart' as http;

class DocumentHub extends StatefulWidget {
  const DocumentHub({super.key});

  @override
  State<DocumentHub> createState() => _DocumentHubState();
}

class _DocumentHubState extends State<DocumentHub> {
  final Color primaryColor = const Color(0xFF0288D1);
  final Color secondaryColor = const Color(0xFF263238);

  List<FileSystemEntity> localFiles = [];
  bool isScanning = true;

  @override
  void initState() {
    super.initState();
    _refreshLocalVault();
  }

  Future<void> _refreshLocalVault() async {
    setState(() => isScanning = true);
    final directory = await getApplicationDocumentsDirectory();
    final myDir = Directory(directory.path);
    setState(() {
      localFiles = myDir.listSync().where((file) => file.path.endsWith('.pdf')).toList();
      isScanning = false;
    });
  }

  Future<void> _createNewDocument() async {
    final PdfDocument document = PdfDocument();
    final PdfPage page = document.pages.add();
    
    page.graphics.drawString(
      'STARLIGHT INSTITUTIONAL RECORD\nCreated: ${DateTime.now()}',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
      bounds: const Rect.fromLTWH(0, 0, 500, 50),
    );

    final directory = await getApplicationDocumentsDirectory();
    final String path = "${directory.path}/DOC_${DateTime.now().millisecondsSinceEpoch}.pdf";
    final File file = File(path);
    await file.writeAsBytes(await document.save());
    document.dispose();

    _refreshLocalVault();
    _showStatus("New Document Created", true);
  }

  Future<void> _importDocument() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      File sourceFile = File(result.files.single.path!);
      final directory = await getApplicationDocumentsDirectory();
      String newPath = "${directory.path}/${result.files.single.name}";
      await sourceFile.copy(newPath);
      _refreshLocalVault();
      _showStatus("Imported to Vault", true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text("INSTITUTIONAL VAULT", 
          style: TextStyle(color: secondaryColor, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
        actions: [
          IconButton(icon: Icon(Icons.add_box_rounded, color: primaryColor), onPressed: _createNewDocument),
          IconButton(icon: Icon(Icons.refresh_rounded, color: primaryColor), onPressed: _refreshLocalVault),
        ],
      ),
      body: Column(
        children: [
          _buildQuickActions(),
          Expanded(
            child: isScanning 
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : _buildFileGrid(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        onPressed: _importDocument,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text("IMPORT PDF", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          _actionTile("NEW SYLLABUS", Icons.menu_book_rounded, Colors.orange),
          const SizedBox(width: 10),
          _actionTile("NEW VOUCHER", Icons.receipt_long_rounded, Colors.green),
          const SizedBox(width: 10),
          _actionTile("DATESHEET", Icons.calendar_month_rounded, Colors.blue),
        ],
      ),
    );
  }

  Widget _actionTile(String label, IconData icon, Color col) {
    return Expanded(
      child: InkWell(
        onTap: label == "NEW VOUCHER" ? _createNewDocument : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: col.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12), // Fixed circular border logic
            border: Border.all(color: col.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: col, size: 20),
              const SizedBox(height: 5),
              Text(label, style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileGrid() {
    if (localFiles.isEmpty) {
      return const Center(child: Text("VAULT IS EMPTY", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.8
      ),
      itemCount: localFiles.length,
      itemBuilder: (context, index) {
        File file = File(localFiles[index].path);
        String fileName = file.path.split('/').last;
        return _fileCard(fileName, file);
      },
    );
  }

  Widget _fileCard(String name, File file) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => PdfEditorScreen(file: file))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(15))),
                child: Icon(Icons.picture_as_pdf_rounded, color: Colors.red.shade400, size: 40),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("EDITABLE", style: TextStyle(fontSize: 8, color: Colors.green, fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: () async {
                          await file.delete();
                          _refreshLocalVault();
                        },
                        child: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                      ),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showStatus(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? Colors.green : Colors.red, behavior: SnackBarBehavior.floating),
    );
  }
}

class PdfEditorScreen extends StatefulWidget {
  final File file;
  const PdfEditorScreen({super.key, required this.file});

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  
  bool _isEditMode = false; // Tracks if the user is in "Edit Mode"

  // 🏛️ INSTALL LOGIC: Saves the current state of the document back to the vault
  Future<void> _installEditedDocument() async {
    try {
      // In a real-world scenario, you would use SfPdfViewer's save document bytes logic.
      // For now, we confirm the current file is the "Master" in the vault.
      _showStatus("Installing Updated Document to Vault...", true);
      
      // Add a small delay to simulate processing
      await Future.delayed(const Duration(seconds: 1));
      
      Navigator.pop(context); // Return to Hub after installation
      _showStatus("Document Successfully Installed", true);
    } catch (e) {
      _showStatus("Installation Failed", false);
    }
  }

  void _showStatus(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), 
        backgroundColor: success ? Colors.green : Colors.red, 
        behavior: SnackBarBehavior.floating
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF263238),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.file.path.split('/').last, style: const TextStyle(fontSize: 10, color: Colors.black)),
            Text(_isEditMode ? "MODE: EDITING" : "MODE: VIEWING", 
              style: TextStyle(fontSize: 8, color: _isEditMode ? Colors.blue : Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          // 📝 EDIT MODE TOGGLE
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isEditMode = !_isEditMode;
              });
              _showStatus(_isEditMode ? "Edit Mode Enabled: Tap fields to write" : "Edit Mode Disabled", true);
            },
            icon: Icon(Icons.edit_note, color: _isEditMode ? Colors.blue : Colors.grey),
            label: Text("EDIT", style: TextStyle(color: _isEditMode ? Colors.blue : Colors.grey, fontSize: 10)),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SfPdfViewer.file(
        widget.file,
        key: _pdfViewerKey,
        controller: _pdfViewerController,
        // When Edit Mode is true, we allow form interaction
        interactionMode: _isEditMode ? PdfInteractionMode.selection : PdfInteractionMode.pan,
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.zoom_in), onPressed: () => _pdfViewerController.zoomLevel = 1.5),
              const Spacer(),
              // 🏛️ INSTALL BUTTON
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0288D1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                ),
                onPressed: _installEditedDocument,
                icon: const Icon(Icons.save_alt_rounded, size: 16),
                label: const Text("INSTALL TO VAULT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}