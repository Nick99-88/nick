import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ShortsChunkStorage {
  static String? _basePath;

  static Future<String> get basePath async {
    if (_basePath != null) return _basePath!;
    final dir = await getApplicationDocumentsDirectory();
    _basePath = p.join(dir.path, 'shorts_cache');
    await Directory(_basePath!).create(recursive: true);
    return _basePath!;
  }

  static Future<String> shortDir(String shortId) async {
    final base = await basePath;
    final dir = p.join(base, shortId);
    await Directory(dir).create(recursive: true);
    return dir;
  }

  static Future<String> chunkPath(String shortId, int chunkIndex) async {
    final dir = await shortDir(shortId);
    return p.join(dir, 'chunk_$chunkIndex.bin');
  }

  static Future<String> mergedVideoPath(String shortId) async {
    final dir = await shortDir(shortId);
    return p.join(dir, 'video.mp4');
  }

  static Future<String> thumbnailPath(String shortId) async {
    final dir = await shortDir(shortId);
    return p.join(dir, 'thumb.jpg');
  }

  static Future<void> saveChunk(String shortId, int chunkIndex, Uint8List data) async {
    final path = await chunkPath(shortId, chunkIndex);
    await File(path).writeAsBytes(data, flush: true);
  }

  static Future<Uint8List?> loadChunk(String shortId, int chunkIndex) async {
    final path = await chunkPath(shortId, chunkIndex);
    final file = File(path);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  }

  static Future<bool> chunkExists(String shortId, int chunkIndex) async {
    final path = await chunkPath(shortId, chunkIndex);
    return File(path).exists();
  }

  static Future<int> getDownloadedChunkCount(String shortId) async {
    final dir = await shortDir(shortId);
    final files = Directory(dir).listSync().whereType<File>();
    return files.where((f) => p.basename(f.path).startsWith('chunk_')).length;
  }

  static Future<File> mergeChunks(String shortId, int totalChunks) async {
    final outputPath = await mergedVideoPath(shortId);
    final sink = File(outputPath).openWrite();

    for (int i = 0; i < totalChunks; i++) {
      final data = await loadChunk(shortId, i);
      if (data != null) {
        sink.add(data);
      }
    }
    await sink.flush();
    await sink.close();

    return File(outputPath);
  }

  static Future<bool> isMerged(String shortId) async {
    final path = await mergedVideoPath(shortId);
    return File(path).exists();
  }

  static Future<int> getMergedSize(String shortId) async {
    final path = await mergedVideoPath(shortId);
    final file = File(path);
    if (!await file.exists()) return 0;
    return file.lengthSync();
  }

  static Future<void> saveThumbnail(String shortId, Uint8List data) async {
    final path = await thumbnailPath(shortId);
    await File(path).writeAsBytes(data, flush: true);
  }

  static Future<void> deleteShort(String shortId) async {
    final base = await basePath;
    final dir = Directory(p.join(base, shortId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  static Future<void> deleteAll() async {
    final base = await basePath;
    final dir = Directory(base);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  static Future<int> getCacheSize() async {
    final base = await basePath;
    final dir = Directory(base);
    if (!await dir.exists()) return 0;

    int totalSize = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  static String formatSize(int bytes) {
    if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}
