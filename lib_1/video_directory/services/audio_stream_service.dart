import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';

class AudioStreamService {
  static String get _baseUrl => StarlightConstants.apiBaseUrl;

  static Future<Map<String, String>> _headers() async {
    final token = await StarlightStorage.getUserToken();
    return {'Authorization': 'Bearer $token'};
  }

  /// Get audio stream info (chunk metadata)
  static Future<AudioStreamInfo> getAudioInfo(String videoId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/$videoId/audio/info'),
      headers: await _headers(),
    );

    if (res.statusCode == 200) {
      return AudioStreamInfo.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load audio info');
  }

  /// Trigger audio extraction for a video
  static Future<void> triggerProcessing(String videoId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/video/$videoId/audio/process'),
      headers: await _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to trigger audio processing');
    }
  }

  /// Build concatenated audio source from chunks
  static Future<ConcatenatingAudioSource> buildAudioSource(AudioStreamInfo info) async {
    final sources = <AudioSource>[];
    for (final chunk in info.chunks) {
      sources.add(ProgressiveAudioSource(Uri.parse(chunk.chunkUrl)));
    }
    return ConcatenatingAudioSource(
      children: sources,
      useLazyPreparation: true,
    );
  }
}

class AudioStreamInfo {
  final bool ready;
  final bool failed;
  final String videoId;
  final int totalChunks;
  final double chunkDuration;
  final double totalDuration;
  final List<AudioChunk> chunks;

  AudioStreamInfo({
    required this.ready,
    this.failed = false,
    required this.videoId,
    required this.totalChunks,
    required this.chunkDuration,
    required this.totalDuration,
    required this.chunks,
  });

  factory AudioStreamInfo.fromJson(Map<String, dynamic> json) {
    final chunksList = (json['chunks'] as List<dynamic>?) ?? [];
    return AudioStreamInfo(
      ready: json['ready'] ?? false,
      failed: json['failed'] ?? false,
      videoId: json['video_id'] ?? '',
      totalChunks: json['total_chunks'] ?? 0,
      chunkDuration: (json['chunk_duration'] ?? 10).toDouble(),
      totalDuration: (json['total_duration'] ?? 0).toDouble(),
      chunks: chunksList.map((c) => AudioChunk.fromJson(c)).toList(),
    );
  }
}

class AudioChunk {
  final String id;
  final String videoId;
  final int chunkIndex;
  final String chunkUrl;
  final double startTime;
  final double endTime;
  final int fileSize;

  AudioChunk({
    required this.id,
    required this.videoId,
    required this.chunkIndex,
    required this.chunkUrl,
    required this.startTime,
    required this.endTime,
    required this.fileSize,
  });

  factory AudioChunk.fromJson(Map<String, dynamic> json) {
    return AudioChunk(
      id: json['id'] ?? '',
      videoId: json['video_id'] ?? '',
      chunkIndex: json['chunk_index'] ?? 0,
      chunkUrl: json['chunk_url'] ?? '',
      startTime: (json['start_time'] ?? 0).toDouble(),
      endTime: (json['end_time'] ?? 0).toDouble(),
      fileSize: json['file_size'] ?? 0,
    );
  }
}
