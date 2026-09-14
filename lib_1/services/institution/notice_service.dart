import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';

class NoticeService {
  final String _baseUrl = "${StarlightConstants.apiBaseUrl}/document/notice";

  // 🏛️ Helper: Get Auth Headers
  Future<Map<String, String>> _getHeaders() async {
    final token = await StarlightStorage.getUserToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // ==========================================
  // 📢 NOTICE ARCHITECT & BROADCAST
  // ==========================================

  /// 🏛️ Broadcast a new notice to the institution
  Future<void> broadcastNotice(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/broadcast"),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "Broadcast: Sync Failed");
    }
  }

  /// 🏛️ Fetch historical notices for this institution
  Future<List<dynamic>> getNoticeHistory() async {
    final response = await http.get(
      Uri.parse("$_baseUrl/history"),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Notice Engine: History Retrieval Failed");
    }
  }

  /// 🏛️ Sign a notice with the current user's graphical signature
  Future<Map<String, dynamic>> signNotice(String noticeId) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/$noticeId/sign"),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final error = jsonDecode(response.body);
    throw Exception(error['detail'] ?? "Failed to sign notice");
  }
}
