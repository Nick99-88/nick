import 'package:http/http.dart' as http;
import 'secure_http_client.dart';

/// Drop-in replacement for `package:http` top-level functions.
/// Every call auto-refreshes the JWT on 401 and retries once.
/// All requests are signed via SecureHttpClient.
class StarlightHttp {
  static final _client = SecureHttpClient.shared;

  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    return _client.sendWithRetry('GET', url, headers: headers);
  }

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _client.sendWithRetry('POST', url, headers: headers, body: body);
  }

  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _client.sendWithRetry('PUT', url, headers: headers, body: body);
  }

  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    return _client.sendWithRetry('DELETE', url, headers: headers);
  }

  static Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    return _client.sendWithRetry('PATCH', url, headers: headers, body: body);
  }
}
