import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';

class DocumentService {
  final String _baseUrl = "${StarlightConstants.apiBaseUrl}/document";

  // 🏛️ Helper: Get Auth Headers
  Future<Map<String, String>> _getHeaders() async {
    final token = await StarlightStorage.getUserToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // ==========================================
  // 📚 DOCUMENT MANAGEMENT (Syllabus, etc.)
  // ==========================================

  /// 🏛️ Fetch all pending/draft documents for the institution
  Future<List<dynamic>> getPendingDocuments() async {
    final response = await http.get(
      Uri.parse("$_baseUrl/pending/list"),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to fetch pending vault: ${response.statusCode}");
    }
  }

  /// 🏛️ Fetch all ready/complete/official finalized documents in the central vault
  Future<List<dynamic>> getFinalizedDocuments() async {
    final url = "$_baseUrl/vault/list";
    final headers = await _getHeaders();
    print("📱 [FLUTTER GET] URL: $url | Headers: $headers");
    
    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    print("📱 [FLUTTER RESPONSE] Status: ${response.statusCode} | Raw Body: ${response.body}");

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to fetch finalized vault: ${response.statusCode}");
    }
  }

  /// 🏛️ Sync a draft document to the institutional vault
  Future<void> syncPendingDocument(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/pending/sync"),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "Failed to sync draft document");
    }
  }

  /// 🏛️ Officially deploy/upload a finalized document to the central vault
  Future<void> uploadFinalDocument(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/vault/upload"),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "Failed to deploy official document");
    }
  }

  /// 🏛️ Formally expunge a draft from the institutional vault
  Future<void> deleteDraftDocument(dynamic id) async {
    final response = await http.delete(
      Uri.parse("$_baseUrl/pending/delete/$id"),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to remove draft from vault");
    }
  }

  // ==========================================
  // 🧭 SYLLABUS DIRECTORY (End-to-End Neo4j)
  // ==========================================

  /// 🏛️ Fetch all syllabuses stored and created in the Neo4j database
  Future<List<dynamic>> getSyllabuses() async {
    final response = await http.get(
      Uri.parse("$_baseUrl/syllabus/list"),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data['syllabuses'] ?? [];
    } else {
      throw Exception("Failed to fetch syllabuses: ${response.statusCode}");
    }
  }

  /// 🏛️ Create/Deploy a new syllabus to the Neo4j database
  Future<Map<String, dynamic>> createSyllabus(Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/syllabus/create"),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "Failed to create syllabus in database");
    }
  }

  /// 🏛️ Safe Fetch with empty-list fallback for robust UI experience
  Future<List<dynamic>> getSyllbusesListFallback() async {
    try {
      return await getSyllabuses();
    } catch (e) {
      print("Starlight Network Notice: Syllabus server fetch fallback active: $e");
      return [];
    }
  }

  // ==========================================
  // 💰 FEE VOUCHERS DIRECTORY (End-to-End Neo4j)
  // ==========================================

  /// 🏛️ Fetch all created and stored fee vouchers from the Neo4j database (Routed via /document for Nginx Proxy Safety)
  Future<List<dynamic>> getFeeVouchersHistory() async {
    final response = await http.get(
      Uri.parse("$_baseUrl/voucher/history"),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data['vouchers'] ?? [];
    } else {
      throw Exception("Failed to fetch fee vouchers: ${response.statusCode}");
    }
  }

  // ==========================================
  // 📅 ATTENDANCE DIRECTORY (End-to-End Neo4j)
  // ==========================================

  /// 🏛️ Fetch all student & staff attendance sessions from the Neo4j database (Routed via /document for Nginx Proxy Safety)
  Future<List<dynamic>> getAttendanceHistory() async {
    final response = await http.get(
      Uri.parse("$_baseUrl/attendance/history"),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return data['sessions'] ?? [];
    } else {
      throw Exception("Failed to fetch attendance sessions: ${response.statusCode}");
    }
  }

  /// 🏛️ Formally update a finalized document's content/name in the vault
  Future<void> updateDocument(String docId, String name, List<dynamic> content) async {
    final response = await http.put(
      Uri.parse("$_baseUrl/$docId"),
      headers: await _getHeaders(),
      body: jsonEncode({
        'name': name,
        'content': content,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to update document: ${response.statusCode}");
    }
  }
}
