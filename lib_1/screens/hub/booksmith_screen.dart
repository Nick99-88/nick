import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/src/document/attribute.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/ai_model_manager.dart';
import '../../services/ml/ml_service.dart';

class _Document {
  final String id;
  String title;
  String author;
  String subject;
  String grade;
  String description;
  List<String> tags;
  String? coverPath;
  DateTime createdAt;
  DateTime updatedAt;
  String contentDelta;
  String fileType;

  _Document({
    required this.id,
    this.title = '',
    this.author = '',
    this.subject = '',
    this.grade = '',
    this.description = '',
    this.tags = const [],
    this.coverPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.contentDelta = '[]',
    this.fileType = 'quill',
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'subject': subject,
        'grade': grade,
        'description': description,
        'tags': tags,
        'coverPath': coverPath,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'contentDelta': contentDelta,
        'fileType': fileType,
      };

  factory _Document.fromJson(Map<String, dynamic> json) => _Document(
        id: json['id'],
        title: json['title'] ?? '',
        author: json['author'] ?? '',
        subject: json['subject'] ?? '',
        grade: json['grade'] ?? '',
        description: json['description'] ?? '',
        tags: List<String>.from(json['tags'] ?? []),
        coverPath: json['coverPath'],
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        contentDelta: json['contentDelta'] ?? '[]',
        fileType: json['fileType'] ?? 'quill',
      );
}

class BookSmithScreen extends StatefulWidget {
  const BookSmithScreen({super.key});

  @override
  State<BookSmithScreen> createState() => _BookSmithScreenState();
}

class _BookSmithScreenState extends State<BookSmithScreen> {
  List<_Document> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<String> get _docDir async {
    final dir = await getApplicationDocumentsDirectory();
    final docDir = Directory('${dir.path}/booksmith');
    if (!await docDir.exists()) await docDir.create(recursive: true);
    return docDir.path;
  }

  Future<void> _loadDocuments() async {
    final dir = await _docDir;
    final file = File('$dir/index.json');
    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString());
      _documents = (data as List).map((e) => _Document.fromJson(e)).toList();
      _documents.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveIndex() async {
    final dir = await _docDir;
    final file = File('$dir/index.json');
    await file.writeAsString(jsonEncode(_documents.map((d) => d.toJson()).toList()));
  }

  Future<void> _saveDocument(_Document doc) async {
    final dir = await _docDir;
    await File('$dir/${doc.id}.json').writeAsString(jsonEncode(doc.toJson()));
  }

  Future<_Document?> _loadDocumentContent(String id) async {
    final dir = await _docDir;
    final file = File('$dir/$id.json');
    if (await file.exists()) {
      return _Document.fromJson(jsonDecode(await file.readAsString()));
    }
    return null;
  }

