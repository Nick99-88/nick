import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';

class ExploreService {
  final String _baseUrl = "${StarlightConstants.apiBaseUrl}/explore";

  Future<Map<String, String>> _getHeaders() async {
    final token = await StarlightStorage.getUserToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  /// 🏛️ Fetches full search results from the REST endpoint
  Future<Map<String, dynamic>> search(String query, {String gender = "", String role = "", String instType = ""}) async {
    try {
      final params = {
        if (query.isNotEmpty) 'query': query,
        if (gender.isNotEmpty) 'gender': gender,
        if (role.isNotEmpty) 'role': role,
        if (instType.isNotEmpty) 'inst_type': instType,
      };
      final uri = Uri.parse("$_baseUrl/search").replace(queryParameters: params);
      final response = await http.get(uri, headers: await _getHeaders());
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'users': List<Map<String, dynamic>>.from(data['users'] ?? []),
          'institutions': List<Map<String, dynamic>>.from(data['institutions'] ?? []),
          'user_institution_info': data['user_institution_info'] ?? {},
        };
      } else if (response.statusCode == 401) {
        throw Exception("Authentication required. Please login again.");
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? "Failed to perform search");
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception("Network error: ${e.toString()}");
    }
  }

  /// 🏛️ Sends a formal request to join an institution
  Future<void> sendJoinRequest(dynamic institutionId, String role) async {
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/join-request/$institutionId"),
        headers: await _getHeaders(),
        body: jsonEncode({"role_requested": role}),
      );
      if (response.statusCode == 200) {
        return; // Success
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? "Failed to send join request");
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception("Network error: ${e.toString()}");
    }
  }

  /// 🏛️ Fetch institutions that have completed setup (has_institution=true)
  Future<Map<String, dynamic>> fetchActiveInstitutions() async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/institutions?has_institution=true"),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'institutions': List<Map<String, dynamic>>.from(data['institutions'] ?? []),
          'user_institution_info': data['user_institution_info'] ?? {},
        };
      } else {
        throw Exception("Failed to fetch active institutions");
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception("Network error: ${e.toString()}");
    }
  }

  /// 🏛️ Fetch detailed professional data of a specific institution
  Future<Map<String, dynamic>> getInstitutionDetails(String institutionId) async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/institution/$institutionId"),
        headers: await _getHeaders(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed to fetch institution details");
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception("Network error: ${e.toString()}");
    }
  }

  /// 🏛️ Join institution by access key
  Future<Map<String, dynamic>> joinWithAccessKey(String institutionId, String accessKey) async {
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/join-with-key/$institutionId"),
        headers: await _getHeaders(),
        body: jsonEncode({"access_key": accessKey}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? "Failed to join with access key");
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception("Network error: ${e.toString()}");
    }
  }

  Future<Map<String, dynamic>> getNearbyUsers(String city, String country, {String role = 'all'}) async {
    try {
      final params = {
        if (city.isNotEmpty) 'city': city,
        if (country.isNotEmpty) 'country': country,
        if (role.isNotEmpty && role != 'all') 'role': role,
      };
      final uri = Uri.parse("$_baseUrl/nearby-users").replace(queryParameters: params);
      final response = await http.get(uri, headers: await _getHeaders());
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed to fetch nearby users");
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception("Network error: ${e.toString()}");
    }
  }

  /// 👨‍🎓 Search for individual students (no role, no institution) with student_portals app
  Future<Map<String, dynamic>> searchStudents(String query) async {
    try {
      final uri = Uri.parse("$_baseUrl/students?query=${Uri.encodeComponent(query)}");
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

  /// 👨‍🎓 Fetch nearby individual students by city/country for map display
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
