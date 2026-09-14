import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';
import '../../chat_system/services/socket_event_bus.dart';

/// 🏛️ Handler interface for chat message screens
abstract class ChatMessageScreenHandler {
  void handleNewMessage(Map<String, dynamic> messageData);
}

/// 🏛️ Enhanced WebSocket Service with Proper Callback Management
/// Ensures callbacks are set before connection to prevent race conditions
class EnhancedSocketService {
  static WebSocketChannel? _channel;
  static bool _isConnecting = false;
  static bool _shouldReconnect = true;
  static Timer? _reconnectTimer;
  static int _connectionAttempts = 0;
  static const int _maxConnectionAttempts = 5;
  static Completer<bool>? _pingCompleter;

  // Callback storage - set before connection
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
  static Function(Map<String, dynamic>)? _onProfilePictureUpdated;
  static Function(Map<String, dynamic>)? _onProfileUpdated;

  /// 🏛️ Global active chat screen reference for direct message handling
  static ChatMessageScreenHandler? _activeChatScreen;

  /// 🏛️ Register active chat screen for direct message handling
  static void registerChatScreen(ChatMessageScreenHandler handler) {
    _activeChatScreen = handler;
    print('🏛️ Enhanced Socket: Chat screen registered for direct message handling');
  }

  /// 🏛️ Unregister chat screen
  static void unregisterChatScreen() {
    _activeChatScreen = null;
    print('🏛️ Enhanced Socket: Chat screen unregistered');
  }

  /// 🏛️ Notify active chat screen directly when callback is null
  static void _notifyActiveChatScreen(Map<String, dynamic> messageData) {
    if (_activeChatScreen != null) {
      print('🏛️ Enhanced Socket: Notifying active chat screen directly');
      _activeChatScreen!.handleNewMessage(messageData);
    } else {
      print('🏛️ Enhanced Socket: No active chat screen to notify');
    }
  }

  /// 🏛️ Set only the phone validation result callback without resetting others
  static void setPhoneValidationResultCallback(Function(Map<String, dynamic>)? callback) {
    _onPhoneValidationResult = callback;
  }

  /// 🏛️ Set only the profile picture updated callback without resetting others
  static void setProfilePictureUpdatedCallback(Function(Map<String, dynamic>)? callback) {
    _onProfilePictureUpdated = callback;
  }

  /// 🏛️ Set only the profile updated callback without resetting others
  static void setProfileUpdatedCallback(Function(Map<String, dynamic>)? callback) {
    _onProfileUpdated = callback;
  }

