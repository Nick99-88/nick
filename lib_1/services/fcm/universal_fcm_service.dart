import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/socket_vault.dart';
import '../socket/socket_service.dart';
import '../chat/chat_service.dart';

/// 🏛️ Universal FCM Service
/// Handles Firebase Cloud Messaging for all user roles
class UniversalFcmService {
  static final UniversalFcmService _instance = UniversalFcmService._internal();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  
  // 🏛️ Stream Controllers
  static final StreamController<Map<String, dynamic>> _messageStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<String> _notificationStreamController = 
      StreamController<String>.broadcast();

  // 🏛️ Public Streams
  static Stream<Map<String, dynamic>> get messageStream => _messageStreamController.stream;
  static Stream<String> get notificationStream => _notificationStreamController.stream;

  UniversalFcmService._internal();

  factory UniversalFcmService() => _instance;

  // 🏛️ Initialize FCM Service
  Future<void> initialize() async {
    try {
      // Request notification permissions
      await _requestPermissions();
      
      // Get FCM token
      await _getFcmToken();
      
      // Set up message handlers
      await _setupMessageHandlers();
      
      // Sync token with server
      await _syncFcmTokenWithServer();
      
      debugPrint('🏛️ Universal FCM Service: Initialized successfully');
    } catch (e) {
      debugPrint('🏛️ Universal FCM Service: Initialization failed - $e');
      rethrow;
    }
  }

