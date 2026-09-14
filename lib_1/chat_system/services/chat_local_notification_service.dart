import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../screens/unified_call_screen.dart';
import 'call_signaling_service.dart';

/// Local notifications for chat messages and incoming calls.
class ChatLocalNotificationService {
  static final ChatLocalNotificationService instance = ChatLocalNotificationService._();
  ChatLocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  BuildContext? _context;

  void setContext(BuildContext context) {
    _context = context;
  }

  static const _chatChannel = AndroidNotificationChannel(
    'starlight_chat',
    'Starlight Chat',
    description: 'New chat messages',
    importance: Importance.high,
    playSound: true,
  );

  static const _callChannel = AndroidNotificationChannel(
    'starlight_calls',
    'Starlight Calls',
    description: 'Incoming voice and video calls',
    importance: Importance.max,
    playSound: true,
  );

  static const _libraryChannel = AndroidNotificationChannel(
    'starlight_library',
    'Starlight Library',
    description: 'New library publications',
    importance: Importance.high,
    playSound: true,
  );

  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_chatChannel);
    await androidPlugin?.createNotificationChannel(_callChannel);
    await androidPlugin?.createNotificationChannel(_libraryChannel);

    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload ?? '';
    print('Notification tapped: $payload');

    if (payload.startsWith('call:')) {
      final session = CallSignalingService.instance.activeCall;
      if (session != null && _context != null && _context!.mounted) {
        Navigator.of(_context!).push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => UnifiedCallScreen(session: session),
        ));
      }
    }
  }

  Future<Uint8List?> _downloadBytes(String url) async {
    try {
      final uri = url.startsWith('http') ? Uri.parse(url) : Uri.parse('\${StarlightConstants.apiBaseUrl}\$url');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) return resp.bodyBytes;
    } catch (_) {}
    return null;
  }

  Future<void> showChatMessage({
    required String senderName,
    required String messageContent,
    required String senderPhone,
    String messageType = 'text',
    String mediaUrl = '',
    String thumbnailUrl = '',
    String fileName = '',
    String senderAvatar = '',
  }) async {
    await initialize();
    String body;
    if (messageType == 'image') {
      body = 'Photo';
    } else if (messageType == 'video') {
      body = 'Video';
    } else if (messageType == 'document') {
      body = fileName.isNotEmpty ? '$fileName' : 'Document';
    } else if (messageType == 'audio') {
      body = 'Audio';
    } else {
      body = messageContent;
    }

    AndroidBitmap<Object>? bigPicture;
    if (messageType == 'image' || messageType == 'video') {
      final bytes = await _downloadBytes(messageType == 'image' ? (thumbnailUrl.isNotEmpty ? thumbnailUrl : mediaUrl) : (thumbnailUrl.isNotEmpty ? thumbnailUrl : ''));
      if (bytes != null) {
        bigPicture = ByteArrayAndroidBitmap(bytes);
      }
    }

    AndroidBitmap<Object>? largeIcon;
    if (senderAvatar.isNotEmpty) {
      final avatarBytes = await _downloadBytes(senderAvatar);
      if (avatarBytes != null) {
        largeIcon = ByteArrayAndroidBitmap(avatarBytes);
      }
    }

    final style = bigPicture != null
        ? BigPictureStyleInformation(
            bigPicture,
            largeIcon: largeIcon,
            contentTitle: senderName,
            summaryText: body,
          )
        : null;

    await _plugin.show(
      id: senderPhone.hashCode,
      title: senderName,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _chatChannel.id,
          _chatChannel.name,
          channelDescription: _chatChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
          largeIcon: largeIcon,
          styleInformation: style,
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
      payload: 'chat:$senderPhone',
    );
  }

  Future<void> showIncomingCall({
    required String callerName,
    required String callerPhone,
    required String callId,
    String callType = 'voice',
    String callerAvatar = '',
  }) async {
    await initialize();
    final label = callType == 'video' ? 'Video call' : 'Voice call';

    AndroidBitmap<Object>? largeIcon;
    if (callerAvatar.isNotEmpty) {
      final bytes = await _downloadBytes(callerAvatar);
      if (bytes != null) {
        largeIcon = ByteArrayAndroidBitmap(bytes);
      }
    }

    await _plugin.show(
      id: callId.hashCode,
      title: 'Incoming \$label',
      body: '\$callerName is calling you',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _callChannel.id,
          _callChannel.name,
          channelDescription: _callChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.call,
          ongoing: true,
          icon: '@drawable/ic_notification',
          largeIcon: largeIcon,
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
      payload: 'call:\$callId',
    );
  }

  Future<void> showMissedCall({
    required String callerName,
    required String callerPhone,
    required String callId,
    String callType = 'voice',
    String callerAvatar = '',
  }) async {
    await initialize();
    final label = callType == 'video' ? 'Video call' : 'Voice call';

    AndroidBitmap<Object>? largeIcon;
    if (callerAvatar.isNotEmpty) {
      final bytes = await _downloadBytes(callerAvatar);
      if (bytes != null) {
        largeIcon = ByteArrayAndroidBitmap(bytes);
      }
    }

    await _plugin.show(
      id: callId.hashCode,
      title: 'Missed \$label',
      body: 'From \$callerName',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _callChannel.id,
          _callChannel.name,
          channelDescription: _callChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
          largeIcon: largeIcon,
        ),
        iOS: const DarwinNotificationDetails(presentSound: false),
      ),
      payload: 'call:\$callId',
    );
  }

  Future<void> showBasicNotification({
    required String title,
    required String body,
    String payload = '',
  }) async {
    await initialize();
    await _plugin.show(
      id: title.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _libraryChannel.id,
          _libraryChannel.name,
          channelDescription: _libraryChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
      payload: payload,
    );
  }

  Future<void> cancelCallNotification(String callId) async {
    await _plugin.cancel(id: callId.hashCode);
  }
}