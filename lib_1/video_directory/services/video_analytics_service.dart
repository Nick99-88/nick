import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';

class VideoAnalyticsService {
  static String get _baseUrl => StarlightConstants.apiBaseUrl;

  static Future<Map<String, String>> _authHeaders() async {
    final token = await StarlightStorage.getUserToken();
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  static Future<void> trackEventsBatch(List<Map<String, dynamic>> events) async {
    if (events.isEmpty) return;
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/video/analytics/batch'),
        headers: await _authHeaders(),
        body: jsonEncode({'events': events}),
      );
    } catch (e) {
      // Silently fail
    }
  }

  static Future<void> updateProgress({
    required String videoId,
    required double position,
    required double watchDuration,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/video/$videoId/analytics/progress'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'position': position,
          'watch_duration': watchDuration,
        }),
      );
    } catch (e) {
      // Silently fail
    }
  }

  static Future<Map<String, dynamic>> getVideoAnalytics(String videoId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/$videoId/analytics'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load analytics');
  }

  static Future<List<Map<String, dynamic>>> getWatchHistory() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/analytics/history'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return List<Map<String, dynamic>>.from(data['history'] ?? []);
    }
    throw Exception('Failed to load watch history');
  }
}

class VideoAnalyticsTracker {
  final String videoId;
  Timer? _flushTimer;
  Timer? _heartbeatTimer;
  
  final List<Map<String, dynamic>> _eventBuffer = [];
  double _lastPosition = 0;
  double _totalWatchTime = 0;
  DateTime? _playStartTime;
  bool _isTracking = false;
  
  static const int _flushIntervalSeconds = 45;
  static const int _maxBufferSize = 20;

  VideoAnalyticsTracker(this.videoId);

  void startTracking() {
    if (_isTracking) return;
    _isTracking = true;
    _playStartTime = DateTime.now();

    _addEvent('play', position: _lastPosition);

    _flushTimer = Timer.periodic(const Duration(seconds: _flushIntervalSeconds), (_) {
      _flushBuffer();
    });
  }

  void pauseTracking(double position) {
    _lastPosition = position;
    if (_playStartTime != null) {
      _totalWatchTime += DateTime.now().difference(_playStartTime!).inMilliseconds / 1000;
      _playStartTime = null;
    }

    _addEvent('pause', position: position, duration: _totalWatchTime);
    _flushBuffer();

    VideoAnalyticsService.updateProgress(
      videoId: videoId,
      position: position,
      watchDuration: _totalWatchTime,
    );
  }

  void resumeTracking(double position) {
    _lastPosition = position;
    _playStartTime = DateTime.now();

    _addEvent('play', position: position, duration: _totalWatchTime);
  }

  void seekTo(double from, double to) {
    _addEvent('seek', position: to, duration: _totalWatchTime);
    _lastPosition = to;
  }

  void changeQuality(String quality) {
    _addEvent('quality_change', position: _lastPosition, quality: quality);
  }

  void changeSpeed(double speed) {
    _addEvent('speed_change', position: _lastPosition, playbackSpeed: speed);
  }

  void videoEnded(double position) {
    if (_playStartTime != null) {
      _totalWatchTime += DateTime.now().difference(_playStartTime!).inMilliseconds / 1000;
      _playStartTime = null;
    }

    _addEvent('ended', position: position, duration: _totalWatchTime);
    _flushBuffer();

    VideoAnalyticsService.updateProgress(
      videoId: videoId,
      position: position,
      watchDuration: _totalWatchTime,
    );

    _flushTimer?.cancel();
    _isTracking = false;
  }

  void _addEvent(String eventType, {
    double position = 0,
    double duration = 0,
    double playbackSpeed = 1.0,
    String quality = 'auto',
  }) {
    _eventBuffer.add({
      'video_id': videoId,
      'event_type': eventType,
      'position': position,
      'duration': duration,
      'playback_speed': playbackSpeed,
      'quality': quality,
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (_eventBuffer.length >= _maxBufferSize) {
      _flushBuffer();
    }
  }

  void _flushBuffer() {
    if (_eventBuffer.isEmpty) return;
    
    final events = List<Map<String, dynamic>>.from(_eventBuffer);
    _eventBuffer.clear();
    
    VideoAnalyticsService.trackEventsBatch(events);
  }

  void dispose() {
    _flushTimer?.cancel();
    if (_playStartTime != null) {
      _totalWatchTime += DateTime.now().difference(_playStartTime!).inMilliseconds / 1000;
    }
    if (_isTracking) {
      VideoAnalyticsService.updateProgress(
        videoId: videoId,
        position: _lastPosition,
        watchDuration: _totalWatchTime,
      );
    }
    _flushBuffer();
  }
}
