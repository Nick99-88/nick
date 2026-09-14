import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 🏛️ Models for the External Event-Stream Ingestion architecture.
///
/// Field mapping is kept tolerant (snake_case / camelCase) so UI never crashes
/// on schema drift, but the canonical shapes match routers/ingestion.py and
/// services/external_ingestion_service.py exactly:
///   • sources  -> {id,name,type,enabled,url,webhook_secret,...}
///   • events   -> {source_id,source_name,message,severity,raw,received_at}
///   • status   -> {enabled,active_workers:[{source_id,running}],stored_events}
///   • subscribers -> {user_ids:[...]}  (Neo4j user ids)

enum SourceType { websocket, polling, webhook }

enum EventSeverity { critical, error, warning, info, unknown }

extension SourceTypeX on SourceType {
  String get value => name;
  String get label {
    switch (this) {
      case SourceType.websocket:
        return 'WebSocket';
      case SourceType.polling:
        return 'Polling';
      case SourceType.webhook:
        return 'Webhook';
    }
  }

  IconSpec get icon {
    switch (this) {
      case SourceType.websocket:
        return IconSpec(Icons.cable_rounded, 0xFF1565C0);
      case SourceType.polling:
        return IconSpec(Icons.sync_rounded, 0xFF6A1B9A);
      case SourceType.webhook:
        return IconSpec(Icons.webhook_rounded, 0xFF00897B);
    }
  }
}

extension EventSeverityX on EventSeverity {
  String get label => name[0].toUpperCase() + name.substring(1);
  ColorSpec get theme {
    switch (this) {
      case EventSeverity.critical:
        return ColorSpec(0xFFC62828, 0xFFFDECEA);
      case EventSeverity.error:
        return ColorSpec(0xFFE65100, 0xFFFFF3E0);
      case EventSeverity.warning:
        return ColorSpec(0xFFF9A825, 0xFFFFF8E1);
      case EventSeverity.info:
        return ColorSpec(0xFF1565C0, 0xFFE8F0FE);
      case EventSeverity.unknown:
        return ColorSpec(0xFF546E7A, 0xFFECEFF1);
    }
  }

  IconData get icon {
    switch (this) {
      case EventSeverity.critical:
        return Icons.priority_high_rounded;
      case EventSeverity.error:
        return Icons.error_outline_rounded;
      case EventSeverity.warning:
        return Icons.warning_amber_rounded;
      case EventSeverity.info:
        return Icons.info_outline_rounded;
      case EventSeverity.unknown:
        return Icons.circle_rounded;
    }
  }
}

class IconSpec {
  final IconData icon;
  final int color;
  const IconSpec(this.icon, this.color);
}

class ColorSpec {
  final int fg;
  final int bg;
  const ColorSpec(this.fg, this.bg);
}

SourceType parseSourceType(dynamic v) {
  if (v == null) return SourceType.webhook;
  final s = v.toString().toLowerCase();
  if (s.contains('socket')) return SourceType.websocket;
  if (s.contains('poll')) return SourceType.polling;
  return SourceType.webhook;
}

EventSeverity parseSeverity(dynamic v) {
  if (v == null) return EventSeverity.unknown;
  final s = v.toString().toUpperCase();
  if (s.contains('CRIT') || s.contains('FATAL')) return EventSeverity.critical;
  if (s.contains('ERR')) return EventSeverity.error;
  if (s.contains('WARN')) return EventSeverity.warning;
  if (s.contains('INFO') || s.contains('DEBUG') || s.contains('NOTICE'))
    return EventSeverity.info;
  return EventSeverity.unknown;
}

DateTime? parseDate(dynamic v) {
  if (v == null) return null;
  if (v is int) {
    return DateTime.fromMillisecondsSinceEpoch(
      v < 1e12 ? v * 1000 : v,
      isUtc: true,
    ).toLocal();
  }
  if (v is String) {
    return DateTime.tryParse(v)?.toLocal();
  }
  if (v is Map && v.containsKey('\$date')) {
    return parseDate(v['\$date']);
  }
  return null;
}

