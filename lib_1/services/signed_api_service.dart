import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:starlight_flutter/core/constants.dart';
import 'package:starlight_flutter/core/hardware_signer.dart';
import 'package:starlight_flutter/core/token_manager.dart';

class SignedApiService {
  static const String _baseUrl = StarlightConstants.apiBaseUrl;
  static final _tm = TokenManager.instance;

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final token = await _tm.getValidToken();
    final headers = await _buildHeaders('POST', endpoint, token, data);
    var response = await http.post(
      Uri.parse(endpoint.startsWith('http') ? endpoint : '$_baseUrl$endpoint'),
      headers: headers,
      body: jsonEncode(data),
    );

    if (response.statusCode == 401) {
      final fresh = await _tm.refreshBecause401();
      final retryHeaders = await _buildHeaders('POST', endpoint, fresh, data);
      response = await http.post(
        Uri.parse(
          endpoint.startsWith('http') ? endpoint : '$_baseUrl$endpoint',
        ),
        headers: retryHeaders,
        body: jsonEncode(data),
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  static Future<Map<String, dynamic>> get(String endpoint) async {
    final token = await _tm.getValidToken();
    final headers = await _buildHeaders('GET', endpoint, token, null);
    var response = await http.get(
      Uri.parse(endpoint.startsWith('http') ? endpoint : '$_baseUrl$endpoint'),
      headers: headers,
    );

    if (response.statusCode == 401) {
      final fresh = await _tm.refreshBecause401();
      final retryHeaders = await _buildHeaders('GET', endpoint, fresh, null);
      response = await http.get(
        Uri.parse(
          endpoint.startsWith('http') ? endpoint : '$_baseUrl$endpoint',
        ),
        headers: retryHeaders,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  static Future<Map<String, dynamic>> delete(String endpoint) async {
    final token = await _tm.getValidToken();
    final headers = await _buildHeaders('DELETE', endpoint, token, null);
    var response = await http.delete(
      Uri.parse(endpoint.startsWith('http') ? endpoint : '$_baseUrl$endpoint'),
      headers: headers,
    );

    if (response.statusCode == 401) {
      final fresh = await _tm.refreshBecause401();
      final retryHeaders = await _buildHeaders('DELETE', endpoint, fresh, null);
      response = await http.delete(
        Uri.parse(
          endpoint.startsWith('http') ? endpoint : '$_baseUrl$endpoint',
        ),
        headers: retryHeaders,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  static Future<Map<String, String>> _buildHeaders(
    String method,
    String path,
    String token, [
    Map<String, dynamic>? body,
  ]) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final publicKey = await HardwareSigner.getPublicKey();
    if (publicKey != null) {
      try {
        final signatureHeader = await HardwareSigner.buildSignatureHeader(
          method: method,
          path: path,
          body: body != null ? jsonEncode(body) : null,
        );
        headers['X-Signature'] = signatureHeader;
      } catch (_) {}
    }

    return headers;
  }
}
