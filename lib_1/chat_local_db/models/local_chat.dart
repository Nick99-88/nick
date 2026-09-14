class LocalChat {
  final String phoneNumber;
  final String peerUserId;
  final String contactName;
  final String profileImageUrl;
  final String lastMessage;
  final String lastMessageTime;
  final String lastMessageType;
  final int unreadCount;
  final bool isMuted;
  final bool isArchived;
  final bool isPinned;
  final bool isBlocked;
  final bool isLocked;
  final int disappearingTimer;
  final String createdAt;
  final String updatedAt;
  final int profilePictureVersion;
  final int blockVersion;
  final int nameVersion;
  final int lastMessageVersion;

  const LocalChat({
    required this.phoneNumber,
    this.peerUserId = '',
    this.contactName = '',
    this.profileImageUrl = '',
    this.lastMessage = '',
    this.lastMessageTime = '',
    this.lastMessageType = 'text',
    this.unreadCount = 0,
    this.isMuted = false,
    this.isArchived = false,
    this.isPinned = false,
    this.isBlocked = false,
    this.isLocked = false,
    this.disappearingTimer = 0,
    this.createdAt = '',
    this.updatedAt = '',
    this.profilePictureVersion = 0,
    this.blockVersion = 0,
    this.nameVersion = 0,
    this.lastMessageVersion = 0,
  });

  factory LocalChat.fromMap(Map<String, dynamic> map) {
    return LocalChat(
      phoneNumber: map['phone_number'] as String,
      peerUserId: map['peer_user_id'] as String? ?? '',
      contactName: map['contact_name'] as String? ?? '',
      profileImageUrl: map['profile_image_url'] as String? ?? '',
      lastMessage: map['last_message'] as String? ?? '',
      lastMessageTime: map['last_message_time'] as String? ?? '',
      lastMessageType: map['last_message_type'] as String? ?? 'text',
      unreadCount: map['unread_count'] as int? ?? 0,
      isMuted: (map['is_muted'] as int? ?? 0) == 1,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      isBlocked: (map['is_blocked'] as int? ?? 0) == 1,
      isLocked: (map['is_locked'] as int? ?? 0) == 1,
      disappearingTimer: map['disappearing_timer'] as int? ?? 0,
      createdAt: map['chat_created_at'] as String? ?? '',
      updatedAt: map['chat_updated_at'] as String? ?? '',
      profilePictureVersion: map['profile_picture_version'] as int? ?? 0,
      blockVersion: map['block_version'] as int? ?? 0,
      nameVersion: map['name_version'] as int? ?? 0,
      lastMessageVersion: map['last_message_version'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phone_number': phoneNumber,
      'peer_user_id': peerUserId,
      'contact_name': contactName,
      'profile_image_url': profileImageUrl,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime,
      'last_message_type': lastMessageType,
      'unread_count': unreadCount,
      'is_muted': isMuted ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'is_pinned': isPinned ? 1 : 0,
      'is_blocked': isBlocked ? 1 : 0,
      'is_locked': isLocked ? 1 : 0,
      'disappearing_timer': disappearingTimer,
      'chat_created_at': createdAt,
      'chat_updated_at': updatedAt,
      'profile_picture_version': profilePictureVersion,
      'block_version': blockVersion,
      'name_version': nameVersion,
      'last_message_version': lastMessageVersion,
    };
  }

  LocalChat copyWith({
    String? phoneNumber,
    String? peerUserId,
    String? contactName,
    String? profileImageUrl,
    String? lastMessage,
    String? lastMessageTime,
    String? lastMessageType,
    int? unreadCount,
    bool? isMuted,
    bool? isArchived,
    bool? isPinned,
    bool? isBlocked,
    bool? isLocked,
    int? disappearingTimer,
    String? updatedAt,
    int? profilePictureVersion,
    int? blockVersion,
    int? nameVersion,
    int? lastMessageVersion,
  }) {
    return LocalChat(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      peerUserId: peerUserId ?? this.peerUserId,
      contactName: contactName ?? this.contactName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted,
      isArchived: isArchived ?? this.isArchived,
      isPinned: isPinned ?? this.isPinned,
      isBlocked: isBlocked ?? this.isBlocked,
      isLocked: isLocked ?? this.isLocked,
      disappearingTimer: disappearingTimer ?? this.disappearingTimer,
      updatedAt: updatedAt ?? this.updatedAt,
      profilePictureVersion: profilePictureVersion ?? this.profilePictureVersion,
      blockVersion: blockVersion ?? this.blockVersion,
      nameVersion: nameVersion ?? this.nameVersion,
      lastMessageVersion: lastMessageVersion ?? this.lastMessageVersion,
    );
  }

  String get displayName => contactName.isNotEmpty ? contactName : phoneNumber;

  String get displayLastMessage {
    if (lastMessage.isEmpty) return 'No messages yet';
    if (lastMessageType != 'text') {
      return '[${_typeToEmoji(lastMessageType)} Media]';
    }
    return lastMessage.length > 50 ? '${lastMessage.substring(0, 50)}...' : lastMessage;
  }

  String _typeToEmoji(String type) {
    switch (type) {
      case 'image': return '🖼️';
      case 'video': return '🎥';
      case 'voice': return '🎤';
      case 'document': return '📄';
      case 'location': return '📍';
      case 'contact': return '👤';
      default: return '📎';
    }
  }

  @override
  String toString() => 'LocalChat(phoneNumber: $phoneNumber, contactName: $contactName, unreadCount: $unreadCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalChat && runtimeType == other.runtimeType && phoneNumber == other.phoneNumber;

  @override
  int get hashCode => phoneNumber.hashCode;
}
