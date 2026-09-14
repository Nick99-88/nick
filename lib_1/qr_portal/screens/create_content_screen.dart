import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:starlight_flutter/core/theme.dart';
import 'package:starlight_flutter/qr_portal/models/professional_content_model.dart';
import 'package:starlight_flutter/services/qr/qr_service_v2.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';

class CreateContentScreen extends StatefulWidget {
  final ProfessionalContentModel? content;
  final bool isQRLink;

  const CreateContentScreen({super.key, this.content, this.isQRLink = false});

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contentController = TextEditingController();
  final _linkController = TextEditingController();

  // State
  String _contentType = 'text';
  bool _isListed = true;
  DateTime? _expiresAt;
  bool _isLoading = false;
  bool _isListening = false;
  Uint8List? _imageData;
  String? _imageName;
  Uint8List? _fileData;
  String? _fileName;
  String? _fileExtension;
  
  // Publishing State
  bool _publishNow = true;
  DateTime? _publishAt;

  // Speech Engine
  final SpeechToText _speech = SpeechToText();
  final Map<String, String> _symbolMap = {
    "comma": ",",
    "period": ".",
    "new line": "\n",
    "question mark": "?",
    "dash": "-",
  };

  @override
  void initState() {
    super.initState();
    _initSpeech();
    if (widget.content != null) {
      _titleController.text = widget.content!.title;
      _descriptionController.text = widget.content!.description;
      _contentType = widget.content!.contentType;
      _contentController.text = widget.content!.content;
      _isListed = widget.content!.isListed;
      _expiresAt = widget.content!.expiresAt;
      final scheduledAt = widget.content!.publishAt;
      if (scheduledAt != null && scheduledAt.isAfter(DateTime.now())) {
        _publishNow = false;
        _publishAt = scheduledAt;
      } else {
        _publishNow = true;
        _publishAt = null;
      }
    }
  }

  void _initSpeech() async => await _speech.initialize();

  // 🏛️ Architect Console: Symbol Translation Logic
  String _applyArchitectLogic(String text) {
    String processed = text.toLowerCase();
    _symbolMap.forEach((word, symbol) {
      processed = processed.replaceAll(RegExp(r'\b' + word + r'\b'), symbol);
    });
    return processed;
  }