  /// 🏛️ Set callbacks BEFORE connecting (prevents race conditions)
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
    Function(Map<String, dynamic>)? onProfilePictureUpdated,
  }) {
    print('🏛️ Enhanced Socket: Setting callbacks before connection...');
    
    // Store callbacks
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
    _onProfilePictureUpdated = onProfilePictureUpdated;
    
    print('🏛️ Enhanced Socket: Callbacks set successfully');
    print('🏛️ Enhanced Socket: onNewMessage is ${_onNewMessage != null ? "NOT NULL" : "NULL"}');
  }

  /// 🏛️ Connect to WebSocket (callbacks must be set first)
  static Future<void> connect({int maxRetries = 3, bool closeExisting = false, String? source}) async {
    // Verify callbacks are set
    if (_onNewMessage == null) {
      print('🏛️ Enhanced Socket: WARNING - Connecting without onNewMessage callback!');
    }

    final connectionSource = source ?? 'Unknown';
    print('🏛️ Enhanced Socket: Connection request from: $connectionSource');
    
    // Close existing connection if requested
    if (closeExisting && _channel != null) {
      print('🏛️ Enhanced Socket: Closing existing connection from: $connectionSource');
      await disconnect();
      _shouldReconnect = true;
    }
    
    // Prevent multiple connections
    if (_isConnecting || (_channel != null && isConnected())) {
      print('🏛️ Enhanced Socket: Already connected or connecting (request from: $connectionSource)');
      return;
    }

    _isConnecting = true;
    
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null || token.isEmpty) {
        print('🏛️ Enhanced Socket: No token found');
        _isConnecting = false;
        await _handleConnectionError('No authentication token available');
        return;
      }

      final wsUrl = '${StarlightConstants.chatSocketUrl}/$token';
      print('🏛️ Enhanced Socket: Connecting to $wsUrl from $connectionSource (attempt ${_connectionAttempts + 1})');
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready.timeout(const Duration(seconds: 10));

      print('🏛️ Enhanced Socket: Connected successfully from: $connectionSource');

      print('🏛️ Enhanced Socket: Authenticated via token in URL');

      // Listen for messages with enhanced error handling
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            _handleMessage(data);
            _connectionAttempts = 0; // Reset attempts on successful connection
          } catch (e) {
            print('🏛️ Enhanced Socket: Error parsing message - $e');
            _handleMessageError('Invalid message format', e);
          }
        },
        onError: (error) {
          print('🏛️ Enhanced Socket Error: $error');
          _isConnecting = false;
          _handleConnectionError(error.toString(), maxRetries);
        },
        onDone: () {
          print('🏛️ Enhanced Socket Disconnected');
          _isConnecting = false;
          _channel = null;
          if (_shouldReconnect) {
            _scheduleReconnect(maxRetries);
          }
        },
      );

      _isConnecting = false;
      print('🏛️ Enhanced Socket Connected successfully');
      _onConnectionStateChanged?.call({'connected': true, 'timestamp': DateTime.now().toIso8601String()});
      
    } catch (e) {
      print('🏛️ Enhanced Socket Connection Failed: $e');
      _isConnecting = false;
      await _handleConnectionError(e.toString(), maxRetries);
    }
  }

  /// 🏛️ Handle incoming socket messages
  static void _handleMessage(Map<String, dynamic> data) {
    final event = data['event'] as String?;
    final action = data['action'] as String?;
    final messageData = data['data'] as Map<String, dynamic>? ?? {};

    // Handle ping/pong for connection health check
    if (action == 'pong') {
      _handlePong(data);
      return;
    }

    SocketEventBus.instance.publish(event ?? action ?? 'unknown', messageData);

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
      case 'connection_created':
        _onConnectionCreated?.call(messageData);
        break;
      case 'connection_error':
        _onConnectionError?.call(messageData);
        break;
      case 'new_message':
        if (_onNewMessage != null) {
          _onNewMessage!(messageData);
        }
        break;
      case 'message_error':
        _onMessageError?.call(messageData);
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
      case 'profile_picture_updated':
        _onProfilePictureUpdated?.call(messageData);
        break;
      case 'user_profile_result':
        _onProfileUpdated?.call(messageData);
        break;
    }
  }

  /// 🏛️ Close existing socket connection
  static Future<void> disconnect() async {
    try {
      _shouldReconnect = false;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      
      if (_channel != null) {
        print('🏛️ Enhanced Socket: Closing existing connection');
        await _channel!.sink.close();
        _channel = null;
      }
      
      _isConnecting = false;
      print('🏛️ Enhanced Socket: Disconnected successfully');
    } catch (e) {
      print('🏛️ Enhanced Socket: Error disconnecting - $e');
    }
  }

  /// 🏛️ Check if socket is connected
  static bool isConnected() {
    return _channel != null && _channel?.closeCode == null;
  }

  /// 🏛️ Send ping to server to verify connection is alive
  static Future<bool> pingServer({Duration timeout = const Duration(seconds: 5)}) async {
    if (!isConnected()) {
      print('🏛️ Enhanced Socket: Ping failed - not connected');
      return false;
    }

    try {
      _pingCompleter = Completer<bool>();
      
      // Send ping message
      _channel!.sink.add(jsonEncode({'action': 'ping', 'timestamp': DateTime.now().toIso8601String()}));
      print('🏛️ Enhanced Socket: Ping sent');

      // Wait for pong response or timeout
      final result = await _pingCompleter!.future.timeout(timeout);
      _pingCompleter = null;
      
      print('🏛️ Enhanced Socket: Ping result: $result');
      return result;
    } catch (e) {
      print('🏛️ Enhanced Socket: Ping timeout or error - $e');
      _pingCompleter = null;
      return false;
    }
  }

  /// 🏛️ Handle pong response from server
  static void _handlePong(Map<String, dynamic> data) {
    if (_pingCompleter != null && !_pingCompleter!.isCompleted) {
      _pingCompleter!.complete(true);
      print('🏛️ Enhanced Socket: Pong received');
    }
  }

  /// 🏛️ Get the current socket instance
  static WebSocketChannel? get socket => _channel;

  /// 🏛️ Send message via WebSocket (recipient-based by phone number)
  static String sendMessageToRecipient(String recipientPhone, String content, {String messageType = "text", String clientUuid = '', String mediaUrl = '', String mediaBlurhash = ''}) {
    if (!isConnected()) {
      print('🏛️ Enhanced Socket: Not connected, cannot send message');
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
        "client_uuid": clientUuid,
        "media_url": mediaUrl,
        "media_blurhash": mediaBlurhash,
        "timestamp": DateTime.now().toIso8601String()
      }
    };
    _channel?.sink.add(jsonEncode(message));
    print('🏛️ Enhanced Socket: Sending $messageType message $messageId to $recipientPhone (uuid: $clientUuid)');

    return messageId;
  }

  /// 🏛️ Send message via WebSocket (recipient-based by user ID - legacy)
  static String sendMessageToRecipientById(int recipientId, String content, {String messageType = "text"}) {
    if (!isConnected()) {
      print('🏛️ Enhanced Socket: Not connected, cannot send message');
      return '';
    }

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();

    final message = <String, dynamic>{
      "action": "send_message",
      "message_id": messageId,
      "data": <String, dynamic>{
        "recipient_id": recipientId,
        "content": content,
        "message_type": messageType,
        "timestamp": DateTime.now().toIso8601String()
      }
    };
    _channel?.sink.add(jsonEncode(message));
    print('🏛️ Enhanced Socket: Sending message $messageId to recipient ID $recipientId (legacy)');

    return messageId;
  }

  /// 🏛️ Send message via WebSocket (legacy chat-based)
  static String sendMessage(int chatId, String content, {String messageType = "text"}) {
    if (!isConnected()) {
      print('🏛️ Enhanced Socket: Not connected, cannot send message');
      return '';
    }
    
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    
    final message = <String, dynamic>{
      "action": "send_message",
      "message_id": messageId,
      "data": <String, dynamic>{
        "chat_id": chatId,
        "content": content,
        "message_type": messageType,
        "timestamp": DateTime.now().toIso8601String()
      }
    };
    _channel?.sink.add(jsonEncode(message));
    print('🏛️ Enhanced Socket: Sending message $messageId to chat $chatId');
    
    return messageId;
  }

  /// 🏛️ Send raw JSON message via WebSocket
  static void sendRawMessage(String jsonMessage) {
    if (!isConnected()) {
      print('🏛️ Enhanced Socket: Not connected, cannot send raw message');
      return;
    }
    _channel?.sink.add(jsonMessage);
  }

  /// 🏛️ Search user by phone number
  static void searchPhone(String phoneNumber) {
    final message = {
      "action": "search_phone",
      "data": {"phone": phoneNumber}
    };
    _channel?.sink.add(jsonEncode(message));
    print('🏛️ Enhanced Socket: Searching for phone: $phoneNumber');
  }

  /// 🏛️ Validate phone number via WebSocket
  static void validatePhone(String phoneNumber) {
    final message = {
      "action": "validate_phone",
      "data": {"phone": phoneNumber}
    };
    _channel?.sink.add(jsonEncode(message));
    print('🏛️ Enhanced Socket: Validating phone: $phoneNumber');
  }

  /// 🏛️ Add user connection via WebSocket
  static String addUserConnection(String phoneNumber) {
    final connectionId = DateTime.now().millisecondsSinceEpoch.toString();
    final message = {
      "action": "add_user_connection",
      "connection_id": connectionId,
      "data": {
        "phone": phoneNumber,
        "timestamp": DateTime.now().toIso8601String()
      }
    };
    _channel?.sink.add(jsonEncode(message));
    print('🏛️ Enhanced Socket: Adding user connection for phone: $phoneNumber');
    return connectionId;
  }

  /// 🏛️ Request chat list update via WebSocket
  static void requestChatListUpdate() {
    final message = {
      "action": "update_chat_list",
      "data": {}
    };
    _channel?.sink.add(jsonEncode(message));
    print('🏛️ Enhanced Socket: Requesting chat list update');
  }

  /// 🏛️ Handle connection errors
  static Future<void> _handleConnectionError(String error, [int maxRetries = 3]) async {
    print('🏛️ Enhanced Socket: Connection error - $error');
    
    _onConnectionStateChanged?.call({
      'connected': false, 
      'error': error, 
      'attempts': _connectionAttempts,
      'timestamp': DateTime.now().toIso8601String()
    });
    
    if (_shouldReconnect && _connectionAttempts < _maxConnectionAttempts) {
      _scheduleReconnect(maxRetries);
    } else {
      print('🏛️ Enhanced Socket: Connection failed permanently');
      _shouldReconnect = false;
    }
  }

  /// 🏛️ Handle message errors
  static void _handleMessageError(String error, dynamic originalError) {
    print('🏛️ Enhanced Socket: Message error - $error');
    
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
      print('🏛️ Enhanced Socket: Max connection attempts reached, stopping reconnection');
      _shouldReconnect = false;
      _onConnectionStateChanged?.call({'connected': false, 'error': 'Max attempts reached', 'timestamp': DateTime.now().toIso8601String()});
      return;
    }
    
    _reconnectTimer?.cancel();
    
    // Exponential backoff: 5s, 10s, 20s, 40s, 80s
    final delay = Duration(seconds: 5 * (1 << (_connectionAttempts - 1)));
    print('🏛️ Enhanced Socket: Scheduling reconnect in ${delay.inSeconds}s (attempt $_connectionAttempts/$_maxConnectionAttempts)');
    
    _reconnectTimer = Timer(delay, () {
      if (_shouldReconnect && !isConnected()) {
        print('🏛️ Enhanced Socket: Attempting to reconnect...');
        connect(maxRetries: maxRetries);
      }
    });
  }

  /// 🏛️ Get current user data from socket connection
  static Map<String, dynamic>? getCurrentUserData() {
    return null; // Implementation depends on app state management
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
    _onProfilePictureUpdated = null;
  }
}
