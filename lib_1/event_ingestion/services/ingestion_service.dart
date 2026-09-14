import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:starlight_flutter/core/constants.dart';
import 'package:starlight_flutter/services/api_service.dart';

import '../models/ingestion_models.dart';

/// 🏛️ API client for the External Event-Stream Ingestion backend.
///
/// Admin endpoints use the app's signed JWT (via [ApiService]); the public
/// webhook endpoint ([pushTestEvent]) signs with HMAC-SHA256 to mirror the
/// FastAPI router's `x-webhook-signature` verification.
///
/// Endpoint contract (routers/ingestion.py):
///   GET  /sources                 -> {"sources":[...]}
///   POST /sources                 -> {"status","source":{...}}
///   PUT  /sources/{id}            -> {"status","source_id"}
///   DELETE /sources/{id}          -> {"status","source_id"}
///   GET  /events?limit&severity&source&source_id -> {"events":[...]}
///   GET  /status                  -> {enabled,active_workers,stored_events}
///   GET  /alerts/subscribers      -> {"user_ids":[...]}
///   PUT  /alerts/subscribers      -> {"status","count"}
///   POST /logs  (public)          -> {"status":"accepted","source":id}
class IngestionService {
  static const String _base = '${StarlightConstants.apiBaseUrl}/api/v1/ingest';

  static final IngestionService instance = IngestionService._();

  IngestionService._();

  // ── Status ──────────────────────────────────────────────────────────────
  Future<IngestionStatus> getStatus() async {
    final res = await ApiService.get('$_base/status');
    return IngestionStatus.fromJson(res);
  }

  // ── Sources ─────────────────────────────────────────────────────────────
  Future<List<IngestionSource>> listSources() async {
    final res = await ApiService.get('$_base/sources');
    return _asList(res, 'sources').map(IngestionSource.fromJson).toList();
  }

  Future<IngestionSource> createSource(Map<String, dynamic> payload) async {
    final res = await ApiService.post('$_base/sources', payload);
    return IngestionSource.fromJson(res['source'] ?? res);
  }

  Future<IngestionSource> updateSource(
    String id,
    Map<String, dynamic> payload,
  ) async {
    await ApiService.put('$_base/sources/$id', payload);
    // Backend returns no source doc; rebuild from the merge we just sent.
    return IngestionSource.fromJson({'id': id, ...payload});
  }

  Future<void> deleteSource(String id) async {
    await ApiService.delete('$_base/sources/$id');
  }

  Future<void> setSourceEnabled(String id, bool enabled) async {
    await ApiService.put('$_base/sources/$id', {'enabled': enabled});
  }

  /// Push a synthetic event to the public webhook (Direct Push).
  ///
  /// Signs the body with HMAC-SHA256 using the source `webhook_secret`, matching
  /// the router's `x-webhook-signature: sha256=<hex>` verification. The backend
  /// resolves the secret from the `source_id` field in the body.
  Future<Map<String, dynamic>> pushTestEvent({
    required String sourceId,
    required String secret,
    required String message,
    String severity = 'info',
    Map<String, dynamic>? extra,
  }) async {
    final body = {
      'source_id': sourceId,
      'message': message,
      'severity': severity.toUpperCase(),
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      if (extra != null) ...extra,
    };
    final encoded = jsonEncode(body);
    final mac = Hmac(sha256, utf8.encode(secret));
    final digest = mac.convert(utf8.encode(encoded));
    final signature = 'sha256=${digest.toString()}';

    final response = await http.post(
      Uri.parse('$_base/logs'),
      headers: {
        'Content-Type': 'application/json',
        'x-webhook-signature': signature,
        'x-source-id': sourceId,
      },
      body: encoded,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  // ── Events ──────────────────────────────────────────────────────────────
  Future<List<IngestionEvent>> listEvents({
    String? sourceId,
    EventSeverity? severity,
    int limit = 100,
    DateTime? since,
  }) async {
    final query = <String, String>{};
    if (sourceId != null && sourceId.isNotEmpty) {
      query['source_id'] = sourceId;
    }
    if (severity != null) {
      query['severity'] = severity.name.toUpperCase();
    }
    query['limit'] = limit.toString();
    if (since != null) {
      query['since'] = since.toUtc().toIso8601String();
    }
    final qs = query.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final res = await ApiService.get('$_base/events${qs.isEmpty ? '' : '?$qs'}');
    final list = _asList(res, 'events').map(IngestionEvent.fromJson).toList();
    list.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return list;
  }

  // ── Alert subscribers (list of Neo4j user ids) ───────────────────────────
  Future<List<AlertSubscriber>> listSubscribers() async {
    final res = await ApiService.get('$_base/alerts/subscribers');
    final ids = res['user_ids'];
    if (ids is List) {
      return ids.map((e) => AlertSubscriber.fromId(e.toString())).toList();
    }
    return [];
  }

  Future<void> addSubscriber(String userId) async {
    final current =
        (await listSubscribers()).map((s) => s.userId).toList();
    if (!current.contains(userId)) current.add(userId);
    await ApiService.put('$_base/alerts/subscribers', {'user_ids': current});
  }

  Future<void> deleteSubscriber(String userId) async {
    final current = (await listSubscribers())
        .map((s) => s.userId)
        .where((u) => u != userId)
        .toList();
    await ApiService.put('$_base/alerts/subscribers', {'user_ids': current});
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _asList(dynamic res, String primary) {
    if (res is List) {
      return res.whereType<Map<String, dynamic>>().toList();
    }
    if (res is Map) {
      final v = res[primary];
      if (v is List) return v.whereType<Map<String, dynamic>>().toList();
      for (final key in const [
        'data',
        'items',
        'results',
        'rows'
      ]) {
        final alt = res[key];
        if (alt is List) {
          return alt.whereType<Map<String, dynamic>>().toList();
        }
      }
    }
    return [];
  }
}
