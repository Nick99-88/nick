import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/storage.dart';
import '../../core/constants.dart';

/// 🏛️ Socket Event Callbacks
class SocketEventCallbacks {
  final Function(Map<String, dynamic>)? onUserConnected;
  final Function(Map<String, dynamic>)? onExploreResults;
  final Function(Map<String, dynamic>)? onStatusSynced;
  final Function(Map<String, dynamic>)? onPhoneSearchResult;
  final Function(Map<String, dynamic>)? onPhoneValidationResult;
  final Function(Map<String, dynamic>)? onNewMessage;
  final Function(Map<String, dynamic>)? onMessageError;
  final Function(Map<String, dynamic>)? onChatListUpdated;
  final Function(Map<String, dynamic>)? onMessageDelivered;
  final Function(Map<String, dynamic>)? onMessageStatus;
  final Function(Map<String, dynamic>)? onConnectionStateChanged;

  const SocketEventCallbacks({
    this.onUserConnected,
    this.onExploreResults,
    this.onStatusSynced,
    this.onPhoneSearchResult,
    this.onPhoneValidationResult,
    this.onNewMessage,
    this.onMessageError,
    this.onChatListUpdated,
    this.onMessageDelivered,
    this.onMessageStatus,
    this.onConnectionStateChanged,
  });
}

/// 🏛️ Instance-Based Socket Service
/// Refactored from static to instance-based for better testability and maintainability
class SocketServiceInstance {
  WebSocketChannel? _channel;
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  Timer? _reconnectTimer;
  int _connectionAttempts = 0;
  static const int _maxConnectionAttempts = 5;
  
  SocketEventCallbacks? _callbacks;

  // Singleton pattern for backward compatibility
  static final SocketServiceInstance _instance = SocketServiceInstance._internal();
  factory SocketServiceInstance() => _instance;
  SocketServiceInstance._internal();

  /// 🏛️ Set callbacks for socket events
  void setCallbacks(SocketEventCallbacks callbacks) {
    _callbacks = callbacks;
  }

  /// 🏛️ Connect to WebSocket with user token
  Future<void> connect({int maxRetries = 3}) async {
    // Prevent multiple connections
    if (_isConnecting || (_channel != null && isConnected())) {
      print('🏛️ Socket: Already connected or connecting');
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
      print('🏛️ Socket: Connecting to $wsUrl (attempt ${_connectionAttempts + 1})');
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready.timeout(const Duration(seconds: 10));

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
      _callbacks?.onConnectionStateChanged?.call({'connected': true, 'timestamp': DateTime.now().toIso8601String()});
      
    } catch (e) {
      print('🏛️ Socket Connection Failed: $e');
      _isConnecting = false;
      await _handleConnectionError(e.toString(), maxRetries);
    }
  }

