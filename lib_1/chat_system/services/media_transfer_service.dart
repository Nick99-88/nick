import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

class MediaTransferService {
  static final MediaTransferService instance = MediaTransferService._();
  MediaTransferService._();

  bool _isInitialized = false;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(settings: initSettings);

    _isInitialized = true;
  }

  Future<int> download({
    required String url,
    required String savePath,
    required String chatId,
    required String messageType,
    String? fileName,
  }) async {
    await init();

    final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _showProgressNotification(
      notificationId: notificationId,
      channelKey: 'media_download',
      title: 'Downloading $messageType',
      body: fileName ?? 'file',
      progress: 0,
    );

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        await _updateNotificationProgress(
          notificationId: notificationId,
          channelKey: 'media_download',
          progress: 100,
          title: 'Download complete',
        );
      } else {
        await _updateNotificationProgress(
          notificationId: notificationId,
          channelKey: 'media_download',
          progress: 0,
          title: 'Download failed',
        );
      }
    } catch (e) {
      await _updateNotificationProgress(
        notificationId: notificationId,
        channelKey: 'media_download',
        progress: 0,
        title: 'Download failed',
      );
    }

    await Future.delayed(const Duration(seconds: 2));
    await _notifications.cancel(id: notificationId);

    return notificationId;
  }

  Future<int> upload({
    required String url,
    required File file,
    required String chatId,
    required String messageType,
    String? fileName,
    Map<String, String>? headers,
  }) async {
    await init();

    final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _showProgressNotification(
      notificationId: notificationId,
      channelKey: 'media_upload',
      title: 'Uploading $messageType',
      body: fileName ?? 'file',
      progress: 0,
    );

    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));
      if (headers != null) request.headers.addAll(headers);
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        await _updateNotificationProgress(
          notificationId: notificationId,
          channelKey: 'media_upload',
          progress: 100,
          title: 'Upload complete',
        );
      } else {
        await _updateNotificationProgress(
          notificationId: notificationId,
          channelKey: 'media_upload',
          progress: 0,
          title: 'Upload failed',
        );
      }
    } catch (e) {
      await _updateNotificationProgress(
        notificationId: notificationId,
        channelKey: 'media_upload',
        progress: 0,
        title: 'Upload failed',
      );
    }

    await Future.delayed(const Duration(seconds: 2));
    await _notifications.cancel(id: notificationId);

    return notificationId;
  }

  NotificationDetails _buildDetails(String channelKey, {required int progress}) {
    final androidDetails = AndroidNotificationDetails(
      channelKey,
      channelKey == 'media_download' ? 'Media Downloads' : 'Media Uploads',
      channelDescription: 'Shows transfer progress for media files',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      onlyAlertOnce: true,
    );
    return NotificationDetails(android: androidDetails);
  }

  Future<void> _showProgressNotification({
    required int notificationId,
    required String channelKey,
    required String title,
    required String body,
    required int progress,
  }) async {
    await _notifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: _buildDetails(channelKey, progress: progress),
    );
  }

  Future<void> _updateNotificationProgress({
    required int notificationId,
    required String channelKey,
    required int progress,
    required String title,
  }) async {
    await _notifications.show(
      id: notificationId,
      title: title,
      body: '$progress%',
      notificationDetails: _buildDetails(channelKey, progress: progress),
    );
  }

  Future<void> cancelNotification(int notificationId) async {
    await _notifications.cancel(id: notificationId);
  }
}
