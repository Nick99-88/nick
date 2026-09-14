import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../core/theme.dart';
import '../services/picture_in_picture_service.dart';

enum VideoPlayerState { idle, loading, playing, paused, buffering, error, ended }

class _SeekIndicator {
  final int id;
  final int seconds;
  _SeekIndicator({required this.id, required this.seconds});
}

class StarlightVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? audioOnlyUrl;
  final String? thumbnailUrl;
  final String title;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final Function(bool)? onFullScreen;
  final Function(String)? onQualityChange;
  final Map<String, String>? availableQualities;
  final bool autoPlay;
  final VoidCallback? onVideoEnd;

  const StarlightVideoPlayer({
    super.key,
    required this.videoUrl,
    this.audioOnlyUrl,
    this.thumbnailUrl,
    this.title = '',
    this.onPlay,
    this.onPause,
    this.onFullScreen,
    this.onQualityChange,
    this.availableQualities,
    this.autoPlay = true,
    this.onVideoEnd,
  });

  @override
  State<StarlightVideoPlayer> createState() => StarlightVideoPlayerState();
}

class StarlightVideoPlayerState extends State<StarlightVideoPlayer> with WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  VideoPlayerState _state = VideoPlayerState.loading;
  bool _showControls = true;
  bool _isFullScreen = false;
  bool _isLocked = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;
  String _selectedQuality = 'auto';
  String _currentUrl = '';
  bool _isAudioOnlyMode = false;
  double _volume = 1.0;
  double _prevVolume = 1.0;

  Timer? _hideControlsTimer;
  Timer? _bufferingCheckTimer;
  Timer? _countdownTimer;

  VideoPlayerController _createVideoController(String url) {
    if (url.startsWith('/data/') || url.startsWith('/storage/') || url.startsWith('file://')) {
      return VideoPlayerController.file(File(url.startsWith('file://') ? Uri.parse(url).toFilePath() : url));
    }
    return VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true, allowBackgroundPlayback: true),
    );
  }
  int _countdownSeconds = 10;
  final _hideControlsDelay = const Duration(seconds: 3);

  bool _showMoreMenu = false;
  bool _showVolumeSlider = false;
  double _lastTapPos = 0;

  final List<_SeekIndicator> _seekIndicators = [];



  static const playbackSpeeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PictureInPictureService.instance.initialize();
    PictureInPictureService.instance.onPipModeChanged = _onPipModeChanged;
    _initializePlayer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !PictureInPictureService.instance.isPipMode) {
      _videoController?.pause();
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted || PictureInPictureService.instance.isPipMode) return;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape && !_isFullScreen) {
      enterFullScreen();
    } else if (!isLandscape && _isFullScreen) {
      exitFullScreen();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownSeconds = 10;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _countdownSeconds--;
      });
      if (_countdownSeconds <= 0) {
        timer.cancel();
        widget.onVideoEnd?.call();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownSeconds = 10;
  }

  @override
  void didUpdateWidget(StarlightVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoUrl != oldWidget.videoUrl) {
      _countdownTimer?.cancel();
      _hideControlsTimer?.cancel();
      _bufferingCheckTimer?.cancel();
      _videoController?.removeListener(_onVideoChanged);
      _videoController?.dispose();
      _chewieController?.dispose();
      _state = VideoPlayerState.loading;
      _position = Duration.zero;
      _duration = Duration.zero;
      _selectedQuality = 'auto';
      _currentUrl = '';
      _isAudioOnlyMode = false;
      _countdownSeconds = 10;
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _hideControlsTimer?.cancel();
    _bufferingCheckTimer?.cancel();
    _videoController?.removeListener(_onVideoChanged);
    _videoController?.dispose();
    _chewieController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    PictureInPictureService.instance.onPipModeChanged = null;
    super.dispose();
  }

  void _onPipModeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initializePlayer({Duration? seekTo}) async {
    try {
      _videoController = _createVideoController(widget.videoUrl);

      await _videoController!.initialize();
      _currentUrl = widget.videoUrl;
      _volume = _videoController!.value.volume;
      _duration = _videoController!.value.duration;
      _videoController!.addListener(_onVideoChanged);

      if (widget.audioOnlyUrl != null) {
        _isAudioOnlyMode = true;
      }

      if (seekTo != null && seekTo < _duration) {
        _videoController!.seekTo(seekTo);
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: widget.autoPlay,
        looping: false,
        showControls: false,
        allowFullScreen: false,
        allowMuting: true,
        draggableProgressBar: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: StarlightTheme.primaryBlue,
          handleColor: Colors.white,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white.withOpacity(0.3),
        ),
      );

      if (widget.autoPlay) {
        setState(() => _state = VideoPlayerState.playing);
      } else {
        setState(() => _state = VideoPlayerState.paused);
      }

      _startBufferingCheck();
    } catch (e) {
      setState(() => _state = VideoPlayerState.error);
    }
  }

  void _onVideoChanged() {
    if (!mounted) return;

    final value = _videoController!.value;

    if (value.isBuffering) {
      if (_state != VideoPlayerState.buffering) {
        setState(() => _state = VideoPlayerState.buffering);
      }
    } else if (value.isPlaying) {
      if (_state != VideoPlayerState.playing) {
        setState(() => _state = VideoPlayerState.playing);
        _resetHideControlsTimer();
      }
    } else if (value.position >= value.duration) {
      if (_state != VideoPlayerState.ended) {
        if (_videoController?.value.isLooping == true) return;
        _bufferingCheckTimer?.cancel();
        _videoController?.pause();
        setState(() => _state = VideoPlayerState.ended);
        _showControls = true;
        _resetHideControlsTimer();
        _startCountdown();
      }
    } else if (value.isInitialized) {
      if (_state != VideoPlayerState.paused) {
        setState(() => _state = VideoPlayerState.paused);
      }
    }

    final clampedDuration = value.duration > Duration.zero ? value.duration : const Duration(milliseconds: 1);
    final clampedPosition = value.position > clampedDuration ? clampedDuration : value.position;
    setState(() {
      _position = clampedPosition;
      _duration = value.duration;
    });
  }

  void _startBufferingCheck() {
    _bufferingCheckTimer?.cancel();
    _bufferingCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || _videoController == null) return;
      if (!_videoController!.value.isBuffering && _state == VideoPlayerState.buffering) {
        setState(() => _state = _videoController!.value.isPlaying ? VideoPlayerState.playing : VideoPlayerState.paused);
      }
    });
  }

  void pause() {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    _bufferingCheckTimer?.cancel();
    _countdownTimer?.cancel();
    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
      widget.onPause?.call();
    }
    _resetHideControlsTimer();
  }

  void _togglePlayPause() {
    if (_videoController == null || !_videoController!.value.isInitialized) return;

    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
      widget.onPause?.call();
    } else if (_videoController!.value.position >= _videoController!.value.duration) {
      _videoController!.seekTo(Duration.zero);
      _videoController!.play();
      widget.onPlay?.call();
    } else {
      _videoController!.play();
      widget.onPlay?.call();
    }
    _resetHideControlsTimer();
  }

  void _seekTo(Duration position, {bool autoPlay = false}) {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    _videoController!.seekTo(position);
    if (autoPlay) {
      _videoController!.play();
      widget.onPlay?.call();
    }
    _resetHideControlsTimer();
  }

  void _showSeekIndicator(int seconds) {
    final id = DateTime.now().millisecondsSinceEpoch;
    _seekIndicators.add(_SeekIndicator(id: id, seconds: seconds));
    if (mounted) setState(() {});
    Future.delayed(const Duration(milliseconds: 800), () {
      _seekIndicators.removeWhere((s) => s.id == id);
      if (mounted) setState(() {});
    });
  }

  void _setPlaybackSpeed(double speed) {
    if (_videoController == null) return;
    _videoController!.setPlaybackSpeed(speed);
    setState(() => _playbackSpeed = speed);
  }

  Future<void> _switchToAudioOnly() async {
    if (widget.audioOnlyUrl == null || widget.audioOnlyUrl!.isEmpty) return;

    setState(() {
      _state = VideoPlayerState.loading;
      _isAudioOnlyMode = true;
    });

    _cancelCountdown();
    _videoController?.removeListener(_onVideoChanged);
    _videoController?.dispose();
    _chewieController?.dispose();

    _videoController = _createVideoController(widget.audioOnlyUrl!);

    _videoController!.addListener(_onVideoChanged);

    try {
      await _videoController!.initialize();
      _duration = _videoController!.value.duration;

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        showControls: false,
        allowFullScreen: false,
        draggableProgressBar: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: StarlightTheme.primaryBlue,
          handleColor: Colors.white,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white.withOpacity(0.3),
        ),
      );

      _currentUrl = widget.audioOnlyUrl!;
      setState(() => _state = VideoPlayerState.playing);
      widget.onQualityChange?.call('audio_only');
      _startBufferingCheck();
    } catch (e) {
      setState(() => _state = VideoPlayerState.error);
    }
  }

  void _switchToVideo() {
    _cancelCountdown();
    setState(() {
      _state = VideoPlayerState.loading;
      _isAudioOnlyMode = false;
    });

    _videoController?.removeListener(_onVideoChanged);
    _videoController?.dispose();
    _chewieController?.dispose();

    _currentUrl = widget.videoUrl;
    _initializePlayer();
  }

  void _changeQuality(String quality, String url) {
    if (url == _currentUrl) return;

    _cancelCountdown();
    final savedPosition = _position;

    setState(() {
      _state = VideoPlayerState.loading;
      _selectedQuality = quality;
    });

    _videoController?.removeListener(_onVideoChanged);
    _videoController?.dispose();
    _chewieController?.dispose();

    _videoController = _createVideoController(url);
    _videoController!.initialize().then((_) {
      _duration = _videoController!.value.duration;
      _videoController!.addListener(_onVideoChanged);

      if (savedPosition < _duration) {
        _videoController!.seekTo(savedPosition);
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        showControls: false,
        allowFullScreen: false,
        draggableProgressBar: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: StarlightTheme.primaryBlue,
          handleColor: Colors.white,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white.withOpacity(0.3),
        ),
      );

      _currentUrl = url;
      setState(() => _state = VideoPlayerState.playing);
      widget.onQualityChange?.call(quality);
      _startBufferingCheck();
    }).catchError((e) {
      setState(() => _state = VideoPlayerState.error);
    });
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      _isLocked = false;
    });
    widget.onFullScreen?.call(_isFullScreen);

    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void enterFullScreen() {
    if (_isFullScreen) return;
    setState(() {
      _isFullScreen = true;
      _isLocked = false;
    });
    widget.onFullScreen?.call(true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void exitFullScreen() {
    if (!_isFullScreen) return;
    setState(() {
      _isFullScreen = false;
      _isLocked = false;
    });
    widget.onFullScreen?.call(false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _handleDoubleTap() {
    final screenWidth = context.size?.width ?? 1;
    if (_lastTapPos < screenWidth / 2) {
      _seekTo(_position - const Duration(seconds: 10));
      _showSeekIndicator(-10);
    } else {
      _seekTo(_position + const Duration(seconds: 10));
      _showSeekIndicator(10);
    }
  }

  void _toggleControls() {
    if (_showControls) {
      _resetHideControlsTimer();
    } else {
      setState(() => _showVolumeSlider = false);
      _resetHideControlsTimer();
    }
  }

  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    setState(() => _showControls = true);
    _hideControlsTimer = Timer(_hideControlsDelay, () {
      if (mounted && !_showVolumeSlider) {
        setState(() {
          _showControls = false;
          _showVolumeSlider = false;
        });
      }
    });
  }

  void _showSpeedSheet() {
    _hideControlsTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Playback Speed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: playbackSpeeds.map((speed) {
                        final isSelected = speed == _playbackSpeed;
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                          leading: Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected ? StarlightTheme.primaryBlue : Colors.grey,
                            size: 20,
                          ),
                          title: Text(
                            speed == 1.0 ? 'Normal (${speed}x)' : '${speed}x',
                            style: TextStyle(
                              color: isSelected ? StarlightTheme.primaryBlue : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 15,
                            ),
                          ),
                          onTap: () {
                            _setPlaybackSpeed(speed);
                            Navigator.pop(ctx);
                            _resetHideControlsTimer();
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) _resetHideControlsTimer();
    });
  }

  void _showQualitySheet() {
    if (_qualityCount < 2) return;

    _hideControlsTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Video Quality',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                          leading: Icon(
                            _selectedQuality == 'auto' ? Icons.settings : Icons.settings_outlined,
                            color: _selectedQuality == 'auto' ? StarlightTheme.primaryBlue : Colors.grey,
                            size: 20,
                          ),
                          title: Text(
                            'Auto',
                            style: TextStyle(
                              color: _selectedQuality == 'auto' ? StarlightTheme.primaryBlue : Colors.white,
                              fontWeight: _selectedQuality == 'auto' ? FontWeight.bold : FontWeight.normal,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            'Recommended',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          onTap: () {
                            if (_selectedQuality != 'auto') {
                              _changeQuality('auto', widget.videoUrl);
                            }
                            Navigator.pop(ctx);
                            _resetHideControlsTimer();
                          },
                        ),
                        ...widget.availableQualities!.entries.where((e) => e.key != 'auto').map((entry) {
                          final isSelected = entry.key == _selectedQuality;
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                            leading: Icon(
                              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isSelected ? StarlightTheme.primaryBlue : Colors.grey,
                              size: 20,
                            ),
                            title: Text(
                              entry.key.toUpperCase(),
                              style: TextStyle(
                                color: isSelected ? StarlightTheme.primaryBlue : Colors.white,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 15,
                              ),
                            ),
                            onTap: () {
                              _changeQuality(entry.key, entry.value);
                              Navigator.pop(ctx);
                              _resetHideControlsTimer();
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) _resetHideControlsTimer();
    });
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final inPip = PictureInPictureService.instance.isPipMode;

    if (inPip) {
      return _buildVideoPlayer();
    }

    return GestureDetector(
      onTap: _isLocked ? null : _toggleControls,
      onDoubleTapDown: _isLocked ? null : (details) => _lastTapPos = details.localPosition.dx,
      onDoubleTap: _isLocked ? null : _handleDoubleTap,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            _buildVideoPlayer(),

            // Circular Gestural Seek Overlay
            ..._seekIndicators.map((ind) => _buildCircularSeekOverlay(ind)),

            if (_state == VideoPlayerState.loading)
              const Center(child: CircularProgressIndicator(color: StarlightTheme.primaryBlue)),

            if (_state == VideoPlayerState.buffering)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: StarlightTheme.primaryBlue),
                      const SizedBox(height: 8),
                      const Text('Buffering...', style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
              ),

            if (_state == VideoPlayerState.error)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: StarlightTheme.errorRed,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.error_outline, size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Video playback error',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _state = VideoPlayerState.loading);
                        _videoController?.dispose();
                        _chewieController?.dispose();
                        _initializePlayer();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StarlightTheme.accentGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),

            if (!_isLocked && _showControls && _state != VideoPlayerState.loading && _state != VideoPlayerState.error)
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: _buildControlsOverlay(),
              ),
            if (!_isLocked && _state == VideoPlayerState.ended)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Next video in $_countdownSeconds s',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
            if (_isLocked)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.lock, color: Colors.white, size: 24),
                  onPressed: () {
                    setState(() {
                      _isLocked = false;
                      _showControls = true;
                      _resetHideControlsTimer();
                    });
                  },
                  tooltip: 'Unlock',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularSeekOverlay(_SeekIndicator ind) {
    final isForward = ind.seconds > 0;
    final label = '${isForward ? '+' : ''}${ind.seconds}s';
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        builder: (context, anim, child) {
          final scale = 1.0 - (anim * 0.2);
          final opacity = 1.0 - anim;
          return Opacity(
            opacity: opacity,
            child: Center(
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black54,
                    border: Border.all(
                      color: isForward ? StarlightTheme.accentGreen : StarlightTheme.errorRed,
                      width: 3,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isForward ? Icons.forward_10 : Icons.replay_10,
                        color: isForward ? StarlightTheme.accentGreen : StarlightTheme.errorRed,
                        size: 36,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAudioOnlyPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.headphones, size: 64, color: StarlightTheme.primaryBlue),
          const SizedBox(height: 16),
          Text(
            'Audio Only Mode',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Low bandwidth optimized',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Center(
      child: _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
          ? Chewie(controller: _chewieController!)
          : _isAudioOnlyMode
              ? _buildAudioOnlyPlaceholder()
              : widget.thumbnailUrl != null
                  ? Image.network(widget.thumbnailUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.movie, size: 64, color: Colors.grey))
                  : const Icon(Icons.movie, size: 64, color: Colors.grey),
    );
  }

  Widget _buildControlsOverlay() {
    return Stack(
      children: [
        _buildTopBar(),
        _buildCenterControls(),
        _buildBottomBar(),
        if (_showMoreMenu) _buildMoreMenu(),
      ],
    );
  }

  Widget _buildTopBar() {
    final topPad = _isFullScreen ? MediaQuery.of(context).padding.top : 0.0;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                if (_isFullScreen) {
                  exitFullScreen();
                }
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                }
              },
            ),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_isAudioOnlyMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: StarlightTheme.accentGreen.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'AUDIO',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () {
                setState(() => _showMoreMenu = !_showMoreMenu);
                _hideControlsTimer?.cancel();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    return Positioned.fill(
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10, color: Colors.white, size: 32),
              onPressed: () {
                _seekTo(_position - const Duration(seconds: 10));
                _showSeekIndicator(-10);
              },
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _state == VideoPlayerState.ended ? () {
                    _cancelCountdown();
                    _seekTo(Duration.zero, autoPlay: true);
                  } : _togglePlayPause,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _state == VideoPlayerState.ended ? Icons.replay : (_state == VideoPlayerState.playing ? Icons.pause : Icons.play_arrow),
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),
            IconButton(
              icon: const Icon(Icons.forward_10, color: Colors.white, size: 32),
              onPressed: () {
                _seekTo(_position + const Duration(seconds: 10));
                _showSeekIndicator(10);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final bottomPad = _isFullScreen ? MediaQuery.of(context).padding.bottom : 0.0;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad + 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_videoController != null && _videoController!.value.isInitialized)
                _buildSeekBar(),
              Row(
              children: [
                Text(
                  _formatDuration(_position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const Text(' / ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const Spacer(),
                _buildSpeedButton(),
                if (widget.audioOnlyUrl != null && widget.audioOnlyUrl!.isNotEmpty)
                  IconButton(
                    icon: Icon(_isAudioOnlyMode ? Icons.videocam : Icons.headphones, color: Colors.white),
                    onPressed: _isAudioOnlyMode ? _switchToVideo : _switchToAudioOnly,
                    tooltip: _isAudioOnlyMode ? 'Switch to Video' : 'Audio Only Mode',
                  ),
                _buildQualityButton(),
                _buildVolumeButton(),
                IconButton(
                  icon: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
                  onPressed: _toggleFullScreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekBar() {
    final durationMs = _duration.inMilliseconds.toDouble();
    final clampedFraction = durationMs > 0 ? (_position.inMilliseconds / durationMs).clamp(0.0, 1.0) : 0.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            final fraction = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
            final seekPos = Duration(milliseconds: (durationMs * fraction).toInt());
            _seekTo(seekPos);
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: clampedFraction,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(StarlightTheme.primaryBlue),
                    ),
                  ),
                ),
              ),
              // Thumbnail preview tooltip (theoretical approach)
              // To implement: replace VideoProgressIndicator above with a custom
              // SliderTheme wrapped Slider. Track onChanged with _scrubFraction.
              // Use a timestamped Positioned widget above the bar:
              //
              //   Positioned(
              //     left: _scrubFraction * constraints.maxWidth - previewWidth / 2,
              //     bottom: 20,
              //     child: _buildThumbnailPreview(_scrubFraction),
              //   )
              //
              // Where _buildThumbnailPreview fetches from a sprite sheet:
              //   final index = (_scrubFraction * totalFrames).floor();
              //   return ClipRRect(
              //     child: Image.network('https://cdn/video_id/thumbnails/$index.jpg'),
              //   );
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpeedButton() {
    return InkWell(
      onTap: _showSpeedSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _playbackSpeed != 1.0 ? StarlightTheme.primaryBlue.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${_playbackSpeed}x',
          style: TextStyle(
            color: _playbackSpeed != 1.0 ? StarlightTheme.primaryBlue : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  int get _qualityCount => widget.availableQualities?.length ?? 0;

  Widget _buildQualityButton() {
    if (widget.availableQualities == null || _qualityCount < 2 || _isAudioOnlyMode) {
      return const SizedBox.shrink();
    }
    return InkWell(
      onTap: _showQualitySheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _selectedQuality != 'auto' ? StarlightTheme.primaryBlue.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings, color: _selectedQuality != 'auto' ? StarlightTheme.primaryBlue : Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              _selectedQuality.toUpperCase(),
              style: TextStyle(
                color: _selectedQuality != 'auto' ? StarlightTheme.primaryBlue : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeButton() {
    final pct = (_volume * 100).round();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            _volume == 0 ? Icons.volume_off : Icons.volume_up,
            color: Colors.white,
          ),
          onPressed: () {
            if (_volume > 0) {
              _prevVolume = _volume;
              _volume = 0;
              _videoController?.setVolume(0);
            } else {
              _volume = _prevVolume;
              _videoController?.setVolume(_prevVolume);
            }
            setState(() {});
            _hideControlsTimer?.cancel();
          },
        ),
        if (_showVolumeSlider)
          Positioned(
            bottom: 48,
            left: -24,
            child: Container(
              height: 140,
              width: 96,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('$pct%', style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                  Expanded(
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Slider(
                          value: _volume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 100,
                          activeColor: StarlightTheme.primaryBlue,
                          inactiveColor: Colors.white24,
                          thumbColor: Colors.white,
                          onChanged: (v) {
                            _volume = v;
                            _prevVolume = v;
                            _videoController?.setVolume(v);
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMoreMenu() {
    return Positioned(
      right: 16,
      top: 50,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 200),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
                title: const Text('Picture-in-Picture', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  setState(() => _showMoreMenu = false);
                  final pipService = PictureInPictureService.instance;
                  final supported = await pipService.isSupported;
                  if (!supported) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PiP not supported on this device')),
                      );
                    }
                    return;
                  }
                  await pipService.enterPip(width: 16, height: 9);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(_isLocked ? Icons.lock_open : Icons.lock, color: Colors.white),
                title: Text(_isLocked ? 'Unlock Controls' : 'Lock Controls', style: const TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() {
                    _isLocked = !_isLocked;
                    _showControls = !_isLocked;
                    _showMoreMenu = false;
                  });
                },
              ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.loop, color: Colors.white),
                title: Text(
                  _videoController?.value.isLooping == true ? 'Disable Loop' : 'Enable Loop',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  if (_videoController != null) {
                    _videoController!.setLooping(!_videoController!.value.isLooping);
                    setState(() => _showMoreMenu = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
