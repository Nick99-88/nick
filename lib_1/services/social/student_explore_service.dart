import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';

class StudentExploreService {
  final String _baseUrl = "${StarlightConstants.apiBaseUrl}/explore/students";

  Future<Map<String, String>> _getHeaders() async {
    final token = await StarlightStorage.getUserToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  Future<Map<String, dynamic>> searchStudents(String query) async {
    try {
      final uri = Uri.parse("$_baseUrl?query=${Uri.encodeComponent(query)}");
      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 403) {
        throw Exception("You must have student portals selected");
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? "Failed to search students");
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception("Network error: ${e.toString()}");
    }
  }

  Future<Map<String, dynamic>> getNearbyStudents(String city, String country) async {
    try {
      final params = {
        if (city.isNotEmpty) 'city': city,
        if (country.isNotEmpty) 'country': country,
      };
      final uri = Uri.parse("$_baseUrl/map").replace(queryParameters: params);
      final response = await http.get(uri, headers: await _getHeaders());

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed to fetch nearby students");
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception("Network error: ${e.toString()}");
    }
  }
}