import 'package:starlight_flutter/chat_local_db/chat_local_db.dart';

class FcmChatSaver {
  static Future<void> saveChatMessage(Map<String, dynamic> data) async {
    try {
      final peerUserId = (data['senderId'] as String?) ?? (data['sender_id'] as String?) ?? '';
      final senderPhone = (data['senderPhone'] as String?) ?? (data['sender_phone'] as String?) ?? '';
      final senderName = (data['senderName'] as String?) ?? (data['sender_name'] as String?) ?? '';
      final chatId = (data['chatId']?.toString()) ?? (data['chat_id']?.toString()) ?? '';

      final messageContent = (data['messageContent'] as String?) ?? (data['message_content'] as String?) ?? (data['content'] as String?) ?? '';

      final messageType = (data['messageType'] as String?) ?? (data['message_type'] as String?) ?? 'text';

      final messageId = (data['messageId'] as String?) ?? (data['message_id'] as String?) ?? '';
      final clientUuid = (data['clientUuid'] as String?) ?? (data['client_uuid'] as String?) ?? '';
      final serverTimestamp = (data['timestamp'] as String?) ?? DateTime.now().toIso8601String();
      final mediaUrl = (data['mediaUrl'] as String?) ?? (data['media_url'] as String?) ?? '';
      final mediaFileName = (data['mediaFileName'] as String?) ?? (data['media_file_name'] as String?) ?? (data['file_name'] as String?) ?? '';
      final mediaBlurhash = (data['mediaBlurhash'] as String?) ?? (data['media_blurhash'] as String?) ?? '';
      final thumbnailUrl = (data['thumbnailUrl'] as String?) ?? (data['thumbnail_url'] as String?) ?? '';

      if (peerUserId.isEmpty) return;

      final chatRepo = ChatRepository();
      final msgRepo = MessageRepository();

      // Use chat_id if provided (inbox/public-ID chats), otherwise derive from phone/user ID
      final chatKey = chatId.isNotEmpty ? chatId : (senderPhone.isNotEmpty ? senderPhone : peerUserId);
      LocalChat chat;
      final existingChat = chatId.isNotEmpty
          ? await chatRepo.getChatByPhone(chatId)
          : null;
      final existingByPhone = (existingChat ?? (senderPhone.isNotEmpty
          ? await chatRepo.getChatByPhone(senderPhone)
          : null));
      final existingByPeer = existingByPhone ?? await chatRepo.getChatByPeerUserId(peerUserId);
      if (existingByPeer != null) {
        chat = existingByPeer;
      } else {
        chat = LocalChat(
          phoneNumber: chatKey,
          peerUserId: peerUserId,
          contactName: senderName.isNotEmpty ? senderName : chatKey,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );
        await chatRepo.insertChat(chat);
      }

      final existingByServerId = await msgRepo.getMessageCountByServerId(messageId);
      if (existingByServerId > 0) return;
      if (clientUuid.isNotEmpty) {
        final existingByClientUuid = await msgRepo.getMessageByClientUuid(clientUuid);
        if (existingByClientUuid != null) return;
      }

      final now = DateTime.now().toIso8601String();
      final message = LocalMessage(
        chatPhoneNumber: chat.phoneNumber,
        peerUserId: peerUserId,
        messageType: messageType,
        messageDirection: 'received',
        content: messageContent,
        mediaRemoteUrl: mediaUrl,
        mediaFileName: mediaFileName,
        mediaBlurhash: mediaBlurhash,
        mediaThumbnailPath: thumbnailUrl,
        clientUuid: clientUuid,
        serverMessageId: messageId,
        status: 'delivered',
        createdAt: serverTimestamp,
        updatedAt: now,
      );
      await msgRepo.insertMessage(message);
      await chatRepo.incrementUnreadCount(chat.phoneNumber);
      await chatRepo.updateLastMessage(
        chat.phoneNumber,
        messageContent.isNotEmpty ? messageContent : message.displayContent,
        messageType,
        messageTime: serverTimestamp,
      );
    } catch (e) {
      print('FcmChatSaver: Error - $e');
    }
  }
}
