import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class ChatMediaStorage {
  static final ChatMediaStorage instance = ChatMediaStorage._init();
  static const _uuid = Uuid();

  ChatMediaStorage._init();

  String? _baseDir;

  Future<String> get baseDirectory async {
    if (_baseDir != null) return _baseDir!;
    final appDir = await getApplicationSupportDirectory();
    _baseDir = path.join(appDir.path, 'StarlightChat');
    await _createDirectories();
    return _baseDir!;
  }

  Future<void> _createDirectories() async {
    final base = await baseDirectory;
    await Directory(path.join(base, 'images')).create(recursive: true);
    await Directory(path.join(base, 'videos')).create(recursive: true);
    await Directory(path.join(base, 'voice')).create(recursive: true);
    await Directory(path.join(base, 'documents')).create(recursive: true);
    await Directory(path.join(base, 'thumbnails')).create(recursive: true);
    await Directory(path.join(base, 'temp')).create(recursive: true);
  }

  Future<void> _setNoBackupFlag(String filePath) async {
    if (Platform.isIOS) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await Process.run('xattr', ['-w', 'com.apple.MobileBackup', '1', filePath]);
        }
      } catch (e) {
        print('⚠️ MediaStorage: Failed to set no-backup flag: $e');
      }
    }
  }

  Future<String> get imagesDir async => path.join(await baseDirectory, 'images');
  Future<String> get videosDir async => path.join(await baseDirectory, 'videos');
  Future<String> get voiceDir async => path.join(await baseDirectory, 'voice');
  Future<String> get documentsDir async => path.join(await baseDirectory, 'documents');
  Future<String> get thumbnailsDir async => path.join(await baseDirectory, 'thumbnails');
  Future<String> get tempDir async => path.join(await baseDirectory, 'temp');

  /// Get save path for a media type without writing bytes
  Future<String> getSavePath(String mediaType, String fileName) async {
    String dir;
    switch (mediaType) {
      case 'image':
        dir = await imagesDir;
        break;
      case 'video':
        dir = await videosDir;
        break;
      case 'voice':
        dir = await voiceDir;
        break;
      default:
        dir = await documentsDir;
    }
    final ext = path.extension(fileName);
    final finalName = fileName.isNotEmpty ? fileName : '${_uuid.v4()}$ext';
    return path.join(dir, finalName);
  }

  Future<String> saveImage(File sourceFile, {String? customName}) async {
    final destDir = await imagesDir;
    final ext = path.extension(sourceFile.path);
    final fileName = customName ?? '${_uuid.v4()}$ext';
    final destPath = path.join(destDir, fileName);
    await sourceFile.copy(destPath);
    await _setNoBackupFlag(destPath);
    return destPath;
  }

  Future<String> saveVideo(File sourceFile, {String? customName}) async {
    final destDir = await videosDir;
    final ext = path.extension(sourceFile.path);
    final fileName = customName ?? '${_uuid.v4()}$ext';
    final destPath = path.join(destDir, fileName);
    await sourceFile.copy(destPath);
    await _setNoBackupFlag(destPath);
    return destPath;
  }

  Future<String> saveVoiceNote(File sourceFile, {String? customName}) async {
    final destDir = await voiceDir;
    final ext = path.extension(sourceFile.path);
    final fileName = customName ?? '${_uuid.v4()}$ext';
    final destPath = path.join(destDir, fileName);
    await sourceFile.copy(destPath);
    await _setNoBackupFlag(destPath);
    return destPath;
  }

  Future<String> saveDocument(File sourceFile, {String? customName}) async {
    final destDir = await documentsDir;
    final ext = path.extension(sourceFile.path);
    final fileName = customName ?? '${_uuid.v4()}$ext';
    final destPath = path.join(destDir, fileName);
    await sourceFile.copy(destPath);
    await _setNoBackupFlag(destPath);
    return destPath;
  }

  Future<String> saveThumbnail(File sourceFile, {String? customName}) async {
    final destDir = await thumbnailsDir;
    final ext = path.extension(sourceFile.path);
    final fileName = customName ?? '${_uuid.v4()}$ext';
    final destPath = path.join(destDir, fileName);
    await sourceFile.copy(destPath);
    return destPath;
  }

  Future<String> saveTempFile(File sourceFile, {String? customName}) async {
    final destDir = await tempDir;
    final ext = path.extension(sourceFile.path);
    final fileName = customName ?? '${_uuid.v4()}$ext';
    final destPath = path.join(destDir, fileName);
    await sourceFile.copy(destPath);
    return destPath;
  }

  Future<String> saveImageBytes(List<int> bytes, String fileName) async {
    if (bytes.length > 10 * 1024 * 1024) {
      throw Exception('Image too large (max 10MB)');
    }
    final destDir = await imagesDir;
    final ext = path.extension(fileName);
    final finalName = fileName.isNotEmpty ? fileName : '${_uuid.v4()}$ext';
    final destPath = path.join(destDir, finalName);
    await File(destPath).writeAsBytes(bytes);
    await _setNoBackupFlag(destPath);
    return destPath;
  }

  Future<String> saveVideoBytes(List<int> bytes, String fileName) async {
    if (bytes.length > 100 * 1024 * 1024) {
      throw Exception('Video too large (max 100MB)');
    }
    final destDir = await videosDir;
    final ext = path.extension(fileName);
    final finalName = fileName.isNotEmpty ? fileName : '${_uuid.v4()}$ext';
    final destPath = path.join(destDir, finalName);
    await File(destPath).writeAsBytes(bytes);
    await _setNoBackupFlag(destPath);
    return destPath;
  }

  Future<String> saveVoiceBytes(List<int> bytes, String fileName) async {
    if (bytes.length > 20 * 1024 * 1024) {
      throw Exception('Voice note too large (max 20MB)');
    }
    final destDir = await voiceDir;
    final ext = path.extension(fileName);
    final finalName = fileName.isNotEmpty ? fileName : '${_uuid.v4()}$ext';
    final destPath = path.join(destDir, finalName);
    await File(destPath).writeAsBytes(bytes);
    await _setNoBackupFlag(destPath);
    return destPath;
  }

  Future<String> saveDocumentBytes(List<int> bytes, String fileName) async {
    if (bytes.length > 50 * 1024 * 1024) {
      throw Exception('Document too large (max 50MB)');
    }
    final destDir = await documentsDir;
    final ext = path.extension(fileName);
    final finalName = fileName.isNotEmpty ? fileName : '${_uuid.v4()}$ext';
    final destPath = path.join(destDir, finalName);
    await File(destPath).writeAsBytes(bytes);
    await _setNoBackupFlag(destPath);
    return destPath;
  }

  Future<bool> fileExists(String filePath) async {
    return File(filePath).exists();
  }

  Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  Future<File?> getFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<bool> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  Future<void> deleteMediaForMessage({
    String? mediaPath,
    String? thumbnailPath,
  }) async {
    if (mediaPath != null) await deleteFile(mediaPath);
    if (thumbnailPath != null) await deleteFile(thumbnailPath);
  }

  Future<int> getStorageSize() async {
    final base = await baseDirectory;
    return await _getDirectorySize(Directory(base));
  }

  Future<int> _getDirectorySize(Directory dir) async {
    int total = 0;
    try {
      await for (final file in dir.list(recursive: true, followLinks: false)) {
        if (file is File) {
          total += await file.length();
        }
      }
    } catch (e) {
      print('Error calculating directory size: $e');
    }
    return total;
  }

  Future<Map<String, int>> getStorageSizeByType() async {
    return {
      'images': await _getDirectorySize(Directory(await imagesDir)),
      'videos': await _getDirectorySize(Directory(await videosDir)),
      'voice': await _getDirectorySize(Directory(await voiceDir)),
      'documents': await _getDirectorySize(Directory(await documentsDir)),
      'thumbnails': await _getDirectorySize(Directory(await thumbnailsDir)),
      'temp': await _getDirectorySize(Directory(await tempDir)),
    };
  }

  Future<void> clearTempFiles() async {
    final temp = Directory(await tempDir);
    if (await temp.exists()) {
      await temp.delete(recursive: true);
      await temp.create(recursive: true);
    }
  }

  Future<void> clearAllMedia() async {
    final base = Directory(await baseDirectory);
    if (await base.exists()) {
      await base.delete(recursive: true);
      await _createDirectories();
    }
  }

  String getMediaTypeFromExtension(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.webp':
      case '.bmp':
        return 'image';
      case '.mp4':
      case '.avi':
      case '.mov':
      case '.mkv':
      case '.webm':
        return 'video';
      case '.mp3':
      case '.aac':
      case '.ogg':
      case '.wav':
      case '.m4a':
      case '.opus':
        return 'voice';
      case '.pdf':
      case '.doc':
      case '.docx':
      case '.xls':
      case '.xlsx':
      case '.ppt':
      case '.pptx':
      case '.txt':
      case '.csv':
      case '.zip':
      case '.rar':
        return 'document';
      default:
        return 'document';
    }
  }

  String getMimeTypeFromExtension(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.mp4':
        return 'video/mp4';
      case '.avi':
        return 'video/x-msvideo';
      case '.mov':
        return 'video/quicktime';
      case '.mp3':
        return 'audio/mpeg';
      case '.aac':
        return 'audio/aac';
      case '.ogg':
        return 'audio/ogg';
      case '.wav':
        return 'audio/wav';
      case '.m4a':
        return 'audio/mp4';
      case '.opus':
        return 'audio/opus';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
