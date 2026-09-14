import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as thumb;
import '../../core/theme.dart';

class ShortsFrameSelectorScreen extends StatefulWidget {
  final File videoFile;

  const ShortsFrameSelectorScreen({super.key, required this.videoFile});

  @override
  State<ShortsFrameSelectorScreen> createState() => _ShortsFrameSelectorScreenState();
}

class _ShortsFrameSelectorScreenState extends State<ShortsFrameSelectorScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _disposed = false;

  final List<File> _filmstripFrames = [];
  bool _generatingFrames = true;

  Duration _selectedPosition = Duration.zero;
  bool _isSeeking = false;
  bool _isPlaying = false;

  static const int _frameSampleCount = 12;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    _controller = VideoPlayerController.file(widget.videoFile);
    await _controller.initialize();
    if (_disposed) return;

    _controller.setLooping(true);
    _controller.setVolume(0);

    setState(() {
      _isInitialized = true;
      _selectedPosition = _controller.value.position;
    });

    _controller.addListener(_onPlayerTick);
    _generateFilmstrip();
  }

  void _onPlayerTick() {
    if (_disposed || _isSeeking || !_isInitialized) return;
    final pos = _controller.value.position;
    final dur = _controller.value.duration;
    if (dur.inMilliseconds > 0) {
      setState(() => _selectedPosition = pos);
    }
  }

  Future<void> _generateFilmstrip() async {
    setState(() => _generatingFrames = true);
    _filmstripFrames.clear();

    final duration = _controller.value.duration;
    if (duration.inMilliseconds <= 0) {
      if (mounted) setState(() => _generatingFrames = false);
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final sampleCount = min(_frameSampleCount, (duration.inSeconds * 2).ceil().clamp(4, _frameSampleCount));

    for (int i = 0; i < sampleCount; i++) {
      if (_disposed) return;
      final timeMs = (duration.inMilliseconds * i / (sampleCount - 1)).round();

      try {
        final path = await thumb.VideoThumbnail.thumbnailFile(
          video: widget.videoFile.path,
          thumbnailPath: tempDir.path,
          imageFormat: thumb.ImageFormat.JPEG,
          quality: 50,
          maxWidth: 120,
          maxHeight: 200,
          timeMs: timeMs,
        );
        if (path != null && !_disposed) {
          _filmstripFrames.add(File(path));
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _generatingFrames = false);
  }

  void _onSliderChangeStart(double value) {
    _isSeeking = true;
    if (_isPlaying) {
      _controller.pause();
    }
    final duration = _controller.value.duration;
    final pos = Duration(milliseconds: (value * duration.inMilliseconds).round());
    _controller.seekTo(pos);
    setState(() => _selectedPosition = pos);
  }

  void _onSliderChanged(double value) {
    final duration = _controller.value.duration;
    final pos = Duration(milliseconds: (value * duration.inMilliseconds).round());
    _controller.seekTo(pos);
    setState(() => _selectedPosition = pos);
  }

  void _onSliderChangeEnd(double value) {
    _isSeeking = false;
    final duration = _controller.value.duration;
    final pos = Duration(milliseconds: (value * duration.inMilliseconds).round());
    _controller.seekTo(pos);
    setState(() => _selectedPosition = pos);
  }

  void _onFilmstripTap(int index) {
    if (_filmstripFrames.isEmpty) return;
    if (_isPlaying) {
      _controller.pause();
      setState(() => _isPlaying = false);
    }
    final duration = _controller.value.duration;
    final pos = Duration(
      milliseconds: (duration.inMilliseconds * index / (_filmstripFrames.length - 1)).round(),
    );
    _isSeeking = true;
    _controller.seekTo(pos);
    setState(() => _selectedPosition = pos);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!_disposed) _isSeeking = false;
    });
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
      setState(() => _isPlaying = false);
    } else {
      _controller.play();
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _selectFrame() async {
    final duration = _controller.value.duration;
    if (duration.inMilliseconds <= 0) return;

    final timeMs = _selectedPosition.inMilliseconds;

    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/shorts_thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      final result = await thumb.VideoThumbnail.thumbnailFile(
        video: widget.videoFile.path,
        thumbnailPath: tempDir.path,
        imageFormat: thumb.ImageFormat.JPEG,
        quality: 95,
        maxWidth: 1080,
        maxHeight: 1920,
        timeMs: timeMs,
      );

      if (result != null && mounted) {
        Navigator.pop(context, File(result));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture frame'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    final ms = (d.inMilliseconds % 1000) ~/ 100;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.$ms';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select Thumbnail',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isInitialized ? _buildBody() : _buildLoading(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: StarlightTheme.primaryBlue),
    );
  }

  Widget _buildBody() {
    final aspectRatio = _controller.value.aspectRatio;
    final duration = _controller.value.duration;
    final progress = duration.inMilliseconds > 0
        ? _selectedPosition.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Column(
      children: [
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Stack(
                  children: [
                    VideoPlayer(_controller),
                    if (!_isPlaying)
                      Center(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(14),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                        ),
                      ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(_selectedPosition),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: StarlightTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'of ${_formatDuration(duration)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildSlider(progress, duration),
        const SizedBox(height: 8),
        _buildFilmstrip(),
        const SizedBox(height: 12),
        _buildSelectButton(),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ],
    );
  }

  Widget _buildSlider(double progress, Duration duration) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: StarlightTheme.primaryBlue,
              inactiveTrackColor: Colors.grey[800],
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayColor: StarlightTheme.primaryBlue.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: _onSliderChanged,
              onChangeStart: _onSliderChangeStart,
              onChangeEnd: _onSliderChangeEnd,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_selectedPosition),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilmstrip() {
    if (_filmstripFrames.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: _generatingFrames
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: StarlightTheme.primaryBlue),
                    ),
                    const SizedBox(width: 8),
                    Text('Generating frames...', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                )
              : Text('No frames available', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ),
      );
    }

    final duration = _controller.value.duration;
    final selectedMs = _selectedPosition.inMilliseconds;
    final totalMs = duration.inMilliseconds > 0 ? duration.inMilliseconds : 1;

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _filmstripFrames.length,
        itemBuilder: (context, index) {
          final frameMs = (totalMs * index / (_filmstripFrames.length - 1)).round();
          final distance = (selectedMs - frameMs).abs();
          final isNearSelected = distance < (totalMs / _filmstripFrames.length / 2);

          return GestureDetector(
            onTap: () => _onFilmstripTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isNearSelected ? StarlightTheme.primaryBlue : Colors.grey[800]!,
                  width: isNearSelected ? 2.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.file(
                  _filmstripFrames[index],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _selectFrame,
          icon: const Icon(Icons.check, size: 20),
          label: Text(
            'Use This Frame',
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: StarlightTheme.primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
