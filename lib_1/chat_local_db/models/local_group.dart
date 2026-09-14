class LocalGroup {
  final String groupId;
  final String groupName;
  final String groupDescription;
  final String groupIconUrl;
  final String adminUserId;
  final String createdBy;
  final int memberCount;
  final bool isMuted;
  final bool isArchived;
  final bool isPinned;
  final int disappearingTimer;
  final String lastMessage;
  final String lastMessageTime;
  final String lastMessageType;
  final String lastMessageSender;
  final int unreadCount;
  final String createdAt;
  final String updatedAt;

  const LocalGroup({
    required this.groupId,
    this.groupName = '',
    this.groupDescription = '',
    this.groupIconUrl = '',
    this.adminUserId = '',
    this.createdBy = '',
    this.memberCount = 0,
    this.isMuted = false,
    this.isArchived = false,
    this.isPinned = false,
    this.disappearingTimer = 0,
    this.lastMessage = '',
    this.lastMessageTime = '',
    this.lastMessageType = 'text',
    this.lastMessageSender = '',
    this.unreadCount = 0,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory LocalGroup.fromMap(Map<String, dynamic> map) {
    return LocalGroup(
      groupId: map['group_id'] as String,
      groupName: map['group_name'] as String? ?? '',
      groupDescription: map['group_description'] as String? ?? '',
      groupIconUrl: map['group_icon_url'] as String? ?? '',
      adminUserId: map['admin_user_id'] as String? ?? '',
      createdBy: map['created_by'] as String? ?? '',
      memberCount: map['member_count'] as int? ?? 0,
      isMuted: (map['is_muted'] as int? ?? 0) == 1,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      disappearingTimer: map['disappearing_timer'] as int? ?? 0,
      lastMessage: map['last_message'] as String? ?? '',
      lastMessageTime: map['last_message_time'] as String? ?? '',
      lastMessageType: map['last_message_type'] as String? ?? 'text',
      lastMessageSender: map['last_message_sender'] as String? ?? '',
      unreadCount: map['unread_count'] as int? ?? 0,
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'group_id': groupId,
      'group_name': groupName,
      'group_description': groupDescription,
      'group_icon_url': groupIconUrl,
      'admin_user_id': adminUserId,
      'created_by': createdBy,
      'member_count': memberCount,
      'is_muted': isMuted ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'is_pinned': isPinned ? 1 : 0,
      'disappearing_timer': disappearingTimer,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime,
      'last_message_type': lastMessageType,
      'last_message_sender': lastMessageSender,
      'unread_count': unreadCount,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  LocalGroup copyWith({
    String? groupId,
    String? groupName,
    String? groupDescription,
    String? groupIconUrl,
    String? adminUserId,
    String? createdBy,
    int? memberCount,
    bool? isMuted,
    bool? isArchived,
    bool? isPinned,
    int? disappearingTimer,
    String? lastMessage,
    String? lastMessageTime,
    String? lastMessageType,
    String? lastMessageSender,
    int? unreadCount,
    String? updatedAt,
  }) {
    return LocalGroup(
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      groupDescription: groupDescription ?? this.groupDescription,
      groupIconUrl: groupIconUrl ?? this.groupIconUrl,
      adminUserId: adminUserId ?? this.adminUserId,
      createdBy: createdBy ?? this.createdBy,
      memberCount: memberCount ?? this.memberCount,
      isMuted: isMuted ?? this.isMuted,
      isArchived: isArchived ?? this.isArchived,
      isPinned: isPinned ?? this.isPinned,
      disappearingTimer: disappearingTimer ?? this.disappearingTimer,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageSender: lastMessageSender ?? this.lastMessageSender,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayLastMessage {
    if (lastMessage.isEmpty) return 'No messages yet';
    if (lastMessageType != 'text') {
      return '[${_typeToEmoji(lastMessageType)} Media]';
    }
    final sender = lastMessageSender.isNotEmpty ? '$lastMessageSender: ' : '';
    final msg = '$sender$lastMessage';
    return msg.length > 50 ? '${msg.substring(0, 50)}...' : msg;
  }

  String _typeToEmoji(String type) {
    switch (type) {
      case 'image': return '🖼️';
      case 'video': return '🎥';
      case 'voice': return '🎤';
      case 'document': return '📄';
      default: return '📎';
    }
  }

  @override
  String toString() => 'LocalGroup(groupId: $groupId, groupName: $groupName, memberCount: $memberCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalGroup && runtimeType == other.runtimeType && groupId == other.groupId;

  @override
  int get hashCode => groupId.hashCode;
}
