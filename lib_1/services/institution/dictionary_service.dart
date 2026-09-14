import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';

class DictionaryService {
  final String _baseUrl = "${StarlightConstants.apiBaseUrl}/linguistic";

  // 🏛️ Helper: Get Auth Headers
  Future<Map<String, String>> _getHeaders() async {
    final token = await StarlightStorage.getUserToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // ==========================================
  // 📖 DICTIONARY & LINGUISTIC ENGINE
  // ==========================================

  /// 🏛️ Fetch word insights (meanings, synonyms, examples)
  Future<Map<String, dynamic>> getWordInsights(String word) async {
    final response = await http.get(
      Uri.parse("$_baseUrl/dictionary?word=$word"),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Linguistic Engine: Insight Fetch Failed");
    }
  }

  /// 🏛️ Perform grammar analysis on a sentence
  Future<Map<String, dynamic>> analyzeGrammar(String text) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/grammar/analyze"),
      headers: await _getHeaders(),
      body: jsonEncode({"text": text}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Linguistic Engine: Grammar Analysis Failed");
    }
  }
}
