import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart'; // For JWT and userId

class IdentityService {
  final String _baseUrl = StarlightConstants.apiBaseUrl;

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await StarlightStorage.getUserToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // 1. Get App Identities by Hardware ID (replaces syncIdentity)
  // Calls GET @router.get("/my-apps")
  Future<List<dynamic>> getAppIdentitiesByHardware(String hardwareId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/system-identity/my-apps?hardware_id=$hardwareId'),
      headers: {'Content-Type': 'application/json'}, // No auth needed for this endpoint
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data; // Backend returns a list directly now
    }
    throw Exception("Failed to load app identities: ${response.statusCode}");
  }

  // 2. Generate: Calls POST @router.post("/register-app")
  // Now requires userId and JWT
  Future<Map<String, dynamic>> generateApp(String hardwareId, String appName, int userId) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/system-identity/register-app'),
      headers: headers,
      body: jsonEncode({
        'hardware_id': hardwareId,
        'app_name': appName,
        'user_id': userId, // Now sent from Flutter
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 403) {
      throw Exception("User not authorized to register app.");
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "App generation failed: ${response.statusCode}");
    }
  }

  // 3. Sync/Activate an App Instance (replaces setActive)
  // Calls POST @router.post("/sync-instance/{app_id}")
  Future<bool> syncAppInstance(String appId, String hardwareId) async {
    // No JWT needed for this endpoint as per backend router
    final response = await http.post(
      Uri.parse('$_baseUrl/system-identity/sync-instance/$appId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'hardware_id': hardwareId,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else if (response.statusCode == 404) {
      throw Exception("App instance not found for activation.");
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "App activation failed: ${response.statusCode}");
    }
  }

  // Placeholder for other identity-related services if needed
  // Future<void> updateApp(String appId, String appName) async { ... }
  // Future<void> deactivateApp(String appId) async { ... }
}
