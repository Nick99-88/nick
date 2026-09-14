import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants.dart';
import '../../core/token_manager.dart';

class TtsConverterScreen extends StatefulWidget {
  const TtsConverterScreen({super.key});

  @override
  State<TtsConverterScreen> createState() => _TtsConverterScreenState();
}

class _TtsConverterScreenState extends State<TtsConverterScreen> {
  final _textController = TextEditingController();
  final _audioPlayer = AudioPlayer();
  final _dio = Dio();

  String _selectedLanguage = 'en';
  String _selectedGender = 'female';
  double _tone = 0.0;
  double _frequency = 1.0;
  bool _isConverting = false;
  String? _audioPath;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _hasCompleted = false;

  final Map<String, String> _languages = {
    'en': 'English (US)',
    'en-GB': 'English (UK)',
    'ar': 'Arabic',
    'ur': 'Urdu',
    'hi': 'Hindi',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'tr': 'Turkish',
  };

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _playerState = state;
          if (state == PlayerState.playing) _hasCompleted = false;
        });
      }
    });
    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _hasCompleted = true);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<String> _getAudioPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/starlight_tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
  }

  Future<void> _convert() async {
    if (_textController.text.trim().isEmpty) return;

    setState(() => _isConverting = true);

    try {
      final token = await TokenManager.instance.getValidToken();
      final baseUrl = StarlightConstants.apiBaseUrl;
      final path = await _getAudioPath();

      final response = await _dio.post(
        '$baseUrl/tts/convert',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Authorization': 'Bearer $token'},
        ),
        data: {
          'text': _textController.text.trim(),
          'language': _selectedLanguage,
          'gender': _selectedGender,
          'tone': _tone,
          'frequency': _frequency,
        },
      );

      if (response.statusCode == 200) {
        final file = File(path);
        await file.writeAsBytes(response.data as List<int>);
        if (await file.exists() && await file.length() > 0) {
          if (mounted) {
            setState(() {
              _audioPath = path;
              _hasCompleted = false;
              _position = Duration.zero;
              _duration = Duration.zero;
            });
            await _audioPlayer.stop();
            await _audioPlayer.setSourceDeviceFile(path);
            await _audioPlayer.resume();
          }
        } else {
          throw Exception('Audio file is empty');
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  Future<void> _saveToFiles() async {
    if (_audioPath == null) return;
    try {
      String saveDir;
      if (Platform.isAndroid) {
        saveDir = '/storage/emulated/0/Download';
      } else if (Platform.isIOS) {
        final dir = await getApplicationDocumentsDirectory();
        saveDir = dir.path;
      } else {
        final dir = await getDownloadsDirectory();
        saveDir = dir?.path ?? (await getApplicationDocumentsDirectory()).path;
      }

      final savePath = '$saveDir/starlight_tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
      await File(_audioPath!).copy(savePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to Downloads'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => OpenFile.open(savePath),
            ),
          ),
        );
      }
    } catch (e) {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/starlight_tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
      await File(_audioPath!).copy(savePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to app files'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => OpenFile.open(savePath),
            ),
          ),
        );
      }
    }
  }

  Future<void> _playPause() async {
    if (_audioPath == null) return;
    if (_playerState == PlayerState.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.setSourceDeviceFile(_audioPath!);
      _hasCompleted = false;
      await _audioPlayer.resume();
    }
  }

  Future<void> _replay() async {
    if (_audioPath == null) return;
    await _audioPlayer.stop();
    await _audioPlayer.setSourceDeviceFile(_audioPath!);
    _hasCompleted = false;
    await _audioPlayer.resume();
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Text to Speech'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter Text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _textController,
                    maxLines: 6,
                    maxLength: 5000,
                    decoration: InputDecoration(
                      hintText: 'Type or paste your text here...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Voice Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedLanguage,
                    decoration: InputDecoration(labelText: 'Language', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    items: _languages.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setState(() => _selectedLanguage = v ?? 'en'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedGender,
                          decoration: InputDecoration(labelText: 'Voice', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          items: const [
                            DropdownMenuItem(value: 'female', child: Text('Female')),
                            DropdownMenuItem(value: 'male', child: Text('Male')),
                          ],
                          onChanged: (v) => setState(() => _selectedGender = v ?? 'female'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Text('Tone (Pitch)', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('${_tone >= 0 ? '+' : ''}${_tone.toInt()}Hz', style: TextStyle(fontSize: 12, color: Colors.teal[700], fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  Slider(
                    value: _tone,
                    min: -50,
                    max: 50,
                    divisions: 100,
                    label: '${_tone.toInt()}Hz',
                    onChanged: (v) => setState(() => _tone = v),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Deep', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      Text('Normal', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      Text('High', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Speed', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('${(_frequency * 100).toInt()}%', style: TextStyle(fontSize: 12, color: Colors.teal[700], fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  Slider(
                    value: _frequency,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    label: '${(_frequency * 100).toInt()}%',
                    onChanged: (v) => setState(() => _frequency = v),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0.5x', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      Text('1x', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      Text('2x', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isConverting ? null : _convert,
                icon: _isConverting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.volume_up),
                label: Text(_isConverting ? 'Converting...' : 'Convert to Speech'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            if (_audioPath != null) ...[
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (_hasCompleted)
                          IconButton(
                            icon: Icon(Icons.replay, color: Colors.teal, size: 32),
                            onPressed: _replay,
                          )
                        else
                          IconButton(
                            icon: Icon(
                              _playerState == PlayerState.playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              color: Colors.teal,
                              size: 40,
                            ),
                            onPressed: _playPause,
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Slider(
                                value: _position.inMilliseconds.toDouble().clamp(0, _duration.inMilliseconds.toDouble().clamp(1, double.infinity)),
                                max: _duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                                onChanged: (v) => _audioPlayer.seek(Duration(milliseconds: v.toInt())),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(_position), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                  Text(_formatDuration(_duration), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!_hasCompleted && _playerState == PlayerState.playing)
                          IconButton(
                            icon: Icon(Icons.stop, color: Colors.grey[400], size: 22),
                            onPressed: () => _audioPlayer.stop(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _replay,
                            icon: const Icon(Icons.replay, size: 18),
                            label: const Text('Replay'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.teal,
                              side: const BorderSide(color: Colors.teal),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saveToFiles,
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Save'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.teal,
                              side: const BorderSide(color: Colors.teal),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
