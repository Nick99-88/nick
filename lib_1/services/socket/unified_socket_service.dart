import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';

/// 🏛️ Unified Socket Service
/// Single source of truth for WebSocket connections
/// Consolidates functionality from multiple socket services
class UnifiedSocketService {
  static WebSocketChannel? _channel;
  static bool _isConnecting = false;
  static bool _shouldReconnect = true;
  static Timer? _reconnectTimer;
  static int _connectionAttempts = 0;
  static const int _maxConnectionAttempts = 5;

  // Unified callback storage
  static Function(Map<String, dynamic>)? _onUserConnected;
  static Function(Map<String, dynamic>)? _onExploreResults;
  static Function(Map<String, dynamic>)? _onStatusSynced;
  static Function(Map<String, dynamic>)? _onPhoneSearchResult;
  static Function(Map<String, dynamic>)? _onPhoneValidationResult;
  static Function(Map<String, dynamic>)? _onNewMessage;
  static Function(Map<String, dynamic>)? _onMessageError;
  static Function(Map<String, dynamic>)? _onChatListUpdated;
  static Function(Map<String, dynamic>)? _onMessageDelivered;
  static Function(Map<String, dynamic>)? _onMessageStatus;
  static Function(Map<String, dynamic>)? _onConnectionStateChanged;
  static Function(Map<String, dynamic>)? _onConnectionReplaced;
  static Function(Map<String, dynamic>)? _onConnectionCreated;
  static Function(Map<String, dynamic>)? _onConnectionError;

  /// 🏛️ Set unified callbacks for all socket events
  static void setCallbacks({
    Function(Map<String, dynamic>)? onUserConnected,
    Function(Map<String, dynamic>)? onExploreResults,
    Function(Map<String, dynamic>)? onStatusSynced,
    Function(Map<String, dynamic>)? onPhoneSearchResult,
    Function(Map<String, dynamic>)? onPhoneValidationResult,
    Function(Map<String, dynamic>)? onNewMessage,
    Function(Map<String, dynamic>)? onMessageError,
    Function(Map<String, dynamic>)? onChatListUpdated,
    Function(Map<String, dynamic>)? onMessageDelivered,
    Function(Map<String, dynamic>)? onMessageStatus,
    Function(Map<String, dynamic>)? onConnectionStateChanged,
    Function(Map<String, dynamic>)? onConnectionReplaced,
    Function(Map<String, dynamic>)? onConnectionCreated,
    Function(Map<String, dynamic>)? onConnectionError,
  }) {
    _onUserConnected = onUserConnected;
    _onExploreResults = onExploreResults;
    _onStatusSynced = onStatusSynced;
    _onPhoneSearchResult = onPhoneSearchResult;
    _onPhoneValidationResult = onPhoneValidationResult;
    _onNewMessage = onNewMessage;
    _onMessageError = onMessageError;
    _onChatListUpdated = onChatListUpdated;
    _onMessageDelivered = onMessageDelivered;
    _onMessageStatus = onMessageStatus;
    _onConnectionStateChanged = onConnectionStateChanged;
    _onConnectionReplaced = onConnectionReplaced;
    _onConnectionCreated = onConnectionCreated;
    _onConnectionError = onConnectionError;
  }

  /// 🏛️ Connect to WebSocket with proper error handling
  static Future<void> connect({int maxRetries = 3, bool closeExisting = true, String? source}) async {
    final connectionSource = source ?? 'Unknown';
    
    // Close existing connection if requested
    if (closeExisting && _channel != null) {
      await disconnect();
      _shouldReconnect = true;
    }
    
    // Prevent multiple connections
    if (_isConnecting || (_channel != null && isConnected())) {
      return;
    }

    _isConnecting = true;
    
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null || token.isEmpty) {
        _isConnecting = false;
        throw Exception('No authentication token available');
      }

      final wsUrl = '${StarlightConstants.socketUrl}/$token';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready.timeout(const Duration(seconds: 10));

