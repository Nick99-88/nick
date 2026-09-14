import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../services/chunk_manager.dart';
import '../services/video_service.dart';
import '../screens/video_directory.dart';

class VideoUploadProgressScreen extends StatefulWidget {
  final File videoFile;
  final String sessionId;
  final int totalSize;

  const VideoUploadProgressScreen({
    super.key,
    required this.videoFile,
    required this.sessionId,
    required this.totalSize,
  });

  @override
  State<VideoUploadProgressScreen> createState() => _VideoUploadProgressScreenState();
}

class _VideoUploadProgressScreenState extends State<VideoUploadProgressScreen> {
  final DynamicChunkManager _chunkManager = DynamicChunkManager();

  bool _isVerifying = false;
  bool _isUploading = false;
  bool _isPaused = false;
  bool _isComplete = false;
  bool _hasError = false;
  bool _isOffline = false;
  String _errorMessage = '';
  int _chunkIndex = 0;
  int _resumePosition = 0;
  Completer<void>? _resumeCompleter;
  StreamSubscription? _connectivitySub;
  WebSocketChannel? _wsChannel;
  Timer? _pollTimer;
  int _wsRetries = 0;

  double get _progress => (_chunkManager.totalBytesUploaded / widget.totalSize).clamp(0.0, 1.0);
  String get _percentText => '${(_progress * 100).toInt()}%';
  String get _bytesText => '${_formatBytes(_chunkManager.totalBytesUploaded)} / ${_formatBytes(widget.totalSize)}';

