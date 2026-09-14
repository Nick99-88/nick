import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';

class StudentFriendService {
  final String _baseUrl = "${StarlightConstants.apiBaseUrl}/friend-requests";

  Future<Map<String, String>> _getHeaders() async {
    final token = await StarlightStorage.getUserToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  Future<Map<String, dynamic>> sendStudentRequest(String receiverId) async {
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/student-request"),
        headers: await _getHeaders(),
        body: jsonEncode({"receiver_id": receiverId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 403) {
        throw Exception("You must have student portals selected");
      } else if (response.statusCode == 409) {
        throw Exception("Request already exists or already friends");
      } else if (response.statusCode == 404) {
        throw Exception("Receiver is not a student portals user");
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? "Failed to send request");
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception("Network error: ${e.toString()}");
    }
  }

  Future<List<Map<String, dynamic>>> getStudentFriends() async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/student-friends"),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['friends'] ?? []);
      } else if (response.statusCode == 403) {
        throw Exception("You must have student portals selected");
      } else {
        throw Exception("Failed to fetch student friends");
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception("Network error: ${e.toString()}");
    }
  }

  Future<List<Map<String, dynamic>>> getPendingStudentRequests() async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/pending"),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['requests'] ?? []);
      } else {
        throw Exception("Failed to fetch pending requests");
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception("Network error: ${e.toString()}");
    }
  }

  Future<Map<String, dynamic>> respondToRequest(String requestId, bool accepted) async {
    try {
      final response = await http.put(
        Uri.parse("$_baseUrl/$requestId/respond"),
        headers: await _getHeaders(),
        body: jsonEncode({"accepted": accepted}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? "Failed to respond");
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception("Network error: ${e.toString()}");
    }
  }

  Future<bool> checkFriendship(String otherId) async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/check/$otherId"),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['is_friend'] ?? false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> removeFriend(String friendId) async {
    try {
      final response = await http.delete(
        Uri.parse("$_baseUrl/$friendId"),
        headers: await _getHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to remove friend");
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception("Network error: ${e.toString()}");
    }
  }
}