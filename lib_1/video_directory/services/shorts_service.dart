import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';

class ShortsPost {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final String uploaderId;
  final String uploaderName;
  final String? uploaderAvatar;
  final int views;
  final int likes;
  final int dislikes;
  final bool isLiked;
  final bool isDisliked;
  final int commentCount;
  final String createdAt;
  final double duration;
  final String? status;
  final int? progress;
  final String category;
  final List<String> tags;

  ShortsPost({
    required this.id,
    required this.title,
    this.description = '',
    required this.videoUrl,
    this.thumbnailUrl = '',
    required this.uploaderId,
    this.uploaderName = '',
    this.uploaderAvatar,
    this.views = 0,
    this.likes = 0,
    this.dislikes = 0,
    this.isLiked = false,
    this.isDisliked = false,
    this.commentCount = 0,
    required this.createdAt,
    this.duration = 0,
    this.status,
    this.progress,
    this.category = 'general',
    this.tags = const [],
  });

  factory ShortsPost.fromJson(Map<String, dynamic> json) {
    return ShortsPost(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      videoUrl: json['video_url']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
      uploaderId: json['uploader_id']?.toString() ?? '',
      uploaderName: json['uploader_name']?.toString() ?? '',
      uploaderAvatar: json['uploader_avatar']?.toString(),
      views: json['views'] ?? 0,
      likes: json['likes'] ?? 0,
      dislikes: json['dislikes'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      isDisliked: json['is_disliked'] ?? false,
      commentCount: json['comment_count'] ?? 0,
      createdAt: json['created_at']?.toString() ?? '',
      duration: (json['duration'] ?? 0).toDouble(),
      status: json['status']?.toString(),
      progress: json['progress'],
      category: json['category']?.toString() ?? 'general',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  String get viewsFormatted {
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
    return views.toString();
  }

  String get likesFormatted {
    if (likes >= 1000000) return '${(likes / 1000000).toStringAsFixed(1)}M';
    if (likes >= 1000) return '${(likes / 1000).toStringAsFixed(1)}K';
    return likes.toString();
  }

  String get timeAgo {
    try {
      final date = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 365) return '${(diff.inDays ~/ 365)}y';
      if (diff.inDays > 30) return '${(diff.inDays ~/ 30)}mo';
      if (diff.inDays > 0) return '${diff.inDays}d';
      if (diff.inHours > 0) return '${diff.inHours}h';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m';
      return 'now';
    } catch (_) {
      return '';
    }
  }
}

class ShortsComment {
  final String id;
  final String shortId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String text;
  final int likes;
  final bool isLiked;
  final bool isOwner;
  final String createdAt;
  final List<ShortsComment> replies;
  final int replyCount;

  ShortsComment({
    required this.id,
    required this.shortId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.text,
    this.likes = 0,
    this.isLiked = false,
    this.isOwner = false,
    required this.createdAt,
    this.replies = const [],
    this.replyCount = 0,
  });

  factory ShortsComment.fromJson(Map<String, dynamic> json) {
    final repliesList = (json['replies'] as List<dynamic>?)
            ?.map((e) => ShortsComment.fromJson(e))
            .toList() ??
        [];
    return ShortsComment(
      id: json['id'] ?? '',
      shortId: json['short_id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? '',
      userAvatar: json['user_avatar'],
      text: json['text'] ?? '',
      likes: json['likes'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      isOwner: json['is_owner'] ?? false,
      createdAt: json['created_at'] ?? '',
      replies: repliesList,
      replyCount: json['reply_count'] ?? repliesList.length,
    );
  }

  String get timeAgo {
    try {
      final date = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 365) return '${(diff.inDays ~/ 365)}y ago';
      if (diff.inDays > 30) return '${(diff.inDays ~/ 30)}mo ago';
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (_) {
      return '';
    }
  }
}

class ShortsService {
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
  // UPLOAD
  // ============================================================

  static Future<Map<String, dynamic>> uploadShort({
    required File videoFile,
    required String title,
    String description = '',
    String category = 'general',
    List<String>? tags,
    String visibility = 'public',
    Function(double)? onProgress,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/shorts/upload');
    final request = http.MultipartRequest('POST', uri);

    final token = await StarlightStorage.getUserToken();
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['category'] = category;
    request.fields['tags'] = jsonEncode(tags ?? []);
    request.fields['visibility'] = visibility;
    request.fields['is_short'] = 'true';

    request.files.add(await http.MultipartFile.fromPath('video', videoFile.path));

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
  // FEED
  // ============================================================

  static Future<List<ShortsPost>> getShortsFeed({int page = 1, int limit = 15}) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/shorts/feed?page=$page&limit=$limit'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data['shorts'] as List;
      return list.map((e) => ShortsPost.fromJson(e)).toList();
    }
    throw Exception('Failed to load shorts feed');
  }

  static Future<List<ShortsPost>> getTrendingShorts({int limit = 15}) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/shorts/trending?limit=$limit'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data['shorts'] as List;
      return list.map((e) => ShortsPost.fromJson(e)).toList();
    }
    throw Exception('Failed to load trending shorts');
  }

  static Future<List<ShortsPost>> getMyShorts({int page = 1}) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/shorts/my?page=$page'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data['shorts'] as List;
      return list.map((e) => ShortsPost.fromJson(e)).toList();
    }
    throw Exception('Failed to load my shorts');
  }

