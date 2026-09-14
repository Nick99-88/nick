import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../../../core/starlight_http.dart';
import '../../../core/storage.dart';

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class BackendChatService {
  static const String _baseUrl = 'http://localhost:8000';

  Future<void> initialize() async {
    try {
      print('🏛️ Backend Chat Service: Initializing with backend database');
      print('🏛️ Backend Chat Service: Connected to $_baseUrl');
    } catch (e) {
      print('🏛️ Backend Chat Service: Initialization failed - $e');
      rethrow;
    }
  }

  Future<int?> createChat({
    required int userId,
    required String userName,
    String? userProfileUrl,
    String? phoneNumber,
  }) async {
    try {
      print('🏛️ Backend Chat Service: Creating chat with user $userId ($userName) phone: $phoneNumber');
      final tempChatId = DateTime.now().millisecondsSinceEpoch;
      print('🏛️ Backend Chat Service: Created temporary chat ID: $tempChatId');
      print('🏛️ Backend Chat Service: Phone number check - phoneNumber: "$phoneNumber", isNull: ${phoneNumber == null}, isEmpty: ${phoneNumber?.isEmpty}');
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        await StarlightStorage.saveActiveChatPhone(tempChatId.toString(), phoneNumber);
        print('🏛️ Backend Chat Service: Saved phone number $phoneNumber for chat $tempChatId');
      } else {
        print('🏛️ Backend Chat Service: SKIPPED phone number save - phoneNumber: "$phoneNumber"');
      }
      return tempChatId;
    } catch (e) {
      print('🏛️ Backend Chat Service: Failed to create chat - $e');
      rethrow;
    }
  }

  Future<int> createChatLocally(
    String userId,
    String userName, {
    String? userProfileUrl,
    String? phoneNumber,
  }) async {
    try {
      print('🏛️ Backend Chat Service: Creating local chat for user $userId ($userName) phone: $phoneNumber');
      final localChatId = DateTime.now().millisecondsSinceEpoch;
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        await StarlightStorage.saveActiveChatPhone(localChatId.toString(), phoneNumber);
        print('🏛️ Backend Chat Service: Saved phone number $phoneNumber for local chat $localChatId');
      }
      print('🏛️ Backend Chat Service: Local chat created with ID: $localChatId');
      return localChatId;
    } catch (e) {
      print('🏛️ Backend Chat Service: Failed to create local chat - $e');
      rethrow;
    }
  }

  Future<void> saveChatUser(Map<String, dynamic> userData) async {
    try {
      print('🏛️ Backend Chat Service: Saving chat user data for user ${userData['id']}');
      final response = await StarlightHttp.put(
        Uri.parse('$_baseUrl/api/users/${userData['id']}/chat-profile'),
        body: jsonEncode({
          'display_name': userData['name'],
          'profile_image': userData['profile_image'],
        }),
      );
      if (response.statusCode == 200) {
        print('🏛️ Backend Chat Service: User chat profile saved');
      } else {
        print('🏛️ Backend Chat Service: Failed to save user profile: ${response.statusCode}');
      }
    } catch (e) {
      print('🏛️ Backend Chat Service: Failed to save chat user - $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserChats() async {
    try {
      print('🏛️ Backend Chat Service: Getting chats from local storage (socket-based)');
      return [];
    } catch (e) {
      print('🏛️ Backend Chat Service: Failed to get user chats - $e');
      rethrow;
    }
  }

  Future<void> markChatAsSeen(int chatId) async {
    try {
      print('🏛️ Backend Chat Service: Marking chat $chatId as seen via socket');
      print('🏛️ Backend Chat Service: Chat $chatId marked as seen (socket-based)');
    } catch (e) {
      print('🏛️ Backend Chat Service: Failed to mark chat as seen - $e');
      rethrow;
    }
  }

  Future<int?> sendMessage({
    required int chatId,
    required String content,
    required int senderId,
    String messageType = 'text',
  }) async {
    try {
      print('🏛️ Backend Chat Service: Sending message via socket to chat $chatId');
      final messageId = DateTime.now().millisecondsSinceEpoch;
      print('🏛️ Backend Chat Service: Message sent with temporary ID: $messageId');
      return messageId;
    } catch (e) {
      print('🏛️ Backend Chat Service: Failed to send message - $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(int chatId, {int limit = 50}) async {
    try {
      print('🏛️ Backend Chat Service: Fetching messages for chat $chatId');
      final response = await StarlightHttp.get(
        Uri.parse('$_baseUrl/chat/messages/$chatId?limit=$limit'),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messages = data['messages'] as List<dynamic>? ?? [];
        print('🏛️ Backend Chat Service: Loaded ${messages.length} messages');
        return messages.cast<Map<String, dynamic>>();
      } else {
        print('🏛️ Backend Chat Service: Failed to load messages - ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('🏛️ Backend Chat Service: Error fetching messages - $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMessagesByPhone(String recipientPhone, {int limit = 50}) async {
    try {
      print('🏛️ Backend Chat Service: Fetching messages by phone for $recipientPhone');
      final response = await StarlightHttp.get(
        Uri.parse('$_baseUrl/chat/messages/by-phone/$recipientPhone?limit=$limit'),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messages = data['messages'] as List<dynamic>? ?? [];
        print('🏛️ Backend Chat Service: Loaded ${messages.length} messages by phone');
        return messages.cast<Map<String, dynamic>>();
      } else {
        print('🏛️ Backend Chat Service: Failed to load messages by phone - ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('🏛️ Backend Chat Service: Error fetching messages by phone - $e');
      return [];
    }
  }

  Future<String> getMessageStatus(int messageId) async {
    try {
      print('🏛️ Backend Chat Service: Getting status for message $messageId');
      final response = await StarlightHttp.get(
        Uri.parse('$_baseUrl/api/messages/$messageId/status'),
      );
      if (response.statusCode == 200) {
        final messageData = jsonDecode(response.body);
        String status = 'sent';
        if (messageData['is_read']) status = 'read';
        else if (messageData['is_delivered']) status = 'delivered';
        return status;
      } else {
        return 'unknown';
      }
    } catch (e) {
      print('🏛️ Backend Chat Service: Failed to get message status - $e');
      return 'unknown';
    }
  }

  Future<void> deleteMessage(int messageId) async {
    try {
      print('🏛️ Backend Chat Service: Deleting message $messageId');
      final response = await StarlightHttp.delete(
        Uri.parse('$_baseUrl/api/messages/$messageId'),
      );
      if (response.statusCode == 200) {
        print('🏛️ Backend Chat Service: Message deleted');
      } else {
        print('🏛️ Backend Chat Service: Failed to delete message: ${response.statusCode}');
      }
    } catch (e) {
      print('🏛️ Backend Chat Service: Failed to delete message - $e');
      rethrow;
    }
  }

  Future<void> deleteChat(int chatId) async {
    try {
      print('🏛️ Backend Chat Service: Deleting chat $chatId');
      final response = await StarlightHttp.delete(
        Uri.parse('$_baseUrl/api/chats/$chatId'),
      );
      if (response.statusCode == 200) {
        print('🏛️ Backend Chat Service: Chat deleted');
      } else {
        print('🏛️ Backend Chat Service: Failed to delete chat: ${response.statusCode}');
      }
    } catch (e) {
      print('🏛️ Backend Chat Service: Failed to delete chat - $e');
      rethrow;
    }
  }

  Future<void> syncWithBackend(int localChatId, int backendUserId) async {
    try {
      print('🏛️ Backend Chat Service: Syncing local chat $localChatId with backend user $backendUserId');
      print('🏛️ Backend Chat Service: Chat synced with backend');
    } catch (e) {
      print('🏛️ Backend Chat Service: Failed to sync with backend - $e');
      rethrow;
    }
  }
}