  @override
  void initState() {
    super.initState();
    _startConnectivityMonitoring();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _connectWebSocket();
      await _restoreState();
      _startVerification();
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _wsChannel?.sink.close();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startConnectivityMonitoring() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = results.any((r) => r != ConnectivityResult.none);
      if (!isConnected && !_isComplete && !_hasError) {
        setState(() => _isOffline = true);
        _isPaused = true;
      } else if (isConnected && _isOffline) {
        setState(() => _isOffline = false);
        _togglePause();
      }
    });
  }

  void _connectWebSocket() {
    try {
      final baseUrl = StarlightConstants.apiBaseUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');
      final wsUrl = Uri.parse('$baseUrl/api/video/upload/chunk/${widget.sessionId}/ws');
      _wsChannel = WebSocketChannel.connect(wsUrl);
      _wsRetries = 0;

      _wsChannel!.stream.listen(
        (raw) {
          try {
            final data = jsonDecode(raw as String) as Map<String, dynamic>;
            if (data['type'] == 'progress') {
              final serverBytes = data['uploaded_bytes'] as int;
              if (serverBytes > _chunkManager.totalBytesUploaded) {
                _chunkManager.restoreBytes(serverBytes);
                _chunkIndex = (data['chunk_index'] as int?) ?? _chunkIndex;
                setState(() {});
              }
            }
          } catch (_) {}
        },
        onDone: () {
          _wsChannel = null;
          if (!_isComplete && !_hasError && _wsRetries < 3) {
            _wsRetries++;
            Future.delayed(Duration(seconds: 2 * _wsRetries), _connectWebSocket);
          } else if (!_isComplete && !_hasError) {
            _startPolling();
          }
        },
        onError: (_) {
          _wsChannel = null;
          if (!_isComplete && !_hasError && _wsRetries < 3) {
            _wsRetries++;
            Future.delayed(Duration(seconds: 2 * _wsRetries), _connectWebSocket);
          } else if (!_isComplete && !_hasError) {
            _startPolling();
          }
        },
      );
    } catch (_) {
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_isComplete || _hasError) {
        _pollTimer?.cancel();
        return;
      }
      try {
        final status = await VideoService.getChunkStatus(widget.sessionId);
        final serverBytes = status['uploaded_bytes'] as int? ?? 0;
        if (serverBytes > _chunkManager.totalBytesUploaded) {
          _chunkManager.restoreBytes(serverBytes);
          if (mounted) setState(() {});
        }
      } catch (_) {}
    });
  }

  Future<void> _restoreState() async {
    final saved = await StarlightStorage.getUploadState(widget.sessionId);
    if (saved == null) return;

    final uploadedBytes = saved['uploaded_bytes'] as int? ?? 0;
    final lastIndex = saved['last_chunk_index'] as int? ?? 0;

    if (uploadedBytes > 0) {
      try {
        final serverStatus = await VideoService.getChunkStatus(widget.sessionId);
        final serverBytes = serverStatus['uploaded_bytes'] as int? ?? 0;
        if (serverBytes > 0) {
          _chunkIndex = (serverStatus['uploaded_chunks'] as List?)?.length ?? lastIndex;
          _resumePosition = serverBytes;
          _chunkManager.restoreBytes(serverBytes);
          _chunkManager.currentSize = DynamicChunkManager.minSize;
          if (serverBytes >= widget.totalSize) {
            await VideoService.completeChunkUpload(widget.sessionId);
            if (mounted) setState(() => _isComplete = true);
            return;
          }
        }
      } catch (_) {
        _chunkIndex = lastIndex;
        _resumePosition = uploadedBytes;
        _chunkManager.restoreBytes(uploadedBytes);
      }
    }
  }

  Future<void> _startVerification() async {
    if (_isComplete) return;
    setState(() => _isVerifying = true);
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      final serverStatus = await VideoService.getChunkStatus(widget.sessionId);
      final serverTotalSize = serverStatus['total_size'] as int? ?? widget.totalSize;
      final serverHeadHash = serverStatus['head_hash'] as String?;
      final serverTailHash = serverStatus['tail_hash'] as String?;

      if (widget.videoFile.lengthSync() != serverTotalSize) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _isVerifying = false;
          _errorMessage = 'File size mismatch. The source file may have been modified.';
        });
        return;
      }

      if (serverHeadHash != null && serverTailHash != null) {
        final raf = widget.videoFile.openSync(mode: FileMode.read);
        final fileSize = widget.totalSize;
        final headChunk = raf.readSync(fileSize < 65536 ? fileSize : 65536);
        final tailChunk = fileSize >= 65536
            ? (raf..setPositionSync(fileSize - 65536)).readSync(65536)
            : headChunk;
        raf.closeSync();

        final localHeadHash = sha256.convert(headChunk).toString();
        final localTailHash = sha256.convert(tailChunk).toString();

        if (localHeadHash != serverHeadHash || localTailHash != serverTailHash) {
          if (!mounted) return;
          setState(() {
            _hasError = true;
            _isVerifying = false;
            _errorMessage = 'File checksum mismatch. The file content has changed since upload started.';
          });
          return;
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isVerifying = false);
    if (_isComplete) return;
    _startUpload();
  }

  Future<void> _startUpload() async {
    if (_isComplete) return;
    setState(() => _isUploading = true);
    final file = widget.videoFile;
    final fileSize = widget.totalSize;

    RandomAccessFile? raf;
    try {
      raf = file.openSync(mode: FileMode.read);
      int position = _resumePosition;

      while (position < fileSize && !_hasError) {
        if (_isPaused) {
          _resumeCompleter = Completer<void>();
          await _resumeCompleter!.future;
          _resumeCompleter = null;
        }
        if (!mounted) return;

        final remaining = fileSize - position;
        final bytesToRead = remaining <= _chunkManager.currentSize
            ? remaining
            : _chunkManager.currentSize;
        final chunkBytes = raf.readSync(bytesToRead);

        final stopwatch = Stopwatch()..start();
        bool uploaded = false;

        for (int attempt = 0; attempt < 5 && !uploaded; attempt++) {
          if (attempt > 0) {
            _chunkManager.resetOnFailure();
            final delay = min(pow(2, attempt).toInt(), 30);
            await Future.delayed(Duration(seconds: delay));
          }
          try {
            await VideoService.uploadChunkBytes(
              sessionId: widget.sessionId,
              chunkIndex: _chunkIndex,
              chunkBytes: chunkBytes,
            );
            uploaded = true;
          } catch (e) {
            if (attempt >= 4) {
              throw e;
            }
          }
        }

        if (!mounted) return;
        stopwatch.stop();
        _chunkManager.updateBasedOnPerformance(stopwatch.elapsed, chunkBytes.length);

        setState(() => _chunkIndex++);

        unawaited(StarlightStorage.saveUploadState(
          sessionId: widget.sessionId,
          filePath: file.path,
          totalSize: fileSize,
          uploadedBytes: _chunkManager.totalBytesUploaded,
          lastChunkIndex: _chunkIndex,
        ));

        position += bytesToRead;
      }

      if (!mounted || _hasError || _isComplete) return;

      await VideoService.completeChunkUpload(widget.sessionId);
      await StarlightStorage.clearUploadState(widget.sessionId);
      if (!mounted) return;

      setState(() {
        _isComplete = true;
        _isUploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = 'Upload failed: $e';
        _isUploading = false;
      });
    } finally {
      raf?.closeSync();
    }
  }

  void _togglePause() {
    if (_isPaused) {
      _resumeCompleter?.complete();
    }
    setState(() => _isPaused = !_isPaused);
  }

  void _cancel() async {
    await StarlightStorage.clearUploadState(widget.sessionId);
    try {
      await VideoService.cancelChunkUpload(widget.sessionId);
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  void _done() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const VideoDirectory()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        title: Text(
          _isComplete ? 'Video Uploaded' : (_hasError ? 'Upload Failed' : 'Uploading Video'),
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            _isUploading || _isPaused ? Icons.close : Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: _isUploading || _isPaused ? _cancel : _done,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isVerifying) ...[
                SizedBox(
                  width: 80, height: 80,
                  child: Stack(alignment: Alignment.center, children: [
                    CircularProgressIndicator(strokeWidth: 6, backgroundColor: Colors.grey[800], valueColor: const AlwaysStoppedAnimation<Color>(StarlightTheme.primaryBlue)),
                    const Icon(Icons.verified_user, color: StarlightTheme.primaryBlue, size: 36),
                  ]),
                ),
                const SizedBox(height: 24),
                Text('Verifying Integrity...', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Checking file consistency before upload', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14)),
              ] else if (!_isComplete && !_hasError) ...[
                _buildProgressCircle(),
                const SizedBox(height: 16),
                Text(
                  _isOffline
                      ? 'No Internet Connection'
                      : (_isPaused ? 'Upload Paused' : 'Uploading your video...'),
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_isOffline)
                  Text(
                    'Waiting for network...',
                    style: GoogleFonts.poppins(color: Colors.orange, fontSize: 14),
                  ),
                if (!_isOffline) ...[
                  Text(
                    _bytesText,
                    style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _chunkManager.currentSize >= 1024 * 1024
                        ? 'Chunk: ${( _chunkManager.currentSize / (1024 * 1024)).toStringAsFixed(1)} MB'
                        : 'Chunk: ${( _chunkManager.currentSize / 1024).toInt()} KB',
                    style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionButton(
                      icon: _isPaused ? Icons.play_arrow : Icons.pause,
                      label: _isPaused ? 'Resume' : 'Pause',
                      color: StarlightTheme.primaryBlue,
                      onTap: _isOffline ? null : _togglePause,
                    ),
                    const SizedBox(width: 16),
                    _buildActionButton(
                      icon: Icons.close,
                      label: 'Cancel',
                      color: StarlightTheme.errorRed,
                      onTap: _cancel,
                    ),
                  ],
                ),
              ] else if (_isComplete) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 80),
                const SizedBox(height: 16),
                Text(
                  'Upload Complete!',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your video is now being processed',
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _done,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StarlightTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('View My Videos', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else ...[
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _cancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Go Back', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCircle() {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: _progress,
            strokeWidth: 8,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(
              _isOffline ? Colors.red : (_isPaused ? Colors.orange : StarlightTheme.accentGreen),
            ),
          ),
          Text(
            _percentText,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toInt()} KB';
    return '$bytes B';
  }
}
