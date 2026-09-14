import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:starlight_flutter/core/constants.dart';
import 'package:starlight_flutter/core/storage.dart';

typedef UploadProgressCallback = void Function(double fraction, int bytesUploaded, int totalBytes);

class ChunkedUploadResult {
  final String mediaUrl;
  final String? thumbnailUrl;

  const ChunkedUploadResult({required this.mediaUrl, this.thumbnailUrl});
}

class ChunkedUploadService {
  static const int _chunkSize = 256 * 1024; // 256 KB per chunk

  static Future<ChunkedUploadResult?> uploadMedia({
    required String phoneNumber,
    required File file,
    required String messageType,
    required String clientUuid,
    UploadProgressCallback? onProgress,
  }) async {
    final token = await StarlightStorage.getUserToken();
    if (token == null) return null;

    final fileSize = await file.length();
    if (fileSize <= _chunkSize) {
      return _uploadSingle(file, token, phoneNumber, messageType, clientUuid);
    }

    return _uploadChunked(file, token, phoneNumber, messageType, clientUuid, fileSize, onProgress);
  }

  static Future<ChunkedUploadResult?> _uploadSingle(
    File file, String token, String phoneNumber, String messageType, String clientUuid) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${StarlightConstants.apiBaseUrl}/chat/upload-media-by-phone/$phoneNumber?message_type=$messageType&client_uuid=$clientUuid'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['X-Client-UUID'] = clientUuid;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ChunkedUploadResult(
          mediaUrl: data['media_url'] as String? ?? '',
          thumbnailUrl: data['thumbnail_url'] as String?,
        );
      }
    } catch (e) {
      print('ChunkedUploadService: Upload error - $e');
    }
    return null;
  }

  static Future<ChunkedUploadResult?> _uploadChunked(
    File file, String token, String phoneNumber, String messageType, String clientUuid,
    int fileSize, UploadProgressCallback? onProgress) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final uploadId = '${DateTime.now().millisecondsSinceEpoch}_$clientUuid';
      final totalChunks = (fileSize / _chunkSize).ceil();

      int bytesUploaded = 0;
      final fileHandle = file.openSync();

      try {
        for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
          final start = chunkIndex * _chunkSize;
          final end = (start + _chunkSize > fileSize) ? fileSize : start + _chunkSize;
          final chunkSize = end - start;

          final chunkData = fileHandle.readSync(chunkSize);

          final request = http.MultipartRequest(
            'POST',
            Uri.parse('${StarlightConstants.apiBaseUrl}/chat/upload-chunk'),
          );
          request.headers['Authorization'] = 'Bearer $token';
          request.headers['X-Client-UUID'] = clientUuid;
          request.headers['X-Upload-Id'] = uploadId;
          request.headers['X-Chunk-Index'] = chunkIndex.toString();
          request.headers['X-Total-Chunks'] = totalChunks.toString();
          request.headers['X-File-Name'] = Uri.encodeComponent(fileName);
          request.headers['X-Message-Type'] = messageType;
          request.headers['X-Recipient-Phone'] = phoneNumber;

          request.files.add(http.MultipartFile.fromBytes('file', chunkData, filename: fileName));

          final streamedResponse = await request.send();
          final response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode != 200) {
            fileHandle.closeSync();
            return null;
          }

          bytesUploaded += chunkSize;
          onProgress?.call(bytesUploaded / fileSize, bytesUploaded, fileSize);
        }
      } finally {
        fileHandle.closeSync();
      }

      // Finalize: notify server all chunks uploaded
      final finalResponse = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/chat/upload-complete'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'upload_id': uploadId,
          'client_uuid': clientUuid,
          'recipient_phone': phoneNumber,
          'message_type': messageType,
          'file_name': fileName,
        }),
      );

      if (finalResponse.statusCode == 200) {
        final data = jsonDecode(finalResponse.body);
        return ChunkedUploadResult(
          mediaUrl: data['media_url'] as String? ?? '',
          thumbnailUrl: data['thumbnail_url'] as String?,
        );
      }
    } catch (e) {
      print('ChunkedUploadService: Chunked upload error - $e');
    }
    return null;
  }
}
