import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';

class UserProfileService {
  final String _baseUrl = "${StarlightConstants.apiBaseUrl}/profile";

  Future<Map<String, String>> _getHeaders() async {
    final token = await StarlightStorage.getUserToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  /// 🏛️ Fetches the user's personal identity record
  Future<Map<String, dynamic>> getIdentity() async {
    final response = await http.get(
      Uri.parse("$_baseUrl/identity"),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception("Failed to load user identity");
  }

  /// 🏛️ Updates specific fields in the user's identity
  Future<void> updateIdentity(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/identity/update"),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "Failed to update identity");
    }
  }
}
