import 'dart:convert';

class LocalChannel {
  final String channelId;
  final String name;
  final String description;
  final String createdBy;
  final bool isPublic;
  final String memberUserIdsJson;
  final int memberCount;
  final String lastMessage;
  final String lastMessageTime;
  final String lastMessageType;
  final String lastMessageSender;
  final int unreadCount;
  final bool isMuted;
  final bool isPinned;
  final bool isArchived;
  final bool amIAdmin;
  final String localCachedAt;
  final String createdAt;
  final String updatedAt;

  const LocalChannel({
    required this.channelId,
    this.name = '',
    this.description = '',
    this.createdBy = '',
    this.isPublic = true,
    this.memberUserIdsJson = '[]',
    this.memberCount = 0,
    this.lastMessage = '',
    this.lastMessageTime = '',
    this.lastMessageType = 'text',
    this.lastMessageSender = '',
    this.unreadCount = 0,
    this.isMuted = false,
    this.isPinned = false,
    this.isArchived = false,
    this.amIAdmin = false,
    this.localCachedAt = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory LocalChannel.fromMap(Map<String, dynamic> map) {
    return LocalChannel(
      channelId: map['channel_id'] as String,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      createdBy: map['created_by'] as String? ?? '',
      isPublic: (map['is_public'] as int? ?? 1) == 1,
      memberUserIdsJson: map['member_user_ids'] as String? ?? '[]',
      memberCount: map['member_count'] as int? ?? 0,
      lastMessage: map['last_message'] as String? ?? '',
      lastMessageTime: map['last_message_time'] as String? ?? '',
      lastMessageType: map['last_message_type'] as String? ?? 'text',
      lastMessageSender: map['last_message_sender'] as String? ?? '',
      unreadCount: map['unread_count'] as int? ?? 0,
      isMuted: (map['is_muted'] as int? ?? 0) == 1,
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      amIAdmin: (map['am_i_admin'] as int? ?? 0) == 1,
      localCachedAt: map['local_cached_at'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'channel_id': channelId,
      'name': name,
      'description': description,
      'created_by': createdBy,
      'is_public': isPublic ? 1 : 0,
      'member_user_ids': memberUserIdsJson,
      'member_count': memberCount,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime,
      'last_message_type': lastMessageType,
      'last_message_sender': lastMessageSender,
      'unread_count': unreadCount,
      'is_muted': isMuted ? 1 : 0,
      'is_pinned': isPinned ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'am_i_admin': amIAdmin ? 1 : 0,
      'local_cached_at': localCachedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  List<String> get memberUserIds {
    try {
      final decoded = jsonDecode(memberUserIdsJson);
      return List<String>.from(decoded);
    } catch (_) {
      return [];
    }
  }

  LocalChannel copyWith({
    String? name,
    String? description,
    String? createdBy,
    bool? isPublic,
    String? memberUserIdsJson,
    int? memberCount,
    String? lastMessage,
    String? lastMessageTime,
    String? lastMessageType,
    String? lastMessageSender,
    int? unreadCount,
    bool? isMuted,
    bool? isPinned,
    bool? isArchived,
    bool? amIAdmin,
    String? updatedAt,
  }) {
    return LocalChannel(
      channelId: channelId,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      isPublic: isPublic ?? this.isPublic,
      memberUserIdsJson: memberUserIdsJson ?? this.memberUserIdsJson,
      memberCount: memberCount ?? this.memberCount,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageSender: lastMessageSender ?? this.lastMessageSender,
      unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      amIAdmin: amIAdmin ?? this.amIAdmin,
      localCachedAt: localCachedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayName => name.isNotEmpty ? name : 'Channel';

  String get displayLastMessage {
    if (lastMessage.isEmpty) return 'No messages yet';
    if (lastMessageType != 'text') {
      return '[Media]';
    }
    return lastMessage.length > 50 ? '${lastMessage.substring(0, 50)}...' : lastMessage;
  }

  @override
  String toString() => 'LocalChannel(channelId: $channelId, name: $name, memberCount: $memberCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalChannel && runtimeType == other.runtimeType && channelId == other.channelId;

  @override
  int get hashCode => channelId.hashCode;
}
