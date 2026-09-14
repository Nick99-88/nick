import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/video_models.dart';
import 'audio_stream_service.dart';

class GlobalAudioService extends ChangeNotifier {
  static final GlobalAudioService _instance = GlobalAudioService._();
  static GlobalAudioService get instance => _instance;
  GlobalAudioService._();

  final AudioPlayer _player = AudioPlayer();
  VideoPost? _currentVideo;
  bool _isLoading = false;
  bool _isReady = false;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _stateSub;

  VideoPost? get currentVideo => _currentVideo;
  bool get isLoading => _isLoading;
  bool get isReady => _isReady;
  bool get isPlaying => _isPlaying;
  Duration get duration => _duration;
  Duration get position => _position;
  AudioPlayer get player => _player;

  void _listen() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    _durationSub = _player.durationStream.listen((d) {
      _duration = d ?? Duration.zero;
      notifyListeners();
    });
    _positionSub = _player.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });
    _stateSub = _player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.play();
      }
      notifyListeners();
    });
  }

  Future<void> play(VideoPost video) async {
    if (_currentVideo?.id == video.id && _isReady) {
      await _player.play();
      return;
    }
    _currentVideo = video;
    _isLoading = true;
    _isReady = false;
    notifyListeners();
    try {
      final info = await AudioStreamService.getAudioInfo(video.id);
      if (info.ready) {
        final source = await AudioStreamService.buildAudioSource(info);
        await _player.setAudioSource(source);
        _listen();
        _isReady = true;
        _isLoading = false;
        notifyListeners();
        await _player.play();
      } else {
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  void pause() {
    _player.pause();
  }

  void resume() {
    _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
    _currentVideo = null;
    _isReady = false;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  void seek(Duration position) {
    _player.seek(position);
  }

  Future<void> processAndPlay(VideoPost video) async {
    _currentVideo = video;
    _isLoading = true;
    notifyListeners();
    try {
      await AudioStreamService.triggerProcessing(video.id);
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 2));
        final info = await AudioStreamService.getAudioInfo(video.id);
        if (info.ready) {
          final source = await AudioStreamService.buildAudioSource(info);
          await _player.setAudioSource(source);
          _listen();
          _isReady = true;
          _isLoading = false;
          notifyListeners();
          await _player.play();
          return;
        }
        if (info.failed) {
          break;
        }
      }
    } catch (e) {
      // ignore errors silently
    }
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
