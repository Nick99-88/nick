import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../services/gemini_service.dart';
import '../../../core/storage.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';

class DocumentTranslator extends StatefulWidget {
  const DocumentTranslator({super.key});

  @override
  State<DocumentTranslator> createState() => _DocumentTranslatorState();
}

class _DocumentTranslatorState extends State<DocumentTranslator>
    with TickerProviderStateMixin {
  final _picker = ImagePicker();
  final _apiBase = StarlightConstants.apiBaseUrl;

  File? _selectedFile;
  bool _isProcessing = false;
  double _processingProgress = 0;
  String _translatedTitle = '';
  List<Map<String, dynamic>> _translatedContent = [];
  Uint8List? _pdfBytes;
  String _pdfFileName = '';

  String _fromLang = 'English';
  String _toLang = 'Urdu';
  final _languages = [
    {'code': 'English', 'flag': '🇬🇧', 'name': 'English'},
    {'code': 'Urdu', 'flag': '🇵🇰', 'name': 'Urdu'},
    {'code': 'Arabic', 'flag': '🇸🇦', 'name': 'Arabic'},
    {'code': 'Spanish', 'flag': '🇪🇸', 'name': 'Spanish'},
    {'code': 'French', 'flag': '🇫🇷', 'name': 'French'},
    {'code': 'German', 'flag': '🇩🇪', 'name': 'German'},
    {'code': 'Chinese', 'flag': '🇨🇳', 'name': 'Chinese'},
    {'code': 'Hindi', 'flag': '🇮🇳', 'name': 'Hindi'},
    {'code': 'Japanese', 'flag': '🇯🇵', 'name': 'Japanese'},
    {'code': 'Korean', 'flag': '🇰🇷', 'name': 'Korean'},
    {'code': 'Portuguese', 'flag': '🇧🇷', 'name': 'Portuguese'},
    {'code': 'Russian', 'flag': '🇷🇺', 'name': 'Russian'},
  ];

  late AnimationController _floatController;
  late AnimationController _pulseController;
  late AnimationController _swapController;
  late Animation<double> _floatAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _swapAnimation;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _swapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _swapAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _swapController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    _pulseController.dispose();
    _swapController.dispose();
    super.dispose();
  }

  void _playSwapAnimation() {
    _swapController.forward(from: 0);
  }

  void _swapLanguages() {
    final temp = _fromLang;
    setState(() {
      _fromLang = _toLang;
      _toLang = temp;
    });
    _playSwapAnimation();
  }

  static const int _maxFileSize = 10 * 1024 * 1024;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      final originalName = result.files.single.name;
      final fileBytes = result.files.single.bytes!;
      if (fileBytes.length > _maxFileSize) {
        _showSizeError();
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$originalName';
      final file = File(tempPath);
      await file.writeAsBytes(fileBytes);

      setState(() {
        _selectedFile = file;
        _translatedTitle = '';
        _translatedContent = [];
        _pdfBytes = null;
        _pdfFileName = '';
      });
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final file = File(picked.path);
      final size = await file.length();
      if (size > _maxFileSize) {
        _showSizeError();
        return;
      }
      setState(() {
        _selectedFile = file;
        _translatedTitle = '';
        _translatedContent = [];
        _pdfBytes = null;
        _pdfFileName = '';
      });
    }
  }

  void _showSizeError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("File too large. Maximum size is 10 MB."),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _processDocument() async {
    if (_selectedFile == null) return;
    setState(() {
      _isProcessing = true;
      _processingProgress = 0;
      _translatedTitle = '';
      _translatedContent = [];
      _pdfBytes = null;
      _pdfFileName = '';
    });
    _pulseController.forward(from: 0);

    try {
      final bytes = await _selectedFile!.readAsBytes();
      final base64Image = base64Encode(bytes);
      final ext = _selectedFile!.path.toLowerCase().split('.').last;
      final mimeType = ext == 'pdf'
          ? 'application/pdf'
          : ext == 'png'
              ? 'image/png'
              : ext == 'webp'
                  ? 'image/webp'
                  : 'image/jpeg';

      final token = await StarlightStorage.getUserToken();

      for (int i = 0; i <= 100; i += 20) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          setState(() => _processingProgress = i / 100);
        }
      }

      final response = await http.post(
        Uri.parse('$_apiBase/document-translator/process'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'imageData': base64Image,
          'mimeType': mimeType,
          'from_lang': _fromLang,
          'to_lang': _toLang,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final title = (jsonResponse['title'] as String?) ?? 'Translated Document';
        final content = (jsonResponse['content'] as List<dynamic>?)
            ?.map((e) => (e as Map<String, dynamic>))
            .toList() ??
            <Map<String, dynamic>>[];

        if (!mounted) return;

        setState(() {
          _translatedTitle = title;
          _translatedContent = content;
          _isProcessing = false;
          _processingProgress = 1.0;
        });

        _pulseController.stop();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Document translated successfully!",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _generatePdf,
                    child: const Text("SAVE PDF",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF4CAF50),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _processingProgress = 0;
      });
      _pulseController.stop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _generatePdf() async {
    if (_translatedContent.isEmpty) return;

    pw.Font urduFont = pw.Font.helvetica();
    pw.Font fallbackFont = pw.Font.helvetica();

    try {
      final fontData = await rootBundle.load('assets/fonts/NotoNastaliqUrdu-Regular.ttf');
      urduFont = pw.Font.ttf(fontData);
      fallbackFont = pw.Font.helvetica();
    } catch (_) {
      // Fallback to Helvetica if font not found
    }

    final pdf = pw.Document();
    final theme = pw.ThemeData.withFont(
      base: urduFont,
      bold: urduFont,
    );

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              _translatedTitle.isEmpty ? 'Translated Document' : _translatedTitle,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green700,
                fontFallback: [fallbackFont],
              ),
            ),
            pw.Text(
              '$_fromLang to $_toLang',
              style: pw.TextStyle(
                fontSize: 10, 
                color: PdfColors.grey,
                fontFallback: [fallbackFont],
              ),
            ),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 9, 
              color: PdfColors.grey,
              fontFallback: [fallbackFont],
            ),
          ),
        ),
        build: (context) => [
          for (final item in _translatedContent)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  item['title']?.toString() ?? '',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                    fontFallback: [fallbackFont],
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  item['translated_text']?.toString() ?? '',
                  style: pw.TextStyle(
                    fontSize: 14, 
                    color: PdfColors.black, 
                    lineSpacing: 2,
                    fontFallback: [fallbackFont],
                  ),
                ),
                pw.SizedBox(height: 20),
              ],
            ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'Translated_$timestamp.pdf';
    final filePath = '${dir.path}/$fileName';
    await File(filePath).writeAsBytes(bytes);

    if (!mounted) return;

    setState(() {
      _pdfBytes = bytes;
      _pdfFileName = fileName;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          child: Row(
            children: [
              const Icon(Icons.description_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "PDF saved: $fileName",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => OpenFile.open(filePath),
                child: const Text("OPEN",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF263238),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildLanguageSelector(String label, String currentLang, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.95),
            Colors.white.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentLang,
          onChanged: onChanged,
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          iconEnabledColor: StarlightTheme.primaryBlue,
          items: _languages.map((lang) {
            return DropdownMenuItem<String>(
              value: lang['code'],
              child: Row(
                children: [
                  Text(lang['flag'] ?? '', style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lang['code'] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF263238),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFilePreview() {
    if (_selectedFile == null) return const SizedBox.shrink();

    final fileName = _selectedFile!.path.split('/').last;
    final fileSize = _selectedFile!.lengthSync();
    final sizeKB = fileSize >= 1024 * 1024
        ? '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(fileSize / 1024).toStringAsFixed(1)} KB';
    final fileExt = fileName.contains('.') ? fileName.split('.').last.toUpperCase() : 'FILE';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            StarlightTheme.primaryBlue.withOpacity(0.05),
            StarlightTheme.primaryBlue.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StarlightTheme.primaryBlue.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [StarlightTheme.primaryBlue, StarlightTheme.primaryBlue.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: StarlightTheme.primaryBlue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.insert_drive_file_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF263238),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${fileExt} · $sizeKB',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedFile = null;
                _translatedTitle = '';
                _translatedContent = [];
                _pdfBytes = null;
                _pdfFileName = '';
              });
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded, color: Colors.red.shade400, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    if (!_isProcessing) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [StarlightTheme.primaryBlue, Color(0xFF1A237E)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                      value: null,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Translating...',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: StarlightTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Processing ${_fromLang} → ${_toLang}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              Text(
                '${(_processingProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: StarlightTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _processingProgress,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(StarlightTheme.primaryBlue),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    if (_translatedTitle.isEmpty && _translatedContent.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4CAF50).withOpacity(0.08),
            const Color(0xFF4CAF50).withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_outline, color: const Color(0xFF4CAF50), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _translatedTitle.isEmpty ? 'Translation Complete!' : _translatedTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: const Color(0xFF263238),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_fromLang → $_toLang · ${_translatedContent.length} sections',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 320),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _translatedContent.length,
              separatorBuilder: (_, __) => Divider(height: 20, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final item = _translatedContent[index];
                final original = item['title']?.toString() ?? '';
                final translated = item['translated_text']?.toString() ?? '';
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildSectionColumn(
                        label: 'Original',
                        text: original,
                        color: const Color(0xFF263238),
                        bg: const Color(0xFFECEFF1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: const Color(0xFF4CAF50)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSectionColumn(
                        label: _toLang,
                        text: translated,
                        color: const Color(0xFF1B5E20),
                        bg: const Color(0xFF4CAF50).withOpacity(0.12),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.description_rounded,
                  label: 'Save PDF',
                  color: StarlightTheme.primaryBlue,
                  onTap: _generatePdf,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  color: const Color(0xFF4CAF50),
                  onTap: () async {
                    if (_pdfBytes == null) {
                      await _generatePdf();
                      return;
                    }
                    if (_pdfBytes != null) {
                      final dir = await getApplicationDocumentsDirectory();
                      final path = '${dir.path}/$_pdfFileName';
                      Share.shareXFiles([XFile(path)]);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionColumn({
    required String label,
    required String text,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color.withOpacity(0.6),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text.isEmpty ? '—' : text,
            style: TextStyle(fontSize: 12, height: 1.45, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: _pickFile,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: StarlightTheme.primaryBlue.withOpacity(0.3),
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
            boxShadow: [
              BoxShadow(
                color: StarlightTheme.primaryBlue.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: StarlightTheme.primaryBlue.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_upload_rounded,
                  size: 40,
                  color: StarlightTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Drop your document here',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: StarlightTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Supports PDF, JPG, PNG — Max 10MB',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [StarlightTheme.primaryBlue, const Color(0xFF1A237E)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: StarlightTheme.primaryBlue.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_open_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Browse Files',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.camera_alt_rounded, color: StarlightTheme.primaryBlue, size: 18),
                    onPressed: _pickImage,
                    tooltip: 'Pick from camera',
                  ),
                  const Text('|', style: TextStyle(color: Colors.grey)),
                  const SizedBox(width: 8),
                  Text('Camera', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1A237E).withOpacity(0.03),
                    Colors.white,
                    const Color(0xFFF0F4FF),
                  ],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(),
                  const SizedBox(height: 24),

                  // Upload Area
                  if (_selectedFile == null) _buildUploadArea(),

                  // File Preview
                  if (_selectedFile != null) _buildFilePreview(),

                  const SizedBox(height: 24),

                  // Language Selection Card
                  _buildLanguageCard(),

                  const SizedBox(height: 24),

                  // Translate Button
                  _buildTranslateButton(),

                  const SizedBox(height: 16),

                  // Progress Indicator
                  _buildProgressIndicator(),

                  const SizedBox(height: 16),

                  // Result Card
                  _buildResultCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [StarlightTheme.primaryBlue, Color(0xFF1A237E)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: StarlightTheme.primaryBlue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.translate_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Document Translator',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: Color(0xFF263238),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Upload & translate documents instantly',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguageCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: StarlightTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.language_rounded, color: StarlightTheme.primaryBlue, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Language Settings',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF263238),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // From Language
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'From',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    _buildLanguageSelector('From', _fromLang, (v) {
                      if (v != null) setState(() => _fromLang = v);
                    }),
                  ],
                ),
              ),

              // Swap Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ScaleTransition(
                  scale: _swapAnimation,
                  child: Material(
                    color: const Color(0xFFFF7043).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _swapLanguages,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [const Color(0xFFFF7043), const Color(0xFFFFAB91)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF7043).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.swap_vert_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
              ),

              // To Language
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'To',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    _buildLanguageSelector('To', _toLang, (v) {
                      if (v != null) setState(() => _toLang = v);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTranslateButton() {
    final isReady = _selectedFile != null && !_isProcessing;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: isReady
            ? const LinearGradient(
                colors: [StarlightTheme.primaryBlue, Color(0xFF1A237E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [Colors.grey.shade300, Colors.grey.shade400],
              ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isReady
            ? [
                BoxShadow(
                  color: StarlightTheme.primaryBlue.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isReady ? _processDocument : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isProcessing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              else
                const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                _isProcessing ? 'Translating...' : 'Translate Document',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}