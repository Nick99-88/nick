import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../services/call_recording_service.dart';
import 'rtc_recording_player_screen.dart';

/// Lists all locally-saved call recordings (no server involved) and lets the
/// user play, export/share, or delete each one.
class RtcRecordingsHistoryScreen extends StatefulWidget {
  const RtcRecordingsHistoryScreen({super.key});

  @override
  State<RtcRecordingsHistoryScreen> createState() => _RtcRecordingsHistoryScreenState();
}

class _RtcRecordingsHistoryScreenState extends State<RtcRecordingsHistoryScreen> {
  final CallRecordingService _service = CallRecordingService();
  List<RecordingEntry> _recordings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _service.getAllRecordings();
    if (mounted) setState(() {
      _recordings = list;
      _loading = false;
    });
  }

  Future<void> _delete(RecordingEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B3A),
        title: const Text('Delete recording?', style: TextStyle(color: Colors.white)),
        content: Text('This will permanently delete the recording of "${entry.roomName}".',
          style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteRecording(entry.id);
      _load();
    }
  }

  Future<void> _export(RecordingEntry entry) async {
    final files = entry.segmentPaths
        .where((p) => File(p).existsSync())
        .map((p) => XFile(p))
        .toList();
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording files not found')));
      return;
    }
    await Share.shareXFiles(files, text: 'Recording of ${entry.roomName}');
  }

  String _formatDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('MMM d, yyyy · h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0C20),
        title: const Text('Call Recordings', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _recordings.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_off, size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text('No recordings yet', style: TextStyle(color: Colors.white54, fontSize: 16)),
                      SizedBox(height: 8),
                      Text('Record a call to see it here', style: TextStyle(color: Colors.white38, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _recordings.length,
                  itemBuilder: (_, i) {
                    final entry = _recordings[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B3A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          // Thumbnail — always audio icon
                          Container(
                            width: 88, height: 88,
                            decoration: const BoxDecoration(
                              color: Color(0xFF15102A),
                              borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
                            ),
                            child: const Icon(Icons.mic, color: Colors.deepPurpleAccent, size: 32),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.roomName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text('By ${entry.recorderName} · ${_formatDate(entry.createdAtMs)}',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text('Duration ${formatRecordingDuration(entry.durationMs)}',
                                    style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                          Column(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => RtcRecordingPlayerScreen(entry: entry)),
                                ),
                                icon: const Icon(Icons.play_arrow, color: Colors.deepPurpleAccent),
                                tooltip: 'Play',
                              ),
                              IconButton(
                                onPressed: () => _export(entry),
                                icon: const Icon(Icons.share, color: Colors.white70),
                                tooltip: 'Export / Share',
                              ),
                              IconButton(
                                onPressed: () => _delete(entry),
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
