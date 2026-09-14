import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme.dart';
import '../services/video_service.dart';
import '../widgets/video_upload_progress.dart';

class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({super.key});

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  File? _videoFile;
  File? _thumbnailFile;
  VideoPlayerController? _previewController;
  bool _isPreviewInitialized = false;
  String _selectedCategory = 'general';
  String _visibility = 'public';
  bool _extractAudio = false;
  bool _scheduleUpload = false;
  DateTime? _scheduledTime;
  bool _isUploading = false;
  final List<String> _tags = [];
  final _tagController = TextEditingController();

  static const int _maxDescriptionLength = 2000;
  static const int _maxFileSizeMB = 2048;

  final List<String> _categories = [
    'general', 'education', 'entertainment', 'gaming',
    'music', 'news', 'science', 'sports', 'technology', 'vlog',
    'tutorial', 'documentary', 'comedy', 'film', 'animation',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _tagController.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'avi', 'mkv', 'webm'],
      );
      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        final file = File(result.files.first.path!);
        final fileSizeMB = file.lengthSync() / (1024 * 1024);

        if (fileSizeMB > _maxFileSizeMB) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File too large (${fileSizeMB.toStringAsFixed(0)}MB). Max: ${_maxFileSizeMB}MB'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        _previewController?.dispose();
        _previewController = VideoPlayerController.file(file);

        try {
          await _previewController!.initialize();
          if (mounted) {
            setState(() {
              _videoFile = file;
              _isPreviewInitialized = true;
            });
            _previewController!.play();
          }
        } catch (e) {
          if (mounted) {
            setState(() => _videoFile = file);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file picker: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _pickThumbnail() async {
    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
      setState(() => _thumbnailFile = File(result.files.first.path!));
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag) && _tags.length < 15) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(int index) {
    setState(() => _tags.removeAt(index));
  }

  Future<void> _pickScheduledTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null && mounted) {
        setState(() => _scheduledTime = DateTime(
          date.year, date.month, date.day,
          time.hour, time.minute,
        ));
      }
    }
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a video file'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_scheduleUpload && _scheduledTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a schedule time'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final file = _videoFile!;
      final fileSize = file.lengthSync();
      final raf = file.openSync(mode: FileMode.read);
      final headChunk = raf.readSync(fileSize < 65536 ? fileSize : 65536);
      final tailChunk = fileSize >= 65536
          ? (raf..setPositionSync(fileSize - 65536)).readSync(65536)
          : headChunk;
      raf.closeSync();
      final headHash = sha256.convert(headChunk).toString();
      final tailHash = sha256.convert(tailChunk).toString();

      List<int>? thumbBytes;
      if (_thumbnailFile != null) {
        thumbBytes = await _thumbnailFile!.readAsBytes();
      }

      final initResult = await VideoService.initChunkUpload(
        filename: file.path.split(Platform.pathSeparator).last,
        totalSize: fileSize,
        headHash: headHash,
        tailHash: tailHash,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: _selectedCategory,
        tags: _tags,
        visibility: _visibility,
        extractAudio: _extractAudio,
        scheduledTime: _scheduleUpload ? _scheduledTime?.toIso8601String() : null,
        thumbnailBytes: thumbBytes,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VideoUploadProgressScreen(
            videoFile: _videoFile!,
            sessionId: initResult['session_id'],
            totalSize: fileSize,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        title: Text(
          'Upload Video',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildUploadForm(),
    );
  }

  Widget _buildUploadForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildVideoPreview(),
          const SizedBox(height: 16),
          _buildThumbnailPicker(),
          const SizedBox(height: 24),
          TextFormField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Title',
              labelStyle: TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Color(0xFF1A1A1A),
              border: OutlineInputBorder(),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            maxLength: 200,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descController,
            style: const TextStyle(color: Colors.white),
            maxLines: 6,
            maxLength: _maxDescriptionLength,
            decoration: InputDecoration(
              labelText: 'Description',
              labelStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: const OutlineInputBorder(),
              counterText: '${_descController.text.length}/$_maxDescriptionLength',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Category',
              labelStyle: TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Color(0xFF1A1A1A),
              border: OutlineInputBorder(),
            ),
            items: _categories.map((c) => DropdownMenuItem(
              value: c,
              child: Text(c[0].toUpperCase() + c.substring(1)),
            )).toList(),
            onChanged: (v) => setState(() => _selectedCategory = v!),
          ),
          const SizedBox(height: 16),
          _buildTagsSection(),
          const SizedBox(height: 16),
          _buildVisibilitySection(),
          const SizedBox(height: 16),
          _buildScheduleSection(),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audio Mode',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                Text(
                  'Extract MP3 for audio-only playback',
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
            value: _extractAudio,
            onChanged: (v) => setState(() => _extractAudio = v),
            activeColor: StarlightTheme.primaryBlue,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _upload,
              style: ElevatedButton.styleFrom(
                backgroundColor: StarlightTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isUploading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      _videoFile == null ? 'Select a Video First' : (_scheduleUpload ? 'Schedule Upload' : 'Upload Video'),
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    return InkWell(
      onTap: _videoFile == null ? _pickVideo : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _videoFile != null ? StarlightTheme.primaryBlue : Colors.grey,
          ),
        ),
        child: _videoFile != null && _isPreviewInitialized
            ? Stack(
                children: [
                  VideoPlayer(_previewController!),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        _formatDuration(_previewController!.value.duration),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        _fileSizeFormatted(_videoFile!),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              )
            : _videoFile != null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_file, color: Colors.grey, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to select video',
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Max ${_maxFileSizeMB}MB • MP4, MOV, AVI, MKV, WebM',
                        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tags (${_tags.length}/15)',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._tags.asMap().entries.map((e) => Chip(
                label: Text(e.value, style: const TextStyle(color: Colors.white)),
                deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white),
                onDeleted: () => _removeTag(e.key),
                backgroundColor: StarlightTheme.primaryBlue,
              )),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _tagController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Add tag',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add, size: 18, color: StarlightTheme.primaryBlue),
                      onPressed: _addTag,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilitySection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visibility',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildVisibilityOption('public', Icons.public, 'Public', 'Anyone can search and view'),
          _buildVisibilityOption('unlisted', Icons.link, 'Unlisted', 'Only people with the link can view'),
          _buildVisibilityOption('private', Icons.lock, 'Private', 'Only you can view'),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      children: [
        SwitchListTile(
          title: Text(
            'Schedule Upload',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          subtitle: _scheduleUpload && _scheduledTime != null
              ? Text(
                  'Scheduled for: ${_scheduledTime!.toString().split('.')[0]}',
                  style: GoogleFonts.poppins(color: StarlightTheme.primaryBlue, fontSize: 12),
                )
              : null,
          value: _scheduleUpload,
          onChanged: (v) => setState(() => _scheduleUpload = v),
          activeColor: StarlightTheme.primaryBlue,
        ),
        if (_scheduleUpload)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: _pickScheduledTime,
              icon: const Icon(Icons.calendar_today, color: StarlightTheme.primaryBlue),
              label: Text(
                _scheduledTime != null
                    ? 'Change: ${_scheduledTime!.toString().split('.')[0]}'
                    : 'Pick Date & Time',
                style: const TextStyle(color: StarlightTheme.primaryBlue),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: StarlightTheme.primaryBlue),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVisibilityOption(String value, IconData icon, String title, String subtitle) {
    final isSelected = _visibility == value;
    return InkWell(
      onTap: () => setState(() => _visibility = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? StarlightTheme.primaryBlue.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? StarlightTheme.primaryBlue : Colors.grey[700]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? StarlightTheme.primaryBlue : Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: isSelected ? StarlightTheme.primaryBlue : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: StarlightTheme.primaryBlue, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailPicker() {
    return InkWell(
      onTap: _pickThumbnail,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _thumbnailFile != null ? StarlightTheme.primaryBlue : Colors.grey,
          ),
          image: _thumbnailFile != null
              ? DecorationImage(
                  image: FileImage(_thumbnailFile!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: _thumbnailFile == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image, color: Colors.grey[600], size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'Default Thumbnail',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Tap to customize',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            : Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Tap to change',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildFilePicker({
    required String title,
    required IconData icon,
    required File? file,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null ? StarlightTheme.primaryBlue : Colors.grey,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: file != null ? StarlightTheme.primaryBlue : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (file != null)
                    Text(
                      file.path.split(Platform.pathSeparator).last,
                      style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                    ),
                ],
              ),
            ),
            Icon(
              file != null ? Icons.check_circle : Icons.add,
              color: file != null ? Colors.green : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _fileSizeFormatted(File file) {
    final bytes = file.lengthSync();
    if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(0)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}
