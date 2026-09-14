import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';

class InstitutionProfileService {
  final String _baseUrl = "${StarlightConstants.apiBaseUrl}/profile";

  Future<Map<String, String>> _getHeaders() async {
    final token = await StarlightStorage.getUserToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  /// 🏛️ Fetches the owner's institutional setup, including polymorphic details.
  Future<Map<String, dynamic>> getInstitutionProfile() async {
    final response = await http.get(
      Uri.parse("$_baseUrl/institution-details"),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception("Failed to load institution profile");
  }

  /// 🏛️ Polymorphic Upsert: Creates or updates the institution and its specific details.
  Future<void> updateInstitutionProfile(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/institution-details/update"),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "Failed to sync institution profile");
    }
  }
}