  /// 🏛️ Schedule reconnection attempt
  void _scheduleReconnect([int maxRetries = 3]) {
    if (!_shouldReconnect) return;
    
    _connectionAttempts++;
    
    if (_connectionAttempts >= _maxConnectionAttempts) {
      print('🏛️ Socket: Max connection attempts reached, stopping reconnection');
      _shouldReconnect = false;
      _callbacks?.onConnectionStateChanged?.call({'connected': false, 'error': 'Max attempts reached', 'timestamp': DateTime.now().toIso8601String()});
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
  Future<void> _handleConnectionError(String error, [int maxRetries = 3]) async {
    print('🏛️ Socket: Connection error - $error');
    
    // Notify listeners of connection error
    _callbacks?.onConnectionStateChanged?.call({
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
  void _handleMessageError(String error, dynamic originalError) {
    print('🏛️ Socket: Message error - $error');
    
    // Notify listeners of message error
    _callbacks?.onMessageError?.call({
      'error': error,
      'original_error': originalError.toString(),
      'timestamp': DateTime.now().toIso8601String()
    });
  }

  /// 🏛️ Disconnect from WebSocket
  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close();
    _channel = null;
    _isConnecting = false;
    print('🏛️ Socket Disconnected manually');
  }

  /// 🏛️ Check if socket is connected
  bool isConnected() {
    return _channel != null;
  }

  /// 🏛️ Send explore search request
  void searchExplore(String query) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'action': 'explore_search',
        'data': {'query': query}
      }));
    }
  }

  /// 🏛️ Send location update
  void updateLocation(String location) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode({
        'action': 'update_location',
        'data': {'location': location}
      }));
    }
  }

  /// 🏛️ Search user by phone number
  void searchPhone(String phoneNumber) {
    final message = {
      "action": "search_phone",
      "data": {"phone": phoneNumber}
    };
    _channel?.sink.add(jsonEncode(message));
    print('🏛️ Socket: Searching for phone: $phoneNumber');
  }

  /// 🏛️ Send message via WebSocket
  String sendMessage(int chatId, String content, {String messageType = "text"}) {
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
  void validatePhoneRealtime(String phoneNumber) {
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
  void _handleMessage(Map<String, dynamic> data) {
    print('🏛️ Socket: Received message: $data');
    final event = data['event'] as String?;
    final messageData = data['data'] as Map<String, dynamic>? ?? {};

    print('🏛️ Socket: Event type: $event');
    print('🏛️ Socket: Message data: $messageData');

    switch (event) {
      case 'connected':
        print('🏛️ Socket: Connected event received');
        _callbacks?.onUserConnected?.call(messageData);
        break;
      case 'explore_results':
        print('🏛️ Socket: Explore results received');
        _callbacks?.onExploreResults?.call(messageData);
        break;
      case 'status_synced':
        print('🏛️ Socket: Status synced received');
        _callbacks?.onStatusSynced?.call(messageData);
        break;
      case 'phone_search_result':
        print('🏛️ Socket: Phone search result received');
        _callbacks?.onPhoneSearchResult?.call(messageData);
        break;
      case 'phone_validation_result':
        print('🏛️ Socket: Phone validation result received');
        _callbacks?.onPhoneValidationResult?.call(messageData);
        break;
      case 'new_message':
        print('🏛️ Socket: New message received');
        _callbacks?.onNewMessage?.call(messageData);
        break;
      case 'message_error':
        print('🏛️ Socket: Message error received');
        _callbacks?.onMessageError?.call(messageData);
        break;
      case 'message_delivered':
        print('🏛️ Socket: Message delivered received');
        _callbacks?.onMessageDelivered?.call(messageData);
        break;
      case 'message_status':
        print('🏛️ Socket: Message status received');
        _callbacks?.onMessageStatus?.call(messageData);
        break;
      default:
        print('🏛️ Socket: Unknown event type: $event');
        break;
    }
  }

  /// 🏛️ Request chat list update via WebSocket
  void requestChatListUpdate() {
    final message = {
      "action": "update_chat_list",
      "data": {}
    };
    _channel?.sink.add(jsonEncode(message));
    print('🏛️ Socket: Requesting chat list update');
  }

  /// 🏛️ Get current user data from socket connection
  Map<String, dynamic>? getCurrentUserData() {
    // This would be stored when socket connects
    return null; // Implementation depends on your app state management
  }

  /// 🏛️ Get connection status
  Map<String, dynamic> getConnectionStatus() {
    return {
      'connected': isConnected(),
      'connecting': _isConnecting,
      'should_reconnect': _shouldReconnect,
      'connection_attempts': _connectionAttempts,
      'max_attempts': _maxConnectionAttempts,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// 🏛️ Reset connection attempts
  void resetConnectionAttempts() {
    _connectionAttempts = 0;
    print('🏛️ Socket: Connection attempts reset');
  }
}

/// 🏛️ Static wrapper for backward compatibility
/// This maintains the existing static API while using the instance-based implementation
class SocketService {
  static final SocketServiceInstance _instance = SocketServiceInstance();

  /// 🏛️ Connect to WebSocket
  static Future<void> connect({int maxRetries = 3}) => _instance.connect(maxRetries: maxRetries);

  /// 🏛️ Disconnect from WebSocket
  static void disconnect() => _instance.disconnect();

  /// 🏛️ Check if socket is connected
  static bool isConnected() => _instance.isConnected();

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
  }) {
    _instance.setCallbacks(SocketEventCallbacks(
      onUserConnected: onUserConnected,
      onExploreResults: onExploreResults,
      onStatusSynced: onStatusSynced,
      onPhoneSearchResult: onPhoneSearchResult,
      onPhoneValidationResult: onPhoneValidationResult,
      onNewMessage: onNewMessage,
      onMessageError: onMessageError,
      onChatListUpdated: onChatListUpdated,
      onMessageDelivered: onMessageDelivered,
      onMessageStatus: onMessageStatus,
      onConnectionStateChanged: onConnectionStateChanged,
    ));
  }

  /// 🏛️ Send explore search request
  static void searchExplore(String query) => _instance.searchExplore(query);

  /// 🏛️ Send location update
  static void updateLocation(String location) => _instance.updateLocation(location);

  /// 🏛️ Search user by phone number
  static void searchPhone(String phoneNumber) => _instance.searchPhone(phoneNumber);

  /// 🏛️ Send message via WebSocket
  static String sendMessage(int chatId, String content, {String messageType = "text"}) => 
      _instance.sendMessage(chatId, content, messageType: messageType);

  /// 🏛️ Real-time phone number validation via WebSocket
  static void validatePhoneRealtime(String phoneNumber) => _instance.validatePhoneRealtime(phoneNumber);

  /// 🏛️ Request chat list update via WebSocket
  static void requestChatListUpdate() => _instance.requestChatListUpdate();

  /// 🏛️ Get current user data from socket connection
  static Map<String, dynamic>? getCurrentUserData() => _instance.getCurrentUserData();

  /// 🏛️ Get connection status
  static Map<String, dynamic> getConnectionStatus() => _instance.getConnectionStatus();

  /// 🏛️ Reset connection attempts
  static void resetConnectionAttempts() => _instance.resetConnectionAttempts();
}
