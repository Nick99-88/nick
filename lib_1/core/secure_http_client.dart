import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'hardware_signer.dart';
import 'token_manager.dart';

/// Centralized HTTP client that enforces auth + cryptographic signing
/// on every outbound request. All API callers should route through this.
///
/// Usage:
///   final client = SecureHttpClient();
///   final response = await client.post(url, body: body);
///   // — or use the static convenience methods which use a shared singleton:
///   final response = await SecureHttpClient.post(url, body: body);
class SecureHttpClient extends http.BaseClient {
  final http.Client _inner;
  final bool signRequests;

  SecureHttpClient({http.Client? inner, this.signRequests = true})
      : _inner = inner ?? http.Client();

  static final SecureHttpClient _shared = SecureHttpClient();
  static SecureHttpClient get shared => _shared;

  /// Static convenience: mirrors `package:http` top-level API.
  static Future<http.Response> getRequest(Uri url, {Map<String, String>? headers}) =>
      _shared.sendWithRetry('GET', url, headers: headers);

  static Future<http.Response> postRequest(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _shared.sendWithRetry('POST', url, headers: headers, body: body);

  static Future<http.Response> putRequest(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _shared.sendWithRetry('PUT', url, headers: headers, body: body);

  static Future<http.Response> deleteRequest(Uri url,
          {Map<String, String>? headers}) =>
      _shared.sendWithRetry('DELETE', url, headers: headers);

  static Future<http.Response> patchRequest(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _shared.sendWithRetry('PATCH', url, headers: headers, body: body);

  /// Core logic: build headers → send → retry once on 401.
  Future<http.Response> sendWithRetry(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      final token = await TokenManager.instance.getValidToken();
      final enriched = await _enrichHeaders(method, url, token, body, headers);
      final request = _buildRequest(method, url, enriched, body);
      var response = await _inner.send(request);

      if (response.statusCode == 401) {
        try {
          final fresh = await TokenManager.instance.refreshBecause401();
          final retryHeaders =
              await _enrichHeaders(method, url, fresh, body, headers);
          final retryRequest = _buildRequest(method, url, retryHeaders, body);
          response = await _inner.send(retryRequest);
        } catch (_) {
          return http.Response.fromStream(response);
        }
      }
      return http.Response.fromStream(response);
    } catch (_) {
      return http.Response('{"detail":"No stored session"}', 401);
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // For callers using the BaseClient interface directly.
    final method = request.method;
    final url = request.url;

    try {
      final token = await TokenManager.instance.getValidToken();
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Content-Type'] ??= 'application/json';

      if (signRequests) {
        await _attachSignature(request, method, url.toString());
      }

      var response = await _inner.send(request);

      if (response.statusCode == 401) {
        try {
          final fresh = await TokenManager.instance.refreshBecause401();
          // Rebuild request with fresh token.
          final retry = _cloneRequest(request);
          retry.headers['Authorization'] = 'Bearer $fresh';
          if (signRequests) {
            await _attachSignature(retry, method, url.toString());
          }
          response = await _inner.send(retry);
        } catch (_) {
          return response;
        }
      }
      return response;
    } catch (_) {
      return http.StreamedResponse(
        Stream.value([]),
        401,
        reasonPhrase: 'No stored session',
      );
    }
  }

  /// Attaches the Ed25519 device signature header.
  Future<void> _attachSignature(
    http.BaseRequest request,
    String method,
    String path,
  ) async {
    final publicKey = await HardwareSigner.getPublicKey();
    if (publicKey == null) return;

    try {
      String? bodyString;
      if (request is http.Request) {
        bodyString = request.body;
      }

      final signatureHeader = await HardwareSigner.buildSignatureHeader(
        method: method,
        path: path,
        body: bodyString,
      );
      request.headers['X-Signature'] = signatureHeader;
    } catch (_) {
      // Signing failed — proceed without signature.
      // The backend middleware will reject if signature is mandatory.
    }
  }

  /// Builds headers with auth token, signature, and caller overrides.
  Future<Map<String, String>> _enrichHeaders(
    String method,
    Uri url,
    String token,
    Object? body,
    Map<String, String>? callerHeaders,
  ) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      if (callerHeaders != null) ...callerHeaders,
    };

    if (signRequests) {
      final publicKey = await HardwareSigner.getPublicKey();
      if (publicKey != null) {
        try {
          final bodyString = body != null
              ? (body is String ? body : jsonEncode(body))
              : null;
          final signatureHeader = await HardwareSigner.buildSignatureHeader(
            method: method,
            path: url.toString(),
            body: bodyString,
          );
          headers['X-Signature'] = signatureHeader;
        } catch (_) {}
      }
    }

    return headers;
  }

  http.BaseRequest _buildRequest(
    String method,
    Uri url,
    Map<String, String> headers,
    Object? body,
  ) {
    switch (method) {
      case 'POST':
        final req = http.Request('POST', url);
        req.headers.addAll(headers);
        req.body = body != null
            ? (body is String ? body : jsonEncode(body))
            : '';
        return req;
      case 'PUT':
        final req = http.Request('PUT', url);
        req.headers.addAll(headers);
        req.body = body != null
            ? (body is String ? body : jsonEncode(body))
            : '';
        return req;
      case 'PATCH':
        final req = http.Request('PATCH', url);
        req.headers.addAll(headers);
        req.body = body != null
            ? (body is String ? body : jsonEncode(body))
            : '';
        return req;
      case 'DELETE':
        final req = http.Request('DELETE', url);
        req.headers.addAll(headers);
        return req;
      default: // GET
        final req = http.Request('GET', url);
        req.headers.addAll(headers);
        return req;
    }
  }

  http.BaseRequest _cloneRequest(http.BaseRequest original) {
    final clone = http.Request(original.method, original.url);
    clone.headers.addAll(original.headers);
    if (original is http.Request) {
      (clone as http.Request).body = (original as http.Request).body;
    }
    return clone;
  }
}
