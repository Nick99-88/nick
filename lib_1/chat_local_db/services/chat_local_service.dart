import 'dart:io';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../storage/storage.dart';

class ChatLocalService {
  static final ChatLocalService instance = ChatLocalService._init();

  final ChatRepository _chatRepo = ChatRepository();
  final MessageRepository _messageRepo = MessageRepository();
  final MediaRepository _mediaRepo = MediaRepository();
  final ChatMediaStorage _mediaStorage = ChatMediaStorage.instance;

  ChatLocalService._init();

  Future<void> initialize() async {
    await _mediaStorage.baseDirectory;
  }

  // ==================== CHAT OPERATIONS ====================

  Future<LocalChat> getOrCreateChat(String phoneNumber, {String? contactName}) async {
    var chat = await _chatRepo.getChatByPhone(phoneNumber);
    if (chat == null) {
      chat = LocalChat(
        phoneNumber: phoneNumber,
        contactName: contactName ?? phoneNumber,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _chatRepo.insertChat(chat);
    }
    return chat;
  }

  Future<List<LocalChat>> getAllChats({bool includeArchived = false, bool includeBlocked = false}) async {
    return await _chatRepo.getAllChats(
      includeArchived: includeArchived,
      includeBlocked: includeBlocked,
    );
  }

  Future<List<LocalChat>> searchChats(String query) async {
    return await _chatRepo.searchChats(query);
  }

  Future<void> updateChatName(String phoneNumber, String newName) async {
    await _chatRepo.updateChatField(phoneNumber, 'contact_name', newName);
  }

  Future<void> muteChat(String phoneNumber, bool mute) async {
    await _chatRepo.toggleMute(phoneNumber, mute);
  }

  Future<void> pinChat(String phoneNumber, bool pin) async {
    await _chatRepo.togglePin(phoneNumber, pin);
  }

  Future<void> archiveChat(String phoneNumber, bool archive) async {
    await _chatRepo.toggleArchive(phoneNumber, archive);
  }

  Future<void> blockChat(String phoneNumber, bool block) async {
    await _chatRepo.toggleBlock(phoneNumber, block);
  }

  Future<void> deleteChat(String phoneNumber) async {
    await _messageRepo.deleteMessagesByPhone(phoneNumber);
    await _chatRepo.deleteChat(phoneNumber);
  }

  Future<int> getUnreadChatsCount() async {
    return await _chatRepo.getUnreadChatsCount();
  }

  // ==================== TEXT MESSAGE OPERATIONS ====================

  Future<LocalMessage> saveTextMessage({
    required String phoneNumber,
    required String text,
    required String direction,
    int? replyToMessageId,
    String? replyToContent,
    String? forwardedFrom,
  }) async {
    final now = DateTime.now().toIso8601String();
    final message = LocalMessage(
      chatPhoneNumber: phoneNumber,
      messageType: 'text',
      messageDirection: direction,
      content: text,
      replyToMessageId: replyToMessageId,
      replyToContent: replyToContent ?? '',
      forwardedFrom: forwardedFrom ?? '',
      status: direction == 'sent' ? 'sending' : 'delivered',
      createdAt: now,
      updatedAt: now,
    );

    final id = await _messageRepo.insertMessage(message);
    await _chatRepo.updateLastMessage(phoneNumber, text, 'text');

    if (direction == 'received') {
      await _chatRepo.incrementUnreadCount(phoneNumber);
    }

    return message.copyWith(id: id);
  }

  Future<LocalMessage> updateTextMessageStatus(int messageId, String status) async {
    await _messageRepo.updateMessageStatus(messageId, status);
    return (await _messageRepo.getMessageById(messageId))!;
  }

  // ==================== IMAGE MESSAGE OPERATIONS ====================

  Future<LocalMessage> saveImageMessage({
    required String phoneNumber,
    required File imageFile,
    required String direction,
    String? caption,
    String? remoteUrl,
    File? thumbnailFile,
    int? replyToMessageId,
  }) async {
    final now = DateTime.now().toIso8601String();
    final localPath = await _mediaStorage.saveImage(imageFile);
    String? thumbnailPath;
    if (thumbnailFile != null) {
      thumbnailPath = await _mediaStorage.saveThumbnail(thumbnailFile);
    }

    final fileSize = await _mediaStorage.getFileSize(localPath);
    final mimeType = _mediaStorage.getMimeTypeFromExtension(imageFile.path);

    final message = LocalMessage(
      chatPhoneNumber: phoneNumber,
      messageType: 'image',
      messageDirection: direction,
      content: caption ?? '',
      mediaLocalPath: localPath,
      mediaRemoteUrl: remoteUrl ?? '',
      mediaFileName: imageFile.path.split('/').last,
      mediaMimeType: mimeType,
      mediaSizeBytes: fileSize,
      mediaThumbnailPath: thumbnailPath ?? '',
      status: direction == 'sent' ? 'sending' : 'delivered',
      replyToMessageId: replyToMessageId,
      createdAt: now,
      updatedAt: now,
    );

    final id = await _messageRepo.insertMessage(message);

    await _mediaRepo.insertMediaCache(MediaInfo(
      messageId: id,
      filePath: localPath,
      fileType: 'image',
      fileSizeBytes: fileSize,
      isDownloaded: true,
      lastAccessed: now,
    ));

    final displayText = caption?.isNotEmpty == true ? caption! : '🖼️ Photo';
    await _chatRepo.updateLastMessage(phoneNumber, displayText, 'image');

    if (direction == 'received') {
      await _chatRepo.incrementUnreadCount(phoneNumber);
    }

    return message.copyWith(id: id);
  }

  // ==================== VIDEO MESSAGE OPERATIONS ====================

  Future<LocalMessage> saveVideoMessage({
    required String phoneNumber,
    required File videoFile,
    required String direction,
    String? caption,
    String? remoteUrl,
    File? thumbnailFile,
    int? durationMs,
    int? replyToMessageId,
  }) async {
    final now = DateTime.now().toIso8601String();
    final localPath = await _mediaStorage.saveVideo(videoFile);
    String? thumbnailPath;
    if (thumbnailFile != null) {
      thumbnailPath = await _mediaStorage.saveThumbnail(thumbnailFile);
    }

    final fileSize = await _mediaStorage.getFileSize(localPath);
    final mimeType = _mediaStorage.getMimeTypeFromExtension(videoFile.path);

    final message = LocalMessage(
      chatPhoneNumber: phoneNumber,
      messageType: 'video',
      messageDirection: direction,
      content: caption ?? '',
      mediaLocalPath: localPath,
      mediaRemoteUrl: remoteUrl ?? '',
      mediaFileName: videoFile.path.split('/').last,
      mediaMimeType: mimeType,
      mediaSizeBytes: fileSize,
      mediaDurationMs: durationMs ?? 0,
      mediaThumbnailPath: thumbnailPath ?? '',
      status: direction == 'sent' ? 'sending' : 'delivered',
      replyToMessageId: replyToMessageId,
      createdAt: now,
      updatedAt: now,
    );

    final id = await _messageRepo.insertMessage(message);

    await _mediaRepo.insertMediaCache(MediaInfo(
      messageId: id,
      filePath: localPath,
      fileType: 'video',
      fileSizeBytes: fileSize,
      isDownloaded: true,
      lastAccessed: now,
    ));

    final displayText = caption?.isNotEmpty == true ? caption! : '🎥 Video';
    await _chatRepo.updateLastMessage(phoneNumber, displayText, 'video');

    if (direction == 'received') {
      await _chatRepo.incrementUnreadCount(phoneNumber);
    }

    return message.copyWith(id: id);
  }

  // ==================== VOICE MESSAGE OPERATIONS ====================

  Future<LocalMessage> saveVoiceMessage({
    required String phoneNumber,
    required File voiceFile,
    required String direction,
    int? durationMs,
    String? remoteUrl,
    int? replyToMessageId,
  }) async {
    final now = DateTime.now().toIso8601String();
    final localPath = await _mediaStorage.saveVoiceNote(voiceFile);
    final fileSize = await _mediaStorage.getFileSize(localPath);
    final mimeType = _mediaStorage.getMimeTypeFromExtension(voiceFile.path);

    final message = LocalMessage(
      chatPhoneNumber: phoneNumber,
      messageType: 'voice',
      messageDirection: direction,
      mediaLocalPath: localPath,
      mediaRemoteUrl: remoteUrl ?? '',
      mediaFileName: voiceFile.path.split('/').last,
      mediaMimeType: mimeType,
      mediaSizeBytes: fileSize,
      mediaDurationMs: durationMs ?? 0,
      status: direction == 'sent' ? 'sending' : 'delivered',
      replyToMessageId: replyToMessageId,
      createdAt: now,
      updatedAt: now,
    );

    final id = await _messageRepo.insertMessage(message);

    await _mediaRepo.insertMediaCache(MediaInfo(
      messageId: id,
      filePath: localPath,
      fileType: 'audio',
      fileSizeBytes: fileSize,
      isDownloaded: true,
      lastAccessed: now,
    ));

    await _chatRepo.updateLastMessage(phoneNumber, '🎤 Voice message', 'voice');

    if (direction == 'received') {
      await _chatRepo.incrementUnreadCount(phoneNumber);
    }

    return message.copyWith(id: id);
  }

  // ==================== DOCUMENT MESSAGE OPERATIONS ====================

  Future<LocalMessage> saveDocumentMessage({
    required String phoneNumber,
    required File documentFile,
    required String direction,
    String? caption,
    String? remoteUrl,
    int? replyToMessageId,
  }) async {
    final now = DateTime.now().toIso8601String();
    final localPath = await _mediaStorage.saveDocument(documentFile);
    final fileSize = await _mediaStorage.getFileSize(localPath);
    final mimeType = _mediaStorage.getMimeTypeFromExtension(documentFile.path);
    final fileName = documentFile.path.split('/').last;

    final message = LocalMessage(
      chatPhoneNumber: phoneNumber,
      messageType: 'document',
      messageDirection: direction,
      content: caption ?? '',
      mediaLocalPath: localPath,
      mediaRemoteUrl: remoteUrl ?? '',
      mediaFileName: fileName,
      mediaMimeType: mimeType,
      mediaSizeBytes: fileSize,
      status: direction == 'sent' ? 'sending' : 'delivered',
      replyToMessageId: replyToMessageId,
      createdAt: now,
      updatedAt: now,
    );

    final id = await _messageRepo.insertMessage(message);

    await _mediaRepo.insertMediaCache(MediaInfo(
      messageId: id,
      filePath: localPath,
      fileType: 'document',
      fileSizeBytes: fileSize,
      isDownloaded: true,
      lastAccessed: now,
    ));

    await _chatRepo.updateLastMessage(phoneNumber, '📄 $fileName', 'document');

    if (direction == 'received') {
      await _chatRepo.incrementUnreadCount(phoneNumber);
    }

    return message.copyWith(id: id);
  }

  // ==================== LOAD MESSAGES ====================

  Future<List<LocalMessage>> loadMessages(String phoneNumber, {int limit = 100, int offset = 0}) async {
    await _chatRepo.resetUnreadCount(phoneNumber);
    return await _messageRepo.getMessagesByPhone(phoneNumber, limit: limit, offset: offset);
  }

  Future<List<LocalMessage>> loadOlderMessages(String phoneNumber, String beforeDate, {int limit = 50}) async {
    return await _messageRepo.getMessagesBeforeDate(phoneNumber, beforeDate, limit: limit);
  }

  Future<List<LocalMessage>> loadNewerMessages(String phoneNumber, String afterDate, {int limit = 50}) async {
    return await _messageRepo.getMessagesAfterDate(phoneNumber, afterDate, limit: limit);
  }

  Future<List<LocalMessage>> searchMessages(String phoneNumber, String query) async {
    return await _messageRepo.searchMessages(phoneNumber, query);
  }

  Future<List<LocalMessage>> getStarredMessages(String phoneNumber) async {
    return await _messageRepo.getStarredMessages(phoneNumber);
  }

  Future<List<LocalMessage>> getMediaMessages(String phoneNumber) async {
    return await _messageRepo.getMediaMessages(phoneNumber);
  }

  // ==================== MESSAGE ACTIONS ====================

  Future<void> starMessage(int messageId) async {
    await _messageRepo.toggleStarMessage(messageId);
  }

  Future<void> deleteMessageForMe(int messageId) async {
    final message = await _messageRepo.getMessageById(messageId);
    if (message != null) {
      if (message.hasMedia) {
        await _mediaStorage.deleteMediaForMessage(
          mediaPath: message.mediaLocalPath,
          thumbnailPath: message.mediaThumbnailPath,
        );
        await _mediaRepo.deleteMediaCacheByMessageId(messageId);
      }
      await _messageRepo.softDeleteMessage(messageId);
    }
  }

  Future<void> deleteMessageForEveryone(int messageId) async {
    final message = await _messageRepo.getMessageById(messageId);
    if (message != null) {
      if (message.hasMedia) {
        await _mediaStorage.deleteMediaForMessage(
          mediaPath: message.mediaLocalPath,
          thumbnailPath: message.mediaThumbnailPath,
        );
        await _mediaRepo.deleteMediaCacheByMessageId(messageId);
      }
      await _messageRepo.deleteMessageForEveryone(messageId);
    }
  }

  Future<void> markMessageAsFailed(int messageId, String errorMessage) async {
    await _messageRepo.markMessageAsFailed(messageId, errorMessage);
  }

  Future<void> updateMessageServerId(int messageId, String serverId) async {
    await _messageRepo.updateServerMessageId(messageId, serverId);
  }

  // ==================== STORAGE MANAGEMENT ====================

  Future<int> getStorageSize() async {
    return await _mediaStorage.getStorageSize();
  }

  Future<Map<String, int>> getStorageSizeByType() async {
    return await _mediaStorage.getStorageSizeByType();
  }

  Future<void> clearTempFiles() async {
    await _mediaStorage.clearTempFiles();
  }

  Future<void> clearAllLocalData() async {
    await _mediaStorage.clearAllMedia();
    await _messageRepo.deleteAllMessages();
    await _chatRepo.deleteAllChats();
    await _mediaRepo.deleteAllMediaCache();
  }

  // ==================== HELPERS ====================

  String formatFileSize(int bytes) {
    return _mediaStorage.formatFileSize(bytes);
  }

  String getMediaTypeFromExtension(String filePath) {
    return _mediaStorage.getMediaTypeFromExtension(filePath);
  }
}
