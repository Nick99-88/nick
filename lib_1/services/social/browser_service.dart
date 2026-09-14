import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';

class BrowserService {
  final String _baseUrl = "${StarlightConstants.apiBaseUrl}/browser";

  Future<Map<String, String>> _getHeaders() async {
    final token = await StarlightStorage.getUserToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  Future<void> addHistory(String url, String title) async {
    try {
      await http.post(
        Uri.parse("$_baseUrl/history?url=${Uri.encodeComponent(url)}&title=${Uri.encodeComponent(title)}"),
        headers: await _getHeaders(),
      );
    } catch (_) {}
  }

  Future<List<Map<String, String>>> getHistory({int limit = 100}) async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/history?limit=$limit"),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, String>>.from(
          (data['history'] as List).map((e) => {
            'title': e['title'] ?? '',
            'url': e['url'] ?? '',
            'time': e['visited_at'] ?? '',
          }),
        );
      }
    } catch (_) {}
    return [];
  }

  Future<void> clearHistory() async {
    try {
      await http.delete(
        Uri.parse("$_baseUrl/history"),
        headers: await _getHeaders(),
      );
    } catch (_) {}
  }
}
