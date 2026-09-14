import 'dart:async';
import 'dart:io';
import '../../chat_local_db/chat_local_db.dart';
import '../../chat_local_db/models/local_message.dart';
import '../services/chat_sync_manager.dart';

class MessageActionService {
  static final MessageActionService instance = MessageActionService._init();
  MessageActionService._init();

  final MessageRepository _messageRepo = MessageRepository();
  final ChatRepository _chatRepo = ChatRepository();
  final ChatSyncManager _syncManager = ChatSyncManager.instance;

  static const Duration deleteForEveryoneTimeLimit = Duration(minutes: 60);
  static const Duration editMessageTimeLimit = Duration(minutes: 15);

  Future<bool> canDeleteForEveryone(LocalMessage message) async {
    if (!message.isSent) return false;
    
    final createdAt = DateTime.tryParse(message.createdAt);
    if (createdAt == null) return false;
    
    return DateTime.now().difference(createdAt) < deleteForEveryoneTimeLimit;
  }

  Future<bool> canEditMessage(LocalMessage message) async {
    if (!message.isSent || !message.isText) return false;
    
    final createdAt = DateTime.tryParse(message.createdAt);
    if (createdAt == null) return false;
    
    return DateTime.now().difference(createdAt) < editMessageTimeLimit;
  }

  Future<void> deleteForMe(int messageId) async {
    final message = await _messageRepo.getMessageById(messageId);
    if (message == null) return;

    await _messageRepo.softDeleteMessage(messageId);

    if (message.hasMedia && message.mediaLocalPath.isNotEmpty) {
      await _deleteLocalMedia(message);
    }
  }

  Future<void> deleteForEveryone(int messageId) async {
    final message = await _messageRepo.getMessageById(messageId);
    if (message == null) return;

    if (!await canDeleteForEveryone(message)) {
      throw Exception('Time limit exceeded for deleting message for everyone');
    }

    await _messageRepo.deleteMessageForEveryone(messageId);

    if (message.hasMedia && message.mediaLocalPath.isNotEmpty) {
      await _deleteLocalMedia(message);
    }

    if (message.serverMessageId.isNotEmpty) {
      await _syncManager.sendDeleteForEveryone(message.serverMessageId, message.chatPhoneNumber);
    }
  }

  Future<void> editMessage(int messageId, String newContent) async {
    final message = await _messageRepo.getMessageById(messageId);
    if (message == null) return;

    if (!await canEditMessage(message)) {
      throw Exception('Time limit exceeded for editing message');
    }

    final now = DateTime.now().toIso8601String();
    await _messageRepo.updateMessage(message.copyWith(
      content: newContent,
      updatedAt: now,
    ));

    if (message.serverMessageId.isNotEmpty) {
      await _syncManager.sendEditMessage(message.serverMessageId, newContent, message.chatPhoneNumber);
    }
  }

  Future<LocalMessage> forwardMessage({
    required int messageId,
    required String targetPhoneNumber,
    String? caption,
  }) async {
    final message = await _messageRepo.getMessageById(messageId);
    if (message == null) throw Exception('Message not found');

    final now = DateTime.now().toIso8601String();
    final forwardedMessage = LocalMessage(
      chatPhoneNumber: targetPhoneNumber,
      messageType: message.messageType,
      messageDirection: 'sent',
      content: caption ?? message.content,
      mediaLocalPath: message.mediaLocalPath,
      mediaRemoteUrl: message.mediaRemoteUrl,
      mediaFileName: message.mediaFileName,
      mediaMimeType: message.mediaMimeType,
      mediaSizeBytes: message.mediaSizeBytes,
      mediaDurationMs: message.mediaDurationMs,
      mediaWidth: message.mediaWidth,
      mediaHeight: message.mediaHeight,
      forwardedFrom: message.chatPhoneNumber,
      status: 'sending',
      createdAt: now,
      updatedAt: now,
    );

    final id = await _messageRepo.insertMessage(forwardedMessage);
    final savedMessage = forwardedMessage.copyWith(id: id);

    await _chatRepo.updateLastMessage(
      targetPhoneNumber,
      caption?.isNotEmpty == true ? caption! : message.displayContent,
      message.messageType,
    );

    return savedMessage;
  }

  Future<void> starMessage(int messageId) async {
    await _messageRepo.toggleStarMessage(messageId);
  }

  Future<List<LocalMessage>> getStarredMessages(String phoneNumber) async {
    return await _messageRepo.getStarredMessages(phoneNumber);
  }

  Future<List<LocalMessage>> searchMessages(String phoneNumber, String query) async {
    return await _messageRepo.searchMessages(phoneNumber, query);
  }

  Future<void> setDisappearingTimer(String phoneNumber, Duration? timer) async {
    if (timer == null) {
      await _chatRepo.updateChatField(phoneNumber, 'disappearing_timer', 0);
    } else {
      await _chatRepo.updateChatField(phoneNumber, 'disappearing_timer', timer.inSeconds);
    }
  }

  Future<Duration?> getDisappearingTimer(String phoneNumber) async {
    final chat = await _chatRepo.getChatByPhone(phoneNumber);
    if (chat == null) return null;
    
    if (chat.disappearingTimer <= 0) return null;
    
    return Duration(seconds: chat.disappearingTimer);
  }

  Future<void> processDisappearingMessages() async {
    final chats = await _chatRepo.getAllChats();
    
    for (final chat in chats) {
      final timerSeconds = chat.disappearingTimer;
      if (timerSeconds <= 0) continue;

      final threshold = DateTime.now().subtract(Duration(seconds: timerSeconds));
      final messages = await _messageRepo.getMessagesByPhone(chat.phoneNumber, limit: 1000);

      for (final message in messages) {
        final createdAt = DateTime.tryParse(message.createdAt);
        if (createdAt != null && createdAt.isBefore(threshold) && !message.isDeleted) {
          await _messageRepo.deleteMessageForEveryone(message.id!);
        }
      }
    }
  }

  Future<void> _deleteLocalMedia(LocalMessage message) async {
    try {
      if (message.mediaLocalPath.isNotEmpty) {
        final file = File(message.mediaLocalPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      if (message.mediaThumbnailPath.isNotEmpty) {
        final file = File(message.mediaThumbnailPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      print('⚡ MessageAction: Error deleting local media: $e');
    }
  }
}
