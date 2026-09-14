import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';

class SupportService {
  final String _baseUrl = StarlightConstants.apiBaseUrl;

  // 🏛️ Logic: Hit the support-request route
  Future<Map<String, dynamic>> submitTicket(String email, String issue) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/support-request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'issue': issue,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data; // Returns ticket_id and success message
    } else {
      // 🏛️ Propagates your FastAPI HTTPException detail
      throw Exception(data['detail'] ?? "The support vault is locked.");
    }
  }
}