import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';

class BootstrapService {
  final String _baseUrl = "${StarlightConstants.apiBaseUrl}/auth";

  Future<Map<String, String>> _getHeaders() async {
    final token = await StarlightStorage.getUserToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  /// 🏛️ Fetches the initial app state and saves it to local storage.
  Future<void> performBootstrap() async {
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl/bootstrap"),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Save all fetched data to SharedPreferences
        await StarlightStorage.setHasInstitution(data['has_institution'] ?? false);
        await StarlightStorage.setPhoneVerified(data['is_phone_verified'] ?? false);
        await StarlightStorage.setDashboardStats(
          students: data['student_count'] ?? 0,
          teachers: data['teacher_count'] ?? 0,
          staff: data['staff_count'] ?? 0,
        );
      }
    } catch (e) {
      // In case of network failure, it will just use the old cached data.
      print("Bootstrap failed: $e");
    }
  }

  /// 🏛️ Notifies the backend that the user's phone is now verified.
  Future<void> confirmPhoneVerification(String phoneNumber) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/verify-phone"),
      headers: await _getHeaders(),
      body: jsonEncode({"phone_number": phoneNumber}),
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to confirm phone verification with backend.");
    }
  }
}
