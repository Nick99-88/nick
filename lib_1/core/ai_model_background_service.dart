import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'ai_model_manager.dart';

class AIModelBackgroundService {
  static bool _isRunning = false;
  static String? _currentModelId;
  static String? _currentModelName;

  static const int _notifId = 8888;
  static const String _channelId = 'ai_model_downloads';
  static const String _channelName = 'AI Model Downloads';

  static final FlutterLocalNotificationsPlugin _notifPlugin =
      FlutterLocalNotificationsPlugin();

  static final StreamController<Map<String, dynamic>> _progressController =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get progressStream =>
      _progressController.stream;

  static bool get isRunning => _isRunning;
  static String? get currentModelId => _currentModelId;

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifPlugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
    );

    final androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'AI model download progress',
      importance: Importance.low,
      playSound: false,
    );
    await _notifPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'AI Model Download',
        initialNotificationContent: 'Initializing...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );

    FlutterBackgroundService().on('downloadProgress').listen((data) {
      if (data == null) return;
      _progressController.add(Map<String, dynamic>.from(data));
      _updateNotif(data);
    });
  }

  static void _updateNotif(Map<String, dynamic> data) {
    final progress = (data['progress'] as num?)?.toDouble() ?? 0.0;
    final status = data['status'] as String? ?? '';
    final name = data['name'] as String? ?? _currentModelName ?? 'Model';

    if (status == 'Installed') {
      _notifPlugin.cancel(id: _notifId);
      return;
    }
    if (status == 'Cancelled' || status == 'Failed') {
      _notifPlugin.cancel(id: _notifId);
      return;
    }
    if (status == 'Paused') {
      _notifPlugin.show(
        id: _notifId,
        title: 'Download Paused',
        body: '$name — tap to resume',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.low,
            priority: Priority.low,
            showProgress: false,
            onlyAlertOnce: true,
          ),
        ),
      );
      return;
    }
    if (status == 'downloading' || status.contains('%')) {
      final pct = (progress * 100).toInt();
      _notifPlugin.show(
        id: _notifId,
        title: 'Downloading $name',
        body: '$pct%',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.low,
            priority: Priority.low,
            showProgress: true,
            maxProgress: 100,
            progress: pct,
            indeterminate: false,
            onlyAlertOnce: true,
          ),
        ),
      );
      return;
    }
  }

  static Future<void> startDownload(String modelId) async {
    final manager = AIModelManager();
    final model = manager.availableModels.firstWhere(
      (m) => m.id == modelId,
      orElse: () => manager.availableModels.first,
    );

    _currentModelId = modelId;
    _currentModelName = model.name;
    _isRunning = true;

    final service = FlutterBackgroundService();
    final alreadyRunning = await service.isRunning();
    if (!alreadyRunning) {
      await service.startService();
    }
    service.invoke('startDownload', {'modelId': modelId});
  }

  static Future<void> pauseDownload() async {
    final service = FlutterBackgroundService();
    service.invoke('pauseDownload');
    _isRunning = false;
  }

  static Future<void> cancelDownload() async {
    final service = FlutterBackgroundService();
    service.invoke('cancelDownload');
    _notifPlugin.cancel(id: _notifId);
    _currentModelId = null;
    _isRunning = false;
  }

  static Future<bool> isCurrentlyDownloading(String modelId) async {
    return _currentModelId == modelId && _isRunning;
  }

  static Future<void> checkAndResumePending() async {
    final manager = AIModelManager();
    final pending = await manager.getPendingDownload();
    if (pending != null && !_isRunning) {
      await startDownload(pending);
    }
  }

  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    if (service is AndroidServiceInstance) {
      bool paused = false;
      bool cancelled = false;

      service.on('startDownload').listen((data) async {
        if (data == null) return;
        cancelled = false;
        paused = false;

        final modelId = data['modelId'] as String?;
        if (modelId == null) return;

        _currentModelId = modelId;
        final manager = AIModelManager();
        final model = manager.availableModels.firstWhere(
          (m) => m.id == modelId,
          orElse: () => manager.availableModels.first,
        );

        service.setForegroundNotificationInfo(
          title: "Downloading ${model.name}",
          content: "Starting...",
        );

        await manager.downloadModel(
          modelId: model.id,
          onProgress: (progress) {
            if (cancelled || paused) return;
            final pct = (progress * 100).toStringAsFixed(0);
            service.setForegroundNotificationInfo(
              title: "Downloading ${model.name}",
              content: "$pct% complete",
            );
            service.invoke('downloadProgress', {
              'modelId': model.id,
              'name': model.name,
              'progress': progress,
              'status': 'downloading',
            });
          },
          onStatus: (status) {
            service.setForegroundNotificationInfo(
              title: model.name,
              content: status,
            );
            service.invoke('downloadProgress', {
              'modelId': model.id,
              'name': model.name,
              'progress': status == 'Installed' ? 1.0 : 0.0,
              'status': status,
            });
            if (status == 'Installed' || status == 'Failed') {
              _currentModelId = null;
              _isRunning = false;
              service.stopSelf();
            }
          },
        );
      });

      service.on('pauseDownload').listen((_) async {
        paused = true;
        if (_currentModelId != null) {
          final manager = AIModelManager();
          await manager.pauseDownload(_currentModelId!);
        }
        final savedId = _currentModelId;
        _currentModelId = null;
        _isRunning = false;
        service.invoke('downloadProgress', {
          'modelId': savedId ?? '',
          'name': _currentModelName ?? '',
          'progress': 0.0,
          'status': 'Paused',
        });
        await service.stopSelf();
      });

      service.on('cancelDownload').listen((_) async {
        cancelled = true;
        paused = true;
        if (_currentModelId != null) {
          final manager = AIModelManager();
          await manager.cancelDownload(_currentModelId!);
        }
        _currentModelId = null;
        _isRunning = false;
        await service.stopSelf();
      });
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    return true;
  }
}
