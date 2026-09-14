import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';

class SocketService {
  static WebSocketChannel? _channel;
  static bool _isConnecting = false;
  static bool _shouldReconnect = true;
  static Timer? _reconnectTimer;
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
  static int _connectionAttempts = 0;
  static const int _maxConnectionAttempts = 5;

  /// 🏛️ Close existing socket connection
  static Future<void> disconnect() async {
    try {
      _shouldReconnect = false;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      
      if (_channel != null) {
        print('🏛️ Socket: Closing existing connection');
        await _channel!.sink.close();
        _channel = null;
      }
      
      _isConnecting = false;
      print('🏛️ Socket: Disconnected successfully');
    } catch (e) {
      print('🏛️ Socket: Error disconnecting - $e');
    }
  }

  /// 🏛️ Connect to WebSocket with user token (singleton pattern)
  static Future<void> connect({int maxRetries = 3, bool closeExisting = true, String? source}) async {
    // Add source identification
    final connectionSource = source ?? 'Unknown';
    print('🏛️ Socket: Connection request from: $connectionSource');
    
    // Close existing connection if requested
    if (closeExisting && _channel != null) {
      print('🏛️ Socket: Closing existing connection from: $connectionSource');
      await disconnect();
      // Reset reconnection flag for new connection
      _shouldReconnect = true;
    }
    
    // Prevent multiple connections
    if (_isConnecting || (_channel != null && isConnected())) {
      print('🏛️ Socket: Already connected or connecting (request from: $connectionSource)');
      return;
    }

    _isConnecting = true;
    
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null || token.isEmpty) {
        print('🏛️ Socket: No token found');
        _isConnecting = false;
        await _handleConnectionError('No authentication token available');
        return;
      }

      final wsUrl = '${StarlightConstants.socketUrl}/$token';
      print('🏛️ Socket: Connecting to $wsUrl from $connectionSource (attempt ${_connectionAttempts + 1})');
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready.timeout(const Duration(seconds: 10));

      print('🏛️ Socket: Connected successfully from: $connectionSource');

