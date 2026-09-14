import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'shorts_cache_database.dart';
import 'shorts_chunk_storage.dart';
import 'shorts_service.dart';
import '../../core/constants.dart';

class ShortsCacheManager {
  static final ShortsCacheManager instance = ShortsCacheManager._init();
  ShortsCacheManager._init();

  final ShortsCacheDatabase _db = ShortsCacheDatabase.instance;
  final Map<String, StreamController<double>> _progressControllers = {};
  final Map<String, bool> _activeDownloads = {};
  final Map<String, Completer<String?>> _downloadCompleters = {};
  bool _isProcessingQueue = false;

  static const int windowSize = 3;
  static const int maxCached = windowSize * 2 + 1;
  static const int chunkSizeBytes = 256 * 1024;

  Stream<double> getProgressStream(String shortId) {
    _progressControllers[shortId] ??= StreamController<double>.broadcast();
    return _progressControllers[shortId]!.stream;
  }

  void _emitProgress(String shortId, double progress) {
    _progressControllers[shortId]?.add(progress);
  }

  void disposeProgress(String shortId) {
    _progressControllers[shortId]?.close();
    _progressControllers.remove(shortId);
  }

  Future<void> initialize(List<ShortsPost> feed) async {
    for (int i = 0; i < feed.length; i++) {
      final short = feed[i];
      final existing = await _db.get(short.id);
      if (existing == null) {
        await _db.insertOrUpdate(ShortsCacheEntry(
          shortId: short.id,
          title: short.title,
          description: short.description,
          uploaderName: short.uploaderName,
          uploaderAvatar: short.uploaderAvatar ?? '',
          thumbnailUrl: short.thumbnailUrl,
          videoUrl: short.videoUrl,
          feedPosition: i,
          status: 'pending',
          createdAt: DateTime.now().toIso8601String(),
        ));
      } else {
        final updated = ShortsCacheEntry(
          shortId: existing.shortId,
          title: existing.title,
          description: existing.description,
          uploaderName: existing.uploaderName,
          uploaderAvatar: existing.uploaderAvatar,
          thumbnailUrl: existing.thumbnailUrl,
          videoUrl: existing.videoUrl,
          feedPosition: i,
          totalChunks: existing.totalChunks,
          downloadedChunks: existing.downloadedChunks,
          status: existing.status,
          localVideoPath: existing.localVideoPath,
          localThumbPath: existing.localThumbPath,
          fileSize: existing.fileSize,
          duration: existing.duration,
          createdAt: existing.createdAt,
        );
        await _db.insertOrUpdate(updated);
      }
    }
    await _cleanupExcess();
    _processDownloadQueue();
  }

  Future<void> updateFeedPositions(List<ShortsPost> feed) async {
    for (int i = 0; i < feed.length; i++) {
      final entry = await _db.get(feed[i].id);
      if (entry != null) {
        final updated = ShortsCacheEntry(
          shortId: entry.shortId,
          title: entry.title,
          description: entry.description,
          uploaderName: entry.uploaderName,
          uploaderAvatar: entry.uploaderAvatar,
          thumbnailUrl: entry.thumbnailUrl,
          videoUrl: entry.videoUrl,
          feedPosition: i,
          totalChunks: entry.totalChunks,
          downloadedChunks: entry.downloadedChunks,
          status: entry.status,
          localVideoPath: entry.localVideoPath,
          localThumbPath: entry.localThumbPath,
          fileSize: entry.fileSize,
          duration: entry.duration,
          createdAt: entry.createdAt,
        );
        await _db.insertOrUpdate(updated);
      }
    }
  }

  Future<String?> getLocalVideoPath(String shortId) async {
    final entry = await _db.get(shortId);
    if (entry == null) return null;

    if (entry.isReady && entry.localVideoPath != null) {
      final file = File(entry.localVideoPath!);
      if (await file.exists()) return entry.localVideoPath;
    }

    if (await ShortsChunkStorage.isMerged(shortId)) {
      final path = await ShortsChunkStorage.mergedVideoPath(shortId);
      await _db.updateLocalPaths(shortId, path, entry.localThumbPath ?? '');
      return path;
    }

    return null;
  }

  Future<String?> getLocalThumbPath(String shortId) async {
    final entry = await _db.get(shortId);
    if (entry?.localThumbPath != null) {
      final file = File(entry!.localThumbPath!);
      if (await file.exists()) return entry.localThumbPath;
    }
    return null;
  }

