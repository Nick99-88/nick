import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../models/video_models.dart';
import '../services/global_audio_service.dart';
import '../services/audio_stream_service.dart';

class AudioPlayerScreen extends StatefulWidget {
  const AudioPlayerScreen({super.key});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen>
    with SingleTickerProviderStateMixin {
  final _audioService = GlobalAudioService.instance;
  bool _isProcessing = false;
  bool _hasFailed = false;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _audioService.addListener(_onServiceChanged);
    _checkAndProcess();
  }

  @override
  void dispose() {
    _audioService.stop();
    _rotationController.dispose();
    _audioService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    setState(() {});
    if (_audioService.isPlaying) {
      if (!_rotationController.isAnimating) _rotationController.repeat();
    } else {
      if (_rotationController.isAnimating) _rotationController.stop();
    }
  }

  Future<void> _checkAndProcess() async {
    final video = _audioService.currentVideo;
    if (video == null) return;
    if (_audioService.isReady || _audioService.isLoading) return;
    setState(() {
      _isProcessing = true;
      _hasFailed = false;
    });
    try {
      final info = await AudioStreamService.getAudioInfo(video.id);
      if (info.failed) {
        if (mounted) {
          setState(() {
            _hasFailed = true;
            _isProcessing = false;
          });
        }
        return;
      }
      if (!info.ready) {
        await _audioService.processAndPlay(video);
      }
    } catch (_) {}
    if (mounted) setState(() => _isProcessing = false);
  }

  void _togglePlayPause() {
    if (_audioService.isPlaying) {
      _audioService.pause();
    } else {
      _audioService.resume();
    }
  }

  void _retryProcessing() {
    final video = _audioService.currentVideo;
    if (video == null) return;
    setState(() {
      _hasFailed = false;
      _isProcessing = true;
    });
    _audioService.processAndPlay(video);
  }

  @override
  Widget build(BuildContext context) {
    final video = _audioService.currentVideo;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: video == null
          ? const Center(
              child: Text('No audio loaded',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
            )
          : _buildContent(video, bottomPadding),
    );
  }

  Widget _buildContent(VideoPost video, double bottomPadding) {
    return SafeArea(
      child: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: _audioService.isLoading || _isProcessing
                ? _buildLoading(video)
                : _hasFailed
                    ? _buildFailed(video)
                    : _audioService.isReady
                        ? _buildPlayer(video, bottomPadding)
                        : _buildNotReady(video),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down,
                color: Colors.white, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'NOW PLAYING',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  String _resolveThumbnail(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('/')) return '${StarlightConstants.apiBaseUrl}$url';
    return url;
  }

  Widget _buildArtwork(VideoPost video, {double size = 280}) {
    final thumbUrl = _resolveThumbnail(video.thumbnailUrl);
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _audioService.isPlaying
              ? _rotationController.value * 6.283185307
              : 0,
          child: child,
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: StarlightTheme.primaryBlue.withOpacity(0.3),
              blurRadius: 40,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ClipOval(
          child: thumbUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: thumbUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _buildDefaultArtwork(size),
                  errorWidget: (_, __, ___) => _buildDefaultArtwork(size),
                )
              : _buildDefaultArtwork(size),
        ),
      ),
    );
  }

  Widget _buildDefaultArtwork(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A237E), Color(0xFF7C4DFF)],
        ),
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.35,
        color: Colors.white.withOpacity(0.8),
      ),
    );
  }

  Widget _buildSlider() {
    final duration = _audioService.duration;
    final position = _audioService.position;
    final maxMs = duration.inMilliseconds.toDouble();
    final posMs = position.inMilliseconds.toDouble().clamp(0.0, maxMs > 0 ? maxMs : 1.0);

    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: Colors.white12,
          ),
          child: Slider(
            value: posMs,
            max: maxMs > 0 ? maxMs : 1,
            onChanged: (v) {
              _audioService.seek(Duration(milliseconds: v.toInt()));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(position),
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Text(_fmt(duration),
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36),
          onPressed: () => _audioService.player.seekToPrevious(),
        ),
        const SizedBox(width: 24),
        _buildPlayButton(),
        const SizedBox(width: 24),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 36),
          onPressed: () => _audioService.player.seekToNext(),
        ),
      ],
    );
  }

  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Icon(
          _audioService.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          size: 40,
          color: const Color(0xFF0A0A0A),
        ),
      ),
    );
  }

  Widget _buildLoading(VideoPost video) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildArtwork(video, size: 220),
          const SizedBox(height: 40),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _audioService.isLoading ? 'Preparing audio...' : 'Extracting audio...',
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFailed(VideoPost video) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildArtwork(video, size: 200),
          const SizedBox(height: 32),
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
          const SizedBox(height: 12),
          Text(
            'Audio extraction failed',
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Could not process audio for this video',
            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _retryProcessing,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: StarlightTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotReady(VideoPost video) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildArtwork(video, size: 200),
          const SizedBox(height: 32),
          Icon(Icons.headphones_rounded, color: Colors.white24, size: 40),
          const SizedBox(height: 12),
          Text(
            'Audio not available',
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap below to extract audio from this video',
            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _isProcessing = true);
              _audioService.processAndPlay(video);
            },
            icon: const Icon(Icons.headphones_rounded, size: 18),
            label: const Text('Generate Audio'),
            style: ElevatedButton.styleFrom(
              backgroundColor: StarlightTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer(VideoPost video, double bottomPadding) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _buildArtwork(video),
          const Spacer(flex: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              video.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            video.uploaderName,
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
          ),
          const Spacer(flex: 1),
          _buildSlider(),
          const SizedBox(height: 8),
          _buildControls(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
