import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme.dart';
import '../services/video_service.dart';

class VideoCaptionsScreen extends StatefulWidget {
  final String videoId;
  final String videoTitle;

  const VideoCaptionsScreen({
    super.key,
    required this.videoId,
    required this.videoTitle,
  });

  @override
  State<VideoCaptionsScreen> createState() => _VideoCaptionsScreenState();
}

class _VideoCaptionsScreenState extends State<VideoCaptionsScreen> {
  List<Map<String, dynamic>> _captions = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadCaptions();
  }

  Future<void> _loadCaptions() async {
    setState(() => _isLoading = true);
    try {
      final res = await VideoService.getCaptions(widget.videoId);
      if (mounted) {
        setState(() {
          _captions = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

    Future<void> _uploadCaption() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['vtt', 'srt'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.first.path!);
    final language = await _showLanguageDialog();

    if (language == null || !mounted) return;

    setState(() => _isUploading = true);

    try {
      await VideoService.uploadCaption(
        videoId: widget.videoId,
        language: language,
        file: file,
      );
      if (mounted) {
        setState(() => _isUploading = false);
        _loadCaptions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caption uploaded'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _showLanguageDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Select Language', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              'en', 'ar', 'ur', 'fr', 'de', 'es', 'zh', 'hi', 'pt', 'ru', 'ja', 'ko',
            ].map((lang) => ListTile(
              title: Text(_languageName(lang), style: const TextStyle(color: Colors.white)),
              subtitle: Text(lang, style: const TextStyle(color: Colors.grey)),
              onTap: () => Navigator.pop(context, lang),
            )).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCaption(String language) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete Caption', style: TextStyle(color: Colors.white)),
        content: Text('Delete ${_languageName(language)} caption?', style: const TextStyle(color: Colors.grey)),
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

    if (confirm == true && mounted) {
      try {
        await VideoService.deleteCaption(widget.videoId, language);
        _loadCaptions();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _languageName(String code) {
    const names = {
      'en': 'English', 'ar': 'Arabic', 'ur': 'Urdu', 'fr': 'French',
      'de': 'German', 'es': 'Spanish', 'zh': 'Chinese', 'hi': 'Hindi',
      'pt': 'Portuguese', 'ru': 'Russian', 'ja': 'Japanese', 'ko': 'Korean',
    };
    return names[code] ?? code.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        title: Text(
          'Captions',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.videoTitle,
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : _uploadCaption,
                        icon: _isUploading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.add),
                        label: const Text('Upload'),
                        style: ElevatedButton.styleFrom(backgroundColor: StarlightTheme.primaryBlue),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.grey),
                Expanded(
                  child: _captions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.subtitles, size: 64, color: Colors.grey[600]),
                              const SizedBox(height: 16),
                              Text(
                                'No captions yet',
                                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Upload VTT or SRT files',
                                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _captions.length,
                          itemBuilder: (context, index) {
                            final caption = _captions[index];
                            return ListTile(
                              leading: const Icon(Icons.subtitles, color: StarlightTheme.primaryBlue),
                              title: Text(
                                _languageName(caption['language'] ?? ''),
                                style: GoogleFonts.poppins(color: Colors.white),
                              ),
                              subtitle: Text(
                                caption['title'] ?? '',
                                style: GoogleFonts.poppins(color: Colors.grey),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteCaption(caption['language']),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
