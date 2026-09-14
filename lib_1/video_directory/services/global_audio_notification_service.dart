import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'global_audio_service.dart';

class GlobalAudioNotificationService {
  static final GlobalAudioNotificationService instance = GlobalAudioNotificationService._();
  GlobalAudioNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  static const int _notificationId = 1001;

  static const String actionPlay = 'audio_play';
  static const String actionPause = 'audio_pause';
  static const String _channelId = 'global_audio_playback';

  StreamSubscription? _stateSub;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationAction,
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      'Audio Playback',
      description: 'Controls for audio playback',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;

    _listen();
  }

  void _listen() {
    final service = GlobalAudioService.instance;
    service.addListener(_onServiceChanged);
    _stateSub = service.player.playerStateStream.listen((_) => _onServiceChanged());
  }

  void _onServiceChanged() {
    final service = GlobalAudioService.instance;
    if (!service.isReady || service.currentVideo == null) {
      _cancelNotification();
      return;
    }
    _showNotification();
  }

  void _onNotificationAction(NotificationResponse response) {
    final service = GlobalAudioService.instance;
    switch (response.actionId) {
      case actionPlay:
        service.resume();
        break;
      case actionPause:
        service.pause();
        break;
      default:
        break;
    }
    _onServiceChanged();
  }

  void _showNotification() {
    final service = GlobalAudioService.instance;
    final video = service.currentVideo;
    if (video == null) return;

    final isPlaying = service.isPlaying;
    final playPauseAction = isPlaying ? actionPause : actionPlay;
    final playPauseLabel = isPlaying ? 'Pause' : 'Play';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      'Audio Playback',
      channelDescription: 'Controls for audio playback',
      importance: Importance.low,
      priority: Priority.low,
      playSound: false,
      enableVibration: false,
      showWhen: false,
      ongoing: isPlaying,
      autoCancel: false,
      actions: [
        AndroidNotificationAction(playPauseAction, playPauseLabel, showsUserInterface: false),
      ],
    );

    _plugin.show(
      id: _notificationId,
      title: video.title,
      body: video.uploaderName,
      notificationDetails: NotificationDetails(android: androidDetails),
    );
  }

  void _cancelNotification() {
    _plugin.cancel(id: _notificationId);
  }

  void dispose() {
    _stateSub?.cancel();
    GlobalAudioService.instance.removeListener(_onServiceChanged);
    _cancelNotification();
  }
}