  Future<void> _createDocument() async {
    final doc = _Document(id: DateTime.now().millisecondsSinceEpoch.toString());
    _documents.insert(0, doc);
    await _saveDocument(doc);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _BookEditorScreen(doc: doc, onSaved: _reload)),
    );
  }

  Future<void> _importFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'pdf', 'md'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = await File(file.path!).readAsBytes();
    final ext = file.extension?.toLowerCase() ?? 'txt';

    String content;
    String fileType;
    if (ext == 'pdf') {
      content = base64Encode(bytes);
      fileType = 'pdf';
    } else {
      content = utf8.decode(bytes);
      fileType = 'text';
    }

    final doc = _Document(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: file.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
      fileType: fileType,
      contentDelta: content,
    );
    _documents.insert(0, doc);
    await _saveDocument(doc);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _BookReaderScreen(doc: doc, onSaved: _reload)),
    );
  }

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Scan Document / Book',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.teal),
                title: const Text('Scan Document'),
                subtitle: const Text('One page — camera or gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickScanSource(isBook: false);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.menu_book, color: Colors.indigo),
                title: const Text('Scan Book'),
                subtitle: const Text('Multiple pages — scan page by page'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickScanSource(isBook: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickScanSource({required bool isBook}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.teal),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (isBook) {
                    _scanBook(ImageSource.camera);
                  } else {
                    _scanDocument(ImageSource.camera);
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  if (isBook) {
                    _scanBook(ImageSource.gallery);
                  } else {
                    _scanDocument(ImageSource.gallery);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scanDocument(ImageSource source) async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      _showLoadingDialog('Scanning document...');
      final text = await MLService().recognizeText(imagePath: image.path);
      _dismissDialog();

      if (!mounted) return;
      final doc = _Document(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Scanned Document ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
        fileType: 'text',
        contentDelta: text,
      );
      _documents.insert(0, doc);
      await _saveDocument(doc);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _BookReaderScreen(doc: doc, onSaved: _reload)),
      );
    } catch (e) {
      _dismissDialog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  final List<String> _scannedPages = [];

  Future<void> _scanBook(ImageSource source) async {
    _scannedPages.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scan pages one by one. Tap Cancel to finish.'), backgroundColor: Colors.indigo),
    );

    bool keepScanning = true;
    while (keepScanning && mounted) {
      try {
        final XFile? image = await ImagePicker().pickImage(
          source: source,
          imageQuality: 85,
        );
        if (image == null) break;

        if (!mounted) break;
        _showLoadingDialog('Scanning page ${_scannedPages.length + 1}...');
        final text = await MLService().recognizeText(imagePath: image.path);
        _dismissDialog();

        _scannedPages.add(text);

        if (!mounted) break;
        final more = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Page ${_scannedPages.length} scanned'),
            content: Text('${text.length} characters extracted. Scan another page?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Finish', style: TextStyle(color: Colors.indigo)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Next Page'),
              ),
            ],
          ),
        );
        keepScanning = more ?? false;
      } catch (e) {
        _dismissDialog();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Page scan failed: $e'), backgroundColor: Colors.red),
          );
        }
        keepScanning = false;
      }
    }

    if (_scannedPages.isEmpty || !mounted) return;
    final fullText = _scannedPages.join('\n\n--- Page Break ---\n\n');
    final doc = _Document(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Scanned Book ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
      fileType: 'text',
      contentDelta: fullText,
    );
    _documents.insert(0, doc);
    await _saveDocument(doc);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _BookReaderScreen(doc: doc, onSaved: _reload)),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Text(message, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _dismissDialog() {
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _reload() async {
    await _loadDocuments();
  }

  Future<void> _deleteDocument(_Document doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Delete "${doc.title.isEmpty ? 'Untitled' : doc.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    _documents.removeWhere((d) => d.id == doc.id);
    final dir = await _docDir;
    await File('$dir/${doc.id}.json').delete();
    await _saveIndex();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('BookSmith'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'scan',
            backgroundColor: const Color(0xFF7C4DFF),
            onPressed: _showScanOptions,
            child: const Icon(Icons.document_scanner, color: Colors.white),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'import',
            backgroundColor: Colors.blueGrey,
            onPressed: _importFile,
            child: const Icon(Icons.file_open, color: Colors.white),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'create',
            backgroundColor: Colors.teal,
            onPressed: _createDocument,
            child: const Icon(Icons.edit_note, color: Colors.white),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_stories, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No documents yet', style: TextStyle(fontSize: 18, color: Colors.grey[400], fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text('Tap + to create or import', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _documents.length,
                  itemBuilder: (_, i) => _DocumentCard(
                    doc: _documents[i],
                    onTap: () async {
                      final full = await _loadDocumentContent(_documents[i].id);
                      if (full == null) return;
                      if (!mounted) return;
                      if (full.fileType == 'quill') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => _BookEditorScreen(doc: full, onSaved: _reload)),
                        );
                      } else {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => _BookReaderScreen(doc: full, onSaved: _reload)),
                        );
                      }
                    },
                    onDelete: () => _deleteDocument(_documents[i]),
                  ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final _Document doc;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DocumentCard({required this.doc, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    final icon = doc.fileType == 'pdf'
        ? Icons.picture_as_pdf
        : doc.fileType == 'text'
            ? Icons.description
            : Icons.auto_stories;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.teal, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title.isEmpty ? 'Untitled' : doc.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${doc.author.isEmpty ? 'No author' : doc.author}  ·  ${fmt.format(doc.updatedAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    if (doc.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 4,
                          children: doc.tags.take(3).map((t) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(t, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                              )).toList(),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: Colors.grey[400]),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookEditorScreen extends StatefulWidget {
  final _Document doc;
  final VoidCallback onSaved;

  const _BookEditorScreen({required this.doc, required this.onSaved});

  @override
  State<_BookEditorScreen> createState() => _BookEditorScreenState();
}

class _BookEditorScreenState extends State<_BookEditorScreen> {
  late QuillController _quillController;
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _subjectController;
  late TextEditingController _descController;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.doc.title);
    _authorController = TextEditingController(text: widget.doc.author);

    try {
      final json = jsonDecode(widget.doc.contentDelta);
      if (json is List && json.isNotEmpty) {
        _quillController = QuillController(
          document: Document.fromJson(json),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } else {
        _quillController = QuillController(document: Document(), selection: const TextSelection.collapsed(offset: 0));
      }
    } catch (_) {
      final doc = Document();
      if (widget.doc.contentDelta.isNotEmpty && widget.doc.contentDelta != '[]') {
        doc.insert(0, widget.doc.contentDelta);
      }
      _quillController = QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));
    }

    _subjectController = TextEditingController(text: widget.doc.subject);
    _descController = TextEditingController(text: widget.doc.description);
  }

  @override
  void dispose() {
    _quillController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _subjectController.dispose();
    _descController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    widget.doc.title = _titleController.text;
    widget.doc.author = _authorController.text;
    widget.doc.subject = _subjectController.text;
    widget.doc.description = _descController.text;
    widget.doc.contentDelta = jsonEncode(_quillController.document.toDelta().toJson());
    widget.doc.updatedAt = DateTime.now();
    widget.doc.fileType = 'quill';

    final dir = await _getDocDir();
    await File('$dir/${widget.doc.id}.json').writeAsString(jsonEncode(widget.doc.toJson()));
    widget.onSaved();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<String> _getDocDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final docDir = Directory('${dir.path}/booksmith');
    if (!await docDir.exists()) await docDir.create(recursive: true);
    return docDir.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            hintText: 'Title',
            border: InputBorder.none,
            isDense: true,
          ),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showProperties,
            tooltip: 'Properties',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
            tooltip: 'Save',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _toolBtn(Icons.format_bold, (_) => _quillController.formatSelection(Attribute.bold)),
                  _toolBtn(Icons.format_italic, (_) => _quillController.formatSelection(Attribute.italic)),
                  _toolBtn(Icons.format_underline, (_) => _quillController.formatSelection(Attribute.underline)),
                  _toolBtn(Icons.format_strikethrough, (_) => _quillController.formatSelection(Attribute.strikeThrough)),
                  const _Divider(),
                  _toolBtn(Icons.format_list_bulleted, (_) => _quillController.formatSelection(ListAttribute('bullet'))),
                  _toolBtn(Icons.format_list_numbered, (_) => _quillController.formatSelection(ListAttribute('ordered'))),
                  const _Divider(),
                  _toolBtn(Icons.format_align_left, (_) => _quillController.formatSelection(AlignAttribute('left'))),
                  _toolBtn(Icons.format_align_center, (_) => _quillController.formatSelection(AlignAttribute('center'))),
                  _toolBtn(Icons.format_align_right, (_) => _quillController.formatSelection(AlignAttribute('right'))),
                  const _Divider(),
                  _toolBtn(Icons.title, (_) => _quillController.formatSelection(Attribute.h1)),
                  _toolBtn(Icons.text_fields, (_) => _quillController.formatSelection(Attribute.h2)),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: QuillEditor.basic(
                controller: _quillController,
                focusNode: _focusNode,
                config: const QuillEditorConfig(
                  placeholder: 'Start writing...',
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolBtn(IconData icon, void Function(QuillController) action) {
    return IconButton(
      icon: Icon(icon, size: 20),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      onPressed: () => action(_quillController),
    );
  }

  void _showProperties() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Document Properties', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            TextField(controller: _authorController, decoration: const InputDecoration(labelText: 'Author', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _subjectController, decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()), maxLines: 3),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 24, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 4));
}

enum _TextFormat { highlight, underline, strikethrough, squiggly }
enum _AIAction { explain, meaning }

class _TextRange {
  final int start;
  final int end;
  final _TextFormat format;
  _TextRange(this.start, this.end, this.format);
}

class _BookReaderScreen extends StatefulWidget {
  final _Document doc;
  final VoidCallback onSaved;

  const _BookReaderScreen({required this.doc, required this.onSaved});

  @override
  State<_BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<_BookReaderScreen> {
  String? _pdfPath;
  bool _isPreparing = true;
  bool _lineExplainerInstalled = false;
  bool _checkingModel = true;
  final List<_TextRange> _textFormats = [];
  final List<void Function()> _undoStack = [];
  final GlobalKey _selectionKey = GlobalKey();
  final FlutterTts _tts = FlutterTts();
  bool _isReading = false;

  @override
  void initState() {
    super.initState();
    _prepareFile();
    _checkModelStatus();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.5);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isReading = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _isReading = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _isReading = false);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _checkModelStatus() async {
    try {
      final installed = await AIModelManager().isModelInstalled('line_explainer');
      if (mounted) setState(() {
        _lineExplainerInstalled = installed;
        _checkingModel = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checkingModel = false);
    }
  }

  Future<void> _prepareFile() async {
    if (widget.doc.fileType == 'pdf') {
      try {
        final bytes = base64Decode(widget.doc.contentDelta);
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/booksmith_${widget.doc.id}.pdf';
        await File(path).writeAsBytes(bytes);
        if (mounted) setState(() { _pdfPath = path; _isPreparing = false; });
      } catch (e) {
        if (mounted) setState(() => _isPreparing = false);
      }
    } else {
      if (mounted) setState(() => _isPreparing = false);
    }
  }

  void _toggleFormat(int start, int end, _TextFormat format) {
    final existing = _textFormats.indexWhere(
      (h) => h.start == start && h.end == end && h.format == format,
    );
    if (existing >= 0) {
      final removed = _textFormats.removeAt(existing);
      _undoStack.add(() => _textFormats.add(removed));
    } else {
      _textFormats.add(_TextRange(start, end, format));
      _undoStack.add(() => _textFormats.removeLast());
    }
    setState(() {});
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _undoStack.removeLast()();
    setState(() {});
  }

  void _clearFormats() {
    if (_textFormats.isEmpty) return;
    final snapshot = List<_TextRange>.from(_textFormats);
    _undoStack.add(() => _textFormats.addAll(snapshot));
    _textFormats.clear();
    setState(() {});
  }

  void _toggleReadAloud() {
    if (_isReading) {
      _tts.stop();
      setState(() => _isReading = false);
    } else {
      _checkAndReadAloud();
    }
  }

  Future<void> _checkAndReadAloud() async {
    if (!_lineExplainerInstalled) {
      _navigateToAIPackages();
      return;
    }
    _readAloud();
  }

  Future<void> _readAloud() async {
    final text = widget.doc.contentDelta
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No readable text in this document')),
      );
      return;
    }
    setState(() => _isReading = true);
    await _tts.speak(text);
  }

  bool _hasFormat(int start, int end, _TextFormat format) {
    return _textFormats.any((h) => h.start == start && h.end == end && h.format == format);
  }

  TextStyle _styleForFormat(_TextFormat format) {
    switch (format) {
      case _TextFormat.highlight:
        return const TextStyle(backgroundColor: Color(0xFFFFD54F));
      case _TextFormat.underline:
        return const TextStyle(decoration: TextDecoration.underline);
      case _TextFormat.strikethrough:
        return const TextStyle(decoration: TextDecoration.lineThrough);
      case _TextFormat.squiggly:
        return const TextStyle(
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.wavy,
          decorationColor: Colors.red,
        );
    }
  }

  TextSpan _buildStyledText() {
    final text = widget.doc.contentDelta;
    if (_textFormats.isEmpty) {
      return TextSpan(text: text);
    }

    // Build a map of position → list of styles to merge
    final List<({int start, int end, TextStyle style})> styled = [];
    for (final fmt in _textFormats) {
      styled.add((start: fmt.start, end: fmt.end, style: _styleForFormat(fmt.format)));
    }

    // Sort by start position
    styled.sort((a, b) => a.start.compareTo(b.start));

    // Split text into segments with merged styles
    final spans = <TextSpan>[];
    int pos = 0;

    // Collect all boundary points
    final breakpoints = <int>{0, text.length};
    for (final s in styled) {
      breakpoints.add(s.start.clamp(0, text.length));
      breakpoints.add(s.end.clamp(0, text.length));
    }
    final sorted = breakpoints.toList()..sort();

    for (int i = 0; i < sorted.length - 1; i++) {
      final segStart = sorted[i];
      final segEnd = sorted[i + 1];
      if (segStart >= segEnd || segStart >= text.length) continue;

      // Collect all styles active in this segment
      final segStyles = <TextStyle>[];
      for (final s in styled) {
        if (s.start <= segStart && s.end >= segEnd) {
          segStyles.add(s.style);
        }
      }

      TextStyle? mergedStyle;
      for (final s in segStyles) {
        mergedStyle = (mergedStyle ?? const TextStyle()).merge(s);
      }

      spans.add(TextSpan(
        text: text.substring(segStart, segEnd),
        style: mergedStyle,
      ));
    }

    if (spans.isEmpty) spans.add(TextSpan(text: text));
    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.doc.title.isEmpty ? 'Untitled' : widget.doc.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_textFormats.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.undo, color: Colors.black54),
              tooltip: 'Undo',
              onPressed: _undo,
            ),
            IconButton(
              icon: const Icon(Icons.format_clear, color: Colors.black54),
              tooltip: 'Clear all',
              onPressed: _clearFormats,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.auto_fix_high, color: Colors.blueGrey),
            tooltip: 'AI Tools',
            onPressed: () => _showAITerminal(),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              mini: true,
              heroTag: 'tts_reader',
              backgroundColor: _isReading ? Colors.red : Colors.teal,
              onPressed: _toggleReadAloud,
              child: Icon(
                _isReading ? Icons.stop : Icons.volume_up,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isPreparing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.doc.fileType == 'pdf') {
      if (_pdfPath != null) {
        return SfPdfViewer.file(File(_pdfPath!));
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            const Text('Failed to load PDF', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
        child: SelectionArea(
        key: _selectionKey,
        contextMenuBuilder: _buildSelectionMenu,
        child: Text.rich(
          _buildStyledText(),
          style: const TextStyle(fontSize: 16, height: 1.8),
        ),
      ),
    );
  }

  Widget _buildSelectionMenu(BuildContext context, SelectableRegionState state) {
    final value = state.textEditingValue;
    final selection = value.selection;
    final text = selection.isValid && !selection.isCollapsed
        ? value.text.substring(selection.start, selection.end)
        : '';

    if (text.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Wrap(
          spacing: 0,
          runSpacing: 0,
          children: [
            _ctxBtn(Icons.copy, 'Copy', () {
              Clipboard.setData(ClipboardData(text: text));
              state.hideToolbar();
            }),
            _ctxBtn(Icons.highlight_alt, 'Highlight', () {
              _toggleFormat(selection.start, selection.end, _TextFormat.highlight);
              state.hideToolbar();
            }),
            _ctxBtn(Icons.format_underline, 'Underline', () {
              _toggleFormat(selection.start, selection.end, _TextFormat.underline);
              state.hideToolbar();
            }),
            _ctxBtn(Icons.format_strikethrough, 'Strikethrough', () {
              _toggleFormat(selection.start, selection.end, _TextFormat.strikethrough);
              state.hideToolbar();
            }),
            _ctxBtn(Icons.spellcheck, 'Squiggly', () {
              _toggleFormat(selection.start, selection.end, _TextFormat.squiggly);
              state.hideToolbar();
            }),
            _ctxBtn(Icons.auto_awesome, 'Explain AI', () {
              state.hideToolbar();
              _runAIAction(_AIAction.explain, text);
            }),
            _ctxBtn(Icons.book, 'Meaning', () {
              state.hideToolbar();
              _runAIAction(_AIAction.meaning, text);
            }),
          ],
        ),
      ),
    );
  }

  String _getSelectedText() {
    try {
      final sel = _selectionKey.currentState as SelectableRegionState?;
      if (sel != null) {
        final s = sel.textEditingValue.selection;
        if (s.isValid && !s.isCollapsed) {
          final doc = widget.doc.contentDelta;
          final start = s.start.clamp(0, doc.length);
          final end = s.end.clamp(0, doc.length);
          return doc.substring(start, end);
        }
      }
    } catch (_) {}
    return '';
  }

  void _runAIAction(_AIAction action, String text) {
    if (_lineExplainerInstalled) {
      switch (action) {
        case _AIAction.explain:
          _explainWithAI(text);
        case _AIAction.meaning:
          _getMeaning(text);
      }
    } else {
      _navigateToAIPackages();
    }
  }

  void _showAITerminal() {
    final selected = _getSelectedText();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AITerminalSheet(
        initialText: selected,
        lineExplainerInstalled: _lineExplainerInstalled,
      ),
    );
  }

  Widget _ctxBtn(IconData icon, String label, VoidCallback onTap) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
        ],
      ),
    );
  }

  Future<void> _explainWithAI(String text) async {
    _showLoadingDialog('🤖 Explaining...');
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) { _dismissDialog(); _showError('Not authenticated'); return; }

      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/dictionary/translate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'text': text,
          'from_lang': 'en',
          'to_lang': 'en',
          'content_type': 'phrase',
        }),
      );

      _dismissDialog();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _showResultSheet('🤖 AI Explanation', data['data']);
        } else {
          _showError(data['message'] ?? 'Explanation failed');
        }
      } else {
        _showError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _dismissDialog();
      _showError('Connection error: $e');
    }
  }

  Future<void> _getMeaning(String text) async {
    _showLoadingDialog('📖 Looking up meaning...');
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) { _dismissDialog(); _showError('Not authenticated'); return; }

      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/dictionary/translate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'text': text,
          'from_lang': 'en',
          'to_lang': 'en',
          'content_type': 'word',
        }),
      );

      _dismissDialog();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _showResultSheet('📖 Meaning', data['data']);
        } else {
          _showError(data['message'] ?? 'Lookup failed');
        }
      } else {
        _showError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _dismissDialog();
      _showError('Connection error: $e');
    }
  }

  void _navigateToAIPackages() {
    Navigator.pushNamed(context, '/ai-packages');
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Text(message, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _dismissDialog() {
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red[600]),
    );
  }

  void _showResultSheet(String title, Map<String, dynamic> data) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (data['translation'] != null) ...[
                _resultTile('Translation', data['translation']),
              ],
              if (data['meaning_from'] != null) ...[
                _resultTile('Meaning', data['meaning_from']),
              ],
              if (data['meaning_to'] != null) ...[
                _resultTile('Meaning (Urdu)', data['meaning_to']),
              ],
              if (data['word_type'] != null) ...[
                _resultTile('Type', data['word_type']),
              ],
              if (data['grammar'] != null) ...[
                _resultTile('Grammar Analysis', data['grammar'].toString()),
              ],
              if (data['synonyms'] != null && (data['synonyms'] as List).isNotEmpty) ...[
                _resultTile('Synonyms', (data['synonyms'] as List).join(', ')),
              ],
              if (data['antonyms'] != null && (data['antonyms'] as List).isNotEmpty) ...[
                _resultTile('Antonyms', (data['antonyms'] as List).join(', ')),
              ],
              if (data['examples'] != null && (data['examples'] as List).isNotEmpty) ...[
                _resultTile('Examples', (data['examples'] as List).join('\n')),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.indigo[50],
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: Colors.indigo[100]!),
            ),
            child: Text(label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.indigo,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
              border: Border(
                left: BorderSide(color: Colors.indigo[100]!),
                right: BorderSide(color: Colors.indigo[100]!),
                bottom: BorderSide(color: Colors.indigo[100]!),
              ),
            ),
            child: SelectableText(value,
              style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _AITerminalSheet extends StatefulWidget {
  final String initialText;
  final bool lineExplainerInstalled;

  const _AITerminalSheet({
    required this.initialText,
    required this.lineExplainerInstalled,
  });

  @override
  State<_AITerminalSheet> createState() => _AITerminalSheetState();
}

class _AITerminalSheetState extends State<_AITerminalSheet> {
  late final TextEditingController _inputCtrl;
  late final StreamController<String> _logCtrl;
  late final ScrollController _scrollCtrl;
  StreamSubscription<String>? _sub;
  final _logs = <String>[];
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _inputCtrl = TextEditingController(text: widget.initialText);
    _logCtrl = StreamController<String>.broadcast();
    _scrollCtrl = ScrollController();
    _sub = _logCtrl.stream.listen(_onLogLine);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _inputCtrl.dispose();
    _logCtrl.close();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onLogLine(String line) {
    if (line == '___clear___') {
      setState(() => _logs.clear());
    } else {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _addLog(String line, {bool isDivider = false}) {
    final f = isDivider ? line : '  $line';
    _logs.add(f);
    _logCtrl.add(f);
  }

  void _clearLogs() {
    _logs.clear();
    _logCtrl.add('___clear___');
  }

  Future<void> _doAction(_AIAction action) async {
    if (_running) return;
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _running = true);
    _clearLogs();

    _addLog('${action == _AIAction.explain ? 'EXPLAIN' : 'MEANING'} — "${text.length > 40 ? '${text.substring(0, 40)}...' : text}"', isDivider: true);
    _addLog('');

    final token = await StarlightStorage.getUserToken();
    if (token == null) { _addLog('ERROR: Not authenticated', isDivider: true); setState(() => _running = false); return; }

    _addLog('> POST /dictionary/translate');
    _addLog('');

    try {
      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/dictionary/translate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'text': text,
          'from_lang': 'en',
          'to_lang': 'en',
          'content_type': action == _AIAction.explain ? 'phrase' : 'word',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final d = data['data'];
          _addLog('✓ Response received', isDivider: true);
          _addLog('');

          final sections = <MapEntry<String, String>>{};
          if (d['translation'] != null) sections.add(MapEntry('TRANSLATION', d['translation']));
          if (d['meaning_from'] != null) sections.add(MapEntry('MEANING (EN)', d['meaning_from']));
          if (d['meaning_to'] != null) sections.add(MapEntry('MEANING (UR)', d['meaning_to']));
          if (d['word_type'] != null) sections.add(MapEntry('TYPE', d['word_type']));
          if (d['grammar'] != null) sections.add(MapEntry('GRAMMAR', d['grammar'].toString()));
          if (d['synonyms'] != null && (d['synonyms'] as List).isNotEmpty) {
            sections.add(MapEntry('SYNONYMS', (d['synonyms'] as List).join(', ')));
          }
          if (d['antonyms'] != null && (d['antonyms'] as List).isNotEmpty) {
            sections.add(MapEntry('ANTONYMS', (d['antonyms'] as List).join(', ')));
          }
          if (d['examples'] != null && (d['examples'] as List).isNotEmpty) {
            sections.add(MapEntry('EXAMPLES', (d['examples'] as List).join('\n')));
          }

          for (final entry in sections) {
            _addLog('── ${entry.key} ──', isDivider: true);
            for (final line in entry.value.split('\n')) {
              _addLog(line);
              await Future.delayed(const Duration(milliseconds: 30));
            }
            _addLog('');
          }

          _addLog('─' * 30, isDivider: true);
          _addLog('Done.');
        } else {
          _addLog('ERROR: ${data['message'] ?? 'Request failed'}', isDivider: true);
        }
      } else {
        _addLog('ERROR: HTTP ${response.statusCode}', isDivider: true);
      }
    } catch (e) {
      _addLog('ERROR: $e', isDivider: true);
    }

    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF0D1117),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Row(
                children: [
                  const Text('\$ ', style: TextStyle(color: Color(0xFF00FF00), fontFamily: 'monospace', fontSize: 14)),
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      style: const TextStyle(color: Color(0xFFE6EDF3), fontFamily: 'monospace', fontSize: 14),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'paste or type text...',
                        hintStyle: TextStyle(color: Colors.grey, fontFamily: 'monospace'),
                      ),
                      maxLines: 2,
                      minLines: 1,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (_inputCtrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                      onPressed: () { _inputCtrl.clear(); setState(() {}); },
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _termBtn('▸ EXPLAIN', const Color(0xFF58A6FF), _running ? null : () => _doAction(_AIAction.explain)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _termBtn('▸ MEANING', const Color(0xFF3FB950), _running ? null : () => _doAction(_AIAction.meaning)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44, height: 44,
                    child: _termBtn('✕', const Color(0xFF8B949E), () => Navigator.pop(context)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: _logs.isEmpty
                    ? const Center(
                        child: Text(
                          '  Select text or type above to begin.\n  Tap EXPLAIN or MEANING to run.',
                          style: TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        itemCount: _logs.length,
                        itemBuilder: (_, i) {
                          final line = _logs[i];
                          Color color;
                          if (line.startsWith('─') || line == '  Done.') {
                            color = const Color(0xFF8B949E);
                          } else if (line.contains('ERROR')) {
                            color = const Color(0xFFFF7B72);
                          } else if (line.contains('✓')) {
                            color = const Color(0xFF3FB950);
                          } else if (line.startsWith('  >')) {
                            color = const Color(0xFF58A6FF);
                          } else if (line.startsWith('  ──')) {
                            color = const Color(0xFFD2A8FF);
                          } else {
                            color = const Color(0xFFE6EDF3);
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(line, style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 13, height: 1.4)),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _termBtn(String label, Color color, VoidCallback? onTap) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: color,
        backgroundColor: onTap != null ? color.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: onTap != null ? color.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.15)),
        ),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
