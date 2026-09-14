import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PictureInPictureService {
  static const _channel = MethodChannel('com.starlight.console/pip');

  static final PictureInPictureService instance = PictureInPictureService._();
  PictureInPictureService._();

  bool _isPipMode = false;
  bool _initialized = false;

  final StreamController<bool> _pipModeController = StreamController<bool>.broadcast();
  final StreamController<void> _userLeaveHintController = StreamController<void>.broadcast();

  Stream<bool> get pipModeChanged => _pipModeController.stream;
  Stream<void> get userLeaveHint => _userLeaveHintController.stream;
  bool get isPipMode => _isPipMode;

  @Deprecated('Use pipModeChanged stream instead')
  VoidCallback? onPipModeChanged;

  Future<bool> get isSupported async {
    try {
      return await _channel.invokeMethod<bool>('isPipSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> enterPip({int width = 16, int height = 9}) async {
    try {
      final result = await _channel.invokeMethod<bool>('enterPip', {
        'width': width,
        'height': height,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setInRtcRoom(bool value) async {
    try {
      await _channel.invokeMethod('setInRtcRoom', value);
    } catch (_) {}
  }

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'pipModeChanged':
          _isPipMode = call.arguments as bool;
          _pipModeController.add(_isPipMode);
          onPipModeChanged?.call();
          break;
        case 'onUserLeaveHint':
          _userLeaveHintController.add(null);
          break;
      }
    });
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _initialized = false;
  }
}
