import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../../chat_local_db/chat_local_db.dart';
import '../../chat_local_db/models/local_message.dart';
import '../../services/socket/enhanced_socket_service.dart';
import 'socket_event_bus.dart';
import '../../core/storage.dart';
import '../../core/constants.dart';
import 'package:http/http.dart' as http;

class MessageOutboxQueue {
  static final MessageOutboxQueue instance = MessageOutboxQueue._init();
  MessageOutboxQueue._init();

  final MessageRepository _messageRepo = MessageRepository();
  final ChatRepository _chatRepo = ChatRepository();
  Timer? _retryTimer;
  bool _isProcessing = false;
  final Map<String, Completer<void>> _pendingAcks = {};
  final int _maxMediaRetries = 5;
  final List<int> _backoffSeconds = [5, 15, 60, 300, 900, 1800, 3600];

  Future<void> initialize() async {
    _setupAckListener();
    _startRetryTimer();
    await _processPendingMessages();
  }

  void _setupAckListener() {
    SocketEventBus.instance.subscribe('msg_ack', (data) async {
      await _handleServerAck(data);
    });
  }

  Future<void> _handleServerAck(Map<String, dynamic> data) async {
    try {
      final clientUuid = data['client_uuid'] as String?;
      final serverMessageId = data['message_id']?.toString() ?? '';
      final sequenceId = data['sequence_id'] as int? ?? 0;

      if (clientUuid == null || clientUuid.isEmpty) return;

      final message = await _messageRepo.getMessageByClientUuid(clientUuid);
      if (message == null || message.id == null) return;

      await _messageRepo.updateMessage(message.copyWith(
        serverMessageId: serverMessageId,
        sequenceId: sequenceId,
        status: 'sent',
        errorMessage: '',
        updatedAt: DateTime.now().toIso8601String(),
      ));

      _pendingAcks[clientUuid]?.complete();
      _pendingAcks.remove(clientUuid);

      print('📤 Outbox: ACK received for $clientUuid → server_id=$serverMessageId');
    } catch (e) {
      print('📤 Outbox: Error handling ACK: $e');
    }
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_isProcessing) {
        _processPendingMessages();
      }
    });
  }

  Future<void> triggerProcess() async {
    if (!_isProcessing) {
      await _processPendingMessages();
    }
  }

  Future<void> _processPendingMessages() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) return;

      final allChats = await _chatRepo.getAllChats(includeArchived: false, includeBlocked: false);
      
      for (final chat in allChats) {
        final unsentMessages = await _messageRepo.getUnsentMessages(chat.phoneNumber);
        
        for (final message in unsentMessages) {
          if (message.id == null) continue;
          if (message.clientUuid.isEmpty) continue;

          final retryData = _parseRetryData(message.errorMessage);
          final retryCount = retryData['retry_count'] ?? 0;
          final isMedia = message.isMedia;
          final hasUploadedMedia = !isMedia || message.mediaRemoteUrl.isNotEmpty;

          if (isMedia && retryCount >= _maxMediaRetries) {
            await _messageRepo.markMessageAsFailed(message.id!, 'Media upload expired');
            continue;
          }

          if (!hasUploadedMedia) {
            // Keep failed media messages local until media upload succeeds in UI flow.
            continue;
          }

          final lastAttempt = retryData['last_attempt'] != null
              ? DateTime.tryParse(retryData['last_attempt'])
              : DateTime.tryParse(message.createdAt);
          
          if (lastAttempt == null) continue;

          final backoffIndex = retryCount.clamp(0, _backoffSeconds.length - 1);
          final backoffSeconds = _backoffSeconds[backoffIndex];
          final nextRetryTime = lastAttempt.add(Duration(seconds: backoffSeconds));
          
          if (DateTime.now().isBefore(nextRetryTime)) continue;

          await _sendMessageWithRetry(message);
        }
      }
    } catch (e) {
      print('📤 Outbox: Error processing pending messages: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Map<String, dynamic> _parseRetryData(String errorMessage) {
    if (errorMessage.isEmpty) return {};
    try {
      return jsonDecode(errorMessage);
    } catch (e) {
      return {};
    }
  }

  Future<void> _sendMessageWithRetry(LocalMessage message) async {
    try {
      final retryData = _parseRetryData(message.errorMessage);
      final newRetryCount = (retryData['retry_count'] ?? 0) + 1;

      if (EnhancedSocketService.isConnected()) {
        final ackCompleter = Completer<void>();
        _pendingAcks[message.clientUuid] = ackCompleter;

        EnhancedSocketService.sendMessageToRecipient(
          message.chatPhoneNumber,
          message.content,
          messageType: message.messageType,
          clientUuid: message.clientUuid,
          mediaUrl: message.mediaRemoteUrl,
          mediaBlurhash: message.mediaBlurhash,
        );

        try {
          await ackCompleter.future.timeout(const Duration(seconds: 10));
          if (message.id != null) {
            await _messageRepo.updateMessageStatus(message.id!, 'sent');
          }
        } on TimeoutException {
          _pendingAcks.remove(message.clientUuid);
          await _markRetryError(message.id!, newRetryCount, 'ACK timeout');
        }
      } else {
        await _sendViaHttpFallback(message);
      }
    } catch (e) {
      final retryData = _parseRetryData(message.errorMessage);
      if (message.id != null) {
        await _markRetryError(message.id!, (retryData['retry_count'] ?? 0) + 1, e.toString());
      }
    }
  }

  Future<void> _sendViaHttpFallback(LocalMessage message) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/chat/send-message-by-phone/${message.chatPhoneNumber}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'content': message.content,
          'message_type': message.messageType,
          'client_uuid': message.clientUuid,
          'media_url': message.mediaRemoteUrl,
          'media_blurhash': message.mediaBlurhash,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && message.id != null) {
        final data = jsonDecode(response.body);
        final serverId = data['message_id']?.toString() ?? '';
        final sequenceId = data['sequence_id'] as int? ?? 0;
        await _messageRepo.updateMessage(message.copyWith(
          serverMessageId: serverId,
          sequenceId: sequenceId,
          status: 'sent',
          errorMessage: '',
          updatedAt: DateTime.now().toIso8601String(),
        ));
      } else if (message.id != null) {
        final retryData = _parseRetryData(message.errorMessage);
        await _markRetryError(message.id!, (retryData['retry_count'] ?? 0) + 1, 'HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (message.id != null) {
        final retryData = _parseRetryData(message.errorMessage);
        await _markRetryError(message.id!, (retryData['retry_count'] ?? 0) + 1, 'HTTP fallback failed: $e');
      }
    }
  }

  Future<void> _markRetryError(int messageId, int retryCount, String error) async {
    final errorMessage = jsonEncode({
      'retry_count': retryCount,
      'last_error': error,
      'last_attempt': DateTime.now().toIso8601String(),
    });
    await _messageRepo.markMessageAsFailed(messageId, errorMessage);
  }

  static String generateClientUuid() {
    return const Uuid().v4();
  }

  Future<void> dispose() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    for (final completer in _pendingAcks.values) {
      completer.complete();
    }
    _pendingAcks.clear();
  }
}