  Future<String?> downloadAndWait(String shortId, {Duration timeout = const Duration(seconds: 120)}) async {
    final existing = await getLocalVideoPath(shortId);
    if (existing != null) return existing;

    final entry = await _db.get(shortId);
    if (entry == null) return null;

    if (_downloadCompleters.containsKey(shortId)) {
      return _downloadCompleters[shortId]!.future.timeout(timeout, onTimeout: () => null);
    }

    final completer = Completer<String?>();
    _downloadCompleters[shortId] = completer;

    if (_activeDownloads[shortId] == true) {
      return completer.future.timeout(timeout, onTimeout: () {
        _downloadCompleters.remove(shortId);
        return null;
      });
    }

    startDownload(shortId, currentPosition: entry.feedPosition);

    return completer.future.timeout(timeout, onTimeout: () {
      _downloadCompleters.remove(shortId);
      return null;
    });
  }

  void _completeDownload(String shortId, String? path) {
    if (_downloadCompleters.containsKey(shortId) && !_downloadCompleters[shortId]!.isCompleted) {
      _downloadCompleters[shortId]!.complete(path);
      _downloadCompleters.remove(shortId);
    }
  }

  void _failDownload(String shortId) {
    if (_downloadCompleters.containsKey(shortId) && !_downloadCompleters[shortId]!.isCompleted) {
      _downloadCompleters[shortId]!.complete(null);
      _downloadCompleters.remove(shortId);
    }
  }

  Future<void> startDownload(String shortId, {int currentPosition = 0}) async {
    final entry = await _db.get(shortId);
    if (entry == null || entry.isReady) return;

    if (_activeDownloads[shortId] == true) {
      return;
    }

    final resolvedUrl = shortUrl(entry.videoUrl);

    _activeDownloads[shortId] = true;
    await _db.updateStatus(shortId, 'downloading');

    try {
      final client = http.Client();
      final request = http.Request('HEAD', Uri.parse(resolvedUrl));
      final headResponse = await client.send(request);
      final contentLength = int.parse(headResponse.headers['content-length'] ?? '0');
      client.close();

      if (contentLength <= 0) {
        await _downloadAsSingleFile(shortId, resolvedUrl);
        return;
      }

      final totalChunks = (contentLength / chunkSizeBytes).ceil();
      final alreadyDownloaded = await ShortsChunkStorage.getDownloadedChunkCount(shortId);

      await _db.updateProgress(shortId, alreadyDownloaded, totalChunks);

      for (int i = alreadyDownloaded; i < totalChunks; i++) {
        if (_activeDownloads[shortId] != true) break;

        final start = i * chunkSizeBytes;
        final end = (i + 1) * chunkSizeBytes - 1;

        final chunkClient = http.Client();
        final chunkRequest = http.Request('GET', Uri.parse(resolvedUrl));
        chunkRequest.headers['Range'] = 'bytes=$start-$end';

        final chunkResponse = await chunkClient.send(chunkRequest);
        final bytes = await chunkResponse.stream.toBytes();
        chunkClient.close();

        await ShortsChunkStorage.saveChunk(shortId, i, bytes);
        await _db.updateProgress(shortId, i + 1, totalChunks);
        _emitProgress(shortId, (i + 1) / totalChunks);
      }

      if (_activeDownloads[shortId] == true) {
        await _finalizeDownload(shortId, totalChunks);
      }
    } catch (e) {
      debugPrint('Shorts cache download error for $shortId: $e');
      await _db.updateStatus(shortId, 'error');
      _failDownload(shortId);
    } finally {
      _activeDownloads.remove(shortId);
    }
  }

