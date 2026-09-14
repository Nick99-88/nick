import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/storage.dart';
import '../../../core/theme.dart';

class DocumentScannerScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const DocumentScannerScreen({super.key, this.initialData});

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen> {
  final String apiBase = "https://api.institution.site";
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  
  String? currentDocumentId; // 🏛️ ADDED: Stores the existing document's ID for editing/updates!

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final data = widget.initialData!;
      currentDocumentId = data['id']?.toString(); // Capture the document's ID
      _titleController.text = data['title'] ?? data['name'] ?? '';
      _contentController.text = data['rawText'] ?? data['content']?.toString() ?? '';
      fileName = data['original_file'] ?? "Scanned_Receipt.png";
      
      final sections = data['content'];
      if (sections is List) {
        scannedDocument['sections'] = sections;
      }
    }
  }
  
  File? selectedFile;
  String fileName = "No file selected";
  bool isScanning = false;
  bool isSaving = false;
  String? scanError;
  
  // Document content structure
  Map<String, dynamic> scannedDocument = {
    'title': '',
    'content': '',
    'metadata': {},
    'sections': [],
    'tables': [],
    'images': [],
  };
  
  // Editor state
  bool isEditMode = true;
  String selectedFont = 'Arial';
  double fontSize = 14.0;
  bool isBold = false;
  bool isItalic = false;
  bool isUnderline = false;
  Color textColor = Colors.black;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85, // Balance size and quality for fast OCR transmission
      );
      if (image != null) {
        setState(() {
          selectedFile = File(image.path);
          fileName = image.name;
          scanError = null;
        });
      }
    } catch (e) {
      _showMessage("Error picking image: $e", false);
    }
  }

  Future<void> _pickDocumentFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'txt'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          selectedFile = File(result.files.single.path!);
          fileName = result.files.single.name;
          scanError = null;
        });
      }
    } catch (e) {
      _showMessage("Error picking file: $e", false);
    }
  }

  Future<void> pickFile() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Select Source",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: StarlightTheme.primaryBlue),
              title: const Text("Take Photo (Camera)"),
              subtitle: const Text("Scan physical paper documents instantly"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.teal),
              title: const Text("Photo Gallery"),
              subtitle: const Text("Choose a document screenshot or picture"),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded, color: Colors.indigo),
              title: const Text("Browse Local Files"),
              subtitle: const Text("Select PDFs or other doc types"),
              onTap: () {
                Navigator.pop(context);
                _pickDocumentFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> scanDocument() async {
    if (selectedFile == null) {
      _showMessage("Please select a file first", false);
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      _showMessage("Please enter a document title first", false);
      return;
    }

    setState(() {
      isScanning = true;
      scanError = null;
    });

    try {
      final token = await StarlightStorage.getUserToken();
      final fileBytes = await selectedFile!.readAsBytes();
      final base64Image = base64Encode(fileBytes);

      final payload = {
        "title": _titleController.text.trim(),
        "font_family": selectedFont,
        "imageData": base64Image,
      };

      final response = await http.post(
        Uri.parse('$apiBase/document-scanner/scan-text'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _contentController.text = data['text'] ?? '';
          isScanning = false;
        });
        _showMessage("Document scanned and digitized with Gemini successfully!", true);
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          scanError = data['detail'] ?? 'OCR Digitization failed';
          isScanning = false;
        });
      }
    } catch (e) {
      setState(() {
        scanError = "OCR Engine error: $e";
        isScanning = false;
      });
    }
  }

  Future<void> saveDocument() async {
    if (_titleController.text.trim().isEmpty) {
      _showMessage("Please enter a title", false);
      return;
    }

    setState(() => isSaving = true);

    try {
      final token = await StarlightStorage.getUserToken();
      
      final payload = {
        if (currentDocumentId != null) 'id': currentDocumentId, // 🏛️ ADDED: Directs the server to UPDATE the existing document!
        'name': _titleController.text.trim(),
        'subject': "Scanned (Font: $selectedFont)",
        'targets': ["All"],
        'date': "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
        'content': [
          {'name': 'Extracted OCR Text', 'text': _contentController.text}
        ],
        'is_final': true,
      };

      final res = await http.post(
        Uri.parse('$apiBase/document/vault/upload'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        _showMessage("Document saved to Vault successfully!", true);
        Navigator.pop(context, true);
      } else {
        _showMessage("Server error: ${res.statusCode}", false);
      }
    } catch (e) {
      _showMessage("Network error: $e", false);
    } finally {
      setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("DOCUMENT SCANNER",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: StarlightTheme.primaryBlue,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: StarlightTheme.primaryBlue),
            onPressed: isSaving ? null : saveDocument,
            tooltip: "Save Document",
          ),
        ],
      ),
      body: Column(
        children: [
          // File Selection Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select Document", style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                )),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.description, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                fileName,
                                style: TextStyle(
                                  color: selectedFile != null ? Colors.black : Colors.grey,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: pickFile,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text("Browse"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StarlightTheme.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: isScanning ? null : scanDocument,
                      icon: isScanning 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.scanner, size: 18),
                      label: Text(isScanning ? "Scanning..." : "Scan"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (scanError != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            scanError!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Editor Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Font family dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButton<String>(
                      value: selectedFont,
                      underline: const SizedBox(),
                      items: ['Arial', 'Times New Roman', 'Calibri', 'Verdana', 'Georgia']
                          .map((font) => DropdownMenuItem(value: font, child: Text(font)))
                          .toList(),
                      onChanged: (value) => setState(() => selectedFont = value!),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Font size
                  Container(
                    width: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: TextField(
                      controller: TextEditingController(text: fontSize.toInt().toString()),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(border: InputBorder.none),
                      keyboardType: TextInputType.number,
                      onSubmitted: (value) => setState(() => fontSize = double.tryParse(value) ?? 14.0),
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Formatting buttons
                  IconButton(
                    onPressed: () => setState(() => isBold = !isBold),
                    icon: Icon(Icons.format_bold, color: isBold ? StarlightTheme.primaryBlue : Colors.grey),
                    tooltip: "Bold",
                  ),
                  IconButton(
                    onPressed: () => setState(() => isItalic = !isItalic),
                    icon: Icon(Icons.format_italic, color: isItalic ? StarlightTheme.primaryBlue : Colors.grey),
                    tooltip: "Italic",
                  ),
                  IconButton(
                    onPressed: () => setState(() => isUnderline = !isUnderline),
                    icon: Icon(Icons.format_underlined, color: isUnderline ? StarlightTheme.primaryBlue : Colors.grey),
                    tooltip: "Underline",
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Color picker
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: textColor,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: PopupMenuButton<Color>(
                      child: const SizedBox(),
                      itemBuilder: (context) => [
                        PopupMenuItem(value: Colors.black, child: Container(color: Colors.black, height: 20)),
                        PopupMenuItem(value: Colors.red, child: Container(color: Colors.red, height: 20)),
                        PopupMenuItem(value: Colors.blue, child: Container(color: Colors.blue, height: 20)),
                        PopupMenuItem(value: Colors.green, child: Container(color: Colors.green, height: 20)),
                      ],
                      onSelected: (color) => setState(() => textColor = color),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Document Editor
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Title field
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _titleController,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: selectedFont,
                      ),
                      decoration: const InputDecoration(
                        hintText: "Document Title",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  
                  // Content editor
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _contentController,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontFamily: selectedFont,
                          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                          decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
                          color: textColor,
                          height: 1.5,
                        ),
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          hintText: "Start typing your document content here...",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
