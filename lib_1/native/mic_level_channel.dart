import 'dart:async';
import 'package:flutter/services.dart';

/// Android platform channel that captures mic audio via AudioRecord,
/// feeds it into the native C++ FFT analyzer, and returns real-time
/// RMS amplitude (0.0 - 1.0) and frequency bands (36 floats, 0.0 - 1.0).
class MicLevelChannel {
  static MicLevelChannel? _instance;
  MicLevelChannel._();
  static MicLevelChannel get instance => _instance ??= MicLevelChannel._();

  static const _method = MethodChannel('com.starlight.console/mic_level');
  static const _event = EventChannel('com.starlight.console/mic_level_events');

  StreamSubscription? _subscription;
  final StreamController<MicLevelData> _dataController =
      StreamController<MicLevelData>.broadcast();
  MicLevelData _currentData = MicLevelData.zero;

  /// Stream of audio data (level + frequency bands) at ~20Hz.
  Stream<MicLevelData> get onData => _dataController.stream;

  /// Current audio level (0.0 - 1.0).
  double get currentLevel => _currentData.level;

  /// Current frequency bands (36 values, 0.0 - 1.0).
  List<double> get currentBands => _currentData.bands;

  /// Start capturing mic audio and emitting levels + bands.
  Future<void> start() async {
    if (_currentData.isStarted) return;
    try {
      await _method.invokeMethod('startCapturing');
      _subscription = _event.receiveBroadcastStream().listen((event) {
        if (event is Map) {
          final level = (event['level'] as num?)?.toDouble() ?? 0.0;
          final rawBands = event['bands'];
          List<double> bands = List.filled(36, 0.0);
          if (rawBands is List) {
            bands = rawBands.map((b) => (b as num).toDouble()).toList();
            // Pad to 36 if shorter
            while (bands.length < 36) bands.add(0.0);
          }
          _currentData = MicLevelData(
            level: level,
            bands: bands,
            isStarted: true,
          );
          _dataController.add(_currentData);
        }
      });
      _currentData = MicLevelData(
        level: 0.0,
        bands: List.filled(36, 0.0),
        isStarted: true,
      );
    } catch (e) {
      print('MicLevelChannel start error: $e');
    }
  }

  /// Stop capturing.
  Future<void> stop() async {
    if (!_currentData.isStarted) return;
    try {
      await _method.invokeMethod('stopCapturing');
    } catch (_) {}
    _subscription?.cancel();
    _subscription = null;
    _currentData = MicLevelData.zero;
    _dataController.add(_currentData);
  }

  void dispose() {
    stop();
    _dataController.close();
  }
}

class MicLevelData {
  final double level;
  final List<double> bands;
  final bool isStarted;

  const MicLevelData({
    required this.level,
    required this.bands,
    required this.isStarted,
  });

  static const zero = MicLevelData(
    level: 0.0,
    bands: [],
    isStarted: false,
  );
}
