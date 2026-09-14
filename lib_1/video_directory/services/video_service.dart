import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../models/video_models.dart';

class VideoService {
  static String get _baseUrl => StarlightConstants.apiBaseUrl;

  static Future<Map<String, String>> _authHeaders() async {
    final token = await StarlightStorage.getUserToken();
    return {'Authorization': 'Bearer $token'};
  }

  static Future<Map<String, String>> _jsonHeaders() async {
    final headers = await _authHeaders();
    headers['Content-Type'] = 'application/json';
    return headers;
  }

  // ============================================================
  // DIRECT BACKEND UPLOAD (multipart)
  // ============================================================

  static Future<Map<String, dynamic>> uploadVideo({
    required File videoFile,
    File? thumbnailFile,
    required String title,
    required String description,
    required String category,
    List<String>? tags,
    String visibility = 'public',
    bool extractAudio = false,
    String? scheduledTime,
    Function(double)? onProgress,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/video/upload');
    final request = http.MultipartRequest('POST', uri);

    final token = await StarlightStorage.getUserToken();
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['category'] = category;
    request.fields['tags'] = jsonEncode(tags ?? []);
    request.fields['visibility'] = visibility;
    request.fields['extract_audio'] = extractAudio.toString();
    if (scheduledTime != null) {
      request.fields['scheduled_time'] = scheduledTime;
    }

    request.files.add(await http.MultipartFile.fromPath('video', videoFile.path));
    if (thumbnailFile != null) {
      request.files.add(await http.MultipartFile.fromPath('thumbnail', thumbnailFile.path));
    }

    final streamedResponse = await request.send();
    onProgress?.call(1.0);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    final errorBody = jsonDecode(response.body);
    throw Exception(errorBody['detail'] ?? 'Upload failed: ${response.statusCode}');
  }

  // ============================================================
  // UPLOAD STATUS POLLING
  // ============================================================

  static Future<VideoUploadStatus> getUploadStatus(String videoId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/upload/status/$videoId'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      return VideoUploadStatus.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to get upload status');
  }

  // ============================================================
  // HLS STREAMING
  // ============================================================

