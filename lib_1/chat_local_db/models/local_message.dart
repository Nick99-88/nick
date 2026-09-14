class LocalMessage {
  final int? id;
  final String chatPhoneNumber;
  final String peerUserId;
  final int sequenceId;
  final String clientUuid;
  final String messageType;
  final String messageDirection;
  final String content;
  final String mediaLocalPath;
  final String mediaRemoteUrl;
  final String mediaFileName;
  final String mediaMimeType;
  final int mediaSizeBytes;
  final int mediaDurationMs;
  final int mediaWidth;
  final int mediaHeight;
  final String mediaThumbnailPath;
  final String mediaBlurhash;
  final bool isStarred;
  final bool isDeleted;
  final bool deleteForMe;
  final bool isEdited;
  final String editedAt;
  final String originalContent;
  final int? replyToMessageId;
  final String replyToContent;
  final String forwardedFrom;
  final String status;
  final String serverMessageId;
  final String errorMessage;
  final String createdAt;
  final String updatedAt;

  const LocalMessage({
    this.id,
    required this.chatPhoneNumber,
    this.peerUserId = '',
    this.sequenceId = 0,
    this.clientUuid = '',
    this.messageType = 'text',
    this.messageDirection = 'sent',
    this.content = '',
    this.mediaLocalPath = '',
    this.mediaRemoteUrl = '',
    this.mediaFileName = '',
    this.mediaMimeType = '',
    this.mediaSizeBytes = 0,
    this.mediaDurationMs = 0,
    this.mediaWidth = 0,
    this.mediaHeight = 0,
    this.mediaThumbnailPath = '',
    this.mediaBlurhash = '',
    this.isStarred = false,
    this.isDeleted = false,
    this.deleteForMe = false,
    this.isEdited = false,
    this.editedAt = '',
    this.originalContent = '',
    this.replyToMessageId,
    this.replyToContent = '',
    this.forwardedFrom = '',
    this.status = 'sent',
    this.serverMessageId = '',
    this.errorMessage = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory LocalMessage.fromMap(Map<String, dynamic> map) {
    return LocalMessage(
      id: map['id'] as int?,
      chatPhoneNumber: map['chat_phone_number'] as String,
      peerUserId: map['peer_user_id'] as String? ?? '',
      sequenceId: map['sequence_id'] as int? ?? 0,
      clientUuid: map['client_uuid'] as String? ?? '',
      messageType: map['message_type'] as String? ?? 'text',
      messageDirection: map['message_direction'] as String? ?? 'sent',
      content: map['content'] as String? ?? '',
      mediaLocalPath: map['media_local_path'] as String? ?? '',
      mediaRemoteUrl: map['media_remote_url'] as String? ?? '',
      mediaFileName: map['media_file_name'] as String? ?? '',
      mediaMimeType: map['media_mime_type'] as String? ?? '',
      mediaSizeBytes: map['media_size_bytes'] as int? ?? 0,
      mediaDurationMs: map['media_duration_ms'] as int? ?? 0,
      mediaWidth: map['media_width'] as int? ?? 0,
      mediaHeight: map['media_height'] as int? ?? 0,
      mediaThumbnailPath: map['media_thumbnail_path'] as String? ?? '',
      mediaBlurhash: map['media_blurhash'] as String? ?? '',
      isStarred: (map['is_starred'] as int? ?? 0) == 1,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      deleteForMe: (map['delete_for_me'] as int? ?? 0) == 1,
      isEdited: (map['is_edited'] as int? ?? 0) == 1,
      editedAt: map['edited_at'] as String? ?? '',
      originalContent: map['original_content'] as String? ?? '',
      replyToMessageId: map['reply_to_message_id'] as int?,
      replyToContent: map['reply_to_content'] as String? ?? '',
      forwardedFrom: map['forwarded_from'] as String? ?? '',
      status: map['status'] as String? ?? 'sent',
      serverMessageId: map['server_message_id'] as String? ?? '',
      errorMessage: map['error_message'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'chat_phone_number': chatPhoneNumber,
      'peer_user_id': peerUserId,
      'sequence_id': sequenceId,
      'client_uuid': clientUuid,
      'message_type': messageType,
      'message_direction': messageDirection,
      'content': content,
      'media_local_path': mediaLocalPath,
      'media_remote_url': mediaRemoteUrl,
      'media_file_name': mediaFileName,
      'media_mime_type': mediaMimeType,
      'media_size_bytes': mediaSizeBytes,
      'media_duration_ms': mediaDurationMs,
      'media_width': mediaWidth,
      'media_height': mediaHeight,
      'media_thumbnail_path': mediaThumbnailPath,
      'media_blurhash': mediaBlurhash,
      'is_starred': isStarred ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'delete_for_me': deleteForMe ? 1 : 0,
      'is_edited': isEdited ? 1 : 0,
      'edited_at': editedAt,
      'original_content': originalContent,
      'reply_to_message_id': replyToMessageId,
      'reply_to_content': replyToContent,
      'forwarded_from': forwardedFrom,
      'status': status,
      'server_message_id': serverMessageId,
      'error_message': errorMessage,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  LocalMessage copyWith({
    int? id,
    String? chatPhoneNumber,
    String? peerUserId,
    int? sequenceId,
    String? clientUuid,
    String? messageType,
    String? messageDirection,
    String? content,
    String? mediaLocalPath,
    String? mediaRemoteUrl,
    String? mediaFileName,
    String? mediaMimeType,
    int? mediaSizeBytes,
    int? mediaDurationMs,
    int? mediaWidth,
    int? mediaHeight,
    String? mediaThumbnailPath,
    String? mediaBlurhash,
    bool? isStarred,
    bool? isDeleted,
    bool? deleteForMe,
    bool? isEdited,
    String? editedAt,
    String? originalContent,
    int? replyToMessageId,
    String? replyToContent,
    String? forwardedFrom,
    String? status,
    String? serverMessageId,
    String? errorMessage,
    String? updatedAt,
  }) {
    return LocalMessage(
      id: id ?? this.id,
      chatPhoneNumber: chatPhoneNumber ?? this.chatPhoneNumber,
      peerUserId: peerUserId ?? this.peerUserId,
      sequenceId: sequenceId ?? this.sequenceId,
      clientUuid: clientUuid ?? this.clientUuid,
      messageType: messageType ?? this.messageType,
      messageDirection: messageDirection ?? this.messageDirection,
      content: content ?? this.content,
      mediaLocalPath: mediaLocalPath ?? this.mediaLocalPath,
      mediaRemoteUrl: mediaRemoteUrl ?? this.mediaRemoteUrl,
      mediaFileName: mediaFileName ?? this.mediaFileName,
      mediaMimeType: mediaMimeType ?? this.mediaMimeType,
      mediaSizeBytes: mediaSizeBytes ?? this.mediaSizeBytes,
      mediaDurationMs: mediaDurationMs ?? this.mediaDurationMs,
      mediaWidth: mediaWidth ?? this.mediaWidth,
      mediaHeight: mediaHeight ?? this.mediaHeight,
      mediaThumbnailPath: mediaThumbnailPath ?? this.mediaThumbnailPath,
      mediaBlurhash: mediaBlurhash ?? this.mediaBlurhash,
      isStarred: isStarred ?? this.isStarred,
      isDeleted: isDeleted ?? this.isDeleted,
      deleteForMe: deleteForMe ?? this.deleteForMe,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      originalContent: originalContent ?? this.originalContent,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToContent: replyToContent ?? this.replyToContent,
      forwardedFrom: forwardedFrom ?? this.forwardedFrom,
      status: status ?? this.status,
      serverMessageId: serverMessageId ?? this.serverMessageId,
      errorMessage: errorMessage ?? this.errorMessage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isText => messageType == 'text';
  bool get isImage => messageType == 'image';
  bool get isVideo => messageType == 'video';
  bool get isVoice => messageType == 'voice';
  bool get isDocument => messageType == 'document';
  bool get isLocation => messageType == 'location';
  bool get isContact => messageType == 'contact';
  bool get isMedia => !isText && !isLocation && !isContact;
  bool get isSent => messageDirection == 'sent';
  bool get isReceived => messageDirection == 'received';
  bool get hasMedia => mediaLocalPath.isNotEmpty || mediaRemoteUrl.isNotEmpty;
  bool get isFailed => status == 'failed';
  bool get isSending => status == 'sending';
  bool get isDelivered => status == 'delivered';
  bool get isRead => status == 'read';

  String get displayContent {
    if (isDeleted && deleteForMe) return '🚫 This message was deleted';
    if (isText) return content;
    if (isImage) return '🖼️ Photo';
    if (isVideo) return '🎥 Video';
    if (isVoice) return '🎤 Voice message';
    if (isDocument) return '📄 ${mediaFileName.isNotEmpty ? mediaFileName : 'Document'}';
    if (isLocation) return '📍 Location';
    if (isContact) return '👤 Contact';
    return '📎 Attachment';
  }

  @override
  String toString() => 'LocalMessage(id: $id, type: $messageType, direction: $messageDirection, status: $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalMessage && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
