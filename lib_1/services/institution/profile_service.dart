import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';

class ProfileService {
  final String _baseUrl = "${StarlightConstants.apiBaseUrl}/profile";

  Future<Map<String, String>> _getHeaders() async {
    final token = await StarlightStorage.getUserToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  /// 🏛️ Fetches the combined Professional & Institutional profile
  Future<Map<String, dynamic>> getProfessionalProfile() async {
    final response = await http.get(
      Uri.parse("$_baseUrl/professional-details"),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception("Failed to load professional profile");
  }

  /// 🏛️ Updates both User Profile and Institution details in one transaction
  Future<void> updateProfessionalProfile(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/professional-details/update"),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "Failed to update profile");
    }
  }

  /// 🏛️ Mark institution setup as complete (has_institution=true)
  Future<void> completeInstitutionSetup() async {
    final response = await http.post(
      Uri.parse("$_baseUrl/complete-institution-setup"),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      await StarlightStorage.setHasInstitution(true);
      debugPrint('🏛️ Institution setup marked as complete');
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "Failed to complete institution setup");
    }
  }
}
