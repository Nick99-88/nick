import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// ── audio_service handler (notification + background) ───────────────────────

class _AudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  void Function()? onComplete;

  AudioPlayer get player => _player;

  _AudioHandler() {
    _player.onPlayerStateChanged.listen((state) => _emitState());
    _player.onPositionChanged.listen((p) {
      _position = p;
      _emitState();
    });
    _player.onDurationChanged.listen((d) {
      _duration = d;
      _emitState();
    });
    _player.onPlayerComplete.listen((_) {
      _position = Duration.zero;
      _emitState();
      stop();
      onComplete?.call();
    });
  }

  void _emitState() {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        _player.state == PlayerState.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      processingState: AudioProcessingState.ready,
      playing: _player.state == PlayerState.playing,
      updatePosition: _position,
      bufferedPosition: _duration,
      speed: 1.0,
    ));
  }

  void setMediaItem(String url, String title) {
    mediaItem.add(MediaItem(id: url, title: title, artist: 'Starlight', duration: _duration));
  }

  @override
  Future<void> play() => _player.resume();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _position = position;
  }

  Future<void> setSourceUrl(String url) => _player.setSourceUrl(url);
  Future<void> resumePlayer() => _player.resume();

  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _player.state == PlayerState.playing;

  void dispose() {
    _player.dispose();
  }
}

// ── Public API singleton ────────────────────────────────────────────────────

class AudioPlaybackService {
  static AudioPlaybackService? _instance;
  static AudioPlaybackService get instance => _instance ??= AudioPlaybackService._();
  AudioPlaybackService._();

  static _AudioHandler? _handler;
  static bool _initialized = false;

  String? _currentUrl;
  bool _isNearEar = false;
  double _originalVolume = 1.0;
  StreamSubscription<int>? _proximitySub;
  bool _proximityActive = false;

  bool get isPlaying => _handler?.isPlaying ?? false;
  String? get currentUrl => _currentUrl;
  Duration get position => _handler?.position ?? Duration.zero;
  Duration get duration => _handler?.duration ?? Duration.zero;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      _handler = _AudioHandler();
      await AudioService.init(
        builder: () => _handler!,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.starlight.console.audio',
          androidNotificationChannelName: 'Voice Playback',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationIcon: 'drawable/ic_notification',
        ),
      );
      _initialized = true;
    } catch (e) {
      debugPrint('AudioPlaybackService: AudioService.init failed - $e');
    }
  }

  Future<void> play(String url, {String? title, String? subtitle}) async {
    if (url.isEmpty) return;
    if (!_initialized) await init();

    // Toggle if same URL and currently playing
    if (_currentUrl == url && _handler != null) {
      if (isPlaying) {
        await _handler!.pause();
        return;
      }
      // Track completed or stopped — re-load source so it replays from start
      if (_handler!.player.state == PlayerState.stopped || _handler!.player.state == PlayerState.completed) {
        await _handler!.setSourceUrl(url);
      } else {
        await _handler!.seek(Duration.zero);
      }
      await _handler!.resumePlayer();
      _startProximitySensor();
      return;
    }

    await stop();

    if (_handler == null) return;

    _currentUrl = url;
    _handler!.setMediaItem(url, title ?? 'Voice Message');

    try {
      // Set completion callback to auto-stop and clean up proximity sensor
      _handler!.onComplete = stop;
      await _handler!.setSourceUrl(url);
      await _handler!.resumePlayer();
      _startProximitySensor();
    } catch (e) {
      debugPrint('AudioPlaybackService: Failed to play $url - $e');
      await stop();
    }
  }

  Future<void> pause() async {
    await _handler?.pause();
  }

  Future<void> resume() async {
    await _handler?.resumePlayer();
    _startProximitySensor();
  }

  Future<void> seek(Duration position) async {
    await _handler?.seek(position);
  }

  Future<void> stop() async {
    await _stopProximitySensor();
    await _handler?.stop();
    _currentUrl = null;
  }

  void _startProximitySensor() {
    if (_proximityActive) return;
    _proximityActive = true;
    try {
      _proximitySub = ProximitySensor.events.listen((distance) async {
        final near = Platform.isIOS ? distance > 0 : distance == 0;
        if (near != _isNearEar) {
          _isNearEar = near;
          if (near) {
            _originalVolume = await FlutterVolumeController.getVolume() ?? 1.0;
            await FlutterVolumeController.setVolume(0.2);
            await WakelockPlus.disable();
          } else {
            await FlutterVolumeController.setVolume(_originalVolume);
            await WakelockPlus.enable();
          }
        }
      });
    } catch (e) {
      debugPrint('AudioPlaybackService: Proximity sensor unavailable - $e');
    }
  }

  Future<void> _stopProximitySensor() async {
    _proximitySub?.cancel();
    _proximitySub = null;
    _proximityActive = false;
    _isNearEar = false;
    try {
      await FlutterVolumeController.setVolume(_originalVolume);
      await WakelockPlus.enable();
    } catch (_) {}
  }

  void dispose() {
    unawaited(stop());
    _handler?.dispose();
    _handler = null;
    _initialized = false;
  }
}
