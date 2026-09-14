import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';
import '../models/rtc_room_model.dart';

class RtcRoomService {
  static const String _baseUrl = StarlightConstants.apiBaseUrl;

  /// Helper to convert the HTTP base URL to a WebSocket (ws/wss) URL
  static String get wsBaseUrl {
    final baseUrl = StarlightConstants.apiBaseUrl;
    if (baseUrl.startsWith('https://')) {
      return baseUrl.replaceFirst('https://', 'wss://');
    } else if (baseUrl.startsWith('http://')) {
      return baseUrl.replaceFirst('http://', 'ws://');
    }
    // Fallback if not matching standard protocols
    return 'ws://10.0.2.2:8000';
  }

  /// Create a new WebRTC room
  Future<RtcRoom> createRoom({
    required String name,
    required String type,
    required String accessType,
    String? password,
    required String controlType,
    required String visibility,
  }) async {
    final token = await StarlightStorage.getUserToken();
    if (token == null) {
      throw Exception('User is not authenticated');
    }

    final url = Uri.parse('$_baseUrl/rtc/rooms/create?token=$token');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'type': type,
        'access_type': accessType,
        'password': password,
        'control_type': controlType,
        'visibility': visibility,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      return RtcRoom.fromJson(data);
    } else {
      final errorMsg = _parseErrorMessage(response.body);
      throw Exception('Failed to create room: $errorMsg');
    }
  }

  /// Fetch randomly sorted active public rooms
  Future<List<RtcRoom>> getPublicRooms() async {
    final url = Uri.parse('$_baseUrl/rtc/rooms/public');
    final response = await http.get(url);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => RtcRoom.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch public rooms');
    }
  }

  /// Fetch active rooms created by the current user's friends
  Future<List<RtcRoom>> getFriendRooms() async {
    final token = await StarlightStorage.getUserToken();
    if (token == null) throw Exception('User is not authenticated');

    final url = Uri.parse('$_baseUrl/rtc/rooms/friends?token=$token');
    final response = await http.get(url);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => RtcRoom.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch friend rooms');
    }
  }

  /// Fetch active rooms created by users in the same institution
  Future<List<RtcRoom>> getInstitutionalRooms() async {
    final token = await StarlightStorage.getUserToken();
    if (token == null) throw Exception('User is not authenticated');

    final url = Uri.parse('$_baseUrl/rtc/rooms/institutional?token=$token');
    final response = await http.get(url);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => RtcRoom.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch institutional rooms');
    }
  }

  /// Verify if a room exists, is active, and if it requires a password
  Future<Map<String, dynamic>> verifyRoom(String roomId) async {
    final cleanId = roomId.toUpperCase().trim();
    final url = Uri.parse('$_baseUrl/rtc/rooms/verify/$cleanId');
    final response = await http.get(url);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to verify room');
    }
  }

  /// Formulate the WebSocket signaling connection URL for a room
  Future<String> getSignalingUrl(String roomId, {String? roomPassword}) async {
    final token = await StarlightStorage.getUserToken();
    if (token == null) {
      throw Exception('User is not authenticated');
    }

    final cleanId = roomId.toUpperCase().trim();
    var wsUrl = '$wsBaseUrl/rtc/rooms/ws/$cleanId?token=$token';
    if (roomPassword != null && roomPassword.isNotEmpty) {
      wsUrl += '&password=${Uri.encodeComponent(roomPassword)}';
    }
    return wsUrl;
  }

  String _parseErrorMessage(String responseBody) {
    try {
      final parsed = jsonDecode(responseBody);
      if (parsed is Map && parsed.containsKey('detail')) {
        return parsed['detail'].toString();
      }
    } catch (_) {}
    return responseBody;
  }
}
