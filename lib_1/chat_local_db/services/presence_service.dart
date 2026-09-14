import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../database/chat_local_database.dart';
import '../../chat_system/services/socket_event_bus.dart';

class PresenceCache {
  final String userId;
  final String phoneNumber;
  final bool isOnline;
  final String lastSeen;
  final String typingIn;
  final String updatedAt;

  const PresenceCache({
    required this.userId,
    this.phoneNumber = '',
    this.isOnline = false,
    this.lastSeen = '',
    this.typingIn = '',
    this.updatedAt = '',
  });

  factory PresenceCache.fromMap(Map<String, dynamic> map) {
    return PresenceCache(
      userId: map['user_id'] as String,
      phoneNumber: map['phone_number'] as String? ?? '',
      isOnline: (map['is_online'] as int? ?? 0) == 1,
      lastSeen: map['last_seen'] as String? ?? '',
      typingIn: map['typing_in'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'phone_number': phoneNumber,
      'is_online': isOnline ? 1 : 0,
      'last_seen': lastSeen,
      'typing_in': typingIn,
      'updated_at': updatedAt,
    };
  }

  PresenceCache copyWith({
    String? userId,
    String? phoneNumber,
    bool? isOnline,
    String? lastSeen,
    String? typingIn,
    String? updatedAt,
  }) {
    return PresenceCache(
      userId: userId ?? this.userId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      typingIn: typingIn ?? this.typingIn,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isTyping => typingIn.isNotEmpty;
}

class PresenceService {
  static final PresenceService instance = PresenceService._init();
  PresenceService._init();

  final ChatLocalDatabase _db = ChatLocalDatabase.instance;
  final Map<String, PresenceCache> _memoryCache = {};
  Timer? _cleanupTimer;

  Future<void> initialize() async {
    await _loadFromDatabase();
    _startCleanupTimer();
    _setupSocketListeners();
  }

  Future<void> _loadFromDatabase() async {
    try {
      final db = await _db.database;
      final maps = await db.query('presence_cache');
      for (final map in maps) {
        final presence = PresenceCache.fromMap(map);
        _memoryCache[presence.userId] = presence;
      }
    } catch (e) {
      print('💬 Presence: Error loading from database: $e');
    }
  }

  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupStalePresence();
    });
  }

  void _setupSocketListeners() {
    SocketEventBus.instance.subscribe('connected', (data) {
      final userId = data['user_id'] as String?;
      if (userId != null) {
        _setOnline(userId);
      }
    });

    SocketEventBus.instance.subscribe('user_online', (data) {
      final userId = data['user_id'] as String?;
      if (userId != null) {
        _setOnline(userId);
      }
    });

    SocketEventBus.instance.subscribe('user_offline', (data) {
      final userId = data['user_id'] as String?;
      if (userId != null) {
        _setOffline(userId);
      }
    });

    SocketEventBus.instance.subscribe('typing', (data) {
      final senderPhone = data['sender_phone'] as String?;
      if (senderPhone != null) {
        _setTyping(senderPhone, true);
      }
    });

    SocketEventBus.instance.subscribe('stop_typing', (data) {
      final senderPhone = data['sender_phone'] as String?;
      if (senderPhone != null) {
        _setTyping(senderPhone, false);
      }
    });

    SocketEventBus.instance.subscribe('connection_created', (data) {
      final userId = data['user_id'] as String?;
      if (userId != null) {
        _setOnline(userId);
      }
    });
  }

  Future<void> _setOnline(String userId) async {
    final now = DateTime.now().toIso8601String();
    final existing = _memoryCache[userId];
    final presence = (existing ?? PresenceCache(userId: userId)).copyWith(
      isOnline: true,
      lastSeen: now,
      updatedAt: now,
    );
    _memoryCache[userId] = presence;
    await _saveToDatabase(presence);
  }

  Future<void> _setOffline(String userId) async {
    final now = DateTime.now().toIso8601String();
    final existing = _memoryCache[userId];
    final presence = (existing ?? PresenceCache(userId: userId)).copyWith(
      isOnline: false,
      lastSeen: now,
      typingIn: '',
      updatedAt: now,
    );
    _memoryCache[userId] = presence;
    await _saveToDatabase(presence);
  }

  Future<void> _setTyping(String phone, bool isTyping) async {
    final userId = _findUserIdByPhone(phone);
    if (userId == null) return;

    final existing = _memoryCache[userId];
    final presence = (existing ?? PresenceCache(userId: userId, phoneNumber: phone)).copyWith(
      typingIn: isTyping ? 'chat' : '',
      updatedAt: DateTime.now().toIso8601String(),
    );
    _memoryCache[userId] = presence;

    if (isTyping) {
      Timer(const Duration(seconds: 5), () {
        final current = _memoryCache[userId];
        if (current?.typingIn == 'chat') {
          _setTyping(phone, false);
        }
      });
    }
  }

  String? _findUserIdByPhone(String phone) {
    for (final entry in _memoryCache.entries) {
      if (entry.value.phoneNumber == phone) {
        return entry.key;
      }
    }
    return null;
  }

  Future<void> _saveToDatabase(PresenceCache presence) async {
    try {
      final db = await _db.database;
      await db.insert(
        'presence_cache',
        presence.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('💬 Presence: Error saving to database: $e');
    }
  }

  Future<void> _cleanupStalePresence() async {
    final now = DateTime.now();
    final staleIds = <String>[];

    for (final entry in _memoryCache.entries) {
      if (entry.value.isOnline && entry.value.updatedAt.isNotEmpty) {
        try {
          final updatedAt = DateTime.parse(entry.value.updatedAt);
          if (now.difference(updatedAt).inMinutes > 10) {
            staleIds.add(entry.key);
          }
        } catch (e) {}
      }
    }

    for (final userId in staleIds) {
      _setOffline(userId);
    }

    try {
      final db = await _db.database;
      await db.delete(
        'presence_cache',
        where: 'is_online = 0 AND julianday(\'now\') - julianday(updated_at) > 1',
      );
    } catch (e) {}
  }

  bool isUserOnline(String userId) {
    return _memoryCache[userId]?.isOnline ?? false;
  }

  bool isPhoneOnline(String phone) {
    for (final entry in _memoryCache.entries) {
      if (entry.value.phoneNumber == phone && entry.value.isOnline) {
        return true;
      }
    }
    return false;
  }

  bool isPhoneTyping(String phone) {
    for (final entry in _memoryCache.entries) {
      if (entry.value.phoneNumber == phone && entry.value.isTyping) {
        return true;
      }
    }
    return false;
  }

  String getLastSeen(String userId) {
    return _memoryCache[userId]?.lastSeen ?? '';
  }

  PresenceCache? getPresence(String userId) {
    return _memoryCache[userId];
  }

  Future<void> updatePhoneForUser(String userId, String phone) async {
    final existing = _memoryCache[userId];
    if (existing != null) {
      final presence = existing.copyWith(phoneNumber: phone);
      _memoryCache[userId] = presence;
      await _saveToDatabase(presence);
    } else {
      final presence = PresenceCache(
        userId: userId,
        phoneNumber: phone,
        updatedAt: DateTime.now().toIso8601String(),
      );
      _memoryCache[userId] = presence;
      await _saveToDatabase(presence);
    }
  }

  Future<void> dispose() async {
    _cleanupTimer?.cancel();
    _memoryCache.clear();
  }
}