  Future<void> _downloadAsSingleFile(String shortId, String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final path = await ShortsChunkStorage.mergedVideoPath(shortId);
        await File(path).writeAsBytes(response.bodyBytes, flush: true);
        await _db.updateLocalPaths(shortId, path, '');
        await _db.updateStatus(shortId, 'ready');
        _emitProgress(shortId, 1.0);
        _completeDownload(shortId, path);
      }
    } catch (e) {
      debugPrint('Single file download failed: $e');
      await _db.updateStatus(shortId, 'error');
      _failDownload(shortId);
    }
  }

  Future<void> _finalizeDownload(String shortId, int totalChunks) async {
    try {
      await ShortsChunkStorage.mergeChunks(shortId, totalChunks);
      final videoPath = await ShortsChunkStorage.mergedVideoPath(shortId);
      final thumbPath = await ShortsChunkStorage.thumbnailPath(shortId);
      final hasThumb = await File(thumbPath).exists();

      await _db.updateLocalPaths(shortId, videoPath, hasThumb ? thumbPath : '');
      await _db.updateStatus(shortId, 'ready');
      _emitProgress(shortId, 1.0);
      _completeDownload(shortId, videoPath);

      await _prefetchNext(shortId);
    } catch (e) {
      debugPrint('Finalize error: $e');
      _failDownload(shortId);
    }
  }

  Future<void> _prefetchNext(String currentShortId) async {
    final all = await _db.getAll();
    final currentIdx = all.indexWhere((e) => e.shortId == currentShortId);
    if (currentIdx < 0) return;

    final currentPos = all[currentIdx].feedPosition;

    final nextEntry = all.firstWhere(
      (e) => e.feedPosition == currentPos + 1 && !e.isReady,
      orElse: () => ShortsCacheEntry(shortId: '', title: '', videoUrl: '', createdAt: ''),
    );
    if (nextEntry.shortId.isNotEmpty) {
      startDownload(nextEntry.shortId, currentPosition: nextEntry.feedPosition);
    }
  }

  Future<void> onFocus(shortId, int currentPosition) async {
    final entry = await _db.get(shortId);
    if (entry != null && !entry.isReady) {
      startDownload(shortId, currentPosition: currentPosition);
    }
    await _enforceWindow(currentPosition);
  }

  Future<void> _enforceWindow(int currentPosition) async {
    final all = await _db.getAll();
    final inWindow = all.where((e) =>
        e.feedPosition >= currentPosition - windowSize &&
        e.feedPosition <= currentPosition + windowSize).toList();

    final inWindowIds = inWindow.map((e) => e.shortId).toSet();
    final outsideWindow = all.where((e) => !inWindowIds.contains(e.shortId)).toList();

    for (final entry in outsideWindow) {
      if (entry.isReady || entry.isDownloading) {
        _activeDownloads[entry.shortId] = false;
        await ShortsChunkStorage.deleteShort(entry.shortId);
        await _db.updateStatus(entry.shortId, 'pending');
      }
    }

    final readyInWindow = inWindow.where((e) => e.isReady).length;
    if (readyInWindow > maxCached) {
      final toRemove = readyInWindow - maxCached;
      final sorted = List<ShortsCacheEntry>.from(inWindow)
        ..sort((a, b) => a.feedPosition.compareTo(b.feedPosition));

      int removed = 0;
      for (final entry in sorted) {
        if (removed >= toRemove) break;
        if (entry.feedPosition < currentPosition) {
          await ShortsChunkStorage.deleteShort(entry.shortId);
          await _db.updateStatus(entry.shortId, 'pending');
          removed++;
        }
      }
    }
  }

  Future<void> _processDownloadQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    try {
      final all = await _db.getAll();
      final pending = all.where((e) => e.status == 'pending').toList()
        ..sort((a, b) => a.feedPosition.compareTo(b.feedPosition));

      final readyCount = all.where((e) => e.isReady).length;
      if (readyCount < maxCached && pending.isNotEmpty) {
        final toDownload = pending.take(maxCached - readyCount).toList();
        for (final entry in toDownload) {
          if (!_activeDownloads.containsKey(entry.shortId)) {
            startDownload(entry.shortId, currentPosition: entry.feedPosition);
          }
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  Future<void> _cleanupExcess() async {
    final all = await _db.getAll();
    if (all.length <= maxCached) return;

    final sorted = List<ShortsCacheEntry>.from(all)
      ..sort((a, b) => a.feedPosition.compareTo(b.feedPosition));

    final toRemove = sorted.take(all.length - maxCached).toList();
    for (final entry in toRemove) {
      await ShortsChunkStorage.deleteShort(entry.shortId);
      await _db.delete(entry.shortId);
    }
  }

  Future<void> onAppResume() async {
    final all = await _db.getAll();
    final downloading = all.where((e) => e.status == 'downloading').toList();
    for (final entry in downloading) {
      await _db.updateStatus(entry.shortId, 'pending');
      _activeDownloads.remove(entry.shortId);
    }
    _processDownloadQueue();
  }

  Future<void> pauseDownload(String shortId) async {
    _activeDownloads[shortId] = false;
  }

  Future<void> resumeDownload(String shortId) async {
    final entry = await _db.get(shortId);
    if (entry != null && !entry.isReady) {
      startDownload(shortId, currentPosition: entry.feedPosition);
    }
  }

  Future<void> deleteCached(String shortId) async {
    _activeDownloads[shortId] = false;
    await ShortsChunkStorage.deleteShort(shortId);
    await _db.delete(shortId);
  }

  Future<void> clearAll() async {
    _activeDownloads.clear();
    await ShortsChunkStorage.deleteAll();
    await _db.deleteAll();
  }

  Future<int> getCacheSize() async {
    return ShortsChunkStorage.getCacheSize();
  }

  Future<Map<String, dynamic>> getStats() async {
    final all = await _db.getAll();
    final ready = all.where((e) => e.isReady).length;
    final downloading = all.where((e) => e.isDownloading).length;
    final pending = all.where((e) => e.status == 'pending').length;
    final cacheSize = await getCacheSize();
    return {
      'total': all.length,
      'ready': ready,
      'downloading': downloading,
      'pending': pending,
      'cache_size': ShortsChunkStorage.formatSize(cacheSize),
    };
  }

  String shortUrl(String url) {
    if (url.startsWith('/')) {
      return '${StarlightConstants.apiBaseUrl}$url';
    }
    return url;
  }
}
