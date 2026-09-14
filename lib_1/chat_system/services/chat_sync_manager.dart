import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../chat_local_db/chat_local_db.dart';
import '../../chat_local_db/models/local_message.dart';
import '../../services/socket/enhanced_socket_service.dart';
import 'socket_event_bus.dart';
import '../utils/phone_normalization.dart';
import '../../core/storage.dart';
import '../../core/constants.dart';

class ChatSyncManager {
  static final ChatSyncManager instance = ChatSyncManager._init();
  ChatSyncManager._init();

  final ChatRepository _chatRepo = ChatRepository();
  final MessageRepository _messageRepo = MessageRepository();
  final MediaRepository _mediaRepo = MediaRepository();
  final ChatMediaStorage _mediaStorage = ChatMediaStorage.instance;

  Timer? _heartbeatTimer;
  Timer? _deltaSyncTimer;
  String? _myPhoneNumber;
  bool _isInitialized = false;

  Function(LocalMessage)? onNewMessageReceived;
  Function(String, String)? onMessageStatusUpdated;
  Function()? onChatListUpdated;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _myPhoneNumber = await StarlightStorage.getUserPhoneNumber();
    await _mediaStorage.baseDirectory;
    
    _setupSocketListeners();
    _startHeartbeat();
    _startDeltaSync();
    
