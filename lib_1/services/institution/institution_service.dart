import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';
import '../../models/institution/institution_model.dart';
import '../../models/staff/staff_join_request.dart';

class InstitutionService {
  final String _baseUrl = StarlightConstants.apiBaseUrl;
  // 🏛️ Check Ownership: The Gateway Call
  Future<Map<String, dynamic>> checkOwnership() async {
    final token = await StarlightStorage.getUserToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/dashboard/check-ownership'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['detail'] ?? "Ownership verification failed.");
  }

  // 🏛️ Create Institution: Handles /create-school, /create-academy, /create-college
  Future<Map<String, dynamic>> createInstitution({
    required String type, // school, academy, or college
    required Map<String, dynamic> payload,
  }) async {
    final token = await StarlightStorage.getUserToken();

    // 🏛️ The URL must strictly match the @router.post names
    final url = Uri.parse('$_baseUrl/ready/create-$type');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return data;
    } else {
      // 🏛️ If 422 occurs, this will show the specific field error from FastAPI
      print("Establishment Error: ${data['detail']}");
      throw Exception(data['detail'] ?? "Establishment rejected by system.");
    }
  }

  // 🔍 Get list of institutions with pagination
  Future<List<InstitutionModel>> getInstitutions({
    required String token,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/institutions?limit=$limit&offset=$offset'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final List<dynamic> institutions = data['institutions'] ?? [];
      return institutions.map((json) => InstitutionModel.fromJson(json)).toList();
    }
    throw Exception(data['detail'] ?? "Failed to fetch institutions.");
  }

  // 🔍 Search institutions by name or code
  Future<List<InstitutionModel>> searchInstitutions({
    required String token,
    required String query,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/institutions/search?q=${Uri.encodeComponent(query)}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final List<dynamic> institutions = data['institutions'] ?? [];
      return institutions.map((json) => InstitutionModel.fromJson(json)).toList();
    }
    throw Exception(data['detail'] ?? "Search failed.");
  }

  // 📤 Send staff join request to an institution
  Future<void> sendStaffJoinRequest({
    required String token,
    required int institutionId,
    String? message,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/staff/join-request'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'institution_id': institutionId,
        'message': message,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }
    throw Exception(data['detail'] ?? "Failed to send join request.");
  }

  // 📋 Get staff join requests
  Future<List<StaffJoinRequest>> getStaffJoinRequests({
    required String token,
    String? status,
  }) async {
    String url = '$_baseUrl/staff/join-requests';
    if (status != null) {
      url += '?status=$status';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final List<dynamic> requests = data['requests'] ?? [];
      return requests.map((json) => StaffJoinRequest.fromJson(json)).toList();
    }
    throw Exception(data['detail'] ?? "Failed to fetch join requests.");
  }

  // ❌ Cancel a pending join request
  Future<void> cancelStaffJoinRequest({
    required String token,
    required String requestId,
  }) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/staff/join-requests/$requestId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return;
    }
    throw Exception(data['detail'] ?? "Failed to cancel join request.");
  }
}