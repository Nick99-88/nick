import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:starlight_flutter/core/constants.dart';
import 'package:starlight_flutter/core/token_manager.dart';

class ApiService {
  static const String _baseUrl = StarlightConstants.apiBaseUrl;
  static final _tm = TokenManager.instance;

  /// Sends a POST. If [requireAuth] is false, skips JWT (for pre-auth endpoints like login/signup).
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data, {
    bool requireAuth = true,
  }) async {
    Map<String, String> headers = {'Content-Type': 'application/json'};

    if (requireAuth) {
      try {
        final token = await _tm.getValidToken();
        headers['Authorization'] = 'Bearer $token';
      } catch (_) {
        throw Exception('{"detail":"No stored session"}');
      }
    }

    var response = await http.post(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
      body: jsonEncode(data),
    );

    if (requireAuth && response.statusCode == 401) {
      try {
        final fresh = await _tm.refreshBecause401();
        headers['Authorization'] = 'Bearer $fresh';
        response = await http.post(
          Uri.parse('$_baseUrl$endpoint'),
          headers: headers,
          body: jsonEncode(data),
        );
      } catch (_) {}
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    bool requireAuth = true,
  }) async {
    Map<String, String> headers = {'Content-Type': 'application/json'};

    if (requireAuth) {
      try {
        final token = await _tm.getValidToken();
        headers['Authorization'] = 'Bearer $token';
      } catch (_) {
        throw Exception('{"detail":"No stored session"}');
      }
    }

    var response = await http.get(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
    );

    if (requireAuth && response.statusCode == 401) {
      try {
        final fresh = await _tm.refreshBecause401();
        headers['Authorization'] = 'Bearer $fresh';
        response = await http.get(
          Uri.parse('$_baseUrl$endpoint'),
          headers: headers,
        );
      } catch (_) {}
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data, {
    bool requireAuth = true,
  }) async {
    Map<String, String> headers = {'Content-Type': 'application/json'};

    if (requireAuth) {
      try {
        final token = await _tm.getValidToken();
        headers['Authorization'] = 'Bearer $token';
      } catch (_) {
        throw Exception('{"detail":"No stored session"}');
      }
    }

    var response = await http.put(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
      body: jsonEncode(data),
    );

    if (requireAuth && response.statusCode == 401) {
      try {
        final fresh = await _tm.refreshBecause401();
        headers['Authorization'] = 'Bearer $fresh';
        response = await http.put(
          Uri.parse('$_baseUrl$endpoint'),
          headers: headers,
          body: jsonEncode(data),
        );
      } catch (_) {}
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool requireAuth = true,
  }) async {
    Map<String, String> headers = {'Content-Type': 'application/json'};

    if (requireAuth) {
      try {
        final token = await _tm.getValidToken();
        headers['Authorization'] = 'Bearer $token';
      } catch (_) {
        throw Exception('{"detail":"No stored session"}');
      }
    }

    var response = await http.delete(
      Uri.parse('$_baseUrl$endpoint'),
      headers: headers,
    );

    if (requireAuth && response.statusCode == 401) {
      try {
        final fresh = await _tm.refreshBecause401();
        headers['Authorization'] = 'Bearer $fresh';
        response = await http.delete(
          Uri.parse('$_baseUrl$endpoint'),
          headers: headers,
        );
      } catch (_) {}
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }
}
