import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../services/api_service.dart';
import '../models/book_models.dart';

class LibraryService {
  static String get _baseUrl => StarlightConstants.apiBaseUrl;

  static Future<Map<String, dynamic>> checkChannel() async {
    return await ApiService.get('/library/channel/check');
  }

  static Future<LibraryChannel> createChannel({
    required String name,
    required String description,
    String? profilePicPath,
  }) async {
    final token = await StarlightStorage.getUserToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/library/channel/create'),
    );
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['name'] = name;
    request.fields['description'] = description;

    if (profilePicPath != null && await File(profilePicPath).exists()) {
      final picFile = await http.MultipartFile.fromPath(
        'profile_pic',
        profilePicPath,
        filename: profilePicPath.split('/').last,
      );
      request.files.add(picFile);
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return LibraryChannel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Channel creation failed (${response.statusCode}): ${response.body}');
    }
  }

  /// 📤 Upload a file picked from the user's device to the library.
  ///
  /// Sends a `multipart/form-data` request with the picked file + the usual
  /// metadata as form fields. Backend persists the file to disk and returns
  /// the new `Book` (with a server-issued `file_url` we can stream back).
  static Future<Book> uploadBook({
    required String title,
    required String author,
    required String topic,
    required String docType,
    required String filePath,
    String? fileName,
    String? description,
    String? thumbnailPath,
    String monetizationType = 'free',
    double price = 0.0,
    DateTime? scheduledAt,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception("Selected file does not exist on disk");
    }

    final token = await StarlightStorage.getUserToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/library/upload'),
    );
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['title'] = title;
    request.fields['author'] = author;
    request.fields['topic'] = topic;
    request.fields['doc_type'] = docType;
    request.fields['monetization_type'] = monetizationType;
    request.fields['price'] = price.toStringAsFixed(2);
    if (scheduledAt != null) {
      request.fields['scheduled_at'] = scheduledAt.toIso8601String();
    }
    if (description != null && description.isNotEmpty) {
      request.fields['description'] = description;
    }

    final multipartFile = await http.MultipartFile.fromPath(
      'file',
      filePath,
      filename: fileName ?? filePath.split('/').last,
    );
    request.files.add(multipartFile);

    if (thumbnailPath != null && await File(thumbnailPath).exists()) {
      final thumbFile = await http.MultipartFile.fromPath(
        'thumbnail',
        thumbnailPath,
        filename: thumbnailPath.split('/').last,
      );
      request.files.add(thumbFile);
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Book.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Upload failed (${response.statusCode}): ${response.body}');
    }
  }

  static Future<List<Book>> getBooks({String? search, int? limit, bool? subscribed, bool? mine}) async {
    String endpoint = '/library/items';
    final List<String> queryParams = [];
    if (search != null && search.trim().isNotEmpty) {
      queryParams.add('search=${Uri.encodeComponent(search.trim())}');
    }
    if (limit != null) {
      queryParams.add('limit=$limit');
    }
    if (subscribed == true) {
      queryParams.add('subscribed=true');
    }
    if (mine == true) {
      queryParams.add('mine=true');
    }

    if (queryParams.isNotEmpty) {
      endpoint += '?${queryParams.join('&')}';
    }

    final response = await ApiService.get(endpoint);
    if (response['items'] is List) {
      return (response['items'] as List).map((b) => Book.fromJson(b)).toList();
    }
    return [];
  }

  /// 🏠 Netflix-style home endpoint with sections
  static Future<Map<String, List<Book>>> getLibraryHome() async {
    final response = await ApiService.get('/library/home');
    final Map<String, List<Book>> result = {};
    
    if (response['new_notes'] is List) {
      result['new_notes'] = (response['new_notes'] as List).map((b) => Book.fromJson(b)).toList();
    } else {
      result['new_notes'] = [];
    }
    
    if (response['trending'] is List) {
      result['trending'] = (response['trending'] as List).map((b) => Book.fromJson(b)).toList();
    } else {
      result['trending'] = [];
    }
    
    if (response['history'] is List) {
      result['history'] = (response['history'] as List).map((b) => Book.fromJson(b)).toList();
    } else {
      result['history'] = [];
    }
    
    if (response['saved'] is List) {
      result['saved'] = (response['saved'] as List).map((b) => Book.fromJson(b)).toList();
    } else {
      result['saved'] = [];
    }
    
    if (response['subscribed'] is List) {
      result['subscribed'] = (response['subscribed'] as List).map((b) => Book.fromJson(b)).toList();
    } else {
      result['subscribed'] = [];
    }
    
    return result;
  }

  /// 🔍 Fetch a specific note or book dynamically from the database.
  static Future<Book> getBook(String bookId) async {
    final response = await ApiService.get('/library/item/$bookId');
    return Book.fromJson(response);
  }

  static Future<Map<String, dynamic>> recordView(String bookId) async {
    return await ApiService.post('/library/$bookId/view', {});
  }

  static Future<Map<String, dynamic>> getChannelDetails(String channelId) async {
    return await ApiService.get('/library/channel/$channelId');
  }

  static Future<Map<String, dynamic>> toggleLike(String bookId) async {
    return await ApiService.post('/library/$bookId/like', {});
  }

  static Future<Map<String, dynamic>> toggleDislike(String bookId) async {
    return await ApiService.post('/library/$bookId/dislike', {});
  }

  /// 🔖 Toggle bookmark/save state for a specific book/note on backend.
  static Future<Map<String, dynamic>> toggleSave(String bookId) async {
    return await ApiService.post('/library/$bookId/save', {});
  }

  /// 🔔 Toggle subscription state for a publisher channel on backend.
  static Future<Map<String, dynamic>> toggleSubscribe(String channelId) async {
    return await ApiService.post('/library/channel/$channelId/subscribe', {});
  }

  /// 🔔 Fetch subscribed channels (with profile pics).
  static Future<List<LibraryChannel>> getSubscribedChannels() async {
    final response = await ApiService.get('/library/subscribed/channels');
    if (response['channels'] is List) {
      return (response['channels'] as List).map((c) => LibraryChannel.fromJson(c)).toList();
    }
    return [];
  }

  /// 📂 Fetch all library publications saved by the user.
  static Future<List<Book>> getSavedBooks() async {
    final response = await ApiService.get('/library/saved');
    if (response['items'] is List) {
      return (response['items'] as List).map((b) => Book.fromJson(b)).toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> reportBook(String bookId, String reason) async {
    return await ApiService.post('/library/$bookId/report', {'reason': reason});
  }

  static Future<BookComment> addComment(String bookId, String comment) async {
    final response = await ApiService.post('/library/$bookId/comment', {'comment': comment});
    return BookComment.fromJson(response);
  }

  static Future<Map<String, dynamic>> getComments(String bookId) async {
    final response = await ApiService.get('/library/$bookId/comments');
    final List<BookComment> commentsList = [];
    if (response['comments'] is List) {
      commentsList.addAll((response['comments'] as List).map((c) => BookComment.fromJson(c)));
    }
    return {
      'comments': commentsList,
      'book_owner_id': response['book_owner_id'] ?? '',
      'current_user_id': response['current_user_id'] ?? '',
    };
  }

  /// 📌 Toggle pin/unpin status on a comment. Only the book/library owner can call this.
  static Future<Map<String, dynamic>> togglePinComment(String commentId) async {
    return await ApiService.post('/library/comment/$commentId/pin', {});
  }

  /// 📊 Fetch studio earnings for the channel owner
  static Future<Map<String, dynamic>> getStudioEarnings() async {
    return await ApiService.get('/library/studio/earnings');
  }

  /// 👍 Toggle like status on a comment.
  static Future<Map<String, dynamic>> toggleLikeComment(String commentId) async {
    return await ApiService.post('/library/comment/$commentId/like', {});
  }

  /// 👎 Toggle dislike status on a comment.
  static Future<Map<String, dynamic>> toggleDislikeComment(String commentId) async {
    return await ApiService.post('/library/comment/$commentId/dislike', {});
  }

  /// ⛔ Toggle force stop for a publication (hides from search/home)
  static Future<Map<String, dynamic>> forceStopContent(String bookId) async {
    return await ApiService.put('/library/$bookId/force-stop', {});
  }

  /// 🗑️ Delete a publication permanently
  static Future<void> deleteContent(String bookId) async {
    await ApiService.delete('/library/$bookId');
  }

  // 📋 Playlist methods
  static Future<LibraryPlaylist> createPlaylist(String name, {String description = '', String visibility = 'public'}) async {
    final res = await ApiService.post('/library/playlists/create', {
      'name': name,
      'description': description,
      'visibility': visibility,
    });
    return LibraryPlaylist.fromJson(res);
  }

  static Future<List<LibraryPlaylist>> getMyPlaylists() async {
    final res = await ApiService.get('/library/playlists/my');
    if (res['playlists'] is List) {
      return (res['playlists'] as List).map((p) => LibraryPlaylist.fromJson(p)).toList();
    }
    return [];
  }

  static Future<LibraryPlaylist> getPlaylist(String playlistId) async {
    final res = await ApiService.get('/library/playlists/$playlistId');
    return LibraryPlaylist.fromJson(res['playlist'] ?? {});
  }

  static Future<Map<String, dynamic>> addToPlaylist(String playlistId, String bookId) async {
    return await ApiService.post('/library/playlists/$playlistId/add', {'book_id': bookId});
  }

  static Future<Map<String, dynamic>> removeFromPlaylist(String playlistId, String bookId) async {
    return await ApiService.post('/library/playlists/$playlistId/remove', {'book_id': bookId});
  }

  static Future<Map<String, dynamic>> deletePlaylist(dynamic playlistId) async {
    return await ApiService.delete('/library/playlists/$playlistId');
  }

  static Future<Map<String, dynamic>> updatePlaylist(dynamic playlistId, {String? name, String? description, String? visibility}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (visibility != null) body['visibility'] = visibility;
    return await ApiService.put('/library/playlists/$playlistId', body);
  }

  static Future<Map<String, dynamic>> reorderPlaylist(dynamic playlistId, List<String> bookIds) async {
    return await ApiService.post('/library/playlists/$playlistId/reorder', {'book_ids': bookIds});
  }

  // 🔍 Search methods
  static Future<Map<String, dynamic>> searchAll(String query, {int limit = 20}) async {
    return await ApiService.get('/library/search?q=${Uri.encodeComponent(query)}&limit=$limit');
  }

  static Future<Map<String, dynamic>> searchChannels(String query, {int limit = 20}) async {
    return await ApiService.get('/library/channels/search?q=${Uri.encodeComponent(query)}&limit=$limit');
  }

  static Future<Map<String, dynamic>> getBookAccess(String bookId) async {
    return await ApiService.get('/library/book/$bookId/access');
  }

  static Future<Map<String, dynamic>> purchaseBook(String bookId, String purchaseType) async {
    return await ApiService.post('/library/book/$bookId/purchase', {'purchase_type': purchaseType});
  }
}
