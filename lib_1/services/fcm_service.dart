import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../core/starlight_http.dart';
import '../core/storage.dart';
import '../core/constants.dart';
import '../core/firebase_options.dart';
import '../services/notification_service.dart';
import '../chat_system/services/fcm_chat_saver.dart';
import '../chat_system/services/fcm_call_saver.dart';
import '../screens/social/chat_screen.dart';
import '../chat_system/services/call_signaling_service.dart';
import '../chat_system/services/call_kit_service.dart';
import '../chat_system/services/chat_local_notification_service.dart';
import '../screens/social/chat_screen.dart';
import '../library_directory/screens/library_directory_screen.dart';
import '../main.dart' show navigatorKey;

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  String? _fcmToken;
  String? _hardwareId;
  BuildContext? _context;
  bool _isTokenRegistered = false;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _backgroundMessageSubscription;

  // Initialize FCM service
  Future<void> initialize(BuildContext context) async {
    try {
      print('🏛️ FCM Service: Initializing...');
      
      // Store context for notification dialogs
      _context = context;
      
      // Request permission
      await _requestPermission();
      
      // Get hardware ID
      await _getHardwareId(context);
      
      // Get FCM token
      await _getFCMToken();
      
      // Setup message handlers
      await _setupMessageHandlers(context);
      
      // Register token with server
      await _registerTokenWithServer();
      
      print('🏛️ FCM Service: Initialized successfully');
      
    } catch (e) {
      print('🏛️ FCM Service: Initialization failed - $e');
    }
  }

  // Request notification permissions
  Future<void> _requestPermission() async {
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('🏛️ FCM Service: Permission granted');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('🏛️ FCM Service: Provisional permission granted');
      } else {
        print('🏛️ FCM Service: Permission denied');
      }
    } catch (e) {
      print('🏛️ FCM Service: Error requesting permission - $e');
    }
  }

  // Get device hardware ID
  Future<void> _getHardwareId(BuildContext context) async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      
      if (defaultTargetPlatform == TargetPlatform.android) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        _hardwareId = androidInfo.id; // Android ID
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        _hardwareId = iosInfo.identifierForVendor; // iOS identifier
      } else {
        // Fallback for web or other platforms
        _hardwareId = 'web_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      print('🏛️ FCM Service: Hardware ID: $_hardwareId');
      
    } catch (e) {
      print('🏛️ FCM Service: Error getting hardware ID - $e');
      _hardwareId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // Get FCM token
  Future<void> _getFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      _fcmToken = token;
      
      print('🏛️ FCM Service: FCM Token: $_fcmToken');
      
      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((token) {
        _fcmToken = token;
        print('🏛️ FCM Service: Token refreshed: $_fcmToken');
        _isTokenRegistered = false; // Reset flag to allow re-registration
        _registerTokenWithServer();
      });
      
    } catch (e) {
      print('🏛️ FCM Service: Error getting FCM token - $e');
    }
  }

  // Setup message handlers
  Future<void> _setupMessageHandlers(BuildContext context) async {
    try {
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle background messages (when app is in background)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      
      // Handle background messages (when app is terminated)
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
      
      // Setup background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      print('🏛️ FCM Service: Message handlers setup complete');
      
    } catch (e) {
      print('🏛️ FCM Service: Error setting up message handlers - $e');
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    try {
      print('🏛️ FCM Service: Received foreground message');
      print('🏛️ FCM Service: Message data: ${message.data}');
      
      final data = message.data;
      final type = data['type'] ?? '';
      
      if (type == 'chat_message') {
        _handleChatMessage(data, isForeground: true);
        FcmChatSaver.saveChatMessage(data);
      } else if (type == 'incoming_call') {
        _handleIncomingCall(data, isForeground: true);
      } else if (type == 'missed_call') {
        FcmCallSaver.saveMissedCall(data);
        // Show local notification for missed call with avatar
        ChatLocalNotificationService.instance.showMissedCall(
          callerName: data['callerName'] ?? data['caller_name'] ?? 'Someone',
          callerPhone: data['callerPhone'] ?? data['caller_phone'] ?? '',
          callId: data['callId'] ?? data['call_id'] ?? '',
          callType: data['callType'] ?? data['call_type'] ?? 'voice',
          callerAvatar: data['callerAvatar'] ?? data['caller_avatar'] ?? '',
        );
      } else if (type == 'new_library_book') {
        _handleNewLibraryBook(data);
      } else {
        _showNotificationDialog(
          title: message.notification?.title ?? 'Notification',
          body: message.notification?.body ?? '',
          data: data,
        );
      }
      
    } catch (e) {
      print('🏛️ FCM Service: Error handling foreground message - $e');
    }
  }

  // Handle message when app is opened from notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    try {
      print('🏛️ FCM Service: App opened from notification');
      print('🏛️ FCM Service: Message data: ${message.data}');
      
      final data = message.data;
      final type = data['type'] ?? '';
      
      if (type == 'chat_message') {
        _handleChatMessage(data, isForeground: false);
        FcmChatSaver.saveChatMessage(data);
      } else if (type == 'incoming_call') {
        _handleIncomingCall(data, isForeground: false);
      } else if (type == 'missed_call') {
        FcmCallSaver.saveMissedCall(data);
        ChatLocalNotificationService.instance.showMissedCall(
          callerName: data['callerName'] ?? data['caller_name'] ?? 'Someone',
          callerPhone: data['callerPhone'] ?? data['caller_phone'] ?? '',
          callId: data['callId'] ?? data['call_id'] ?? '',
          callType: data['callType'] ?? data['call_type'] ?? 'voice',
          callerAvatar: data['callerAvatar'] ?? data['caller_avatar'] ?? '',
        );
      } else if (type == 'new_library_book') {
        _handleNewLibraryBook(data);
      }
      
    } catch (e) {
      print('🏛️ FCM Service: Error handling opened app message - $e');
    }
  }

  // Handle chat message notifications
  void _handleChatMessage(Map<String, dynamic> data, {required bool isForeground}) {
    try {
      final senderId = data['senderId'] ?? data['sender_id'] ?? '';
      final senderPhone = data['senderPhone'] ?? data['sender_phone'] ?? '';
      final senderName = data['senderName'] ?? data['sender_name'] ?? 'Unknown';
      final senderAvatar = data['senderAvatar'] ?? data['sender_avatar'] ?? '';
      final messageContent = data['messageContent'] ?? data['message_content'] ?? '';
      final chatId = data['chatId'] ?? data['chat_id'] ?? '';
      final messageType = data['messageType'] ?? data['message_type'] ?? 'text';
      final mediaUrl = data['mediaUrl'] ?? data['media_url'] ?? '';
      final thumbnailUrl = data['thumbnailUrl'] ?? data['thumbnail_url'] ?? '';
      final fileName = data['file_name'] ?? data['fileName'] ?? '';
      
      print('🏛️ FCM Service: Chat message from $senderName: $messageContent');

      // Always show system notification
      ChatLocalNotificationService.instance.showChatMessage(
        senderName: senderName,
        messageContent: messageContent,
        senderPhone: senderPhone,
        messageType: messageType,
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl,
        fileName: fileName,
        senderAvatar: senderAvatar,
      );
      
      if (isForeground) {
        // Show in-app snackbar notification
        _showInAppNotification(
          senderName: senderName,
          messageContent: messageContent,
          senderPhone: senderPhone,
          senderId: senderId,
        );
      } else {
        _navigateToChat(
          senderName: senderName,
          senderPhone: senderPhone,
          peerUserId: senderId,
        );
      }
      
    } catch (e) {
      print('🏛️ FCM Service: Error handling chat message - $e');
    }
  }

  void _handleIncomingCall(Map<String, dynamic> data, {required bool isForeground}) {
    try {
      final callerName = data['callerName'] ?? data['caller_name'] ?? 'Unknown';
      final callerPhone = data['callerPhone'] ?? data['caller_phone'] ?? '';
      final callId = data['callId'] ?? data['call_id'] ?? '';
      final callType = data['callType'] ?? data['call_type'] ?? 'voice';
      final callerAvatar = data['callerAvatar'] ?? data['caller_avatar'] ?? '';

      ChatLocalNotificationService.instance.showIncomingCall(
        callerName: callerName,
        callerPhone: callerPhone,
        callId: callId,
        callType: callType,
        callerAvatar: callerAvatar,
      );

      CallSignalingService.instance.handleFcmIncomingCall(data);
      print('🏛️ FCM Service: Incoming call from $callerName');
    } catch (e) {
      print('🏛️ FCM Service: Error handling incoming call - $e');
    }
  }

  void _handleNewLibraryBook(Map<String, dynamic> data) {
    final channelId = data['channelId'] ?? data['channel_id'] ?? '';
    final bookId = data['bookId'] ?? data['book_id'] ?? '';
    final channelName = data['channelName'] ?? data['channel_name'] ?? 'Channel';
    final channelPic = data['channelPic'] ?? data['channel_pic'] ?? '';
    final bookTitle = data['bookTitle'] ?? data['book_title'] ?? 'New publication';

    print('🏛️ FCM Service: New library book from $channelName: $bookTitle');

    final context = navigatorKey.currentContext;
    if (context == null) return;

    final snackBar = SnackBar(
      content: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          _navigateToLibraryHome();
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: channelPic.isNotEmpty ? NetworkImage(
                channelPic.startsWith('http') ? channelPic : '${StarlightConstants.apiBaseUrl}$channelPic',
              ) : null,
              child: channelPic.isEmpty ? Text(
                channelName.isNotEmpty ? channelName[0].toUpperCase() : 'C',
                style: TextStyle(fontSize: 14, color: Colors.blue.shade800),
              ) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(channelName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    bookTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _navigateToLibraryHome() {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LibraryDirectoryScreen()),
    );
  }

  // Show notification dialog
  void _showNotificationDialog({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) {
    // This would show a general notification dialog
    print('🏛️ FCM Service: Showing notification dialog - $title: $body');
  }

  // Show in-app notification snackbar
  void _showInAppNotification({
    required String senderName,
    required String messageContent,
    required String senderPhone,
    required String senderId,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final snackBar = SnackBar(
      content: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          _navigateToChat(
            senderName: senderName,
            senderPhone: senderPhone,
            peerUserId: senderId,
          );
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 14, color: Colors.blue.shade800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(senderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    messageContent,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // Navigate to chat
  void _navigateToChat({
    required String senderName,
    String? senderPhone,
    String? peerUserId,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final phone = (senderPhone != null && senderPhone.isNotEmpty)
        ? senderPhone
        : (peerUserId ?? '');
    if (phone.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          friendId: peerUserId ?? '',
          friendName: senderName,
          friendRole: '',
          friendPhone: phone,
          fromInbox: true,
        ),
      ),
    );
  }

  // Register FCM token with server
  Future<void> _registerTokenWithServer() async {
    try {
      if (_fcmToken == null || _hardwareId == null) {
        print('🏛️ FCM Service: Cannot register token - missing FCM token or hardware ID');
        return;
      }
      
    // Always register with server regardless of cached token
    print('🏛️ FCM Service: Registering FCM token with backend...');

    final response = await StarlightHttp.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/fcm/register-token'),
        body: jsonEncode({
          'fcm_token': _fcmToken,
          'hardware_id': _hardwareId,
        }),
      );
      
      if (response.statusCode == 200) {
        print('🏛️ FCM Service: Token registered successfully');
        final body = jsonDecode(response.body);
        // Save user_id returned by server to preferences
        final serverUserId = body['user_id'] as String?;
        if (serverUserId != null && serverUserId.isNotEmpty) {
          await StarlightStorage.setUserId(serverUserId);
          print('🏛️ FCM Service: Server user_id saved to preferences: $serverUserId');
        }
        // Store the token locally to track registration
        await StarlightStorage.saveFcmToken(_fcmToken!);
      } else {
        print('🏛️ FCM Service: Failed to register token - ${response.statusCode}');
        print('🏛️ FCM Service: Response: ${response.body}');
      }
      
    } catch (e) {
      print('🏛️ FCM Service: Error registering token with server - $e');
    }
  }

  /// Public wrapper so external screens can trigger FCM registration.
  Future<void> registerTokenWithServer() async {
    if (_hardwareId == null && _context != null) {
      await _getHardwareId(_context!);
    }
    if (_fcmToken == null) {
      await _getFCMToken();
    }
    await _registerTokenWithServer();
  }

  // Get current FCM token
  String? get currentToken => _fcmToken;

  // Get current hardware ID
  String? get currentHardwareId => _hardwareId;

  // Dispose FCM service
  void dispose() {
    _messageSubscription?.cancel();
    _backgroundMessageSubscription?.cancel();
    _context = null;
    _isTokenRegistered = false; // Reset flag for next initialization
    print('🏛️ FCM Service: Disposed');
  }
}

// Background message handler (top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🏛️ FCM Service: Handling background message');
  print('🏛️ FCM Service: Background message data: ${message.data}');
  
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    print('🏛️ FCM Service: Background init error - $e');
  }
  
  final data = message.data;
  final type = data['type'] ?? '';
  
  if (type == 'chat_message') {
    final senderName = data['senderName'] ?? data['sender_name'] ?? 'Unknown';
    final senderAvatar = data['senderAvatar'] ?? data['sender_avatar'] ?? '';
    final messageContent = data['messageContent'] ?? data['message_content'] ?? '';
    final senderPhone = data['senderPhone'] ?? data['sender_phone'] ?? '';
    final messageType = data['messageType'] ?? data['message_type'] ?? 'text';
    final mediaUrl = data['mediaUrl'] ?? data['media_url'] ?? '';
    final thumbnailUrl = data['thumbnailUrl'] ?? data['thumbnail_url'] ?? '';
    final fileName = data['file_name'] ?? data['fileName'] ?? '';
    
    print('🏛️ FCM Service: Background chat message from $senderName: $messageContent');
    
    await FcmChatSaver.saveChatMessage(data);
    await ChatLocalNotificationService.instance.showChatMessage(
      senderName: senderName,
      messageContent: messageContent,
      senderPhone: senderPhone,
      messageType: messageType,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      fileName: fileName,
      senderAvatar: senderAvatar,
    );
    print('🏛️ FCM Service: Chat message saved to local DB from background');
  } else if (type == 'incoming_call') {
    // Save initial call record even in background
    await FcmCallSaver.saveCallLog({
      'callId': data['callId'] ?? data['call_id'] ?? '',
      'peerUserId': data['callerId'] ?? data['caller_id'] ?? '',
      'peerName': data['callerName'] ?? data['caller_name'] ?? 'Unknown',
      'callType': data['callType'] ?? data['call_type'] ?? 'voice',
      'callDirection': 'incoming',
      'callState': 'ringing',
      'isSelf': false,
    });

    // Set up call session (synchronous part)
    CallSignalingService.instance.handleFcmIncomingCall(data);

    // Show CallKit incoming call with proper await for error handling
    try {
      await CallKitService.instance.initialize();
      final callerAvatar = data['callerAvatar'] ?? data['caller_avatar'] ?? '';
      await CallKitService.instance.showIncomingCall(
        callId: data['callId'] ?? data['call_id'] ?? '',
        callerName: data['callerName'] ?? data['caller_name'] ?? 'Unknown',
        callerHandle: data['callerPhone'] ?? data['caller_phone'] ?? '',
        callType: data['callType'] ?? data['call_type'] ?? 'voice',
        extra: {
          'peerUserId': data['callerId'] ?? data['caller_id'] ?? '',
          'peerName': data['callerName'] ?? data['caller_name'] ?? '',
          'peerPhone': data['callerPhone'] ?? data['caller_phone'] ?? '',
          'peerHandle': data['callerPhone'] ?? data['caller_phone'] ?? '',
          'callerAvatar': callerAvatar,
        },
      );
      print('🏛️ FCM Service: CallKit incoming call shown from background');
    } catch (e) {
      print('🏛️ FCM Service: CallKit background error - $e');
      // Fallback to local notification
      try {
        final callerAvatar = data['callerAvatar'] ?? data['caller_avatar'] ?? '';
        await ChatLocalNotificationService.instance.initialize();
        await ChatLocalNotificationService.instance.showIncomingCall(
          callerName: data['callerName'] ?? data['caller_name'] ?? 'Unknown',
          callerPhone: data['callerPhone'] ?? data['caller_phone'] ?? '',
          callId: data['callId'] ?? data['call_id'] ?? '',
          callType: data['callType'] ?? data['call_type'] ?? 'voice',
          callerAvatar: callerAvatar,
        );
        print('🏛️ FCM Service: Fallback notification shown from background');
      } catch (e2) {
        print('🏛️ FCM Service: Fallback notification error - $e2');
      }
    }
  } else if (type == 'missed_call') {
    await FcmCallSaver.saveMissedCall(data);
    await ChatLocalNotificationService.instance.showMissedCall(
      callerName: data['callerName'] ?? data['caller_name'] ?? 'Someone',
      callerPhone: data['callerPhone'] ?? data['caller_phone'] ?? '',
      callId: data['callId'] ?? data['call_id'] ?? '',
      callType: data['callType'] ?? data['call_type'] ?? 'voice',
      callerAvatar: data['callerAvatar'] ?? data['caller_avatar'] ?? '',
    );
    print('🏛️ FCM Service: Missed call saved from background');
  } else if (type == 'new_library_book') {
    final channelName = data['channelName'] ?? data['channel_name'] ?? 'Channel';
    final bookTitle = data['bookTitle'] ?? message.notification?.body ?? 'New publication';
    final channelPic = data['channelPic'] ?? data['channel_pic'] ?? '';
    await ChatLocalNotificationService.instance.showBasicNotification(
      title: channelName,
      body: bookTitle,
      payload: jsonEncode(data),
    );
    print('🏛️ FCM Service: Library book notification saved from background');
  } else {
    print('🏛️ FCM Service: Background message of type: $type');
  }
}