String _asString(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

class IngestionSource {
  final String id;
  final String name;
  final SourceType type;
  final bool enabled;
  final String status; // derived: listening | connected | idle | no_secret | disabled
  final String? url;
  final String? webhookSecret;
  final DateTime? lastEventAt;
  final int? pollInterval;
  final Map<String, dynamic> raw;

  const IngestionSource({
    required this.id,
    required this.name,
    required this.type,
    required this.enabled,
    required this.status,
    this.url,
    this.webhookSecret,
    this.lastEventAt,
    this.pollInterval,
    this.raw = const {},
  });

  factory IngestionSource.fromJson(Map<String, dynamic> json) {
    final id = _asString(json['id'] ?? json['_id'] ?? json['source_id']);
    final name = _asString(json['name'] ?? json['source_name'], 'Unnamed Source');
    final type = parseSourceType(json['type'] ?? json['mode']);
    final enabled = json['enabled'] ?? true;
    final status = !enabled
        ? 'disabled'
        : (type == SourceType.webhook
            ? (_asString(json['webhook_secret']).isEmpty ? 'no_secret' : 'listening')
            : 'idle');
    final url = _asString(json['url'] ?? json['endpoint']);
    return IngestionSource(
      id: id,
      name: name,
      type: type,
      enabled: enabled is bool ? enabled : enabled != false,
      status: status,
      url: url.isEmpty ? null : url,
      webhookSecret: _asString(json['webhook_secret']).isEmpty
          ? null
          : _asString(json['webhook_secret']),
      lastEventAt: parseDate(json['last_event_at'] ?? json['last_seen']),
      pollInterval: json['poll_interval'] is int ? json['poll_interval'] : null,
      raw: json,
    );
  }

  bool get isLive =>
      status == 'connected' || status == 'listening';
  bool get hasError => status == 'no_secret';

  String get displayUrl => url ?? '';
  String get shortId =>
      id.length > 18 ? '${id.substring(0, 10)}…${id.substring(id.length - 4)}' : id;

  IngestionSource copyWith({bool? enabled, String? status}) {
    return IngestionSource(
      id: id,
      name: name,
      type: type,
      enabled: enabled ?? this.enabled,
      status: status ?? this.status,
      url: url,
      webhookSecret: webhookSecret,
      lastEventAt: lastEventAt,
      pollInterval: pollInterval,
      raw: raw,
    );
  }
}

class IngestionEvent {
  final String id;
  final String sourceId;
  final String sourceName;
  final EventSeverity severity;
  final String message;
  final DateTime receivedAt;
  final Map<String, dynamic> payload;
  final List<String> tags;

  const IngestionEvent({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.severity,
    required this.message,
    required this.receivedAt,
    this.payload = const {},
    this.tags = const [],
  });

  factory IngestionEvent.fromJson(Map<String, dynamic> json) {
    final id = _asString(json['id'] ?? json['_id'] ?? json['event_id']);
    final severity = parseSeverity(json['severity'] ?? json['level'] ?? json['priority']);
    final message = _asString(
      json['message'] ?? json['text'] ?? json['log'] ?? json['msg'] ?? json['body'],
      '(no message)',
    );
    final tags = (json['tags'] is List)
        ? List<String>.from((json['tags'] as List).map((e) => e.toString()))
        : <String>[];
    final payload = Map<String, dynamic>.from(
      json['raw'] ?? json['payload'] ?? json['data'] ?? {},
    );
    return IngestionEvent(
      id: id,
      sourceId: _asString(json['source_id']),
      sourceName: _asString(json['source_name']),
      severity: severity,
      message: message,
      receivedAt: parseDate(json['received_at'] ?? json['created_at'] ?? json['timestamp']) ??
          DateTime.now(),
      payload: payload,
      tags: tags,
    );
  }

  String get prettyPayload {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(payload.isEmpty ? {'message': message} : payload);
    } catch (_) {
      return payload.toString();
    }
  }

  String get relativeTime => _relative(receivedAt);

  static String _relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

/// Alert subscriber — persisted in Mongo as a Neo4j `user_id` string.
class AlertSubscriber {
  final String userId;
  const AlertSubscriber({required this.userId});

  factory AlertSubscriber.fromId(String id) => AlertSubscriber(userId: id);

  String get shortId => userId.length > 18
      ? '${userId.substring(0, 10)}…${userId.substring(userId.length - 4)}'
      : userId;
}

class WorkerStatus {
  final String sourceId;
  final bool running;
  const WorkerStatus({required this.sourceId, this.running = false});

  factory WorkerStatus.fromJson(Map<String, dynamic> json) {
    return WorkerStatus(
      sourceId: _asString(json['source_id']),
      running: json['running'] ?? false,
    );
  }
}

class IngestionStatus {
  final bool enabled;
  final int storedEvents;
  final List<WorkerStatus> workers;

  const IngestionStatus({
    required this.enabled,
    required this.storedEvents,
    required this.workers,
  });

  factory IngestionStatus.fromJson(Map<String, dynamic> json) {
    final list = (json['active_workers'] is List)
        ? (json['active_workers'] as List)
            .whereType<Map<String, dynamic>>()
            .map((w) => WorkerStatus.fromJson(w))
            .toList()
        : <WorkerStatus>[];
    return IngestionStatus(
      enabled: json['enabled'] ?? false,
      storedEvents: json['stored_events'] ?? 0,
      workers: list,
    );
  }

  int get activeWorkers => workers.where((w) => w.running).length;

  /// Server-configured defaults (environment variables on the backend).
  static const int ttlDays = 30;
  static const int cooldownSeconds = 300;
}
