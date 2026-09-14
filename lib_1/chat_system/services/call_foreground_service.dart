import 'package:flutter/services.dart';

/// Service to manage the Android foreground service for WebSocket persistence during calls.
/// This ensures the WebSocket connection stays alive even when the app is swiped away.
class CallForegroundService {
  static final CallForegroundService instance = CallForegroundService._init();
  CallForegroundService._init();

  static const _channel = MethodChannel('com.starlight.console/call_foreground');
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// Start the foreground service to keep WebSocket alive during calls
  Future<bool> startService() async {
    if (_isRunning) return true;

    try {
      await _channel.invokeMethod('startService');
      _isRunning = true;
      print('📞 CallForegroundService: Started');
      return true;
    } catch (e) {
      print('📞 CallForegroundService: Failed to start - $e');
      return false;
    }
  }

  /// Stop the foreground service
  Future<bool> stopService() async {
    if (!_isRunning) return true;

    try {
      await _channel.invokeMethod('stopService');
      _isRunning = false;
      print('📞 CallForegroundService: Stopped');
      return true;
    } catch (e) {
      print('📞 CallForegroundService: Failed to stop - $e');
      return false;
    }
  }
}
