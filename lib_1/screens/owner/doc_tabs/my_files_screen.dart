import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants.dart';
import '../../../core/storage.dart';
import '../../../core/theme.dart';
import '../../../services/institution/document_service.dart';
import '../../hub/share_picker_screen.dart';
import 'draw_design_screen.dart';
import 'vault_item_browser_screen.dart';

class MyFilesScreen extends StatefulWidget {
  final bool studentMode;
  const MyFilesScreen({super.key, this.studentMode = false});

  @override
  State<MyFilesScreen> createState() => _MyFilesScreenState();
}

class _MyFilesScreenState extends State<MyFilesScreen> {
  final String apiBase = "https://api.institution.site";
  List<Map<String, dynamic>> files = [];
  bool isLoading = false;
  String? error;
  String searchQuery = '';
  String selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    fetchFiles();
  }

  Future<void> fetchFiles() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    if (widget.studentMode) {
      try {
        final token = await StarlightStorage.getUserToken();
        final response = await http.get(
          Uri.parse('${StarlightConstants.apiBaseUrl}/document/student-files'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final rawFiles = data['files'] as List? ?? [];
          if (mounted) {
            setState(() {
              files = rawFiles.map((f) {
                final cat = f['category'] ?? f['subject'] ?? 'General';
                return {
                  'id': f['id'],
                  'name': f['name'] ?? 'Untitled',
                  'type': 'Doc',
                  'size': '',
                  'category': cat.toString(),
                  'uploadedDate': f['created_at']?.toString()?.substring(0, 10) ?? '',
                  'icon': _categoryIcon(cat.toString()),
                  'color': _categoryColor(cat.toString()),
                  'source': f['source'] ?? '',
                  'details': f['details'],
                  'content': f['content'],
                  'sender_name': f['sender_name'],
                };
              }).toList();
              isLoading = false;
            });
          }
        } else {
          if (mounted) setState(() { files = []; isLoading = false; });
        }
      } catch (_) {
        if (mounted) setState(() { files = []; isLoading = false; });
      }
      return;
    }

    // Statically define the 8 Master Document Vault Tiles permanently
    setState(() {
      files = [
        {
          'id': 1,
          'name': 'Syllabus',
          'type': 'PDF',
          'size': '2.4 MB',
          'category': 'Syllabus',
          'uploadedDate': '2024-01-15',
          'icon': Icons.menu_book_rounded,
          'color': Colors.blue.shade700,
        },
        {
          'id': 2,
          'name': 'DateSheets',
          'type': 'PDF',
          'size': '1.2 MB',
          'category': 'DateSheets',
          'uploadedDate': '2024-01-12',
          'icon': Icons.calendar_month_rounded,
          'color': Colors.indigo.shade700,
        },
        {
          'id': 3,
          'name': 'Fee Vouchers Data',
          'type': 'Excel',
          'size': '450 KB',
          'category': 'Fees',
          'uploadedDate': '2024-01-10',
          'icon': Icons.receipt_long_rounded,
          'color': Colors.green.shade700,
        },
        {
          'id': 4,
          'name': 'Scanned Documents',
          'type': 'Image',
          'size': '1.8 MB',
          'category': 'Scanned',
          'uploadedDate': '2024-01-08',
          'icon': Icons.document_scanner_rounded,
          'color': Colors.teal.shade700,
        },
        {
          'id': 5,
          'name': 'MarkSheets and Tests',
          'type': 'PDF',
          'size': '3.2 MB',
          'category': 'Results',
          'uploadedDate': '2024-01-06',
          'icon': Icons.grade_rounded,
          'color': Colors.amber.shade700,
        },
        {
          'id': 6,
          'name': 'Students Attendances and Staff Attendances',
          'type': 'Excel',
          'size': '180 KB',
          'category': 'Attendance',
          'uploadedDate': '2024-01-05',
          'icon': Icons.assignment_turned_in_rounded,
          'color': Colors.lightBlue.shade700,
        },
        {
          'id': 7,
          'name': 'Translated Document',
          'type': 'Word',
          'size': '890 KB',
          'category': 'Translation',
          'uploadedDate': '2024-01-03',
          'icon': Icons.g_translate_rounded,
          'color': Colors.pink.shade700,
        },
        {
          'id': 8,
          'name': 'Uploads',
          'type': 'Folder',
          'size': '8 Items',
          'category': 'General',
          'uploadedDate': '2024-01-01',
          'icon': Icons.folder_copy_rounded,
          'color': Colors.blueGrey.shade700,
        },
      ];
      isLoading = false;
    });
  }

  List<Map<String, dynamic>> get filteredFiles {
    var filtered = files.where((file) {
      final matchesSearch = file['name'].toString().toLowerCase().contains(searchQuery.toLowerCase());
      final matchesCategory = selectedCategory == 'All' || file['category'] == selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
    
    return filtered;
  }

  List<String> get categories {
    final cats = ['All', ...files.map((f) => f['category'] as String).toSet().toList()];
    return cats;
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'syllabus': return Icons.menu_book_rounded;
      case 'datesheet':
      case 'datesheets': return Icons.calendar_month_rounded;
      case 'fees': return Icons.receipt_long_rounded;
      case 'scanned': return Icons.document_scanner_rounded;
      case 'results':
      case 'marksheet': return Icons.grade_rounded;
      case 'attendance': return Icons.assignment_turned_in_rounded;
      case 'translation': return Icons.g_translate_rounded;
      case 'shared': return Icons.share_rounded;
      default: return Icons.description_rounded;
    }
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'syllabus': return Colors.blue.shade700;
      case 'datesheet':
      case 'datesheets': return Colors.indigo.shade700;
      case 'fees': return Colors.green.shade700;
      case 'scanned': return Colors.teal.shade700;
      case 'results':
      case 'marksheet': return Colors.amber.shade700;
      case 'attendance': return Colors.lightBlue.shade700;
      case 'translation': return Colors.pink.shade700;
      case 'shared': return Colors.purple;
      default: return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("MY FILES",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: StarlightTheme.primaryBlue,
        elevation: 0,
        centerTitle: true,
        actions: widget.studentMode
            ? <Widget>[]
            : [
                IconButton(
                  icon: const Icon(Icons.cloud_upload, color: StarlightTheme.primaryBlue),
                  onPressed: () => _showUploadDialog(),
                  tooltip: "Upload File",
                ),
              ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: "Search files...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: StarlightTheme.primaryBlue),
                    ),
                  ),
                  onChanged: (value) => setState(() => searchQuery = value),
                ),
                const SizedBox(height: 12),
                // Category Filter
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = category == selectedCategory;
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => selectedCategory = category);
                          },
                          backgroundColor: Colors.grey.shade200,
                          selectedColor: StarlightTheme.primaryBlue.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: isSelected ? StarlightTheme.primaryBlue : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Files List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(error!, style: TextStyle(color: Colors.grey.shade600)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: fetchFiles,
                              child: const Text("Retry"),
                            ),
                          ],
                        ),
                      )
                    : filteredFiles.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  searchQuery.isEmpty 
                                      ? "No files found"
                                      : "No files match your search",
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredFiles.length,
                            itemBuilder: (context, index) {
                              final file = filteredFiles[index];
                              return _buildFileCard(file);
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: widget.studentMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showUploadDialog(),
              backgroundColor: StarlightTheme.primaryBlue,
              icon: const Icon(Icons.add),
              label: const Text("Upload File"),
            ),
    );
  }

  Widget _buildFileCard(Map<String, dynamic> file) {
    final fileColor = file['color'] as Color;
    bool isPressed = false;
    return StatefulBuilder(
      builder: (context, setCardState) {
        return GestureDetector(
          onTapDown: (_) => setCardState(() => isPressed = true),
          onTapCancel: () => setCardState(() => isPressed = false),
          onTapUp: (_) {
            setCardState(() => isPressed = false);
            if (file.containsKey('bytes')) {
              _showDesignPreviewDialog(file);
            } else if (widget.studentMode) {
              final cat = file['category'] as String? ?? file['name'] as String;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VaultItemBrowserScreen(
                    categoryName: cat,
                    themeColor: fileColor,
                  ),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VaultItemBrowserScreen(
                    categoryName: file['name'] as String,
                    themeColor: fileColor,
                  ),
                ),
              );
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            margin: const EdgeInsets.only(bottom: 20, left: 8, right: 8),
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015) // perspective depth ratio
              ..rotateX(isPressed ? 0.02 : 0.08) // dynamic tilt on press
              ..rotateY(isPressed ? -0.01 : -0.05)
              ..translate(isPressed ? 1.0 : 0.0, isPressed ? 1.0 : -4.0), // push down slightly
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: fileColor.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                // Base shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(-2, 4),
                ),
                // Isometric 3D projection shadow colored by the file's theme color!
                BoxShadow(
                  color: fileColor.withOpacity(0.08),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: isPressed ? const Offset(-2, 4) : const Offset(-8, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Top-right glossy accent line
                Positioned(
                  top: 0,
                  right: 40,
                  child: Container(
                    width: 60,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [fileColor.withOpacity(0.1), fileColor, fileColor.withOpacity(0.1)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      // Floating 3D Icon Block
                      Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..translate(0.0, 0.0, 10.0), // Pop out icon block from the card
                        child: Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [fileColor.withOpacity(0.15), fileColor.withOpacity(0.05)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: fileColor.withOpacity(0.3), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: fileColor.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(-2, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            file['icon'] as IconData,
                            color: fileColor,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Title and Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF263238),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                // 3D LED style category badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: fileColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: fileColor.withOpacity(0.15), width: 1),
                                  ),
                                  child: Text(
                                    file['category'] as String,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: fileColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                 const SizedBox(width: 8),
                                 Expanded(
                                   child: Text(
                                     "${file['type']} • ${file['size']}",
                                     maxLines: 1,
                                     overflow: TextOverflow.ellipsis,
                                     style: TextStyle(
                                       fontSize: 10,
                                       fontWeight: FontWeight.w500,
                                       color: Colors.grey.shade500,
                                     ),
                                   ),
                                 ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Uploaded: ${file['uploadedDate']}",
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Settings Action Dot with elevated color
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Colors.grey.shade400, size: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        itemBuilder: (context) => [
                          if (file.containsKey('bytes'))
                            const PopupMenuItem(
                              value: 'edit_design',
                              child: Row(
                                children: [
                                  Icon(Icons.brush_rounded, color: Colors.indigo, size: 16),
                                  SizedBox(width: 8),
                                  Text('Open in Canvas', style: TextStyle(fontSize: 13, color: Colors.indigo)),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'download',
                            child: Row(
                              children: [
                                Icon(Icons.download_rounded, size: 16, color: Colors.grey),
                                SizedBox(width: 8),
                                Text('Download', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          if (!widget.studentMode) ...[
                            const PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  Icon(Icons.share_rounded, size: 16, color: Colors.grey),
                                  SizedBox(width: 8),
                                  Text('Share', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_rounded, color: Colors.red, size: 16),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ],
                        onSelected: (value) => _handleFileAction(value, file),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSharePicker(Map<String, dynamic> file) async {
    // Load current user as owner
    final token = await StarlightStorage.getUserToken();
    String? ownerName;
    String? ownerId;
    try {
      final res = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        ownerName = data['name'] ?? data['display_name'] ?? 'You';
        ownerId = data['id']?.toString();
      }
    } catch (_) {}

    if (!mounted) return;
    final shared = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SharePickerScreen(
          category: file['category'] ?? 'General',
          title: file['name'] ?? 'Untitled',
          details: file,
          timestamp: DateTime.now().toIso8601String(),
          ownerName: ownerName,
          ownerId: ownerId,
        ),
      ),
    );
    if (shared == true && mounted) {
      _showMessage("Document shared successfully", false);
    }
  }

  void _handleFileAction(String action, Map<String, dynamic> file) {
    switch (action) {
      case 'edit_design':
        _editDesign(file);
        break;
      case 'download':
        _showMessage("Downloading ${file['name']}...", false);
        break;
      case 'share':
        _openSharePicker(file);
        break;
      case 'delete':
        _showDeleteDialog(file);
        break;
    }
  }

  void _showDeleteDialog(Map<String, dynamic> file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete File"),
        content: Text("Are you sure you want to delete '${file['name']}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                files.removeWhere((f) => f['id'] == file['id']);
              });
              _showMessage("File deleted successfully", true);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<void> _drawDesign() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DrawDesignScreen()),
    );

    if (result != null && result is Map<String, dynamic>) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
            child: CircularProgressIndicator(color: StarlightTheme.primaryBlue)),
      );

      try {
        final String newName = result['name'];
        final Uint8List newBytes = result['bytes'];
        final String base64File = base64Encode(newBytes);
        final size = "${(newBytes.length / 1024).toStringAsFixed(1)} KB";

        final newPayload = {
          'name': newName,
          'subject': 'uploads',
          'targets': 'All',
          'content': {
            'base64': base64File,
            'size': size,
            'extension': 'PNG',
          },
        };

        final DocumentService docService = DocumentService();
        await docService.uploadFinalDocument(newPayload);

        if (mounted) {
          Navigator.pop(context); // Pop loading dialog
          _showMessage("Design saved and uploaded to Vault successfully!", true);
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Pop loading dialog
          _showMessage("Failed to upload design to server: $e", false);
        }
      }
    }
  }

  Future<void> _editDesign(Map<String, dynamic> file) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DrawDesignScreen(
          backgroundImageBytes: file['bytes'] as Uint8List,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
            child: CircularProgressIndicator(color: StarlightTheme.primaryBlue)),
      );

      try {
        final String newName = result['name'];
        final Uint8List newBytes = result['bytes'];
        final String base64File = base64Encode(newBytes);
        final size = "${(newBytes.length / 1024).toStringAsFixed(1)} KB";

        final newPayload = {
          'id': file['id'],
          'name': newName,
          'subject': 'uploads',
          'targets': 'All',
          'content': {
            'base64': base64File,
            'size': size,
            'extension': 'PNG',
          },
        };

        final DocumentService docService = DocumentService();
        await docService.uploadFinalDocument(newPayload);

        if (mounted) {
          Navigator.pop(context); // Pop loading dialog
          _showMessage("Design updated on server successfully!", true);
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Pop loading dialog
          _showMessage("Failed to update design on server: $e", false);
        }
      }
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'xls', 'xlsx', 'doc', 'docx'],
      );

      if (result != null && result.files.single.path != null) {
        // Show a beautiful loading modal
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator(color: StarlightTheme.primaryBlue)),
        );

        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        final base64File = base64Encode(bytes);
        final filename = result.files.single.name;
        final extension = filename.split('.').last.toUpperCase();
        final size = "${(bytes.length / 1024).toStringAsFixed(1)} KB";

        final payload = {
          'name': filename,
          'subject': 'uploads', // Stored under category uploads
          'targets': 'All',
          'content': {
            'base64': base64File,
            'size': size,
            'extension': extension,
          },
        };

        final DocumentService docService = DocumentService();
        await docService.uploadFinalDocument(payload);

        if (!mounted) return;
        Navigator.pop(context); // Pop loading indicator
        _showMessage("File '$filename' uploaded successfully!", true);
        fetchFiles(); // Refresh My Files list
      }
    } catch (e) {
      if (mounted) {
        // Safe check to try to pop loading dialog if it remains on top
        try { Navigator.pop(context); } catch (_) {}
        _showMessage("Failed to upload file: $e", false);
      }
    }
  }

  void _showFileUploader() {
    _pickAndUploadFile();
  }

  void _showUploadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New File"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_upload, color: StarlightTheme.primaryBlue),
              title: const Text("Upload Document"),
              subtitle: const Text("PDF, Word, Excel, etc."),
              onTap: () {
                Navigator.pop(context);
                _showFileUploader();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.gesture, color: Colors.teal),
              title: const Text("Draw 2D Design"),
              subtitle: const Text("Create canvas drawing / blueprint"),
              onTap: () {
                Navigator.pop(context);
                _drawDesign();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDesignPreviewDialog(Map<String, dynamic> file) {
    double rotateX = 0.2; // Default starting angles for realistic 3D appearance
    double rotateY = -0.2;
    double perspective = 0.0015;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: const Color(0xFFF8F9FB),
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file['name'] as String,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: StarlightTheme.primaryBlue),
                              ),
                              const SizedBox(height: 2),
                              const Text("Interactive 3D Perspective Viewer", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // 3D Rendering Area (Swipe to Rotate)
                    GestureDetector(
                      onPanUpdate: (details) {
                        setDialogState(() {
                          // Drag up/down rotates X, drag left/right rotates Y
                          rotateX += details.delta.dy * 0.005;
                          rotateY += details.delta.dx * 0.005;
                        });
                      },
                      child: Container(
                        height: 260,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Stack(
                          children: [
                            // Informative Overlay Hint
                            const Positioned(
                              bottom: 12,
                              left: 12,
                              child: Row(
                                children: [
                                  Icon(Icons.swipe, size: 14, color: Colors.grey),
                                  SizedBox(width: 4),
                                  Text("Swipe Card to Rotate in 3D Space", style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            
                            // Core 3D Projection
                            Center(
                              child: Transform(
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, perspective) // 3D Perspective Ratio
                                  ..rotateX(rotateX)
                                  ..rotateY(rotateY),
                                alignment: FractionalOffset.center,
                                child: Container(
                                  width: 180,
                                  height: 180,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: (file['color'] as Color).withOpacity(0.5), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (file['color'] as Color).withOpacity(0.2),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                        offset: const Offset(4, 8),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: Image.memory(
                                      file['bytes'] as Uint8List,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Controls Header
                    const Text("MANUAL 3D CONTROLS",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                    const SizedBox(height: 12),

                    // X-Axis Rotation Slider
                    Row(
                      children: [
                        const Icon(Icons.swap_vert_rounded, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Expanded(
                          flex: 2,
                          child: Text("X-Rotate", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        ),
                        Expanded(
                          flex: 6,
                          child: Slider(
                            value: rotateX,
                            min: -1.5,
                            max: 1.5,
                            activeColor: file['color'] as Color,
                            onChanged: (value) => setDialogState(() => rotateX = value),
                          ),
                        ),
                      ],
                    ),

                    // Y-Axis Rotation Slider
                    Row(
                      children: [
                        const Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Expanded(
                          flex: 2,
                          child: Text("Y-Rotate", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        ),
                        Expanded(
                          flex: 6,
                          child: Slider(
                            value: rotateY,
                            min: -1.5,
                            max: 1.5,
                            activeColor: file['color'] as Color,
                            onChanged: (value) => setDialogState(() => rotateY = value),
                          ),
                        ),
                      ],
                    ),

                    // Perspective Slider
                    Row(
                      children: [
                        const Icon(Icons.center_focus_strong_rounded, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Expanded(
                          flex: 2,
                          child: Text("Perspective", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        ),
                        Expanded(
                          flex: 6,
                          child: Slider(
                            value: perspective,
                            min: 0.0005,
                            max: 0.003,
                            activeColor: file['color'] as Color,
                            onChanged: (value) => setDialogState(() => perspective = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Buttons
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(context); // close preview
                        _editDesign(file);
                      },
                      icon: const Icon(Icons.brush_rounded, size: 18),
                      label: const Text("Open in 2D Canvas", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => setDialogState(() {
                              rotateX = 0.0;
                              rotateY = 0.0;
                              perspective = 0.0015;
                            }),
                            icon: const Icon(Icons.restart_alt_rounded, size: 16),
                            label: const Text("Reset View", style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: StarlightTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _showMessage("Sharing design blueprint ${file['name']}...", false);
                            },
                            icon: const Icon(Icons.share, size: 16),
                            label: const Text("Share Design", style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
