import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../services/shorts_service.dart';
import '../services/chunk_manager.dart';

class ShortsUploadProgressScreen extends StatefulWidget {
  final File videoFile;
  final File? thumbnailFile;
  final String sessionId;
  final int totalSize;
  final String title;
  final String description;
  final String category;
  final List<String> tags;
  final String visibility;

  const ShortsUploadProgressScreen({
    super.key,
    required this.videoFile,
    this.thumbnailFile,
    required this.sessionId,
    required this.totalSize,
    required this.title,
    required this.description,
    required this.category,
    required this.tags,
    required this.visibility,
  });

  @override
  State<ShortsUploadProgressScreen> createState() => _ShortsUploadProgressScreenState();
}

class _ShortsUploadProgressScreenState extends State<ShortsUploadProgressScreen> {
  final DynamicChunkManager _chunkManager = DynamicChunkManager();

  bool _isUploading = false;
  bool _isPaused = false;
  bool _isComplete = false;
  bool _hasError = false;
  String _errorMessage = '';
  int _chunkIndex = 0;
  int _totalChunks = 0;
  int _chunksRemaining = 0;
  Timer? _pollTimer;

  double get _progress => (_chunkManager.totalBytesUploaded / widget.totalSize).clamp(0.0, 1.0);
  String get _percentText => '${(_progress * 100).toInt()}%';
  String get _bytesText => '${_formatBytes(_chunkManager.totalBytesUploaded)} / ${_formatBytes(widget.totalSize)}';

  @override
  void initState() {
    super.initState();
    _totalChunks = (widget.totalSize / _chunkManager.currentSize).ceil();
    _chunksRemaining = _totalChunks;
    WidgetsBinding.instance.addPostFrameCallback((_) => _startUpload());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startUpload() async {
    setState(() {
      _isUploading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final file = widget.videoFile;
      final fileSize = await file.length();

      int bytesSent = 0;
      int chunkIdx = 0;

      while (bytesSent < fileSize) {
        if (_isPaused) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        final chunkSize = _chunkManager.currentSize;
        final remaining = fileSize - bytesSent;
        final actualChunkSize = remaining < chunkSize ? remaining : chunkSize;
        final end = bytesSent + actualChunkSize;

        final List<int> chunkBytes = [];
        await for (final chunk in file.openRead(bytesSent, end)) {
          chunkBytes.addAll(chunk);
        }

        final startTime = DateTime.now();

        await ShortsService.uploadChunk(
          sessionId: widget.sessionId,
          chunkIndex: chunkIdx,
          chunksRemaining: _chunksRemaining - 1,
          chunkBytes: chunkBytes,
        );

        final elapsed = DateTime.now().difference(startTime);
        _chunkManager.updateBasedOnPerformance(elapsed, chunkBytes.length);

        bytesSent += actualChunkSize;
        chunkIdx++;
        _chunksRemaining = _totalChunks - chunkIdx;

        if (mounted) {
          setState(() {
            _chunkIndex = chunkIdx;
          });
        }
      }

      // All chunks sent — complete
      final result = await ShortsService.completeChunkUpload(
        widget.sessionId,
        thumbnailPath: widget.thumbnailFile?.path,
      );

      if (mounted) {
        setState(() {
          _isComplete = true;
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Short uploaded successfully!'), backgroundColor: Colors.green),
        );

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isUploading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  void _retry() {
    _chunkManager.resetOnFailure();
    _startUpload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () async {
            if (_isUploading) {
              await ShortsService.cancelChunkUpload(widget.sessionId);
            }
            if (mounted) Navigator.pop(context);
          },
        ),
        title: Text(
          'Uploading Short',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            _buildProgressRing(),
            const SizedBox(height: 32),
            _buildTitle(),
            const SizedBox(height: 8),
            _buildSubtitle(),
            const SizedBox(height: 24),
            _buildProgressBar(),
            const SizedBox(height: 16),
            _buildStats(),
            const Spacer(),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRing() {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: _progress,
            strokeWidth: 8,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(
              _isComplete ? Colors.green : StarlightTheme.primaryBlue,
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isComplete)
                  const Icon(Icons.check_circle, color: Colors.green, size: 36)
                else if (_hasError)
                  const Icon(Icons.error, color: Colors.red, size: 36)
                else
                  Text(
                    _percentText,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      widget.title,
      style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSubtitle() {
    if (_isComplete) {
      return const Text('Upload complete!', style: TextStyle(color: Colors.green, fontSize: 14));
    }
    if (_hasError) {
      return Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center);
    }
    if (_isPaused) {
      return const Text('Paused', style: TextStyle(color: Colors.orange, fontSize: 14));
    }
    return Text(
      'Chunk ${_chunkIndex + 1} of $_totalChunks • ${_chunkManager.currentSize ~/ 1024}KB per chunk',
      style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(
              _isComplete ? Colors.green : StarlightTheme.primaryBlue,
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 8),
        Text(_bytesText, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _statItem('Speed', '${_chunkManager.currentSize ~/ 1024}KB'),
        _statItem('Remaining', '$_chunksRemaining chunks'),
        _statItem('Uploaded', '${_chunkIndex}/${_totalChunks}'),
      ],
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 11)),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_isComplete) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        children: [
          if (_hasError) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StarlightTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ] else if (_isUploading) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _togglePause,
                icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                label: Text(_isPaused ? 'Resume' : 'Pause'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPaused ? Colors.green : Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}