  static Future<HlsPlaylistInfo> getHlsPlaylist(String videoId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/$videoId/hls/playlist'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      return HlsPlaylistInfo.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to get HLS playlist');
  }

  // ============================================================
  // FEED & DISCOVERY
  // ============================================================

  static Future<List<VideoPost>> getFeed({int page = 1, int limit = 20}) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/feed?page=$page&limit=$limit'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data['videos'] as List;
      return list.map((e) => VideoPost.fromJson(e)).toList();
    }
    throw Exception('Failed to load feed');
  }

  static Future<List<VideoPost>> getTrending({int limit = 10}) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/trending?limit=$limit'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data['videos'] as List;
      return list.map((e) => VideoPost.fromJson(e)).toList();
    }
    throw Exception('Failed to load trending');
  }

  static Future<List<VideoPost>> searchVideos(String query, {int page = 1}) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/search?q=${Uri.encodeComponent(query)}&page=$page'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data['videos'] as List;
      return list.map((e) => VideoPost.fromJson(e)).toList();
    }
    throw Exception('Failed to search');
  }

  // ============================================================
  // SINGLE VIDEO
  // ============================================================

  static Future<VideoPost> getVideo(String videoId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/$videoId'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      return VideoPost.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load video');
  }

  static Future<void> incrementViews(String videoId) async {
    await http.post(
      Uri.parse('$_baseUrl/api/video/$videoId/view'),
      headers: await _authHeaders(),
    );
  }

  // ============================================================
  // ENGAGEMENT
  // ============================================================

  static Future<void> toggleLike(String videoId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/video/$videoId/like'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw Exception('Like failed');
  }

  static Future<void> toggleDislike(String videoId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/video/$videoId/dislike'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw Exception('Dislike failed');
  }

  // ============================================================
  // COMMENTS
  // ============================================================

  static Future<CommentPage> getComments(String videoId, {int page = 1, int limit = 20}) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/$videoId/comments?page=$page&limit=$limit'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data['comments'] as List;
      return CommentPage(
        comments: list.map((e) => VideoComment.fromJson(e)).toList(),
        total: data['total'] ?? 0,
        page: data['page'] ?? 1,
        hasMore: data['has_more'] ?? false,
      );
    }
    throw Exception('Failed to load comments');
  }

  static Future<VideoComment> addComment(String videoId, String text, {String? parentId}) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/video/$videoId/comment'),
      headers: await _jsonHeaders(),
      body: jsonEncode({'text': text, 'parent_id': parentId ?? ''}),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      return VideoComment.fromJson(jsonDecode(res.body));
    }
    throw Exception('Comment failed');
  }

  static Future<void> deleteComment(String videoId, String commentId) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/api/video/$videoId/comment/$commentId'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw Exception('Delete comment failed');
  }

  static Future<void> toggleCommentLike(String videoId, String commentId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/video/$videoId/comment/$commentId/like'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw Exception('Comment like failed');
  }

  static Future<void> toggleCommentDislike(String videoId, String commentId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/video/$videoId/comment/$commentId/dislike'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw Exception('Comment dislike failed');
  }

  // ============================================================
  // CHANNEL
  // ============================================================

  static Future<Channel> getChannel(String userId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/channel/$userId'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return Channel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load channel');
  }

  static Future<Channel> updateChannel({String name = '', String description = '', String links = ''}) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/api/video/channel/me'),
      headers: await _jsonHeaders(),
      body: jsonEncode({'name': name, 'description': description, 'links': links}),
    );
    if (res.statusCode == 200) {
      return Channel.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to update channel');
  }

  // ============================================================
  // SUBSCRIPTIONS
  // ============================================================

  static Future<bool> toggleSubscribe(String uploaderId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/video/subscribe/$uploaderId'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw Exception('Subscribe failed');
    return jsonDecode(res.body)['is_subscribed'] ?? false;
  }

  static Future<bool> isSubscribed(String uploaderId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/subscribe/$uploaderId/status'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body)['is_subscribed'] ?? false;
    }
    return false;
  }

  // ============================================================
  // USER CONTENT
  // ============================================================

  static Future<List<VideoPost>> getUserVideos(String userId, {int page = 1}) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/user/$userId?page=$page'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data['videos'] as List;
      debugPrint('📹 getUserVideos: status=${res.statusCode} raw_count=${list.length}');
      int ok = 0;
      final videos = list.map((e) {
        try {
          final v = VideoPost.fromJson(e);
          debugPrint('  ✅ parsed: id=${v.id} title=${v.title} status=${v.status} url=${v.videoUrl}');
          ok++;
          return v;
        } catch (err) {
          debugPrint('  ❌ parse failed: $err — json=$e');
          rethrow;
        }
      }).toList();
      debugPrint('📹 getUserVideos: ${videos.length} parsed successfully');
      return videos;
    }
    throw Exception('Failed to load user videos');
  }

  static Future<List<VideoPost>> getLikedVideos() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/liked'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data['videos'] as List;
      return list.map((e) => VideoPost.fromJson(e)).toList();
    }
    throw Exception('Failed to load liked videos');
  }

  static Future<List<VideoPost>> getWatchHistory() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/history'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data['videos'] as List;
      return list.map((e) => VideoPost.fromJson(e)).toList();
    }
    throw Exception('Failed to load history');
  }

  static Future<List<VideoPost>> getSubscriptionsFeed() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/subscriptions'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data['videos'] as List;
      return list.map((e) => VideoPost.fromJson(e)).toList();
    }
    throw Exception('Failed to load subscriptions feed');
  }

  // ============================================================
  // DELETE
  // ============================================================

  static Future<void> deleteVideo(String videoId) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/api/video/$videoId'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw Exception('Delete video failed');
  }

  // ============================================================
  // PLAYLISTS
  // ============================================================

  static Future<List<Playlist>> getPlaylists() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/playlists'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data['playlists'] as List;
      return list.map((e) => Playlist.fromJson(e)).toList();
    }
    throw Exception('Failed to load playlists');
  }

  static Future<Playlist> createPlaylist(String title) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/video/playlist'),
      headers: await _jsonHeaders(),
      body: jsonEncode({'title': title}),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      return Playlist.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to create playlist');
  }

  static Future<void> updatePlaylist(String playlistId, String title) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/api/video/playlist/$playlistId'),
      headers: await _jsonHeaders(),
      body: jsonEncode({'title': title}),
    );
    if (res.statusCode != 200) throw Exception('Failed to update playlist');
  }

  static Future<void> deletePlaylist(String playlistId) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/api/video/playlist/$playlistId'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw Exception('Failed to delete playlist');
  }

  static Future<void> addVideoToPlaylist(String playlistId, String videoId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/video/playlist/$playlistId/video'),
      headers: await _jsonHeaders(),
      body: jsonEncode({'video_id': videoId}),
    );
    if (res.statusCode != 200) throw Exception('Failed to add video to playlist');
  }

  static Future<void> removeVideoFromPlaylist(String playlistId, String videoId) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/api/video/playlist/$playlistId/video/$videoId'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw Exception('Failed to remove video from playlist');
  }

  static Future<List<VideoPost>> getPlaylistVideos(String playlistId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/playlist/$playlistId/videos'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data['videos'] as List;
      return list.map((e) => VideoPost.fromJson(e)).toList();
    }
    throw Exception('Failed to load playlist videos');
  }

  // ============================================================
  // REPORTING
  // ============================================================

  static Future<void> reportVideo(String videoId, String reason, {String? details}) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/video/$videoId/report'),
      headers: await _jsonHeaders(),
      body: jsonEncode({
        'reason': reason,
        'details': details ?? '',
      }),
    );
    if (res.statusCode != 200) throw Exception('Failed to report video');
  }

  // ============================================================
  // CAPTIONS
  // ============================================================

  static Future<List<Map<String, dynamic>>> getCaptions(String videoId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/$videoId/captions'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return List<Map<String, dynamic>>.from(data['captions'] ?? []);
    }
    throw Exception('Failed to load captions');
  }

  static Future<void> uploadCaption({
    required String videoId,
    required String language,
    required File file,
    String title = '',
  }) async {
    final token = await StarlightStorage.getUserToken();
    final uri = Uri.parse('$_baseUrl/api/video/$videoId/captions/upload?language=$language&title=$title');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('caption_file', file.path));
    
    final response = await request.send();
    if (response.statusCode != 200) throw Exception('Caption upload failed');
  }

  static Future<void> deleteCaption(String videoId, String language) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/api/video/$videoId/captions/$language'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw Exception('Failed to delete caption');
  }

  // ============================================================
  // CHUNKED UPLOAD
  // ============================================================

  static Future<Map<String, dynamic>> initChunkUpload({
    required String filename,
    required int totalSize,
    int? totalChunks,
    required String title,
    String description = '',
    String category = 'general',
    List<String>? tags,
    String visibility = 'public',
    bool extractAudio = false,
    String? scheduledTime,
    String? headHash,
    String? tailHash,
    List<int>? thumbnailBytes,
  }) async {
    final body = <String, dynamic>{
      'filename': filename,
      'total_size': totalSize,
      'title': title,
      'description': description,
      'category': category,
      'tags': tags ?? [],
      'visibility': visibility,
      'extract_audio': extractAudio,
      'scheduled_time': scheduledTime,
    };
    if (totalChunks != null) {
      body['total_chunks'] = totalChunks;
    }
    if (headHash != null) {
      body['head_hash'] = headHash;
    }
    if (tailHash != null) {
      body['tail_hash'] = tailHash;
    }
    if (thumbnailBytes != null && thumbnailBytes.isNotEmpty) {
      body['thumbnail_base64'] = base64Encode(thumbnailBytes);
    }
    final res = await http.post(
      Uri.parse('$_baseUrl/api/video/upload/chunk/init'),
      headers: await _jsonHeaders(),
      body: jsonEncode(body),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to init chunk upload');
  }

  static Future<Map<String, dynamic>> uploadChunk({
    required String sessionId,
    required int chunkIndex,
    required File chunkFile,
  }) async {
    final token = await StarlightStorage.getUserToken();
    final uri = Uri.parse('$_baseUrl/api/video/upload/chunk/$sessionId/$chunkIndex');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('chunk', chunkFile.path));
    
    final response = await request.send();
    if (response.statusCode == 200) {
      return jsonDecode(await response.stream.bytesToString());
    }
    throw Exception('Chunk upload failed');
  }

  static Future<Map<String, dynamic>> uploadChunkBytes({
    required String sessionId,
    required int chunkIndex,
    required List<int> chunkBytes,
  }) async {
    final token = await StarlightStorage.getUserToken();
    final uri = Uri.parse('$_baseUrl/api/video/upload/chunk/$sessionId/$chunkIndex');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('chunk', chunkBytes, filename: 'chunk_$chunkIndex'));
    
    final response = await request.send();
    if (response.statusCode == 200) {
      return jsonDecode(await response.stream.bytesToString());
    }
    final errorBody = jsonDecode(await response.stream.bytesToString());
    throw Exception(errorBody['detail'] ?? 'Chunk upload failed');
  }

  static Future<List<Map<String, dynamic>>> getPendingUploads() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/upload/chunk/pending'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return List<Map<String, dynamic>>.from(data['pending_uploads'] ?? []);
    }
    throw Exception('Failed to get pending uploads');
  }

  static Future<Map<String, dynamic>> getChunkStatus(String sessionId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/upload/chunk/$sessionId/status'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to get chunk status');
  }

  static Future<Map<String, dynamic>> completeChunkUpload(String sessionId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/video/upload/chunk/$sessionId/complete'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to complete chunk upload');
  }

  static Future<void> cancelChunkUpload(String sessionId) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/api/video/upload/chunk/$sessionId'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw Exception('Failed to cancel upload');
  }

  // ============================================================
  // HEALTH CHECK
  // ============================================================

  static Future<Map<String, dynamic>> getSystemHealth() async {
    final res = await http.get(Uri.parse('$_baseUrl/health'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Health check failed');
  }
}

// ============================================================
// RESPONSE MODELS
// ============================================================

class VideoUploadStatus {
  final String videoId;
  final String status;
  final int progress;
  final String? error;
  final String? hlsUrl;
  final bool audioReady;
  final int retryAttempt;
  final int retryCount;

  VideoUploadStatus({
    required this.videoId,
    required this.status,
    required this.progress,
    this.error,
    this.hlsUrl,
    this.audioReady = false,
    this.retryAttempt = 0,
    this.retryCount = 0,
  });

  factory VideoUploadStatus.fromJson(Map<String, dynamic> json) {
    return VideoUploadStatus(
      videoId: json['video_id'] ?? '',
      status: json['status'] ?? 'processing',
      progress: json['progress'] ?? 0,
      error: json['error'],
      hlsUrl: json['hls_url'],
      audioReady: json['audio_ready'] ?? false,
      retryAttempt: json['retry_attempt'] ?? 0,
      retryCount: json['retry_count'] ?? 0,
    );
  }
}

class HlsPlaylistInfo {
  final bool ready;
  final String? hlsUrl;
  final String? audioOnlyUrl;
  final Map<String, String> qualities;
  final double duration;
  final String? status;
  final int? progress;

  HlsPlaylistInfo({
    required this.ready,
    this.hlsUrl,
    this.audioOnlyUrl,
    this.qualities = const {},
    this.duration = 0,
    this.status,
    this.progress,
  });

  factory HlsPlaylistInfo.fromJson(Map<String, dynamic> json) {
    Map<String, String> parsedQualities = {};
    if (json['qualities'] != null) {
      (json['qualities'] as Map).forEach((key, value) {
        parsedQualities[key.toString()] = value.toString();
      });
    }
    return HlsPlaylistInfo(
      ready: json['ready'] ?? false,
      hlsUrl: json['hls_url'],
      audioOnlyUrl: json['audio_only_url'],
      qualities: parsedQualities,
      duration: (json['duration'] ?? 0).toDouble(),
      status: json['status'],
      progress: json['progress'],
    );
  }
}

class CommentPage {
  final List<VideoComment> comments;
  final int total;
  final int page;
  final bool hasMore;

  CommentPage({
    required this.comments,
    required this.total,
    required this.page,
    required this.hasMore,
  });
}
