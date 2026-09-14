import 'dart:io';
import 'chat_local_db.dart';

final chatLocal = ChatLocalService.instance;

/// Initialize the local chat database (call once at app startup)
Future<void> initChatLocal() async {
  await chatLocal.initialize();
}

/// ==================== SENDING MESSAGES ====================

/// Send a text message
/// Simply call this with the phone number and text
/// Direction: 'sent' for outgoing, 'received' for incoming
Future<void> sendTextMessage(String phoneNumber, String text) async {
  await chatLocal.saveTextMessage(
    phoneNumber: phoneNumber,
    text: text,
    direction: 'sent',
  );
}

/// Receive a text message
Future<void> receiveTextMessage(String phoneNumber, String text) async {
  await chatLocal.saveTextMessage(
    phoneNumber: phoneNumber,
    text: text,
    direction: 'received',
  );
}

/// Send an image message
Future<void> sendImageMessage(String phoneNumber, File imageFile, {String? caption}) async {
  await chatLocal.saveImageMessage(
    phoneNumber: phoneNumber,
    imageFile: imageFile,
    direction: 'sent',
    caption: caption,
  );
}

/// Receive an image message
Future<void> receiveImageMessage(String phoneNumber, File imageFile, {String? caption}) async {
  await chatLocal.saveImageMessage(
    phoneNumber: phoneNumber,
    imageFile: imageFile,
    direction: 'received',
    caption: caption,
  );
}

/// Send a video message
Future<void> sendVideoMessage(String phoneNumber, File videoFile, {String? caption, int? durationMs}) async {
  await chatLocal.saveVideoMessage(
    phoneNumber: phoneNumber,
    videoFile: videoFile,
    direction: 'sent',
    caption: caption,
    durationMs: durationMs,
  );
}

/// Send a voice message
Future<void> sendVoiceMessage(String phoneNumber, File voiceFile, {int? durationMs}) async {
  await chatLocal.saveVoiceMessage(
    phoneNumber: phoneNumber,
    voiceFile: voiceFile,
    direction: 'sent',
    durationMs: durationMs,
  );
}

/// Send a document message
Future<void> sendDocumentMessage(String phoneNumber, File documentFile, {String? caption}) async {
  await chatLocal.saveDocumentMessage(
    phoneNumber: phoneNumber,
    documentFile: documentFile,
    direction: 'sent',
    caption: caption,
  );
}

/// ==================== LOADING MESSAGES ====================

/// Load messages for a specific chat (by phone number)
/// Returns messages in chronological order (oldest first)
Future<List<LocalMessage>> loadChatMessages(String phoneNumber, {int limit = 100}) async {
  return await chatLocal.loadMessages(phoneNumber, limit: limit);
}

/// Load older messages (pagination)
Future<List<LocalMessage>> loadOlderMessages(String phoneNumber, String beforeDate) async {
  return await chatLocal.loadOlderMessages(phoneNumber, beforeDate);
}

/// ==================== CHAT LIST ====================

/// Get all chats (sorted by last message time, pinned first)
Future<List<LocalChat>> getAllChats() async {
  return await chatLocal.getAllChats();
}

/// Search chats by name or phone number
Future<List<LocalChat>> searchChats(String query) async {
  return await chatLocal.searchChats(query);
}

/// Get unread chat count
Future<int> getUnreadCount() async {
  return await chatLocal.getUnreadChatsCount();
}

/// ==================== MESSAGE ACTIONS ====================

/// Star/unstar a message
Future<void> toggleStarMessage(int messageId) async {
  await chatLocal.starMessage(messageId);
}

/// Delete message for me only
Future<void> deleteMessageForMe(int messageId) async {
  await chatLocal.deleteMessageForMe(messageId);
}

/// Delete message for everyone
Future<void> deleteMessageForEveryone(int messageId) async {
  await chatLocal.deleteMessageForEveryone(messageId);
}

/// ==================== CHAT ACTIONS ====================

/// Mute/unmute a chat
Future<void> muteChat(String phoneNumber, bool mute) async {
  await chatLocal.muteChat(phoneNumber, mute);
}

/// Pin/unpin a chat
Future<void> pinChat(String phoneNumber, bool pin) async {
  await chatLocal.pinChat(phoneNumber, pin);
}

/// Archive/unarchive a chat
Future<void> archiveChat(String phoneNumber, bool archive) async {
  await chatLocal.archiveChat(phoneNumber, archive);
}

/// Block/unblock a chat
Future<void> blockChat(String phoneNumber, bool block) async {
  await chatLocal.blockChat(phoneNumber, block);
}

/// Delete entire chat and its messages
Future<void> deleteChat(String phoneNumber) async {
  await chatLocal.deleteChat(phoneNumber);
}

/// ==================== STORAGE ====================

/// Get total storage used by chat media
Future<int> getStorageUsed() async {
  return await chatLocal.getStorageSize();
}

/// Clear temporary files
Future<void> clearTempFiles() async {
  await chatLocal.clearTempFiles();
}

/// Clear all local chat data
Future<void> clearAllChatData() async {
  await chatLocal.clearAllLocalData();
}
