import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import '../services/call_recording_service.dart';

/// Plays a locally-saved audio recording. A recording may consist of several
/// segment files (created when the user paused), which are played back
/// sequentially and presented to the user as one continuous recording.
class RtcRecordingPlayerScreen extends StatefulWidget {
  final RecordingEntry entry;
  const RtcRecordingPlayerScreen({super.key, required this.entry});

  @override
  State<RtcRecordingPlayerScreen> createState() => _RtcRecordingPlayerScreenState();
}

class _RtcRecordingPlayerScreenState extends State<RtcRecordingPlayerScreen> {
  final AudioPlayer _player = AudioPlayer();
  int _segIndex = 0;
  bool _loading = true;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadSegment(0);
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
      if (state.processingState == ProcessingState.completed) {
        _nextSegment();
      }
    });
    _player.positionStream.listen((pos) {
      if (!mounted) return;
      final total = _accumulatedDuration(_segIndex) + pos;
      setState(() => _totalDuration = total);
    });
  }

  Duration _accumulatedDuration(int upToIndex) {
    var d = Duration.zero;
    for (var i = 0; i < upToIndex && i < widget.entry.segmentPaths.length; i++) {
      // approximate — will be corrected once each segment loads
      d += const Duration(seconds: 1);
    }
    return d;
  }

  Future<void> _loadSegment(int index) async {
    if (index >= widget.entry.segmentPaths.length) {
      if (mounted) setState(() { _loading = false; _isPlaying = false; });
      return;
    }
    final path = widget.entry.segmentPaths[index];
    final file = File(path);
    if (!await file.exists()) {
      await _loadSegment(index + 1);
      return;
    }
    _segIndex = index;
    try {
      await _player.setFilePath(path);
      await _player.play();
      if (mounted) setState(() { _loading = false; _isPlaying = true; });
    } catch (e) {
      debugPrint('Audio segment load failed: $e');
      await _loadSegment(index + 1);
    }
  }

  void _nextSegment() {
    if (_segIndex + 1 < widget.entry.segmentPaths.length) {
      _loadSegment(_segIndex + 1);
    }
  }

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Future<void> _export() async {
    final files = widget.entry.segmentPaths
        .where((p) => File(p).existsSync())
        .map((p) => XFile(p))
        .toList();
    if (files.isEmpty) return;
    await Share.shareXFiles(files, text: 'Recording of ${widget.entry.roomName}');
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0C20),
        title: Text(widget.entry.roomName, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(onPressed: _export, icon: const Icon(Icons.share, color: Colors.white70)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mic, size: 80, color: Colors.deepPurpleAccent),
                const SizedBox(height: 12),
                Text(widget.entry.recorderName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(formatRecordingDuration(widget.entry.durationMs),
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 32),

                // Seek bar
                StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (ctx, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final total = _player.duration ?? Duration.zero;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(children: [
                        Slider(
                          value: total.inMilliseconds > 0
                              ? pos.inMilliseconds.toDouble().clamp(0.0, total.inMilliseconds.toDouble())
                              : 0.0,
                          min: 0,
                          max: total.inMilliseconds > 0 ? total.inMilliseconds.toDouble() : 1.0,
                          onChanged: (v) {
                            _player.seek(Duration(milliseconds: v.toInt()));
                          },
                          activeColor: Colors.deepPurpleAccent,
                          inactiveColor: Colors.white24,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_format(pos), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            Text(_format(total), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ]),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Skip back 10s
                    IconButton(
                      onPressed: () {
                        final pos = _player.position;
                        _player.seek(pos - const Duration(seconds: 10));
                      },
                      icon: const Icon(Icons.replay_10, color: Colors.white70, size: 32),
                    ),
                    const SizedBox(width: 24),
                    // Play / Pause
                    GestureDetector(
                      onTap: () {
                        if (_isPlaying) {
                          _player.pause();
                        } else {
                          _player.play();
                        }
                      },
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(color: Colors.deepPurpleAccent, shape: BoxShape.circle),
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Skip forward 10s
                    IconButton(
                      onPressed: () {
                        final pos = _player.position;
                        final total = _player.duration ?? Duration.zero;
                        final next = pos + const Duration(seconds: 10);
                        _player.seek(next > total ? total : next);
                      },
                      icon: const Icon(Icons.forward_10, color: Colors.white70, size: 32),
                    ),
                  ],
                ),

                if (widget.entry.segmentPaths.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('Part ${_segIndex + 1}/${widget.entry.segmentPaths.length}',
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ),
              ],
            ),
    );
  }
}
