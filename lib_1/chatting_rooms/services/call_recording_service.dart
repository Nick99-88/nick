import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// A single locally-saved call recording session.
///
/// Because flutter_webrtc's [MediaRecorder] has no native pause/resume on
/// Android, a "pause" is implemented by finalizing the current segment and
/// starting a fresh one on resume. A recording is therefore a list of segment
/// files played back sequentially but presented to the user as one recording.
class RecordingEntry {
  final String id;
  final String roomId;
  final String roomName;
  final String recorderName;
  final int createdAtMs;
  final int durationMs;
  final List<String> segmentPaths;
  final bool hasVideo;
  final String? thumbnailPath;

  RecordingEntry({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.recorderName,
    required this.createdAtMs,
    required this.durationMs,
    required this.segmentPaths,
    required this.hasVideo,
    this.thumbnailPath,
  });

  factory RecordingEntry.fromJson(Map<String, dynamic> json) => RecordingEntry(
        id: json['id'],
        roomId: json['roomId'],
        roomName: json['roomName'],
        recorderName: json['recorderName'],
        createdAtMs: json['createdAtMs'],
        durationMs: json['durationMs'],
        segmentPaths: List<String>.from(json['segmentPaths'] ?? []),
        hasVideo: json['hasVideo'] ?? true,
        thumbnailPath: json['thumbnailPath'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomId': roomId,
        'roomName': roomName,
        'recorderName': recorderName,
        'createdAtMs': createdAtMs,
        'durationMs': durationMs,
        'segmentPaths': segmentPaths,
        'hasVideo': hasVideo,
        'thumbnailPath': thumbnailPath,
      };

  String get primaryPath => segmentPaths.isNotEmpty ? segmentPaths.first : '';
}

/// Records the in-call WebRTC media directly to the device (no server upload).
///
/// Works by recording the active speaker's video track together with the
/// device audio output (all remote participants' mixed audio) via
/// flutter_webrtc's [MediaRecorder]. Saves to the app's documents directory
/// and keeps an index of all recordings in a local JSON file.
class CallRecordingService {
  MediaRecorder? _recorder;
  bool _isRecording = false;
  bool _isPaused = false;

  String? _roomId;
  String? _roomName;
  String? _recorderName;
  bool _hasVideo = false;
  final List<String> _segmentPaths = [];
  int _segmentIndex = 0;
  DateTime? _segmentStart;
  int _accumulatedMs = 0;

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;

  /// Begins a new recording session.
  ///
  /// Records audio output (all remote participants' mixed audio) via
  /// flutter_webrtc's [MediaRecorder]. Produces a valid WebM file.
  /// Video track recording is omitted because the native MediaRecorder
  /// produces a raw bitstream (no container) that ExoPlayer cannot read.
  Future<void> start({
    required String roomId,
    required String roomName,
    required String recorderName,
  }) async {
    if (_isRecording) return;
    _roomId = roomId;
    _roomName = roomName;
    _recorderName = recorderName;
    _hasVideo = false;
    _segmentPaths.clear();
    _segmentIndex = 0;
    _accumulatedMs = 0;
    await _startSegment();
    _isRecording = true;
    _isPaused = false;
  }

  Future<void> _startSegment() async {
    final dir = await _recordingsDir();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'rec_${_roomId}_${stamp}_s${_segmentIndex}.webm';
    final path = p.join(dir.path, fileName);

    _recorder = MediaRecorder();
    await _recorder!.start(
      path,
      audioChannel: RecorderAudioChannel.OUTPUT,
    );
    _segmentPaths.add(path);
    _segmentStart = DateTime.now();
  }

  /// Pauses by finalizing the current segment. A new segment starts on resume.
  Future<void> pause() async {
    if (!_isRecording || _isPaused || _recorder == null) return;
    await _recorder!.stop();
    _accumulatedMs += DateTime.now().difference(_segmentStart!).inMilliseconds;
    _recorder = null;
    _isPaused = true;
  }

  /// Resumes recording into a new segment file.
  Future<void> resume() async {
    if (!_isRecording || !_isPaused) return;
    _segmentIndex++;
    await _startSegment();
    _isPaused = false;
  }

  /// Stops recording, persists metadata + thumbnail, and returns the entry.
  Future<RecordingEntry?> stop() async {
    if (!_isRecording) return null;
    if (_recorder != null) {
      await _recorder!.stop();
      _accumulatedMs += DateTime.now().difference(_segmentStart!).inMilliseconds;
    }
    _recorder = null;
    _isRecording = false;
    _isPaused = false;

    if (_segmentPaths.isEmpty) return null;

    final id = const Uuid().v4();

    final entry = RecordingEntry(
      id: id,
      roomId: _roomId ?? '',
      roomName: _roomName ?? 'Room',
      recorderName: _recorderName ?? 'You',
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      durationMs: _accumulatedMs,
      segmentPaths: List.from(_segmentPaths),
      hasVideo: _hasVideo,
    );
    await _appendEntry(entry);
    return entry;
  }

  // ── Local storage (JSON index) ──

  Future<Directory> _recordingsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'call_recordings'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _indexFile() async {
    final dir = await _recordingsDir();
    return File(p.join(dir.path, 'index.json'));
  }

  Future<List<RecordingEntry>> getAllRecordings() async {
    try {
      final file = await _indexFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final List<dynamic> list = jsonDecode(content);
      return list
          .map((e) => RecordingEntry.fromJson(e))
          .toList()
        ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    } catch (e) {
      debugPrint('Failed to read recordings index: $e');
      return [];
    }
  }

  Future<void> _appendEntry(RecordingEntry entry) async {
    final all = await getAllRecordings();
    all.removeWhere((e) => e.id == entry.id);
    all.add(entry);
    final file = await _indexFile();
    await file.writeAsString(jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  Future<void> deleteRecording(String id) async {
    final all = await getAllRecordings();
    final target = all.where((e) => e.id == id).firstOrNull;
    if (target != null) {
      for (final path in target.segmentPaths) {
        final f = File(path);
        if (await f.exists()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
      if (target.thumbnailPath != null) {
        final t = File(target.thumbnailPath!);
        if (await t.exists()) {
          try {
            await t.delete();
          } catch (_) {}
        }
      }
    }
    all.removeWhere((e) => e.id == id);
    final file = await _indexFile();
    await file.writeAsString(jsonEncode(all.map((e) => e.toJson()).toList()));
  }
}

String formatRecordingDuration(int ms) {
  final totalSec = (ms / 1000).floor();
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final s = totalSec % 60;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
