import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme.dart';
import '../services/shorts_service.dart';
import 'shorts_frame_selector.dart';
import 'shorts_upload_progress.dart';

class ShortsUploadScreen extends StatefulWidget {
  const ShortsUploadScreen({super.key});

  @override
  State<ShortsUploadScreen> createState() => _ShortsUploadScreenState();
}

class _ShortsUploadScreenState extends State<ShortsUploadScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  File? _videoFile;
  File? _thumbnailFile;
  VideoPlayerController? _previewController;
  bool _isPreviewInitialized = false;
  String _selectedCategory = 'general';
  String _visibility = 'public';
  bool _isUploading = false;
  final List<String> _tags = [];
  final _tagController = TextEditingController();

  static const int _maxFileSizeMB = 512;

  final List<String> _categories = [
    'general', 'education', 'entertainment', 'music',
    'comedy', 'dance', 'sports', 'gaming', 'news',
    'science', 'technology', 'tutorial', 'vlog',
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
        allowedExtensions: ['mp4', 'mov', 'webm'],
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
          final duration = _previewController!.value.duration;
          if (duration.inSeconds < 3) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video must be at least 3 seconds long'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            _previewController?.dispose();
            _previewController = null;
            return;
          }

          if (duration.inSeconds > 180) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Shorts must be 3 minutes or less'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            _previewController?.dispose();
            _previewController = null;
            return;
          }

          _previewController!.setLooping(true);
          _previewController!.setVolume(0);

          setState(() {
            _videoFile = file;
            _isPreviewInitialized = true;
          });

          _openFrameSelector(file);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load video: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openFrameSelector(File videoFile) async {
    final result = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => ShortsFrameSelectorScreen(videoFile: videoFile),
      ),
    );
    if (result != null && mounted) {
      setState(() => _thumbnailFile = result);
    }
  }

  Future<void> _upload() async {
    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a video first'), backgroundColor: Colors.orange),
      );
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title'), backgroundColor: Colors.orange),
      );
      return;
    }

    final fileSize = await _videoFile!.length();

    try {
      final initResult = await ShortsService.initChunkUpload(
        filename: _videoFile!.path.split('/').last,
        totalSize: fileSize,
        title: title,
        description: _descController.text.trim(),
        category: _selectedCategory,
        tags: _tags,
        visibility: _visibility,
      );

      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ShortsUploadProgressScreen(
            videoFile: _videoFile!,
            thumbnailFile: _thumbnailFile,
            sessionId: initResult['session_id'],
            totalSize: fileSize,
            title: title,
            description: _descController.text.trim(),
            category: _selectedCategory,
            tags: _tags,
            visibility: _visibility,
          ),
        ),
      );

      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag) && _tags.length < 10) {
      setState(() => _tags.add(tag));
      _tagController.clear();
    }
  }

  void _removeTag(int index) {
    setState(() => _tags.removeAt(index));
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Upload Short',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isUploading ? _buildUploadProgress() : _buildForm(),
    );
  }

  Widget _buildUploadProgress() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: StarlightTheme.primaryBlue),
          SizedBox(height: 16),
          Text('Preparing upload...', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVideoPreview(),
          const SizedBox(height: 16),
          if (_thumbnailFile != null) _buildThumbnailPreview(),
          if (_thumbnailFile != null) const SizedBox(height: 16),
          _buildTitleField(),
          const SizedBox(height: 12),
          _buildDescriptionField(),
          const SizedBox(height: 12),
          _buildCategoryDropdown(),
          const SizedBox(height: 12),
          _buildVisibilitySection(),
          const SizedBox(height: 12),
          _buildTagsSection(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _upload,
              style: ElevatedButton.styleFrom(
                backgroundColor: StarlightTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _videoFile == null
                  ? Text('Select Video', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold))
                  : Text('Upload Short', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
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
        height: 280,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _videoFile != null ? StarlightTheme.primaryBlue : Colors.grey[700]!,
            width: _videoFile != null ? 2 : 1,
          ),
        ),
        child: _videoFile != null && _isPreviewInitialized
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _previewController!.value.size.width,
                        height: _previewController!.value.size.height,
                        child: VideoPlayer(_previewController!),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(_previewController!.value.duration),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _fileSizeFormatted(_videoFile!),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: StarlightTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'SHORTS',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : _videoFile != null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: StarlightTheme.primaryBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.videocam,
                          color: StarlightTheme.primaryBlue,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap to select a Short',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Max ${_maxFileSizeMB}MB • 3s - 3min • MP4, MOV, WebM',
                        style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vertical (9:16) recommended',
                        style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 10),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildThumbnailPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StarlightTheme.primaryBlue, width: 1.5),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _thumbnailFile!,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thumbnail Selected',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap to change frame',
                  style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: StarlightTheme.primaryBlue, size: 20),
            onPressed: _videoFile != null ? () => _openFrameSelector(_videoFile!) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: TextField(
        controller: _titleController,
        style: GoogleFonts.poppins(color: Colors.white),
        maxLength: 100,
        buildCounter: (ctx, {required currentLength, required isFocused, required maxLength}) => Text(
          '$currentLength/$maxLength',
          style: TextStyle(color: Colors.grey[600], fontSize: 11),
        ),
        decoration: InputDecoration(
          hintText: 'Title (required)',
          hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
          border: InputBorder.none,
          counterText: '',
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: TextField(
        controller: _descController,
        style: GoogleFonts.poppins(color: Colors.white),
        maxLines: 3,
        maxLength: 500,
        buildCounter: (ctx, {required currentLength, required isFocused, required maxLength}) => Text(
          '$currentLength/$maxLength',
          style: TextStyle(color: Colors.grey[600], fontSize: 11),
        ),
        decoration: InputDecoration(
          hintText: 'Description (optional)',
          hintStyle: GoogleFonts.poppins(color: Colors.grey[600]),
          border: InputBorder.none,
          counterText: '',
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1A1A),
          style: GoogleFonts.poppins(color: Colors.white),
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[500]),
          items: _categories.map((cat) {
            return DropdownMenuItem(
              value: cat,
              child: Text(cat[0].toUpperCase() + cat.substring(1)),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedCategory = v);
          },
        ),
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
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _visibilityChip('Public', 'public', Icons.public),
              const SizedBox(width: 8),
              _visibilityChip('Unlisted', 'unlisted', Icons.link),
              const SizedBox(width: 8),
              _visibilityChip('Private', 'private', Icons.lock),
            ],
          ),
        ],
      ),
    );
  }

  Widget _visibilityChip(String label, String value, IconData icon) {
    final selected = _visibility == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _visibility = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? StarlightTheme.primaryBlue : Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? StarlightTheme.primaryBlue : Colors.grey[600]!,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? Colors.white : Colors.grey, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
            'Tags (${_tags.length}/10)',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          if (_tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.asMap().entries.map((e) => Chip(
                label: Text(e.value, style: const TextStyle(color: Colors.white, fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white),
                onDeleted: () => _removeTag(e.key),
                backgroundColor: StarlightTheme.primaryBlue,
                padding: EdgeInsets.zero,
              )).toList(),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Add tag',
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle, color: StarlightTheme.primaryBlue),
                onPressed: _addTag,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fileSizeFormatted(File file) {
    final bytes = file.lengthSync();
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
}
