import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';
import '../../services/signed_api_service.dart';

class ChatService {
  final String _baseUrl = "${StarlightConstants.apiBaseUrl}/chat";

  /// 🏛️ Real-time phone number validation
  Future<Map<String, dynamic>> validatePhoneNumber(String phoneNumber) async {
    try {
      final data = await SignedApiService.post(
        "$_baseUrl/validate-phone?phone=$phoneNumber",
        {},
      );
      return data;
    } catch (e) {
      final error = e.toString();
      throw Exception(error.contains("detail") ? error : "Failed to validate phone number");
    }
  }

  /// 🏛️ Search user by phone number or ID
  Future<Map<String, dynamic>> searchUser(String searchType, String searchValue) async {
    try {
      final data = await SignedApiService.post(
        "$_baseUrl/search-user?search_type=$searchType&search_value=$searchValue",
        {},
      );
      return data;
    } catch (e) {
      final error = e.toString();
      throw Exception(error.contains("detail") ? error : "Failed to search user");
    }
  }

  /// 🏛️ Create chat request (user ID - requires approval)
  Future<Map<String, dynamic>> createChatRequest(int userId, {String? displayName}) async {
    try {
      final data = await SignedApiService.post(
        "$_baseUrl/create-chat/$userId",
        {"display_name": displayName},
      );
      return data;
    } catch (e) {
      final error = e.toString();
      throw Exception(error.contains("detail") ? error : "Failed to create chat request");
    }
  }

  /// 🏛️ Create chat by phone number (auto-approved)
  Future<Map<String, dynamic>> createChatByPhone(String phoneNumber) async {
    try {
      final data = await SignedApiService.post(
        "$_baseUrl/create-chat-by-phone/$phoneNumber",
        {},
      );
      return data;
    } catch (e) {
      final error = e.toString();
      throw Exception(error.contains("detail") ? error : "Failed to create chat by phone number");
    }
  }

  /// 🏛️ Get pending chat requests
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    try {
      final data = await SignedApiService.get("$_baseUrl/pending-requests");
      return List<Map<String, dynamic>>.from(data['requests']);
    } catch (e) {
      final error = e.toString();
      throw Exception(error.contains("detail") ? error : "Failed to get pending requests");
    }
  }

  /// 🏛️ Accept chat request
  Future<void> acceptRequest(int chatId) async {
    try {
      await SignedApiService.post("$_baseUrl/accept-request/$chatId", {});
    } catch (e) {
      final error = e.toString();
      throw Exception(error.contains("detail") ? error : "Failed to accept request");
    }
  }

  /// 🏛️ Reject chat request
  Future<void> rejectRequest(int chatId) async {
    try {
      await SignedApiService.post("$_baseUrl/reject-request/$chatId", {});
    } catch (e) {
      final error = e.toString();
      throw Exception(error.contains("detail") ? error : "Failed to reject request");
    }
  }

  /// 🏛️ Get user's active chats
  Future<List<Map<String, dynamic>>> getUserChats() async {
    try {
      final data = await SignedApiService.get("$_baseUrl/chats");
      return List<Map<String, dynamic>>.from(data['chats']);
    } catch (e) {
      final error = e.toString();
      throw Exception(error.contains("detail") ? error : "Failed to get chats");
    }
  }

  /// 🏛️ Get chat messages by friend user ID (loads history)
  Future<Map<String, dynamic>> getMessagesByFriendId(String friendId, {int limit = 50, int offset = 0}) async {
    try {
      final data = await SignedApiService.get(
        "$_baseUrl/messages-by-user/$friendId?limit=$limit&offset=$offset",
      );
      return data;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception("Network error: ${e.toString()}");
    }
  }

  /// 🏛️ Get chat messages
  Future<List<Map<String, dynamic>>> getChatMessages(int chatId, {int limit = 50, int offset = 0}) async {
    try {
      final data = await SignedApiService.get(
        "$_baseUrl/messages/$chatId?limit=$limit&offset=$offset",
      );
      return List<Map<String, dynamic>>.from(data['messages']);
    } catch (e) {
      final error = e.toString();
      throw Exception(error.contains("detail") ? error : "Failed to get messages");
    }
  }

  /// 🏛️ Send message
  Future<Map<String, dynamic>> sendMessage(int chatId, String content, {String messageType = "text"}) async {
    try {
      final data = await SignedApiService.post(
        "$_baseUrl/send-message/$chatId",
        {"content": content, "message_type": messageType},
      );
      return data;
    } catch (e) {
      final error = e.toString();
      throw Exception(error.contains("detail") ? error : "Failed to send message");
    }
  }

  /// 🏛️ Upload media file (multipart — requires raw http for file upload)
  Future<Map<String, dynamic>> uploadMedia(int chatId, String filePath, String messageType) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse("$_baseUrl/upload-media/$chatId?message_type=$messageType"),
    );

    final token = await StarlightStorage.getUserToken();
    request.headers['Authorization'] = 'Bearer $token';

    final file = await http.MultipartFile.fromPath('file', filePath);
    request.files.add(file);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "Failed to upload media");
    }
  }

  /// 🏛️ Initiate call
  Future<Map<String, dynamic>> initiateCall(int chatId, {String callType = "voice"}) async {
    try {
      final data = await SignedApiService.post(
        "$_baseUrl/initiate-call/$chatId?call_type=$callType",
        {},
      );
      return data;
    } catch (e) {
      final error = e.toString();
      throw Exception(error.contains("detail") ? error : "Failed to initiate call");
    }
  }

  /// 🏛️ Answer call
  Future<Map<String, dynamic>> answerCall(int callId, String action) async {
    try {
      final data = await SignedApiService.post(
        "$_baseUrl/answer-call/$callId?action=$action",
        {},
      );
      return data;
    } catch (e) {
      final error = e.toString();
      throw Exception(error.contains("detail") ? error : "Failed to answer call");
    }
  }

  /// 🏛️ End call
  Future<Map<String, dynamic>> endCall(int callId) async {
    try {
      final data = await SignedApiService.post(
        "$_baseUrl/end-call/$callId",
        {},
      );
      return data;
    } catch (e) {
      final error = e.toString();
      throw Exception(error.contains("detail") ? error : "Failed to end call");
    }
  }
}