    _isInitialized = true;
    print('🔄 SyncManager: Initialized');
  }

  void _setupSocketListeners() {
    SocketEventBus.instance.subscribe('new_message', (data) async {
      await _handleIncomingMessage(data);
    });

    SocketEventBus.instance.subscribe('message_delivered', (data) async {
      await _handleMessageDelivered(data);
    });

    SocketEventBus.instance.subscribe('message_status', (data) async {
      await _handleMessageStatus(data);
    });

    SocketEventBus.instance.subscribe('connection_created', (data) async {
      await _performDeltaSync();
    });

    SocketEventBus.instance.subscribe('message_edited', (data) async {
      await _handleMessageEdited(data);
    });

    SocketEventBus.instance.subscribe('message_deleted', (data) async {
      await _handleMessageDeleted(data);
    });
  }

  Future<void> _handleIncomingMessage(Map<String, dynamic> data) async {
    try {
      final senderPhone = data['sender_phone'] as String?;
      final recipientPhone = data['recipient_phone'] as String?;
      final content = data['content'] as String? ?? '';
      final messageType = data['message_type'] as String? ?? 'text';
      final serverMessageId = data['message_id']?.toString() ?? '';
      final sequenceId = data['sequence_id'] as int? ?? 0;
      final clientUuid = data['client_uuid'] as String? ?? '';
      final timestamp = data['timestamp'] as String? ?? DateTime.now().toIso8601String();
      final mediaUrl = data['media_url'] as String? ?? '';
      final mediaFileName = data['media_file_name'] as String? ?? '';
      final mediaBlurhash = data['media_blurhash'] as String? ?? '';
      final peerUserId = data['peer_user_id'] as String? ?? '';
      final duration = data['duration'] is int ? data['duration'] as int : int.tryParse(data['duration']?.toString() ?? '');
      final durationMs = duration != null ? duration * 1000 : 0;

      if (senderPhone == null) return;

      if (serverMessageId.isNotEmpty) {
        final existingCount = await _messageRepo.getMessageCountByServerId(serverMessageId);
        if (existingCount > 0) return;
      }

      if (clientUuid.isNotEmpty) {
        final existingByUuid = await _messageRepo.getMessageByClientUuid(clientUuid);
        if (existingByUuid != null) return;
      }

      final isMe = PhoneNormalization.matches(senderPhone, _myPhoneNumber ?? '');
      final chatPhone = isMe ? (recipientPhone ?? '') : senderPhone;

      if (chatPhone.isEmpty) return;

      await _chatRepo.getOrCreateChat(chatPhone, peerUserId: peerUserId);
      if (peerUserId.isNotEmpty) {
        await PresenceService.instance.updatePhoneForUser(peerUserId, chatPhone);
      }

      final now = DateTime.now().toIso8601String();
      final message = LocalMessage(
        chatPhoneNumber: chatPhone,
        peerUserId: peerUserId,
        messageType: messageType,
        messageDirection: isMe ? 'sent' : 'received',
        content: content,
        mediaRemoteUrl: mediaUrl,
        mediaFileName: mediaFileName,
        mediaBlurhash: mediaBlurhash,
        mediaDurationMs: durationMs,
        serverMessageId: serverMessageId,
        sequenceId: sequenceId,
        clientUuid: clientUuid,
        status: 'delivered',
        createdAt: timestamp,
        updatedAt: now,
      );

      final id = await _messageRepo.insertMessage(message);
      final savedMessage = message.copyWith(id: id);

      if (!isMe) {
        await _chatRepo.incrementUnreadCount(chatPhone);
      }
      await _chatRepo.updateLastMessage(
        chatPhone,
        content,
        messageType,
        messageTime: timestamp,
      );

      onNewMessageReceived?.call(savedMessage);
      onChatListUpdated?.call();
    } catch (e) {
      print('🔄 SyncManager: Error handling incoming message: $e');
    }
  }

  Future<void> _handleMessageDelivered(Map<String, dynamic> data) async {
    try {
      final serverMessageId = data['message_id']?.toString();
      if (serverMessageId != null && serverMessageId.isNotEmpty) {
        await _messageRepo.updateMessageStatusByServerId(serverMessageId, 'delivered');
        onMessageStatusUpdated?.call(serverMessageId, 'delivered');
      }
    } catch (e) {
      print('🔄 SyncManager: Error handling delivered: $e');
    }
  }

  Future<void> _handleMessageStatus(Map<String, dynamic> data) async {
    try {
      final serverMessageId = data['message_id']?.toString();
      final status = data['status'] as String?;
      if (serverMessageId != null && status != null) {
        await _messageRepo.updateMessageStatusByServerId(serverMessageId, status);
        onMessageStatusUpdated?.call(serverMessageId, status);
      }
    } catch (e) {
      print('🔄 SyncManager: Error handling status: $e');
    }
  }

  Future<void> markMessageAsRead(int messageId) async {
    try {
      final message = await _messageRepo.getMessageById(messageId);
      if (message != null && message.serverMessageId.isNotEmpty) {
        await _messageRepo.updateMessageStatus(messageId, 'read');

        final chat = await _chatRepo.getChatByPhone(message.chatPhoneNumber);
        final peerUserId = chat?.peerUserId ?? message.peerUserId;

        if (EnhancedSocketService.isConnected() && peerUserId.isNotEmpty) {
          final wsMessage = {
            'action': 'mark_read',
            'data': {
              'message_id': message.serverMessageId,
              'peer_user_id': peerUserId,
            },
          };
          EnhancedSocketService.sendRawMessage(jsonEncode(wsMessage));
        }

        final token = await StarlightStorage.getUserToken();
        if (token != null) {
          http.post(
            Uri.parse('${StarlightConstants.apiBaseUrl}/chat/mark-read/${message.serverMessageId}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'peer_user_id': peerUserId}),
          ).timeout(const Duration(seconds: 5));
        }
      }
    } catch (e) {
      print('🔄 SyncManager: Error marking as read: $e');
    }
  }

  Future<void> _handleMessageEdited(Map<String, dynamic> data) async {
    try {
      final serverMessageId = data['message_id']?.toString() ?? '';
      final newContent = data['new_content'] as String? ?? '';
      if (serverMessageId.isEmpty || newContent.isEmpty) return;

      final message = await _messageRepo.getMessageByServerId(serverMessageId);
      if (message?.id != null) {
        await _messageRepo.updateMessage(message!.copyWith(
          content: newContent,
          isEdited: true,
          updatedAt: DateTime.now().toIso8601String(),
        ));
      }
      onChatListUpdated?.call();
    } catch (e) {
      print('🔄 SyncManager: Error handling message edit: $e');
    }
  }

  Future<void> _handleMessageDeleted(Map<String, dynamic> data) async {
    try {
      final serverMessageId = data['message_id']?.toString() ?? '';
      if (serverMessageId.isEmpty) return;

      final message = await _messageRepo.getMessageByServerId(serverMessageId);
      if (message?.id != null) {
        await _messageRepo.updateMessage(message!.copyWith(
          isDeleted: true,
          content: '',
          updatedAt: DateTime.now().toIso8601String(),
        ));
      }
      onChatListUpdated?.call();
    } catch (e) {
      print('🔄 SyncManager: Error handling message delete: $e');
    }
  }

  Future<void> sendTypingIndicator(String phoneNumber) async {
    try {
      if (EnhancedSocketService.isConnected()) {
        final message = {
          'action': 'typing',
          'data': {
            'recipient_phone': phoneNumber,
            'timestamp': DateTime.now().toIso8601String(),
          }
        };
        EnhancedSocketService.sendRawMessage(jsonEncode(message));
      }
    } catch (e) {
      print('🔄 SyncManager: Error sending typing: $e');
    }
  }

  Future<void> sendLastSeen() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token != null) {
        http.post(
          Uri.parse('${StarlightConstants.apiBaseUrl}/chat/last-seen'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'last_seen': DateTime.now().toIso8601String()}),
        ).timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      print('🔄 SyncManager: Error sending last seen: $e');
    }
  }

  Future<void> sendDeleteForEveryone(String serverMessageId, String phoneNumber) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token != null) {
        http.post(
          Uri.parse('${StarlightConstants.apiBaseUrl}/chat/delete-for-everyone/$serverMessageId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'recipient_phone': phoneNumber}),
        ).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      print('🔄 SyncManager: Error sending delete for everyone: $e');
    }
  }

  Future<void> sendEditMessage(String serverMessageId, String newContent, String phoneNumber) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token != null) {
        http.put(
          Uri.parse('${StarlightConstants.apiBaseUrl}/chat/edit-message/$serverMessageId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'new_content': newContent,
            'recipient_phone': phoneNumber,
          }),
        ).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      print('🔄 SyncManager: Error sending edit message: $e');
    }
  }

  Future<void> sendForwardedMessage({
    required String targetPhoneNumber,
    required String content,
    required String messageType,
    String? mediaUrl,
    String? forwardedFrom,
  }) async {
    try {
      if (EnhancedSocketService.isConnected()) {
        final message = {
          'action': 'send_message',
          'data': {
            'recipient_phone': targetPhoneNumber,
            'content': content,
            'message_type': messageType,
            'media_url': mediaUrl,
            'forwarded_from': forwardedFrom,
            'timestamp': DateTime.now().toIso8601String(),
          }
        };
        EnhancedSocketService.sendRawMessage(jsonEncode(message));
      }
    } catch (e) {
      print('🔄 SyncManager: Error sending forwarded message: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      sendLastSeen();
    });
  }

  void _startDeltaSync() {
    _deltaSyncTimer?.cancel();
    _deltaSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _performDeltaSync();
    });
  }

  Future<void> _performDeltaSync() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final lastSequenceId = await _messageRepo.getHighestSequenceId();

      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/chat/sync-delta?last_sequence_id=$lastSequenceId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newMessages = data['messages'] as List? ?? [];
        
        for (final msgData in newMessages) {
          final serverId = msgData['message_id']?.toString();
          final existingCount = await _messageRepo.getMessageCountByServerId(serverId ?? '');
          if (existingCount == 0 && serverId != null) {
            await _handleIncomingMessage(msgData);
          }
        }

        onChatListUpdated?.call();
        print('🔄 SyncManager: Delta sync completed (${newMessages.length} messages, last_seq=$lastSequenceId)');
      }
    } catch (e) {
      print('🔄 SyncManager: Delta sync error: $e');
    }
  }

  Future<void> syncChatFromServer(String phoneNumber) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/chat/messages-by-phone/$phoneNumber'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messages = data['messages'] as List? ?? [];
        
        final localMessages = await _messageRepo.getMessagesByPhone(phoneNumber, limit: 1000);
        final existingServerIds = localMessages.map((m) => m.serverMessageId).where((s) => s.isNotEmpty).toSet();

        for (final msgData in messages) {
          final serverId = msgData['message_id']?.toString();
          if (serverId != null && !existingServerIds.contains(serverId)) {
            await _handleIncomingMessage(msgData);
          }
        }
        
        print('🔄 SyncManager: Chat sync completed for $phoneNumber (${messages.length} messages)');
      }
    } catch (e) {
      print('🔄 SyncManager: Chat sync error for $phoneNumber: $e');
    }
  }

  Future<void> downloadMedia(int messageId, String remoteUrl, String fileType) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final resolvedUrl = remoteUrl.startsWith('http')
          ? remoteUrl
          : '${StarlightConstants.apiBaseUrl}${remoteUrl.startsWith('/') ? '' : '/'}$remoteUrl';

      final response = await http.get(
        Uri.parse(resolvedUrl),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final message = await _messageRepo.getMessageById(messageId);
        if (message == null) return;

        String localPath;
        final bytes = response.bodyBytes;
        
        switch (fileType) {
          case 'image':
            localPath = await _mediaStorage.saveImageBytes(bytes, message.mediaFileName);
            break;
          case 'video':
            localPath = await _mediaStorage.saveVideoBytes(bytes, message.mediaFileName);
            break;
          case 'voice':
          case 'audio':
            localPath = await _mediaStorage.saveVoiceBytes(bytes, message.mediaFileName);
            break;
          default:
            localPath = await _mediaStorage.saveDocumentBytes(bytes, message.mediaFileName);
        }

        await _messageRepo.updateMessage(message.copyWith(
          mediaLocalPath: localPath,
          updatedAt: DateTime.now().toIso8601String(),
        ));

        await _mediaRepo.insertMediaCache(MediaInfo(
          messageId: messageId,
          filePath: localPath,
          fileType: fileType,
          fileSizeBytes: bytes.length,
          isDownloaded: true,
          lastAccessed: DateTime.now().toIso8601String(),
        ));

        print('🔄 SyncManager: Media downloaded for message $messageId');
      }
    } catch (e) {
      print('🔄 SyncManager: Media download error: $e');
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _deltaSyncTimer?.cancel();
    _isInitialized = false;
  }
}