  // 🏛️ Request Notification Permissions
  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('🏛️ FCM: Permission granted');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('🏛️ FCM: Provisional permission granted');
    } else {
      debugPrint('🏛️ FCM: Permission denied');
    }
  }

  // 🏛️ Get FCM Token
  Future<String?> _getFcmToken() async {
    try {
      String? token = await _fcm.getToken();
      
      if (token != null) {
        debugPrint('🏛️ FCM Token: $token');
        
        // Save token locally
        await StarlightStorage.saveFcmToken(token);
        
        // Listen for token refresh
        _fcm.onTokenRefresh.listen((newToken) {
          debugPrint('🏛️ FCM Token refreshed: $newToken');
          _syncFcmTokenWithServer();
        });
        
        return token;
      }
      return null;
    } catch (e) {
      debugPrint('🏛️ FCM: Failed to get token - $e');
      return null;
    }
  }

  // 🏛️ Setup Message Handlers
  Future<void> _setupMessageHandlers() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background messages
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    // Handle initial message (app opened from terminated state)
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
    
    // Handle background messages (for Android)
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
    
    debugPrint('🏛️ FCM: Message handlers setup complete');
  }

  // 🏛️ Handle Foreground Messages
  void _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('🏛️ FCM: Foreground message received');
    debugPrint('🏛️ FCM: Message data: ${message.data}');
    
    // Process message based on type
    await _processIncomingMessage(message.data);
    
    // Show notification if needed
    if (message.notification != null) {
      _notificationStreamController.add(
        message.notification?.title ?? 'New Message'
      );
    }
  }

  // 🏛️ Handle Message Opened App
  void _handleMessageOpenedApp(RemoteMessage message) async {
    debugPrint('🏛️ FCM: Message opened app');
    debugPrint('🏛️ FCM: Message data: ${message.data}');
    
    // Process message and connect socket
    await _processIncomingMessage(message.data, autoConnectSocket: true);
  }

  // 🏛️ Handle Background Messages (Android)
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('🏛️ FCM: Background message received');
    debugPrint('🏛️ FCM: Message data: ${message.data}');
    
    // Process message in background
    final service = UniversalFcmService();
    await service._processIncomingMessage(message.data, autoConnectSocket: true);
  }

  // 🏛️ Process Incoming Message
  Future<void> _processIncomingMessage(Map<String, dynamic> data, {bool autoConnectSocket = false}) async {
    try {
      final messageType = data['type'] ?? 'unknown';
      debugPrint('🏛️ FCM: Processing message type: $messageType');
      
      switch (messageType) {
        case 'chat_message':
          await _handleChatMessage(data, autoConnectSocket: autoConnectSocket);
          break;
        case 'chat_request':
          await _handleChatRequest(data);
          break;
        case 'system_notification':
          await _handleSystemNotification(data);
          break;
        default:
          debugPrint('🏛️ FCM: Unknown message type: $messageType');
      }
      
      // Emit to message stream
      _messageStreamController.add(data);
      
    } catch (e) {
      debugPrint('🏛️ FCM: Error processing message - $e');
    }
  }

  // 🏛️ Handle Chat Message
  Future<void> _handleChatMessage(Map<String, dynamic> data, {bool autoConnectSocket = false}) async {
    try {
      debugPrint('🏛️ FCM: Handling chat message');
      
      // Auto-connect socket if requested
      if (autoConnectSocket) {
        await _autoConnectSocket();
      }
      
      // Store message in local database
      await _storeMessageLocally(data);
      
      // Show notification
      final senderName = data['sender_name'] ?? 'Unknown';
      final messageContent = data['content'] ?? 'New message';
      _notificationStreamController.add('$senderName: $messageContent');
      
      debugPrint('🏛️ FCM: Chat message processed successfully');
      
    } catch (e) {
      debugPrint('🏛️ FCM: Error handling chat message - $e');
    }
  }

  // 🏛️ Handle Chat Request
  Future<void> _handleChatRequest(Map<String, dynamic> data) async {
    try {
      debugPrint('🏛️ FCM: Handling chat request');
      
      final requesterName = data['requester_name'] ?? 'Unknown';
      _notificationStreamController.add('Chat request from $requesterName');
      
      // You can add chat request handling logic here
      
    } catch (e) {
      debugPrint('🏛️ FCM: Error handling chat request - $e');
    }
  }

  // 🏛️ Handle System Notification
  Future<void> _handleSystemNotification(Map<String, dynamic> data) async {
    try {
      debugPrint('🏛️ FCM: Handling system notification');
      
      final title = data['title'] ?? 'Notification';
      final body = data['body'] ?? '';
      _notificationStreamController.add('$title: $body');
      
    } catch (e) {
      debugPrint('🏛️ FCM: Error handling system notification - $e');
    }
  }

  // 🏛️ Auto Connect Socket
  Future<void> _autoConnectSocket() async {
    try {
      debugPrint('🏛️ FCM: Auto-connecting socket');
      
      // Get user token
      final token = await StarlightStorage.getUserToken();
      if (token == null || token.isEmpty) {
        debugPrint('🏛️ FCM: No token available for socket connection');
        return;
      }
      
      // Connect socket
      if (!SocketService.isConnected()) {
        await SocketService.connect(source: 'UniversalFCMService');
        debugPrint('🏛️ FCM: Socket connected successfully');
      } else {
        debugPrint('🏛️ FCM: Socket already connected');
      }
      
    } catch (e) {
      debugPrint('🏛️ FCM: Error auto-connecting socket - $e');
    }
  }

  // 🏛️ Store Message Locally
  Future<void> _storeMessageLocally(Map<String, dynamic> data) async {
    try {
      debugPrint('🏛️ FCM: Storing message locally');
      
      // Convert FCM message data to privacy chat format
      final messageData = {
        'chat_id': data['chat_id'],
        'sender_id': data['sender_id'],
        'content': data['content'],
        'message_type': data['message_type'] ?? 'text',
        'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
        'relay_id': 'fcm_${DateTime.now().millisecondsSinceEpoch}',
      };
      
      // Backend-only approach - no local storage
      // In production, this would handle message via backend API
      
      // Emit to message stream for real-time updates
      _messageStreamController.add(data);
      
      debugPrint('🏛️ FCM: Message handling - backend only (no local storage)');
      
    } catch (e) {
      debugPrint('🏛️ FCM: Error storing message locally - $e');
      // Still emit to stream even if storage fails
      _messageStreamController.add(data);
    }
  }

  // 🏛️ Sync FCM Token with Server
  Future<void> _syncFcmTokenWithServer() async {
    try {
      String? currentFcmToken = await _fcm.getToken();
      if (currentFcmToken == null) return;

      String? cachedToken = await StarlightStorage.getLastFcmToken();
      if (currentFcmToken == cachedToken) return;

      final authToken = await StarlightStorage.getUserToken();
      if (authToken == null) return;

      final response = await http.patch(
        Uri.parse('${StarlightConstants.apiBaseUrl}/auth/update-fcm'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({"fcm_token": currentFcmToken}),
      );

      if (response.statusCode == 200) {
        await StarlightStorage.saveFcmToken(currentFcmToken);
        debugPrint("🏛️ FCM: Token synced with server");
      } else {
        debugPrint("🏛️ FCM: Token sync failed - ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("🏛️ FCM: Token sync error - $e");
    }
  }

  // 🏛️ Subscribe to Topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
      debugPrint('🏛️ FCM: Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('🏛️ FCM: Error subscribing to topic - $e');
    }
  }

  // 🏛️ Unsubscribe from Topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
      debugPrint('🏛️ FCM: Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('🏛️ FCM: Error unsubscribing from topic - $e');
    }
  }

  // 🏛️ Get Current Token
  Future<String?> getCurrentToken() async {
    return await _fcm.getToken();
  }

  // 🏛️ Delete Token
  Future<void> deleteToken() async {
    try {
      await _fcm.deleteToken();
      await StarlightStorage.saveFcmToken('');
      debugPrint('🏛️ FCM: Token deleted');
    } catch (e) {
      debugPrint('🏛️ FCM: Error deleting token - $e');
    }
  }

  // 🏛️ Dispose Service
  void dispose() {
    _messageStreamController.close();
    _notificationStreamController.close();
    debugPrint('🏛️ FCM: Service disposed');
  }
}

/// 🏛️ FCM Message Handler Mixin
/// Can be used in any widget to listen to FCM messages
mixin FcmMessageHandlerMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<String>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _setupFcmListeners();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _setupFcmListeners() {
    // Listen to messages
    _messageSubscription = UniversalFcmService.messageStream.listen((message) {
      onFcmMessageReceived(message);
    });

    // Listen to notifications
    _notificationSubscription = UniversalFcmService.notificationStream.listen((notification) {
      onFcmNotificationReceived(notification);
    });
  }

  // Override these methods in your widget
  void onFcmMessageReceived(Map<String, dynamic> message) {
    debugPrint('🏛️ FCM: Message received in widget: $message');
  }

  void onFcmNotificationReceived(String notification) {
    debugPrint('🏛️ FCM: Notification received in widget: $notification');
  }
}