  static Future<List<ShortsPost>> getChannelShorts(String userId, {int page = 1}) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/shorts/channel/$userId?page=$page'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data['shorts'] as List;
      return list.map((e) => ShortsPost.fromJson(e)).toList();
    }
    throw Exception('Failed to load channel shorts');
  }

  // ============================================================
  // SINGLE SHORT
  // ============================================================

  static Future<ShortsPost> getShort(String shortId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/shorts/$shortId'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      return ShortsPost.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load short');
  }

  static Future<void> incrementViews(String shortId) async {
    await http.post(
      Uri.parse('$_baseUrl/api/shorts/$shortId/view'),
      headers: await _authHeaders(),
    );
  }

  // ============================================================
  // ENGAGEMENT
  // ============================================================

  static Future<Map<String, dynamic>> toggleLike(String shortId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/shorts/$shortId/like'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Like failed');
  }

  static Future<void> toggleDislike(String shortId) async {
    await http.post(
      Uri.parse('$_baseUrl/api/shorts/$shortId/dislike'),
      headers: await _authHeaders(),
    );
  }

  // ============================================================
  // COMMENTS
  // ============================================================

  static Future<List<ShortsComment>> getComments(String shortId, {int page = 1, int limit = 20}) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/shorts/$shortId/comments?page=$page&limit=$limit'),
      headers: await _authHeaders(),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data['comments'] as List;
      return list.map((e) => ShortsComment.fromJson(e)).toList();
    }
    throw Exception('Failed to load comments');
  }

  static Future<ShortsComment> addComment(String shortId, String text, {String? parentId}) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/shorts/$shortId/comment'),
      headers: await _jsonHeaders(),
      body: jsonEncode({'text': text, 'parent_id': parentId ?? ''}),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      return ShortsComment.fromJson(jsonDecode(res.body));
    }
    throw Exception('Comment failed');
  }

  static Future<void> deleteComment(String shortId, String commentId) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/api/shorts/$shortId/comment/$commentId'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw Exception('Delete comment failed');
  }

  static Future<void> toggleCommentLike(String shortId, String commentId) async {
    await http.post(
      Uri.parse('$_baseUrl/api/shorts/$shortId/comment/$commentId/like'),
      headers: await _authHeaders(),
    );
  }

  // ============================================================
  // DELETE / MANAGEMENT
  // ============================================================

  static Future<void> deleteShort(String shortId) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/api/shorts/$shortId'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw Exception('Delete failed');
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
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/shorts/chunk/init'),
      headers: await _jsonHeaders(),
      body: jsonEncode({
        'filename': filename,
        'total_size': totalSize,
        'total_chunks': totalChunks,
        'title': title,
        'description': description,
        'category': category,
        'tags': tags ?? [],
        'visibility': visibility,
      }),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body);
    }
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Init failed');
  }

  static Future<Map<String, dynamic>> uploadChunk({
    required String sessionId,
    required int chunkIndex,
    required int chunksRemaining,
    required List<int> chunkBytes,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/shorts/chunk/$sessionId/upload');
    final request = http.MultipartRequest('POST', uri);

    final token = await StarlightStorage.getUserToken();
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['chunk_index'] = chunkIndex.toString();
    request.fields['chunks_remaining'] = chunksRemaining.toString();

    final stream = http.ByteStream.fromBytes(chunkBytes);
    request.files.add(http.MultipartFile('chunk', stream, chunkBytes.length, filename: 'chunk_$chunkIndex'));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['detail'] ?? 'Chunk upload failed');
  }

  static Future<Map<String, dynamic>> completeChunkUpload(String sessionId, {String? thumbnailPath}) async {
    final uri = Uri.parse('$_baseUrl/api/shorts/chunk/$sessionId/complete');
    final request = http.MultipartRequest('POST', uri);

    final token = await StarlightStorage.getUserToken();
    request.headers['Authorization'] = 'Bearer $token';

    if (thumbnailPath != null) {
      final thumbBytes = await File(thumbnailPath).readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'thumbnail',
        thumbBytes,
        filename: 'thumbnail.jpg',
      ));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['detail'] ?? 'Complete failed');
  }

  static Future<Map<String, dynamic>> getChunkStatus(String sessionId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/shorts/chunk/$sessionId/status'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Status check failed');
  }

  static Future<void> cancelChunkUpload(String sessionId) async {
    await http.delete(
      Uri.parse('$_baseUrl/api/shorts/chunk/$sessionId'),
      headers: await _authHeaders(),
    );
  }
}
