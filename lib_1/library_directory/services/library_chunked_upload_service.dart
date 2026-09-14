import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import '../../core/storage.dart';
import 'library_chunk_manager.dart';

class LibraryChunkUploadState {
  final String sessionId;
  final String filePath;
  final int fileSize;
  final int totalChunks;
  int uploadedChunks;
  bool isPaused;
  bool isCancelled;
  bool hasError;
  String errorMessage;
  int bytesUploaded;

  LibraryChunkUploadState({
    required this.sessionId,
    required this.filePath,
    required this.fileSize,
    required this.totalChunks,
    this.uploadedChunks = 0,
    this.isPaused = false,
    this.isCancelled = false,
    this.hasError = false,
    this.errorMessage = '',
    this.bytesUploaded = 0,
  });
}

class LibraryChunkedUploadService {
  static String get _baseUrl => StarlightConstants.apiBaseUrl;

  static LibraryChunkUploadState? _currentState;
  static LibraryChunkManager? _chunkManager;
  static Completer<void>? _pauseCompleter;

  static LibraryChunkUploadState? get currentState => _currentState;
  static bool get isUploading => _currentState != null && !_currentState!.isPaused && !_currentState!.isCancelled && !_currentState!.hasError;

  /// Initialize a chunk upload session on the server.
  static Future<Map<String, dynamic>> initChunkUpload({
    required String filePath,
    required String fileName,
    required int fileSize,
    required String title,
    required String author,
    required String topic,
    required String docType,
    required String monetizationType,
    double price = 0.0,
    String? scheduledAt,
    String? thumbnailPath,
  }) async {
    final token = await StarlightStorage.getUserToken();
    final uri = Uri.parse('$_baseUrl/library/upload/chunk/init');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['filename'] = fileName
      ..fields['file_size'] = fileSize.toString()
      ..fields['title'] = title
      ..fields['author'] = author
      ..fields['topic'] = topic
      ..fields['doc_type'] = docType
      ..fields['monetization_type'] = monetizationType
      ..fields['price'] = price.toStringAsFixed(2);

    if (scheduledAt != null) {
      request.fields['scheduled_at'] = scheduledAt;
    }
    if (thumbnailPath != null && await File(thumbnailPath).exists()) {
      request.files.add(await http.MultipartFile.fromPath('thumbnail', thumbnailPath));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to init chunk upload (${response.statusCode}): ${response.body}');
  }

  /// Upload a single chunk to the server.
  static Future<void> uploadChunk({
    required String sessionId,
    required int chunkIndex,
    required List<int> chunkBytes,
  }) async {
    final token = await StarlightStorage.getUserToken();
    final uri = Uri.parse('$_baseUrl/library/upload/chunk/$sessionId/$chunkIndex');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('chunk', chunkBytes, filename: 'chunk_$chunkIndex'));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Chunk upload failed (${response.statusCode})');
    }
  }

  /// Get which chunks have already been received by the server (for resume).
  static Future<List<int>> getReceivedChunks(String sessionId) async {
    final token = await StarlightStorage.getUserToken();
    final uri = Uri.parse('$_baseUrl/library/upload/chunk/$sessionId/status');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> received = data['received_chunks'] ?? [];
      return received.cast<int>();
    }
    throw Exception('Failed to get chunk status');
  }

  /// Finalize the upload after all chunks have been sent.
  static Future<Map<String, dynamic>> completeChunkUpload(String sessionId) async {
    final token = await StarlightStorage.getUserToken();
    final uri = Uri.parse('$_baseUrl/library/upload/chunk/$sessionId/complete');
    final response = await http.post(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to complete chunk upload (${response.statusCode})');
  }

  /// Cancel an in-progress chunk upload on the server.
  static Future<void> cancelChunkUpload(String sessionId) async {
    final token = await StarlightStorage.getUserToken();
    final uri = Uri.parse('$_baseUrl/library/upload/chunk/$sessionId');
    await http.delete(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  /// Start uploading a file in chunks with pause/resume/retry support.
  ///
  /// Returns the final result map (with book id etc.) on success.
  /// Throws on failure.
  static Future<Map<String, dynamic>> uploadFile({
    required String filePath,
    required String fileName,
    required int fileSize,
    required String title,
    required String author,
    required String topic,
    required String docType,
    required String monetizationType,
    double price = 0.0,
    String? scheduledAt,
    String? thumbnailPath,
    void Function(double progress, int bytesUploaded, int totalBytes)? onProgress,
    void Function(String message)? onError,
  }) async {
    _pauseCompleter = null;

    // 1. Init chunk session
    final initResult = await initChunkUpload(
      filePath: filePath,
      fileName: fileName,
      fileSize: fileSize,
      title: title,
      author: author,
      topic: topic,
      docType: docType,
      monetizationType: monetizationType,
      price: price,
      scheduledAt: scheduledAt,
      thumbnailPath: thumbnailPath,
    );

    final sessionId = initResult['session_id'] as String;
    final totalChunks = initResult['total_chunks'] as int? ?? ((fileSize / (1024 * 1024)).ceil());

    _chunkManager = LibraryChunkManager();
    _currentState = LibraryChunkUploadState(
      sessionId: sessionId,
      filePath: filePath,
      fileSize: fileSize,
      totalChunks: totalChunks,
    );

    // 2. Check which chunks already received (for resume support)
    Set<int> receivedChunks = {};
    try {
      final received = await getReceivedChunks(sessionId);
      receivedChunks = received.toSet();
      _currentState!.uploadedChunks = received.length;
      _currentState!.bytesUploaded = received.length * _chunkManager!.currentSize;
    } catch (_) {
      // First upload, no chunks yet
    }

    // 3. Upload chunks
    final file = File(filePath);
    final fileHandle = file.openSync();
    int totalBytesUploaded = _currentState!.bytesUploaded;
    int chunkIndex = 0;
    int consecutiveRetries = 0;
    const maxConsecutiveRetries = 3;

    try {
      while (chunkIndex < totalChunks) {
        // Check pause
        if (_currentState!.isPaused) {
          _pauseCompleter = Completer<void>();
          await _pauseCompleter!.future;
          _pauseCompleter = null;
        }

        if (_currentState!.isCancelled) {
          await cancelChunkUpload(sessionId);
          throw Exception('Upload cancelled by user');
        }

        // Skip already-received chunks
        if (receivedChunks.contains(chunkIndex)) {
          chunkIndex++;
          continue;
        }

        // Get chunk size from dynamic manager
        final chunkSize = _chunkManager!.currentSize;
        final start = chunkIndex * chunkSize;
        final actualChunkSize = min(chunkSize, fileSize - start);

        if (actualChunkSize <= 0) {
          chunkIndex++;
          continue;
        }

        // Read chunk bytes
        fileHandle.setPositionSync(start);
        final chunkBytes = fileHandle.readSync(actualChunkSize);
        final chunkStartTime = DateTime.now();

        // Upload chunk
        try {
          await uploadChunk(
            sessionId: sessionId,
            chunkIndex: chunkIndex,
            chunkBytes: chunkBytes,
          );

          final elapsed = DateTime.now().difference(chunkStartTime);
          _chunkManager!.updateBasedOnPerformance(elapsed, actualChunkSize);

          totalBytesUploaded += actualChunkSize;
          _currentState!.uploadedChunks = chunkIndex + 1;
          _currentState!.bytesUploaded = totalBytesUploaded;
          consecutiveRetries = 0;

          onProgress?.call(
            totalBytesUploaded / fileSize,
            totalBytesUploaded,
            fileSize,
          );

          chunkIndex++;
        } catch (e) {
          consecutiveRetries++;
          _chunkManager!.resetOnFailure();

          if (consecutiveRetries >= maxConsecutiveRetries) {
            _currentState!.hasError = true;
            _currentState!.errorMessage = 'Upload failed after $maxConsecutiveRetries retries: $e';
            onError?.call(_currentState!.errorMessage);
            throw Exception(_currentState!.errorMessage);
          }

          // Brief delay before retry
          await Future.delayed(Duration(seconds: consecutiveRetries));
          // Retry same chunk (don't increment chunkIndex)
        }
      }

      // 4. Complete the upload
      final result = await completeChunkUpload(sessionId);
      _currentState = null;
      _chunkManager = null;

      return result;
    } finally {
      fileHandle.closeSync();
    }
  }

  /// Pause the ongoing upload.
  static void pause() {
    if (_currentState != null && !_currentState!.isPaused) {
      _currentState!.isPaused = true;
    }
  }

  /// Resume the paused upload.
  static void resume() {
    if (_currentState != null && _currentState!.isPaused) {
      _currentState!.isPaused = false;
      _pauseCompleter?.complete();
    }
  }

  /// Cancel the ongoing upload.
  static Future<void> cancel() async {
    if (_currentState != null) {
      _currentState!.isCancelled = true;
      _currentState!.isPaused = false;
      _pauseCompleter?.complete();
    }
  }

  /// Retry after an error (resets error state and continues).
  static void retry() {
    if (_currentState != null && _currentState!.hasError) {
      _currentState!.hasError = false;
      _currentState!.errorMessage = '';
    }
  }
}
