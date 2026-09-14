import 'package:flutter/material.dart';
import 'dart:io';
import 'package:gal/gal.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
    final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _filteredDocuments = [];
  bool _isLoading = false;
  bool _isOnline = false;
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Academic',
    'Administrative',
    'Library',
    'Events',
    'Notices',
    'Reports',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    _searchController.addListener(_filterDocuments);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      // TODO: Implement document loading from local server
      // For now, use mock data
      final mockDocuments = [
        {
          'id': 1,
          'title': 'Sample Document',
          'description': 'A sample document',
          'category': 'Academic',
          'fileType': 'pdf',
          'filePath': '',
          'fileUrl': '',
          'fileSize': 1024,
          'uploadedBy': 'Admin',
          'tags': ['sample', 'document'],
          'permissions': ['read', 'write'],
          'uploadDate': DateTime.now().toIso8601String(),
          'expiryDate': null,
          'status': 'active',
          'isSynced': true,
          'syncAction': 'none',
          'lastModified': DateTime.now().toIso8601String(),
        }
      ];
      setState(() {
        _documents = mockDocuments;
        _filteredDocuments = List.from(_documents);
        _isOnline = true; // Default to online for now
      });
    } catch (e) {
      print('Error loading documents: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterDocuments() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDocuments = _documents.where((document) {
        final matchesSearch = document['title']!.toLowerCase().contains(query) ||
                           (document['description']?.toLowerCase().contains(query) ?? false) ||
                           document['category']!.toLowerCase().contains(query);
        
        final matchesCategory = _selectedCategory == 'All' || document['category'] == _selectedCategory;
        
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  Future<void> _addDocument() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddDocumentScreen()),
    );
    
    if (result == true) {
      _loadDocuments();
    }
  }

  Future<void> _viewDocument(Map<String, dynamic> document) async {
    try {
      // TODO: Implement file opening functionality
      // For now, just show a message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File opening not yet implemented'),
          backgroundColor: Colors.orange,
        ),
      );

      String? filePath = document['filePath'];
      if (filePath != null) {
        // TODO: Implement file opening
      } else if (document['fileUrl'] != null && _isOnline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening online file...'),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File not available offline'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteDocument(Map<String, dynamic> document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete ${document['title']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        // TODO: Implement document deletion from local server
        // For now, just remove from local list
        setState(() {
          _documents.removeWhere((d) => d['id'] == document['id']);
          _filteredDocuments.removeWhere((d) => d['id'] == document['id']);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${document['title']} deleted'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return 'Unknown size';
    
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Documents'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [],
      ),
      body: Column(
        children: [
          // Search and filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search documents...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                // Category filter
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = category == _selectedCategory;
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = category;
                            });
                            _filterDocuments();
                          },
                          backgroundColor: Colors.white,
                          selectedColor: StarlightTheme.primaryBlue,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Documents list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredDocuments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No documents found',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload your first document to get started',
                              style: TextStyle(
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredDocuments.length,
                        itemBuilder: (context, index) {
                          final document = _filteredDocuments[index];
                          return _buildDocumentCard(document);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDocument,
        backgroundColor: StarlightTheme.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> document) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getFileIcon(document['fileType']),
            color: Colors.blue,
            size: 30,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                document['title']!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (!document['isSynced'])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Offline',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(document['category']!),
            if (document['description'] != null && document['description']!.isNotEmpty)
              Text(
                document['description']!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600]),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _formatFileSize(document['fileSize']),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Uploaded: ${DateTime.parse(document['uploadDate']).day}/${DateTime.parse(document['uploadDate']).month}/${DateTime.parse(document['uploadDate']).year}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'view':
                _viewDocument(document);
                break;
              case 'delete':
                _deleteDocument(document);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 20),
                  SizedBox(width: 8),
                  Text('View'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddDocumentScreen extends StatefulWidget {
  const AddDocumentScreen({super.key});

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
    final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  
  String _selectedCategory = 'Academic';
  String? _filePath;
  String _fileName = '';
  int _fileSize = 0;
  DateTime? _expiryDate;

  final List<String> _categories = [
    'Academic',
    'Administrative',
    'Library',
    'Events',
    'Notices',
    'Reports',
    'Other'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
          'jpg', 'jpeg', 'png', 'gif', 'mp4', 'avi', 'mov', 'mp3', 'wav'
        ],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileSize = await file.length();
        
        setState(() {
          _filePath = file.path;
          _fileName = result.files.single.name;
          _fileSize = fileSize.toInt();
        });
      }
    } catch (e) {
      print('Error picking file: $e');
    }
  }

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate() || _filePath == null) {
      if (_filePath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a file'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      // TODO: Implement document addition to local server
      // For now, just show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document addition not yet implemented'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pop(context, true);

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Document'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File selection
              const Text(
                'Select File',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                  ),
                  child: _filePath != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.insert_drive_file,
                              size: 40,
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _fileName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _formatFileSize(_fileSize),
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_upload,
                              size: 40,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to select file',
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              'PDF, DOC, XLS, PPT, Images, Videos, Audio',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Document Information
              const Text(
                'Document Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter document title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Expiry Date'),
                subtitle: Text(_expiryDate?.toIso8601String().split('T')[0] ?? 'No expiry'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _expiryDate = date;
                    });
                  }
                },
              ),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveDocument,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StarlightTheme.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Document',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
