import 'package:starlight_flutter/core/storage.dart';
import 'package:starlight_flutter/core/constants.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class MarksheetService {
  final String baseUrl = "${StarlightConstants.apiBaseUrl}/marksheet";

  // Helper: Get Auth Headers
  Future<Map<String, String>> _getHeaders() async {
    final token = await StarlightStorage.getUserToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // ==========================================
  // 📊 MARKSHEET MANAGEMENT (6 ROUTES)
  // ==========================================

  // 1. Create Marksheet (Save as Pending)
  Future<Map<String, dynamic>> createMarksheet(Map<String, dynamic> marksheetData) async {
    final response = await http.post(
      Uri.parse("$baseUrl/create"),
      headers: await _getHeaders(),
      body: jsonEncode({
        ...marksheetData,
        'status': 'pending', // Default to pending status
        'created_at': DateTime.now().toIso8601String(),
      }),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to create marksheet: ${response.statusCode}");
    }
  }

  // 2. Save Marksheet as Completed
  Future<Map<String, dynamic>> completeMarksheet(String marksheetId, Map<String, dynamic> marksheetData) async {
    final response = await http.put(
      Uri.parse("$baseUrl/complete/$marksheetId"),
      headers: await _getHeaders(),
      body: jsonEncode({
        ...marksheetData,
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      }),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to complete marksheet: ${response.statusCode}");
    }
  }

  // 3. Get All Marksheets (Including Pending and Completed)
  Future<List<Map<String, dynamic>>> getAllMarksheets() async {
    final response = await http.get(
      Uri.parse("$baseUrl/all"),
      headers: await _getHeaders(),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Handle both direct array and wrapped object responses
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      } else {
        return List<Map<String, dynamic>>.from(data['marksheets'] ?? []);
      }
    } else {
      throw Exception("Failed to fetch marksheets: ${response.statusCode}");
    }
  }

  // 4. Get Pending Marksheets Only
  Future<List<Map<String, dynamic>>> getPendingMarksheets() async {
    final response = await http.get(
      Uri.parse("$baseUrl/pending"),
      headers: await _getHeaders(),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Handle both direct array and wrapped object responses
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      } else {
        return List<Map<String, dynamic>>.from(data['marksheets'] ?? []);
      }
    } else {
      throw Exception("Failed to fetch pending marksheets: ${response.statusCode}");
    }
  }

  // 5. Get Completed Marksheets Only
  Future<List<Map<String, dynamic>>> getCompletedMarksheets() async {
    final response = await http.get(
      Uri.parse("$baseUrl/completed"),
      headers: await _getHeaders(),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Handle both direct array and wrapped object responses
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      } else {
        return List<Map<String, dynamic>>.from(data['marksheets'] ?? []);
      }
    } else {
      throw Exception("Failed to fetch completed marksheets: ${response.statusCode}");
    }
  }

  // 6. Get Single Marksheet by ID
  Future<Map<String, dynamic>> getMarksheetById(String marksheetId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/$marksheetId"),
      headers: await _getHeaders(),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to fetch marksheet: ${response.statusCode}");
    }
  }

  // ==========================================
  // 🔧 ADDITIONAL MANAGEMENT (3 ROUTES)
  // ==========================================

  // 7. Update Marksheet (For editing pending marksheets)
  Future<Map<String, dynamic>> updateMarksheet(String marksheetId, Map<String, dynamic> updateData) async {
    final response = await http.put(
      Uri.parse("$baseUrl/update/$marksheetId"),
      headers: await _getHeaders(),
      body: jsonEncode({
        ...updateData,
        'updated_at': DateTime.now().toIso8601String(),
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to update marksheet: ${response.statusCode}");
    }
  }

  // 8. Delete Marksheet
  Future<void> deleteMarksheet(String marksheetId) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/delete/$marksheetId"),
      headers: await _getHeaders(),
    );
    
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception("Failed to delete marksheet: ${response.statusCode}");
    }
  }

  // 9. Get Marksheet Statistics
  Future<Map<String, dynamic>> getMarksheetStatistics() async {
    final response = await http.get(
      Uri.parse("$baseUrl/statistics"),
      headers: await _getHeaders(),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to fetch statistics: ${response.statusCode}");
    }
  }

  // ==========================================
  // 📤 EXPORT FUNCTIONALITY (2 ROUTES)
  // ==========================================

  // 10. Export Marksheet as PDF
  Future<http.Response> exportMarksheetPDF(String marksheetId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/export/pdf/$marksheetId"),
      headers: await _getHeaders(),
    );
    return response;
  }

  // 11. Export Marksheet as Excel
  Future<http.Response> exportMarksheetExcel(String marksheetId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/export/excel/$marksheetId"),
      headers: await _getHeaders(),
    );
    return response;
  }
}
