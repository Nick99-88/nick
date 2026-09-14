import '../../chat_local_db/chat_local_db.dart';
import '../../chat_local_db/models/local_chat.dart';
import '../../chat_local_db/models/local_message.dart';

class ChatStorageService {
  static final ChatStorageService instance = ChatStorageService._init();
  ChatStorageService._init();

  final ChatLocalService _localService = ChatLocalService.instance;
  final ChatRepository _chatRepo = ChatRepository();
  final MessageRepository _messageRepo = MessageRepository();

  int? _currentUserId;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _localService.initialize();
    _isInitialized = true;
    print('💾 ChatStorage: Initialized');
  }

  Future<void> setCurrentUserId(int userId) async {
    _currentUserId = userId;
  }

  Future<LocalChat> getOrCreateChat(String phoneNumber, {String? contactName}) async {
    return await _localService.getOrCreateChat(phoneNumber, contactName: contactName);
  }

  Future<List<LocalChat>> getUserChats() async {
    return await _localService.getAllChats();
  }

  Future<List<LocalChat>> searchChats(String query) async {
    return await _localService.searchChats(query);
  }

  Future<LocalMessage> saveMessage({
    required String phoneNumber,
    required String content,
    required String messageType,
    required String direction,
    int? replyToMessageId,
    String? replyToContent,
    String? forwardedFrom,
  }) async {
    return await _localService.saveTextMessage(
      phoneNumber: phoneNumber,
      text: content,
      direction: direction,
      replyToMessageId: replyToMessageId,
      replyToContent: replyToContent,
      forwardedFrom: forwardedFrom,
    );
  }

  Future<List<LocalMessage>> getMessages(String phoneNumber, {int limit = 100, int offset = 0}) async {
    return await _localService.loadMessages(phoneNumber, limit: limit, offset: offset);
  }

  Future<List<LocalMessage>> getOlderMessages(String phoneNumber, String beforeDate, {int limit = 50}) async {
    return await _localService.loadOlderMessages(phoneNumber, beforeDate, limit: limit);
  }

  Future<void> deleteMessage(int messageId) async {
    await _localService.deleteMessageForMe(messageId);
  }

  Future<void> deleteMessageForEveryone(int messageId) async {
    await _localService.deleteMessageForEveryone(messageId);
  }

  Future<void> clearChat(String phoneNumber) async {
    await _localService.deleteChat(phoneNumber);
  }

  Future<void> starMessage(int messageId) async {
    await _localService.starMessage(messageId);
  }

  Future<List<LocalMessage>> getStarredMessages(String phoneNumber) async {
    return await _localService.getStarredMessages(phoneNumber);
  }

  Future<List<LocalMessage>> getMediaMessages(String phoneNumber) async {
    return await _localService.getMediaMessages(phoneNumber);
  }

  Future<List<LocalMessage>> searchMessages(String phoneNumber, String query) async {
    return await _localService.searchMessages(phoneNumber, query);
  }

  Future<void> markMessageAsFailed(int messageId, String errorMessage) async {
    await _localService.markMessageAsFailed(messageId, errorMessage);
  }

  Future<void> updateMessageServerId(int messageId, String serverId) async {
    await _localService.updateMessageServerId(messageId, serverId);
  }

  Future<void> muteChat(String phoneNumber, bool mute) async {
    await _localService.muteChat(phoneNumber, mute);
  }

  Future<void> pinChat(String phoneNumber, bool pin) async {
    await _localService.pinChat(phoneNumber, pin);
  }

  Future<void> archiveChat(String phoneNumber, bool archive) async {
    await _localService.archiveChat(phoneNumber, archive);
  }

  Future<void> blockChat(String phoneNumber, bool block) async {
    await _localService.blockChat(phoneNumber, block);
  }

  Future<int> getUnreadChatsCount() async {
    return await _localService.getUnreadChatsCount();
  }

  Future<void> clearAllLocalData() async {
    await _localService.clearAllLocalData();
  }
}
