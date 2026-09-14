import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';

class BlueprintService {
  final String _baseUrl = "${StarlightConstants.apiBaseUrl}/document/blueprint";

  // 🏛️ Helper: Get Auth Headers
  Future<Map<String, String>> _getHeaders() async {
    final token = await StarlightStorage.getUserToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // ==========================================
  // 📐 BLUEPRINT ARCHITECT ENGINE
  // ==========================================

  /// 🏛️ Save a document blueprint structure to the vault
  Future<void> saveBlueprint(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/save"),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "Blueprint: Sync Failed");
    }
  }

  /// 🏛️ Fetch all existing blueprints for this institution
  Future<List<dynamic>> getBlueprints() async {
    final response = await http.get(
      Uri.parse("$_baseUrl/list"),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Blueprint: Retrieval Failed");
    }
  }
}
