import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../services/library_chunked_upload_service.dart';

class LibraryUploadProgressScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  final int fileSize;
  final String title;
  final String author;
  final String topic;
  final String docType;
  final String monetizationType;
  final double price;
  final String? scheduledAt;
  final String? thumbnailPath;

  const LibraryUploadProgressScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.title,
    required this.author,
    required this.topic,
    required this.docType,
    required this.monetizationType,
    this.price = 0.0,
    this.scheduledAt,
    this.thumbnailPath,
  });

  @override
  State<LibraryUploadProgressScreen> createState() => _LibraryUploadProgressScreenState();
}

class _LibraryUploadProgressScreenState extends State<LibraryUploadProgressScreen> {
  double _progress = 0.0;
  int _bytesUploaded = 0;
  bool _isPaused = false;
  bool _hasError = false;
  bool _isComplete = false;
  bool _isOffline = false;
  String _errorMessage = '';
  StreamSubscription? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _startConnectivityMonitoring();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startUpload());
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  void _startConnectivityMonitoring() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (!isConnected && !_isComplete && !_hasError && !_isPaused) {
        setState(() => _isOffline = true);
        LibraryChunkedUploadService.pause();
      } else if (isConnected && _isOffline) {
        setState(() => _isOffline = false);
        LibraryChunkedUploadService.resume();
      }
    });
  }

  Future<void> _startUpload() async {
    try {
      final result = await LibraryChunkedUploadService.uploadFile(
        filePath: widget.filePath,
        fileName: widget.fileName,
        fileSize: widget.fileSize,
        title: widget.title,
        author: widget.author,
        topic: widget.topic,
        docType: widget.docType,
        monetizationType: widget.monetizationType,
        price: widget.price,
        scheduledAt: widget.scheduledAt,
        thumbnailPath: widget.thumbnailPath,
        onProgress: (progress, bytesUploaded, totalBytes) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            _bytesUploaded = bytesUploaded;
          });
        },
        onError: (message) {
          if (!mounted) return;
          setState(() {
            _hasError = true;
            _errorMessage = message;
          });
        },
      );

      if (!mounted) return;
      setState(() => _isComplete = true);

      // Return result and pop
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.pop(context, result);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _togglePause() {
    final state = LibraryChunkedUploadService.currentState;
    if (state == null) return;

    if (state.isPaused) {
      LibraryChunkedUploadService.resume();
      setState(() => _isPaused = false);
    } else {
      LibraryChunkedUploadService.pause();
      setState(() => _isPaused = true);
    }
  }

  Future<void> _cancelUpload() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Upload?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text('The uploaded chunks will be discarded.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Uploading')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await LibraryChunkedUploadService.cancel();
      if (mounted) Navigator.pop(context, null);
    }
  }

  void _retryUpload() {
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });
    LibraryChunkedUploadService.retry();
    _startUpload();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated icon
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isComplete
                    ? const Icon(Icons.check_circle, key: ValueKey('done'), size: 72, color: Colors.green)
                    : _hasError
                        ? const Icon(Icons.error_outline, key: ValueKey('error'), size: 72, color: Colors.red)
                        : _isPaused
                            ? const Icon(Icons.pause_circle_outline, key: ValueKey('paused'), size: 72, color: Colors.orange)
                            : const Icon(Icons.cloud_upload_outlined, key: ValueKey('uploading'), size: 72, color: StarlightTheme.primaryBlue),
              ),
              const SizedBox(height: 24),

              // File name
              Text(
                widget.fileName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Document title
              Text(
                widget.title,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 32),

              // Progress bar
              if (!_hasError && !_isComplete) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isPaused ? Colors.orange : StarlightTheme.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${(_progress * 100).toInt()}% — ${_formatBytes(_bytesUploaded)} / ${_formatBytes(widget.fileSize)}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],

              // Error message
              if (_hasError) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              // Offline indicator
              if (_isOffline) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off, size: 14, color: Colors.orange),
                      SizedBox(width: 6),
                      Text('No internet — paused', style: TextStyle(fontSize: 11, color: Colors.orange)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isComplete) ...[
                    const Text('Upload complete!', style: TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold)),
                  ] else if (_hasError) ...[
                    _actionButton(Icons.refresh_rounded, 'Retry', StarlightTheme.primaryBlue, _retryUpload),
                    const SizedBox(width: 16),
                    _actionButton(Icons.close_rounded, 'Dismiss', Colors.grey, () => Navigator.pop(context, null)),
                  ] else ...[
                    _actionButton(
                      _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      _isPaused ? 'Resume' : 'Pause',
                      _isPaused ? Colors.green : Colors.orange,
                      _togglePause,
                    ),
                    const SizedBox(width: 16),
                    _actionButton(Icons.close_rounded, 'Cancel', Colors.red, _cancelUpload),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      style: ElevatedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withOpacity(0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: color.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }
}
