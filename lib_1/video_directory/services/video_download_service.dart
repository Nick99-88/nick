import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants.dart';
import '../models/video_models.dart';
import 'download_database.dart';

class InProgressInfo {
  final String id;
  final String videoId;
  final String title;
  final String type;
  final String? qualityLabel;
  final String thumbnailUrl;
  final String uploaderName;
  double progress;
  bool failed;
  String? error;

  InProgressInfo({
    required this.id,
    required this.videoId,
    required this.title,
    required this.type,
    this.qualityLabel,
    required this.thumbnailUrl,
    required this.uploaderName,
    this.progress = 0,
    this.failed = false,
    this.error,
  });
}

class VideoDownloadService extends ChangeNotifier {
  static final VideoDownloadService instance = VideoDownloadService._();
  VideoDownloadService._() {
    _loadDownloads();
  }

  final DownloadDatabase _db = DownloadDatabase.instance;
  List<Map<String, dynamic>> _downloads = [];
  final List<InProgressInfo> _inProgress = [];

  List<Map<String, dynamic>> get downloads => _downloads;
  List<InProgressInfo> get inProgress => _inProgress;
  bool get hasDownloads => _downloads.isNotEmpty || _inProgress.isNotEmpty;

  Future<void> _loadDownloads() async {
    _downloads = await _db.getAllDownloads();
    notifyListeners();
  }

  void startDownload({
    required VideoPost video,
    required String type,
    String? quality,
    String? qualityLabel,
  }) {
    final downloadId = '${video.id}_${DateTime.now().millisecondsSinceEpoch}';

    final info = InProgressInfo(
      id: downloadId,
      videoId: video.id,
      title: video.title,
      type: type,
      qualityLabel: qualityLabel,
      thumbnailUrl: video.thumbnailUrl,
      uploaderName: video.uploaderName,
    );
    _inProgress.add(info);
    notifyListeners();

    _runDownload(info: info, video: video, type: type, quality: quality, qualityLabel: qualityLabel);
  }

  Future<void> _runDownload({
    required InProgressInfo info,
    required VideoPost video,
    required String type,
    String? quality,
    String? qualityLabel,
  }) async {
    try {
      final rawUrl = type == 'audio' && video.audioOnlyUrl != null && video.audioOnlyUrl!.isNotEmpty
          ? video.audioOnlyUrl!
          : (quality != null && video.videoUrl.isNotEmpty ? video.videoUrl : video.videoUrl);
      final uri = Uri.parse(_resolveUrl(rawUrl));

      final dir = await getApplicationDocumentsDirectory();
      final hasAudioStream = video.audioOnlyUrl != null && video.audioOnlyUrl!.isNotEmpty;
      final ext = type == 'audio' && hasAudioStream ? '.mp3' : '.mp4';
      final qualSuffix = qualityLabel != null ? '_$qualityLabel' : '';
      final baseName = '${video.title}${qualSuffix}_${DateTime.now().millisecondsSinceEpoch}';
      final fileName = '$baseName$ext';
      final file = File('${dir.path}/$fileName');

      final client = http.Client();
      List<int> bytes;
      try {
        final request = http.Request('GET', uri);
        final response = await client.send(request);
        final totalBytes = response.contentLength ?? 0;
        var receivedBytes = 0;
        final chunks = <List<int>>[];

        await for (final chunk in response.stream) {
          chunks.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            info.progress = receivedBytes / totalBytes;
            notifyListeners();
          }
        }

        bytes = <int>[];
        for (final chunk in chunks) {
          bytes.addAll(chunk);
        }
        await file.writeAsBytes(bytes);

        info.progress = 1.0;
        notifyListeners();
      } finally {
        client.close();
      }

      String thumbnailPath = '';
      final thumbRaw = video.thumbnailUrl;
      if (thumbRaw.isNotEmpty) {
        try {
          final thumbUrl = _resolveUrl(thumbRaw);
          final thumbResponse = await http.get(Uri.parse(thumbUrl));
          final thumbFileName = '${baseName}_thumb.jpg';
          final thumbFile = File('${dir.path}/$thumbFileName');
          await thumbFile.writeAsBytes(thumbResponse.bodyBytes);
          thumbnailPath = thumbFile.path;
        } catch (e) {
          debugPrint('📹 thumbnail download failed: $e');
        }
      }

      final entry = {
        'id': info.id,
        'video_id': video.id,
        'title': video.title,
        'uploader_name': video.uploaderName,
        'thumbnail_url': video.thumbnailUrl,
        'thumbnail_path': thumbnailPath,
        'type': type,
        'quality': qualityLabel ?? type,
        'local_path': file.path,
        'file_size': bytes.length,
        'duration': video.duration,
        'downloaded_at': DateTime.now().toIso8601String(),
      };

      await _db.insertDownload(entry);
      _inProgress.remove(info);
      await _loadDownloads();
    } catch (e) {
      info.failed = true;
      info.error = e.toString();
      _inProgress.remove(info);
      notifyListeners();
    }
  }

  String _resolveUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '${StarlightConstants.apiBaseUrl}${url.startsWith('/') ? url : '/$url'}';
  }

  Future<void> deleteDownload(String id) async {
    final entry = await _db.getDownloadById(id);
    if (entry != null) {
      final file = File(entry['local_path']);
      if (file.existsSync()) file.deleteSync();
      final thumbFile = entry['thumbnail_path']?.toString().isNotEmpty == true
          ? File(entry['thumbnail_path'])
          : null;
      if (thumbFile != null && thumbFile.existsSync()) thumbFile.deleteSync();
    }
    await _db.deleteDownload(id);
    await _loadDownloads();
  }

  Future<void> openDownload(String localPath) async {
    await OpenFile.open(localPath);
  }

  bool isDownloading(String videoId) =>
      _inProgress.any((info) => info.videoId == videoId);
}