  void _toggleListening() async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    } else {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) {
          if (val.finalResult) {
            final processed = _applyArchitectLogic(val.recognizedWords);
            setState(() {
              _contentController.text += "$processed ";
              _isListening = false;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121214),
        title: Text(widget.content == null 
            ? (widget.isQRLink ? 'QR LINK CREATION' : 'ARCHITECT CONSOLE') 
            : 'EDIT CONTENT',
            style: GoogleFonts.orbitron(color: const Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel("CORE METADATA"),
              _buildTextField(_titleController, "Content Title", Icons.title),
              const SizedBox(height: 15),
              _buildTextField(_descriptionController, "Short Description", Icons.description, maxLines: 2),

              const SizedBox(height: 25),
              _buildSectionLabel("LISTING SCHEDULE"),
              _buildScheduleCard(),

              const SizedBox(height: 25),
              _buildSectionLabel("CONTENT ARCHITECT"),
              _buildContentTypeToggle(),
              const SizedBox(height: 15),
              widget.isQRLink 
                  ? _buildQRLinkContent()
                  : (_contentType == 'link' 
                      ? _buildTextField(_linkController, "HTTPS://URL", Icons.link)
                      : (_contentType == 'image'
                          ? _buildImageContent()
                          : _buildWritingConsole())),

              const SizedBox(height: 40),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 5),
      child: Text(label, style: GoogleFonts.inter(color: const Color(0xFF9E9E9E), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFF121214),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF8A8A8A)),
        prefixIcon: Icon(icon, color: const Color(0xFFD4AF37), size: 20),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A1A1C))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD4AF37))),
      ),
    );
  }

  Widget _buildScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF121214), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1A1A1C))),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text("Publicly Listed", style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text("Enable visibility on global platform", style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12)),
            value: _isListed,
            activeColor: const Color(0xFFD4AF37),
            onChanged: (val) => setState(() => _isListed = val),
          ),
          const Divider(color: Color(0xFF1A1A1C)),
          
          // Publishing Options
          _buildPublishingOptions(),
          
          const Divider(color: Color(0xFF1A1A1C)),
          ListTile(
            leading: const Icon(Icons.event_busy, color: Color(0xFF9E9E9E)),
            title: Text(_expiresAt == null ? "No Expiration Set" : DateFormat('MMM dd, yyyy').format(_expiresAt!), style: const TextStyle(color: Colors.white, fontSize: 14)),
            trailing: TextButton(
              onPressed: _pickExpiryDate,
              child: const Text("SET EXPIRY", style: TextStyle(color: Color(0xFFD4AF37))),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPublishingOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "PUBLISHING SCHEDULE",
          style: GoogleFonts.inter(color: const Color(0xFF9E9E9E), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _publishNow = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _publishNow ? const Color(0xFFD4AF37).withOpacity(0.1) : Colors.transparent,
                    border: Border.all(color: _publishNow ? const Color(0xFFD4AF37) : const Color(0xFF1A1A1C)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "PUBLISH NOW",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _publishNow ? const Color(0xFFD4AF37) : const Color(0xFF9E9E9E),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _publishNow = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: !_publishNow ? const Color(0xFFD4AF37).withOpacity(0.1) : Colors.transparent,
                    border: Border.all(color: !_publishNow ? const Color(0xFFD4AF37) : const Color(0xFF1A1A1C)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "SCHEDULE PUBLISH",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: !_publishNow ? const Color(0xFFD4AF37) : const Color(0xFF9E9E9E),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (!_publishNow) ...[
          const SizedBox(height: 15),
          GestureDetector(
            onTap: _pickPublishDateTime,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1C),
                border: Border.all(color: const Color(0xFFD4AF37)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "PUBLISH DATE",
                        style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _publishAt == null 
                            ? "Select publish date/time"
                            : DateFormat('MMM dd, yyyy - hh:mm a').format(_publishAt!),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                  const Icon(Icons.calendar_today, color: Color(0xFFD4AF37), size: 20),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWritingConsole() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121214),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isListening ? const Color(0xFFD4AF37) : const Color(0xFF1A1A1C)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _contentController,
            maxLines: 10,
            style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
            decoration: const InputDecoration(
              hintText: "Enter formal content or use voice architect...",
              hintStyle: TextStyle(color: Color(0xFF8A8A8A)),
              contentPadding: EdgeInsets.all(20),
              border: InputBorder.none,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: const BoxDecoration(color: Color(0xFF1A1A1C), borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(_isListening ? Icons.stop : Icons.mic, color: _isListening ? Colors.red : const Color(0xFFD4AF37)),
                  onPressed: _toggleListening,
                ),
                IconButton(
                  icon: const Icon(Icons.cleaning_services, color: Color(0xFF9E9E9E)),
                  onPressed: () => _contentController.clear(),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildContentTypeToggle() {
    final contentTypes = widget.isQRLink 
        ? ['document', 'image', 'pdf', 'link']
        : ['text', 'image', 'link'];
    
    return Row(
      children: contentTypes.map((type) {
        bool isSelected = _contentType == type;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _contentType = type),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.1) : Colors.transparent,
                border: Border.all(color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF1A1A1C)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                type.toUpperCase(), 
                textAlign: TextAlign.center, 
                style: TextStyle(
                  color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF9E9E9E), 
                  fontWeight: FontWeight.bold, 
                  fontSize: widget.isQRLink ? 10 : 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQRLinkContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "UPLOAD FILE",
          style: GoogleFonts.inter(color: const Color(0xFF9E9E9E), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1C),
            border: Border.all(color: const Color(0xFF2A2A2E)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                _getQRLinkIcon(),
                size: 48,
                color: const Color(0xFFD4AF37),
              ),
              const SizedBox(height: 15),
              Text(
                _getQRLinkText(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: const Color(0xFF9E9E9E), fontSize: 14),
              ),
              if (_fileName != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file, size: 20, color: const Color(0xFFD4AF37)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _fileName!,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFD4AF37),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 15),
              ElevatedButton.icon(
                onPressed: _handleFileUpload,
                icon: Icon(_fileName != null ? Icons.refresh : Icons.upload_file, size: 18),
                label: Text(
                  _fileName != null ? 'Change File' : 'Choose File',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getQRLinkIcon() {
    switch (_contentType) {
      case 'document':
        return Icons.description;
      case 'image':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'link':
        return Icons.link;
      default:
        return Icons.attach_file;
    }
  }

  String _getQRLinkText() {
    switch (_contentType) {
      case 'document':
        return 'Upload Document (.doc, .docx)';
      case 'image':
        return 'Upload Image (.jpg, .png, .gif)';
      case 'pdf':
        return 'Upload PDF Document';
      case 'link':
        return 'Enter Reference Link';
      default:
        return 'Upload File';
    }
  }

  Future<void> _handleFileUpload() async {
    try {
      FilePickerResult? result;
      
      switch (_contentType) {
        case 'document':
          result = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['doc', 'docx'],
            allowMultiple: false,
          );
          break;
        case 'image':
          result = await FilePicker.pickFiles(
            type: FileType.image,
            allowMultiple: false,
          );
          break;
        case 'pdf':
          result = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf'],
            allowMultiple: false,
          );
          break;
        case 'link':
          // For link type, show URL input dialog
          _showLinkInputDialog();
          return;
        default:
          result = await FilePicker.pickFiles(
            type: FileType.any,
            allowMultiple: false,
          );
      }
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        final fileName = file.name;
        final extension = fileName.split('.').last.toLowerCase();
        
        setState(() {
          _fileData = bytes;
          _fileName = fileName;
          _fileExtension = extension;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File "$fileName" selected successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLinkInputDialog() {
    final TextEditingController linkController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Reference Link',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: linkController,
          decoration: InputDecoration(
            hintText: 'Enter URL',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              if (linkController.text.isNotEmpty) {
                setState(() {
                  _fileData = utf8.encode(linkController.text);
                  _fileName = 'reference_link.txt';
                  _fileExtension = 'txt';
                });
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Reference link added successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: Text('Add', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "SELECT IMAGE",
          style: GoogleFonts.inter(color: const Color(0xFF9E9E9E), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1C),
            border: Border.all(color: const Color(0xFF2A2A2E)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              if (_imageData != null)
                Column(
                  children: [
                    Icon(Icons.image, size: 48, color: const Color(0xFFD4AF37)),
                    const SizedBox(height: 15),
                    Text(
                      _imageName ?? 'Image Selected',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: const Color(0xFFD4AF37), fontSize: 14),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: _handleImageUpload,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(
                        'Change Image',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Icon(Icons.image_outlined, size: 48, color: const Color(0xFF9E9E9E)),
                    const SizedBox(height: 15),
                    Text(
                      'No image selected',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: const Color(0xFF9E9E9E), fontSize: 14),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: _handleImageUpload,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: Text(
                        'Choose Image',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleImageUpload() async {
    print('🏛️ DEBUG: Image upload handler called');
    try {
      final ImagePicker picker = ImagePicker();
      print('🏛️ DEBUG: Opening image picker...');
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      print('🏛️ DEBUG: Image picker result: ${image != null ? "Image selected" : "No image selected"}');
      
      if (image != null) {
        print('🏛️ DEBUG: Reading image bytes...');
        final bytes = await image.readAsBytes();
        print('🏛️ DEBUG: Image bytes read, length: ${bytes.length}');
        print('🏛️ DEBUG: Image name: ${image.name}');
        print('🏛️ DEBUG: Image path: ${image.path}');
        
        setState(() {
          _imageData = bytes;
          _imageName = image.name;
        });
        
        print('🏛️ DEBUG: State updated - _imageData set, _imageName set');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image "${image.name}" selected successfully'),
            backgroundColor: Colors.green,
          ),
        );
        print('🏛️ DEBUG: Success snackbar shown');
      } else {
        print('🏛️ DEBUG: No image selected by user');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isLoading ? const Color(0xFF666666) : const Color(0xFFD4AF37),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isLoading 
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 10),
                Text('PROCESSING...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            )
          : Text(
              widget.content == null 
                ? (_publishNow ? 'PUBLISH NOW' : 'SCHEDULE PUBLISH')
                : 'UPDATE CONTENT', 
              style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold)
            ),
      ),
    );
  }

  // --- LOGIC ---

  void _pickExpiryDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _pickPublishDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _publishAt ?? DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (pickedDate == null) return;
    
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_publishAt ?? DateTime.now().add(const Duration(hours: 1))),
    );
    
    if (pickedTime != null) {
      final publishDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      setState(() => _publishAt = publishDateTime);
    }
  }

  Future<void> _handleSave() async {
    print('🏛️ DEBUG: Save method called');
    print('🏛️ DEBUG: widget.isQRLink = ${widget.isQRLink}');
    print('🏛️ DEBUG: _contentType = $_contentType');
    print('🏛️ DEBUG: _imageData is null = ${_imageData == null}');
    print('🏛️ DEBUG: _imageData length = ${_imageData?.length ?? 0}');
    print('🏛️ DEBUG: _imageName = $_imageName');
    print('🏛️ DEBUG: _fileData is null = ${_fileData == null}');
    print('🏛️ DEBUG: _fileData length = ${_fileData?.length ?? 0}');
    print('🏛️ DEBUG: _fileName = $_fileName');
    print('🏛️ DEBUG: _titleController.text = "${_titleController.text}"');
    print('🏛️ DEBUG: _descriptionController.text = "${_descriptionController.text}"');
    print('🏛️ DEBUG: _linkController.text = "${_linkController.text}"');
    print('🏛️ DEBUG: _isListed = $_isListed');
    print('🏛️ DEBUG: _publishNow = $_publishNow');
    print('🏛️ DEBUG: _publishAt = $_publishAt');
    print('🏛️ DEBUG: _expiresAt = $_expiresAt');
    
    print('🏛️ DEBUG: Starting form validation...');
    if (!_formKey.currentState!.validate()) {
      print('🏛️ DEBUG: Form validation failed');
      return;
    }
    print('🏛️ DEBUG: Form validation passed');
    
    // Additional validation for QR link mode
    print('🏛️ DEBUG: Starting QR link validation...');
    if (widget.isQRLink && _contentType == 'image' && _imageData == null) {
      print('🏛️ DEBUG: QR link image validation failed - isQRLink: ${widget.isQRLink}, contentType: $_contentType, imageData: ${_imageData == null}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image to create QR link'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    print('🏛️ DEBUG: QR link validation passed');
    
    setState(() => _isLoading = true);
    print('🏛️ Create Content: Loading state set to true');

    try {
      DateTime? actualPublishAt;
      if (_publishNow) {
        actualPublishAt = DateTime.now().toUtc();
        print('🏛️ Create Content: Publish Now selected - Current UTC time: $actualPublishAt');
      } else {
        if (_publishAt == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a publish date and time'),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
        actualPublishAt = _publishAt!.toUtc();
        print('🏛️ Create Content: Schedule Publish selected - Future UTC time: $actualPublishAt');
      }
      
      if (widget.content == null) {
        // Create new content
        // Declare response variable outside of if/else blocks
        late final response;
        
        if (widget.isQRLink) {
          // For QR link mode, use QR link endpoint
          // Convert image data to base64 string for link field
          print('🏛️ DEBUG: Processing QR link creation...');
          String linkData;
          if (_contentType == 'image' && _imageData != null) {
            print('🏛️ DEBUG: Encoding image data to base64...');
            linkData = base64Encode(_imageData!);
            print('🏛️ DEBUG: Image data encoded, length: ${linkData.length}');
          } else if (_fileData != null) {
            print('🏛️ DEBUG: Processing file data...');
            linkData = String.fromCharCodes(_fileData!);
            print('🏛️ DEBUG: File data processed, length: ${linkData.length}');
          } else {
            print('🏛️ DEBUG: Using link controller text...');
            linkData = _linkController.text.trim();
            print('🏛️ DEBUG: Link text: "${linkData}"');
          }
          
          print('🏛️ DEBUG: Calling QRServiceV2.createQRLink...');
          print('🏛️ DEBUG: Title: "${_titleController.text.trim()}"');
          print('🏛️ DEBUG: Description: "${_descriptionController.text.trim()}"');
          print('🏛️ DEBUG: Link data length: ${linkData.length}');
          print('🏛️ DEBUG: Is listed: $_isListed');
          print('🏛️ DEBUG: Expires at: $_expiresAt');
          
          response = await QRServiceV2.createQRLink(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            link: linkData,
            isListed: _isListed,
            expiresAt: _expiresAt,
          );
          
          print('🏛️ DEBUG: QRServiceV2.createQRLink completed');
          print('🏛️ DEBUG: Response success: ${response.success}');
          print('🏛️ DEBUG: Response error: ${response.error}');
        } else {
          // For professional content mode
          String contentData;
          if (_contentType == 'image' && _imageData != null) {
            contentData = base64Encode(_imageData!);
          } else {
            contentData = _contentType == 'link' ? _linkController.text.trim() : _contentController.text.trim();
          }
          
          response = await QRServiceV2.createProfessionalContent(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            contentType: _contentType,
            content: contentData,
            isListed: _isListed,
            expiresAt: _expiresAt,
            publishAt: actualPublishAt,
          );
        }

        if (response.success && mounted) {
          // Show success message based on content type and publishing schedule
          String successMessage = widget.isQRLink 
              ? (_publishNow 
                  ? 'QR link created successfully!'
                  : 'QR link scheduled for ${DateFormat('MMM dd, yyyy - hh:mm a').format(actualPublishAt!)}')
              : (_publishNow 
                  ? 'Content published successfully!'
                  : 'Content scheduled for ${DateFormat('MMM dd, yyyy - hh:mm a').format(actualPublishAt!)}');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              backgroundColor: const Color(0xFFD4AF37),
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.pop(context);
        } else if (mounted) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${response.error ?? "Unknown error occurred"}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        // Update existing content
        if (widget.isQRLink) {
          // Update QR link
          String linkData;
          if (_contentType == 'image' && _imageData != null) {
            linkData = base64Encode(_imageData!);
          } else if (_fileData != null) {
            linkData = String.fromCharCodes(_fileData!);
          } else {
            linkData = _linkController.text.trim();
          }
          
          final response = await QRServiceV2.updateQRLink(
            id: widget.content!.id,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            link: linkData,
            isListed: _isListed,
            expiresAt: _expiresAt,
          );

          if (response.success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('QR link updated successfully!'),
                backgroundColor: const Color(0xFFD4AF37),
                duration: const Duration(seconds: 3),
              ),
            );
            Navigator.pop(context);
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${response.error ?? "Unknown error occurred"}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } else {
          // Update professional content
          String contentData;
          if (_contentType == 'image' && _imageData != null) {
            contentData = base64Encode(_imageData!);
          } else {
            contentData = _contentType == 'link' ? _linkController.text.trim() : _contentController.text.trim();
          }
          
          final response = await QRServiceV2.updateProfessionalContent(
            id: widget.content!.id,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            contentType: _contentType,
            content: contentData,
            isListed: _isListed,
            expiresAt: _expiresAt,
            publishAt: actualPublishAt,
          );

          if (response.success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Content updated successfully!'),
                backgroundColor: const Color(0xFFD4AF37),
                duration: const Duration(seconds: 3),
              ),
            );
            Navigator.pop(context);
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${response.error ?? "Unknown error occurred"}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}