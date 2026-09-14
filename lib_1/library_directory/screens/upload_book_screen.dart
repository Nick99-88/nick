import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../../core/theme.dart';
import 'library_upload_progress_screen.dart';

class UploadBookScreen extends StatefulWidget {
  const UploadBookScreen({super.key});

  @override
  State<UploadBookScreen> createState() => _UploadBookScreenState();
}

class _UploadBookScreenState extends State<UploadBookScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _customTopicCtrl = TextEditingController();

  // 🏛️ Picked file state (replaces the old "type the URL" flow)
  PlatformFile? _pickedFile;
  String? _pickedFilePath;

  // Thumbnail state
  String? _thumbnailPath;
  bool _pickingThumbnail = false;

  String _selectedTopic = 'Science';
  final List<String> _topics = ['Science', 'Mathematics', 'Fiction', 'History', 'Other'];

  String _selectedDocType = 'book'; // 'note' or 'book'
  bool _picking = false;

  // Monetization
  String _monetizationType = 'free';
  final _priceCtrl = TextEditingController();

  // Publish scheduling
  String _publishMode = 'instant'; // 'instant' or 'schedule'
  DateTime? _scheduledDate;

  static const int _maxBytes = 50 * 1024 * 1024; // 50 MB

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _customTopicCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  /// 🏛️ Open the OS file picker so the user can grab any file off the device
  /// (image, PDF, doc, sheet, slide, audio, archive…). The selection is
  /// stored locally and streamed to the backend on submit.
  Future<void> _pickFile() async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final path = file.path;
      if (path == null) {
        _showSnack("Could not access the selected file path.", isError: true);
        return;
      }

      final size = file.size;
      if (size > _maxBytes) {
        _showSnack(
          "File is too large (${(size / 1024 / 1024).toStringAsFixed(1)} MB). Max is ${_maxBytes ~/ (1024 * 1024)} MB.",
          isError: true,
        );
        return;
      }

      setState(() {
        _pickedFile = file;
        _pickedFilePath = path;
      });
    } catch (e) {
      _showSnack("Could not open file picker: $e", isError: true);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _removePickedFile() {
    setState(() {
      _pickedFile = null;
      _pickedFilePath = null;
    });
  }

  Future<void> _pickThumbnail() async {
    setState(() => _pickingThumbnail = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.single.path;
        if (path != null) {
          setState(() => _thumbnailPath = path);
        }
      }
    } catch (e) {
      _showSnack("Could not pick thumbnail: $e", isError: true);
    } finally {
      if (mounted) setState(() => _pickingThumbnail = false);
    }
  }

  void _removeThumbnail() {
    setState(() => _thumbnailPath = null);
  }

  Future<void> _pickScheduleDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: "Select publish date",
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      helpText: "Select publish time",
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedFilePath == null) {
      _showSnack("Please pick a file from your device first.", isError: true);
      return;
    }

    final topicToSend = _selectedTopic == 'Other' 
        ? _customTopicCtrl.text.trim() 
        : _selectedTopic;

    if (_selectedTopic == 'Other' && topicToSend.isEmpty) {
      _showSnack("Please specify your custom topic.", isError: true);
      return;
    }

    final price = _monetizationType == 'rent' || _monetizationType == 'sell'
        ? double.tryParse(_priceCtrl.text.trim()) ?? 0.0
        : 0.0;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => LibraryUploadProgressScreen(
          filePath: _pickedFilePath!,
          fileName: _pickedFile?.name ?? 'document',
          fileSize: _pickedFile?.size ?? 0,
          title: _titleCtrl.text.trim(),
          author: _authorCtrl.text.trim(),
          topic: topicToSend,
          docType: _selectedDocType,
          monetizationType: _monetizationType,
          price: price,
          scheduledAt: _publishMode == 'schedule' ? _scheduledDate?.toIso8601String() : null,
          thumbnailPath: _thumbnailPath,
        ),
      ),
    );

    if (result != null && mounted) {
      _showSnack(_publishMode == 'schedule' ? "Publication scheduled successfully" : "Publication posted successfully");
      Navigator.pop(context, true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : null,
      ),
    );
  }

  String _fileKindLabel(String name) {
    final ext = name.contains('.') ? name.split('.').last.toUpperCase() : 'FILE';
    return ext;
  }

  IconData _fileKindIcon(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if ({'pdf'}.contains(ext)) return Icons.picture_as_pdf_rounded;
    if ({'doc', 'docx', 'odt', 'rtf', 'txt', 'md'}.contains(ext)) return Icons.article_rounded;
    if ({'xls', 'xlsx', 'ods', 'csv'}.contains(ext)) return Icons.table_chart_rounded;
    if ({'ppt', 'pptx', 'odp'}.contains(ext)) return Icons.slideshow_rounded;
    if ({'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg', 'heic', 'tiff'}.contains(ext)) return Icons.image_rounded;
    if ({'mp3', 'wav', 'm4a', 'aac', 'ogg'}.contains(ext)) return Icons.audiotrack_rounded;
    if ({'zip', 'rar', '7z'}.contains(ext)) return Icons.folder_zip_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _fileKindColor(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if ({'pdf'}.contains(ext)) return Colors.red;
    if ({'doc', 'docx', 'odt', 'rtf', 'txt', 'md'}.contains(ext)) return Colors.blue;
    if ({'xls', 'xlsx', 'ods', 'csv'}.contains(ext)) return Colors.green;
    if ({'ppt', 'pptx', 'odp'}.contains(ext)) return Colors.orange;
    if ({'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg', 'heic', 'tiff'}.contains(ext)) return Colors.purple;
    if ({'mp3', 'wav', 'm4a', 'aac', 'ogg'}.contains(ext)) return Colors.teal;
    if ({'zip', 'rar', '7z'}.contains(ext)) return Colors.brown;
    return Colors.blueGrey;
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text("PUBLISH NEW DOCUMENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).padding.bottom),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              Card(
                color: StarlightTheme.primaryBlue.withOpacity(0.05),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: StarlightTheme.primaryBlue, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Choose 'Short Note' for quick cheatsheets (Shorts style) or 'Reference Book' for long-form books (Video style). Pick any file from your phone — PDF, image, document, sheet, slide, audio, or archive.",
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Format / Doc Type Selector
              const Text("PUBLISHING FORMAT:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      avatar: Icon(Icons.flash_on_rounded, color: _selectedDocType == 'note' ? Colors.white : Colors.orange, size: 16),
                      label: FittedBox(fit: BoxFit.scaleDown, child: Text("Short Note (Shorts)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _selectedDocType == 'note' ? Colors.white : Colors.black87))),
                      selected: _selectedDocType == 'note',
                      selectedColor: Colors.orange,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _selectedDocType == 'note' ? Colors.transparent : Colors.grey.shade300)),
                      onSelected: (val) {
                        if (val) setState(() => _selectedDocType = 'note');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      avatar: Icon(Icons.play_circle_filled_rounded, color: _selectedDocType == 'book' ? Colors.white : StarlightTheme.primaryBlue, size: 16),
                      label: FittedBox(fit: BoxFit.scaleDown, child: Text("Reference Book (Video)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _selectedDocType == 'book' ? Colors.white : Colors.black87))),
                      selected: _selectedDocType == 'book',
                      selectedColor: StarlightTheme.primaryBlue,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _selectedDocType == 'book' ? Colors.transparent : Colors.grey.shade300)),
                      onSelected: (val) {
                        if (val) setState(() => _selectedDocType = 'book');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Title input
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: "Document / Book Title",
                  hintText: "e.g. Calculus Vol 1",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Title is required" : null,
              ),
              const SizedBox(height: 16),

              // Author input
              TextFormField(
                controller: _authorCtrl,
                decoration: InputDecoration(
                  labelText: "Author Name",
                  hintText: "e.g. Richard Courant",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Author is required" : null,
              ),
              const SizedBox(height: 16),

              // Topic Dropdown
              DropdownButtonFormField<String>(
                value: _selectedTopic,
                decoration: InputDecoration(
                  labelText: "Subject / Topic",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _topics.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedTopic = val);
                },
              ),
              if (_selectedTopic == 'Other') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _customTopicCtrl,
                  decoration: InputDecoration(
                    labelText: "Custom Subject / Topic Name",
                    hintText: "e.g. Astrophysics, Organic Chemistry",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (val) {
                    if (_selectedTopic == 'Other' && (val == null || val.trim().isEmpty)) {
                      return "Please enter your custom topic name";
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 20),

              // 🏛️ File picker — the new "pick from phone" flow.
              // Replaces the old "type a URL" text field.
              const Text("PICK FILE FROM YOUR DEVICE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 8),
              if (_pickedFile == null) ...[
                InkWell(
                  onTap: _picking ? null : _pickFile,
                  borderRadius: BorderRadius.circular(12),
                  child: DottedBorderContainer(
                    color: _selectedDocType == 'note' ? Colors.orange : StarlightTheme.primaryBlue,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.upload_file_rounded,
                            size: 42,
                            color: _selectedDocType == 'note' ? Colors.orange : StarlightTheme.primaryBlue,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _picking ? "Opening file picker..." : "Tap to pick any file",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "PDF, image, Word, Excel, PowerPoint, audio, archive…",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                _pickedFileCard(),
              ],
              const SizedBox(height: 20),

              // Thumbnail picker
              const Text("THUMBNAIL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 8),
              if (_thumbnailPath == null) ...[
                InkWell(
                  onTap: _pickingThumbnail ? null : _pickThumbnail,
                  borderRadius: BorderRadius.circular(12),
                  child: DottedBorderContainer(
                    color: Colors.grey.shade400,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 28, color: Colors.grey.shade500),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _pickingThumbnail
                                  ? "Opening gallery..."
                                  : (_selectedDocType == 'note'
                                      ? "Pick a thumbnail (auto-uses file for images)"
                                      : "Pick a thumbnail image"),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_thumbnailPath!),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Thumbnail selected", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text("Tap remove to change", style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _removeThumbnail,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, color: Colors.red, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 30),

              // 🏛️ Monetization Section
              const Text("MONETIZATION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _monetizationOption('free', Icons.money_off, 'Free', 'No monetization', Colors.green),
                      const Divider(height: 4),
                      _monetizationOption('ads_only', Icons.ads_click, 'Ads Only', 'Earn from ad revenue', Colors.amber),
                      const Divider(height: 4),
                      _monetizationOption('rent', Icons.folder_open, 'Rent', 'Rent for a period', Colors.blue),
                      if (_monetizationType == 'rent') _priceField(),
                      const Divider(height: 4),
                      _monetizationOption('sell', Icons.shopping_cart, 'Sell', 'Sell with a price', Colors.orange),
                      if (_monetizationType == 'sell') _priceField(),
                      const Divider(height: 4),
                      _monetizationOption('user_decision', Icons.touch_app, 'User Decision', 'Let opener choose', Colors.purple),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 🕐 Publish Timing
              const Text("PUBLISH TIMING", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => setState(() { _publishMode = 'instant'; _scheduledDate = null; }),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            children: [
                              Icon(Icons.rocket_launch, color: _publishMode == 'instant' ? Colors.green : Colors.grey, size: 22),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Publish Instantly", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text("Available immediately in library", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Radio<String>(
                                value: 'instant',
                                groupValue: _publishMode,
                                activeColor: Colors.green,
                                onChanged: (v) => setState(() { _publishMode = v!; _scheduledDate = null; }),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 4),
                      InkWell(
                        onTap: () => setState(() { _publishMode = 'schedule'; }),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            children: [
                              Icon(Icons.schedule, color: _publishMode == 'schedule' ? Colors.orange : Colors.grey, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Schedule for Later", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _publishMode == 'schedule' ? Colors.black87 : Colors.grey)),
                                    Text(
                                      _scheduledDate != null
                                          ? "${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year} at ${_scheduledDate!.hour.toString().padLeft(2, '0')}:${_scheduledDate!.minute.toString().padLeft(2, '0')}"
                                          : "Pick a future date & time",
                                      style: TextStyle(fontSize: 10, color: _scheduledDate != null ? Colors.orange : Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Radio<String>(
                                value: 'schedule',
                                groupValue: _publishMode,
                                activeColor: Colors.orange,
                                onChanged: (v) => setState(() => _publishMode = v!),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_publishMode == 'schedule') ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _pickScheduleDate,
                            icon: Icon(Icons.calendar_today, size: 16, color: Colors.orange.shade700),
                            label: Text(
                              _scheduledDate == null ? "Select Date & Time" : "Change Date & Time",
                              style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.orange.shade200),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _selectedDocType == 'note' ? Colors.orange : StarlightTheme.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_publishMode == 'schedule' ? Icons.schedule : Icons.rocket_launch, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _publishMode == 'schedule' ? "Schedule Publication" : (_selectedDocType == 'note' ? "Publish Short Note" : "Publish Reference Book"),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monetizationOption(String value, IconData icon, String title, String subtitle, Color color) {
    final selected = _monetizationType == value;
    return InkWell(
      onTap: () => setState(() => _monetizationType = value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: selected ? Colors.black87 : Colors.grey)),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _monetizationType,
              activeColor: color,
              onChanged: (v) => setState(() => _monetizationType = v!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceField() {
    return Padding(
      padding: const EdgeInsets.only(left: 34, top: 4, bottom: 4),
      child: TextFormField(
        controller: _priceCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          prefixText: '\$ ',
          hintText: 'Enter amount',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        style: const TextStyle(fontSize: 13),
        validator: (val) {
          if (_monetizationType == 'rent' || _monetizationType == 'sell') {
            if (val == null || val.trim().isEmpty) return 'Price is required';
            final parsed = double.tryParse(val.trim());
            if (parsed == null || parsed <= 0) return 'Enter a valid price';
          }
          return null;
        },
      ),
    );
  }

  Widget _pickedFileCard() {
    final file = _pickedFile!;
    final color = _fileKindColor(file.name);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 60,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(_fileKindIcon(file.name), color: color, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _chip(_fileKindLabel(file.name), color),
                    _chip(_formatSize(file.size), Colors.grey),
                  ],
                ),
                const SizedBox(height: 6),
                if (_pickedFilePath != null)
                  Text(
                    _pickedFilePath!,
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _removePickedFile,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, color: Colors.red, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

/// 🏛️ Dashed-border wrapper for the "tap to pick" drop zone. We don't pull in
/// the `dotted_border` package, so this draws a thin dashed rectangle using
/// `CustomPaint` to keep the dependency footprint unchanged.
class DottedBorderContainer extends StatelessWidget {
  final Widget child;
  final Color color;
  const DottedBorderContainer({super.key, required this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(color: color),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  final Color color;
  _DottedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final radius = const Radius.circular(12);
    final rect = RRect.fromRectAndRadius(Offset.zero & size, radius);

    // Walk the rounded rect's perimeter in small straight segments and dash them.
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter old) => old.color != color;
}
