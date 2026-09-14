import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';

class DirectoryService {
  final String _baseUrl = "${StarlightConstants.apiBaseUrl}/institution/directory";

  Future<Map<String, String>> _getHeaders() async {
    final token = await StarlightStorage.getUserToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  /// 🏛️ Fetches pending join requests for the institution
  Future<List<dynamic>> getJoinRequests() async {
    final response = await http.get(
      Uri.parse("$_baseUrl/join-requests"),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception("Failed to fetch join requests");
  }

  /// 🏛️ Approves a pending join request
  Future<void> approveRequest(String requestId) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/approve-request/$requestId"),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "Failed to approve request");
    }
  }

  /// 🏛️ Rejects a pending join request
  Future<void> rejectRequest(String requestId) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/reject-request/$requestId"),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "Failed to reject request");
    }
  }

  /// 🏛️ Kick/Remove a user from the institution (Owner only)
  Future<void> kickUser(String userId, {String? reason}) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/kick-user/$userId"),
      headers: await _getHeaders(),
      body: jsonEncode({
        'reason': reason ?? 'Removed by institution owner',
      }),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "Failed to kick user");
    }
  }

  /// 🏛️ Block a user from the institution (Owner only)
  Future<void> blockUser(String userId, {String? reason}) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/block-user/$userId"),
      headers: await _getHeaders(),
      body: jsonEncode({
        'reason': reason ?? 'Blocked by institution owner',
      }),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "Failed to block user");
    }
  }

  /// 🏛️ Get institution activity logs (who joined, when, role)
  Future<List<dynamic>> getActivityLogs() async {
    final response = await http.get(
      Uri.parse("$_baseUrl/activity-logs"),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception("Failed to fetch activity logs");
  }

  /// 🏛️ Get blocked users list
  Future<List<dynamic>> getBlockedUsers() async {
    final response = await http.get(
      Uri.parse("$_baseUrl/blocked"),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception("Failed to fetch blocked users");
  }

  /// 🏛️ Unblock a user (Owner only)
  Future<void> unblockUser(String userId) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/unblock/$userId"),
      headers: await _getHeaders(),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "Failed to unblock user");
    }
  }

  /// 🏛️ Get join acceptance logs (who was accepted and by whom)
  Future<List<dynamic>> getJoinLogs() async {
    final response = await http.get(
      Uri.parse("$_baseUrl/join-logs"),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception("Failed to fetch join logs");
  }

}