      // Listen for messages with enhanced error handling
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            _handleMessage(data);
            _connectionAttempts = 0; // Reset attempts on successful connection
          } catch (e) {
            print('🏛️ Socket: Error parsing message - $e');
            _handleMessageError('Invalid message format', e);
          }
        },
        onError: (error) {
          print('🏛️ Socket Error: $error');
          _isConnecting = false;
          _handleConnectionError(error.toString(), maxRetries);
        },
        onDone: () {
          print('🏛️ Socket Disconnected');
          _isConnecting = false;
          _channel = null;
          if (_shouldReconnect) {
            _scheduleReconnect(maxRetries);
          }
        },
        cancelOnError: true,
      );

      _isConnecting = false;
      print('🏛️ Socket Connected successfully');
      _onConnectionStateChanged?.call({'connected': true, 'timestamp': DateTime.now().toIso8601String()});
      
    } catch (e) {
      print('🏛️ Socket Connection Failed: $e');
      _isConnecting = false;
      await _handleConnectionError(e.toString(), maxRetries);
    }
  }

  /// 🏛️ Schedule reconnection attempt
  static void _scheduleReconnect([int maxRetries = 3]) {
    if (!_shouldReconnect) return;
    
    _connectionAttempts++;
    
    if (_connectionAttempts >= _maxConnectionAttempts) {
      print('🏛️ Socket: Max connection attempts reached, stopping reconnection');
      _shouldReconnect = false;
      _onConnectionStateChanged?.call({'connected': false, 'error': 'Max attempts reached', 'timestamp': DateTime.now().toIso8601String()});
      return;
    }
    
    _reconnectTimer?.cancel();
    
    // Exponential backoff: 5s, 10s, 20s, 40s, 80s
    final delay = Duration(seconds: 5 * (1 << (_connectionAttempts - 1)));
    print('🏛️ Socket: Scheduling reconnect in ${delay.inSeconds}s (attempt $_connectionAttempts/$_maxConnectionAttempts)');
    
    _reconnectTimer = Timer(delay, () {
      if (_shouldReconnect && !isConnected()) {
        print('🏛️ Socket: Attempting to reconnect...');
        connect(maxRetries: maxRetries);
      }
    });
  }

  /// 🏛️ Handle connection errors
  static Future<void> _handleConnectionError(String error, [int maxRetries = 3]) async {
    print('🏛️ Socket: Connection error - $error');
    
    // Notify listeners of connection error
    _onConnectionStateChanged?.call({
      'connected': false, 
      'error': error, 
      'attempts': _connectionAttempts,
      'timestamp': DateTime.now().toIso8601String()
    });
    
    // Schedule reconnection if should reconnect
    if (_shouldReconnect && _connectionAttempts < _maxConnectionAttempts) {
      _scheduleReconnect(maxRetries);
    } else {
      print('🏛️ Socket: Connection failed permanently');
      _shouldReconnect = false;
    }
  }

  /// 🏛️ Handle message errors
  static void _handleMessageError(String error, dynamic originalError) {
    print('🏛️ Socket: Message error - $error');
    
    // Notify listeners of message error
    _onMessageError?.call({
      'error': error,
      'original_error': originalError.toString(),
      'timestamp': DateTime.now().toIso8601String()
    });
  }

  
  /// 🏛️ Send explore search request
  static void searchExplore(String query) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'action': 'explore_search',
        'data': {'query': query}
      }));
    }
  }

  /// 🏛️ Send location update
  static void updateLocation(String location) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'action': 'update_location',
        'data': {'location': location}
      }));
    }
  }

  /// 🏛️ Search user by phone number
  static void searchPhone(String phoneNumber) {
    final message = {
      "action": "search_phone",
      "data": {"phone": phoneNumber}
    };
    _channel?.sink.add(jsonEncode(message));
    print('🏛️ Socket: Searching for phone: $phoneNumber');
  }

  /// 🏛️ Send message via WebSocket (recipient-based)
  static String sendMessageToRecipient(int recipientId, String content, {String messageType = "text"}) {
    if (!isConnected()) {
      print('🏛️ Socket: Not connected, cannot send message');
      return '';
    }
    
    // Generate unique message ID for tracking
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    
    final message = {
      "action": "send_message",
      "message_id": messageId,
      "data": {
        "recipient_id": recipientId,
        "content": content,
        "message_type": messageType,
        "timestamp": DateTime.now().toIso8601String()
      }
    };
    _channel?.sink.add(jsonEncode(message));
    print('🏛️ Socket: Sending message $messageId to recipient $recipientId');
    
    return messageId;
  }

  /// 🏛️ Send Direct Message (WhatsApp-like - no pre-creation required)
  static Future<String> sendDirectMessage(int recipientId, String content, int senderId, {String messageType = "text"}) async {
    try {
      if (!isConnected()) {
        print('🏛️ Socket: Not connected, using HTTP fallback');
        return await _sendDirectMessageViaHttp(recipientId, content, senderId, messageType);
      }
      
      // Generate unique message ID for tracking
      final messageId = DateTime.now().millisecondsSinceEpoch.toString();
      
      final message = {
        "action": "send_message",
        "message_id": messageId,
        "data": {
          "recipient_id": recipientId,
          "content": content,
          "message_type": messageType,
          "timestamp": DateTime.now().toIso8601String()
        }
      };
      
      _channel?.sink.add(jsonEncode(message));
      print('🏛️ Socket: Sending direct message $messageId to recipient $recipientId');
      
      return messageId;
    } catch (e) {
      print('🏛️ Socket: Error sending direct message - $e');
      return '';
    }
  }

  /// 🏛️ Send Direct Message via HTTP (Fallback)
  static Future<String> _sendDirectMessageViaHttp(int recipientId, String content, int senderId, String messageType) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return '';
      
      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/send-direct-message'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'recipient_id': recipientId,
          'content': content,
          'message_type': messageType,
          'sender_id': senderId,
        }),
      );
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['message_id']?.toString() ?? '';
      } else {
        print('🏛️ Socket: HTTP direct message failed - ${response.statusCode}');
        return '';
      }
    } catch (e) {
      print('🏛️ Socket: HTTP direct message error - $e');
      return '';
    }
  }

  /// 🏛️ Send message via WebSocket (legacy chat-based)
  static String sendMessage(int chatId, String content, {String messageType = "text"}) {
    if (!isConnected()) {
      print('🏛️ Socket: Not connected, cannot send message');
      return '';
    }
    
    // Generate unique message ID for tracking
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    
    final message = {
      "action": "send_message",
      "message_id": messageId,
      "data": {
        "chat_id": chatId,
        "content": content,
        "message_type": messageType,
        "timestamp": DateTime.now().toIso8601String()
      }
    };
    _channel?.sink.add(jsonEncode(message));
    print('🏛️ Socket: Sending message $messageId to chat $chatId');
    
    return messageId;
  }

  /// 🏛️ Real-time phone number validation via WebSocket
  static void validatePhoneRealtime(String phoneNumber) {
    if (_channel != null) {
      print('🏛️ Socket: Sending phone validation for: $phoneNumber');
      _channel!.sink.add(jsonEncode({
        'action': 'validate_phone_realtime',
        'data': {'phone': phoneNumber}
      }));
    } else {
      print('🏛️ Socket: Not connected, cannot validate phone: $phoneNumber');
    }
  }

  /// 🏛️ Handle incoming socket messages
  static void _handleMessage(Map<String, dynamic> data) {
    print('🏛️ Socket: Received message: $data');
    final event = data['event'] as String?;
    final messageData = data['data'] as Map<String, dynamic>? ?? {};

    print('🏛️ Socket: Event type: $event');
    print('🏛️ Socket: Message data: $messageData');

    switch (event) {
      case 'connected':
        print('🏛️ Socket: Connected event received');
        _onUserConnected?.call(messageData);
        break;
      case 'explore_results':
        print('🏛️ Socket: Explore results received');
        _onExploreResults?.call(messageData);
        break;
      case 'status_synced':
        print('🏛️ Socket: Status synced received');
        _onStatusSynced?.call(messageData);
        break;
      case 'phone_search_result':
        print('🏛️ Socket: Phone search result received');
        _onPhoneSearchResult?.call(messageData);
        break;
      case 'phone_validation_result':
        print('🏛️ Socket: Phone validation result received');
        _onPhoneValidationResult?.call(messageData);
        break;
      case 'new_message':
        print('🏛️ Socket: New message received');
        if (_onNewMessage != null) {
          print('🏛️ Socket: Calling onNewMessage callback');
          _onNewMessage!(messageData);
        } else {
          print('🏛️ Socket: WARNING - onNewMessage callback is null!');
        }
        break;
      case 'message_error':
        print('🏛️ Socket: Message error received');
        _onMessageError?.call(messageData);
        break;
      case 'message_delivered':
        print('🏛️ Socket: Message delivered received');
        _onMessageDelivered?.call(messageData);
        break;
      case 'message_status':
        print('🏛️ Socket: Message status received');
        _onMessageStatus?.call(messageData);
        break;
      case 'connection_replaced':
        print('🏛️ Socket: Connection replaced - another device connected');
        _onConnectionReplaced?.call(messageData);
        // Stop reconnection attempts since this connection was intentionally closed
        _shouldReconnect = false;
        break;
      default:
        print('🏛️ Socket: Unknown event type: $event');
        break;
    }
  }

  /// 🏛️ Set callbacks for socket events
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
  }) {
    print('🏛️ Socket: Setting callbacks...');
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
    
    print('🏛️ Socket: Callbacks set - onNewMessage is ${_onNewMessage != null ? "NOT NULL" : "NULL"}');
  }

  /// 🏛️ Request chat list update via WebSocket
  static void requestChatListUpdate() {
    final message = {
      "action": "update_chat_list",
      "data": {}
    };
    _channel?.sink.add(jsonEncode(message));
    print('🏛️ Socket: Requesting chat list update');
  }

  /// 🏛️ Check if socket is connected
  static bool isConnected() {
    return _channel != null;
  }

  /// 🏛️ Get current user data from socket connection
  static Map<String, dynamic>? getCurrentUserData() {
    // This would be stored when socket connects
    return null; // Implementation depends on your app state management
  }
}