      // Listen for messages with enhanced error handling
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            _handleMessage(data);
            _connectionAttempts = 0;
          } catch (e) {
            _handleMessageError('Invalid message format', e);
          }
        },
        onError: (error) {
          _isConnecting = false;
          _handleConnectionError(error.toString(), maxRetries);
        },
        onDone: () {
          _isConnecting = false;
          _channel = null;
          if (_shouldReconnect) {
            _scheduleReconnect(maxRetries);
          }
        },
        cancelOnError: true,
      );

      _isConnecting = false;
      _onConnectionStateChanged?.call({'connected': true, 'timestamp': DateTime.now().toIso8601String()});
      
    } catch (e) {
      _isConnecting = false;
      await _handleConnectionError(e.toString(), maxRetries);
    }
  }

  /// 🏛️ Handle incoming socket messages
  static void _handleMessage(Map<String, dynamic> data) {
    final event = data['event'] as String?;
    final messageData = data['data'] as Map<String, dynamic>? ?? {};

    switch (event) {
      case 'connected':
        _onUserConnected?.call(messageData);
        break;
      case 'explore_results':
        _onExploreResults?.call(messageData);
        break;
      case 'status_synced':
        _onStatusSynced?.call(messageData);
        break;
      case 'phone_search_result':
        _onPhoneSearchResult?.call(messageData);
        break;
      case 'phone_validation_result':
        _onPhoneValidationResult?.call(messageData);
        break;
      case 'new_message':
        _onNewMessage?.call(messageData);
        break;
      case 'message_error':
        _onMessageError?.call(messageData);
        break;
      case 'chat_list_updated':
        _onChatListUpdated?.call(messageData);
        break;
      case 'message_delivered':
        _onMessageDelivered?.call(messageData);
        break;
      case 'message_status':
        _onMessageStatus?.call(messageData);
        break;
      case 'connection_replaced':
        _onConnectionReplaced?.call(messageData);
        _shouldReconnect = false;
        break;
      default:
        break;
    }
  }

  /// 🏛️ Send message via WebSocket (recipient-based by phone number)
  static String sendMessageToRecipient(String recipientPhone, String content, {String messageType = "text"}) {
    if (!isConnected()) {
      return '';
    }

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();

    final message = <String, dynamic>{
      "action": "send_message",
      "message_id": messageId,
      "data": <String, dynamic>{
        "recipient_phone": recipientPhone,
        "content": content,
        "message_type": messageType,
        "timestamp": DateTime.now().toIso8601String()
      }
    };
    
    _channel?.sink.add(jsonEncode(message));
    return messageId;
  }

  /// 🏛️ Search user by phone number
  static void searchPhone(String phoneNumber) {
    final message = {
      "action": "search_phone",
      "data": {"phone": phoneNumber}
    };
    _channel?.sink.add(jsonEncode(message));
  }

  /// 🏛️ Validate phone number via WebSocket
  static void validatePhone(String phoneNumber) {
    final message = {
      "action": "validate_phone",
      "data": {"phone": phoneNumber}
    };
    _channel?.sink.add(jsonEncode(message));
  }

  /// 🏛️ Disconnect from WebSocket
  static Future<void> disconnect() async {
    try {
      _shouldReconnect = false;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      
      if (_channel != null) {
        await _channel!.sink.close();
        _channel = null;
      }
      
      _isConnecting = false;
    } catch (e) {
      // Log error but don't throw to prevent app crashes
    }
  }

  /// 🏛️ Check if socket is connected
  static bool isConnected() {
    return _channel != null;
  }

  /// 🏛️ Clear all callbacks
  static void clearCallbacks() {
    _onUserConnected = null;
    _onExploreResults = null;
    _onStatusSynced = null;
    _onPhoneSearchResult = null;
    _onPhoneValidationResult = null;
    _onNewMessage = null;
    _onMessageError = null;
    _onChatListUpdated = null;
    _onMessageDelivered = null;
    _onMessageStatus = null;
    _onConnectionStateChanged = null;
    _onConnectionReplaced = null;
    _onConnectionCreated = null;
    _onConnectionError = null;
  }

  /// 🏛️ Handle connection errors
  static Future<void> _handleConnectionError(String error, [int maxRetries = 3]) async {
    _onConnectionStateChanged?.call({
      'connected': false, 
      'error': error, 
      'attempts': _connectionAttempts,
      'timestamp': DateTime.now().toIso8601String()
    });
    
    if (_shouldReconnect && _connectionAttempts < _maxConnectionAttempts) {
      _scheduleReconnect(maxRetries);
    } else {
      _shouldReconnect = false;
    }
  }

  /// 🏛️ Handle message errors
  static void _handleMessageError(String error, dynamic originalError) {
    _onMessageError?.call({
      'error': error,
      'original_error': originalError.toString(),
      'timestamp': DateTime.now().toIso8601String()
    });
  }

  /// 🏛️ Schedule reconnection attempt
  static void _scheduleReconnect([int maxRetries = 3]) {
    if (!_shouldReconnect) return;
    
    _connectionAttempts++;
    
    if (_connectionAttempts >= _maxConnectionAttempts) {
      _shouldReconnect = false;
      _onConnectionStateChanged?.call({'connected': false, 'error': 'Max attempts reached', 'timestamp': DateTime.now().toIso8601String()});
      return;
    }
    
    _reconnectTimer?.cancel();
    
    final delay = Duration(seconds: 5 * (1 << (_connectionAttempts - 1)));
    _reconnectTimer = Timer(delay, () {
      if (_shouldReconnect && !isConnected()) {
        connect(maxRetries: maxRetries);
      }
    });
  }
}
