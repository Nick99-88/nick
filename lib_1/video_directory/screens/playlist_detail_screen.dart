import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../models/video_models.dart';
import '../services/video_service.dart';
import '../widgets/video_widgets.dart';
import 'video_player_screen.dart';
import 'channel_screen.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  final String title;

  const PlaylistDetailScreen({super.key, required this.playlistId, required this.title});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  List<VideoPost> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);
    try {
      final videos = await VideoService.getPlaylistVideos(widget.playlistId);
      if (mounted) setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        title: Text(widget.title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? VideoWidgets.buildEmptyState(
                  icon: Icons.playlist_play,
                  title: 'Empty playlist',
                  subtitle: 'Add videos to this playlist',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    final video = _videos[index];
                    return VideoWidgets.buildVideoCard(
                      context,
                      video,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: video)),
                      ),
                      onUploaderTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ChannelScreen(channelId: video.uploaderId, initialName: video.uploaderName),
                      )),
                    );
                  },
                ),
    );
  }
}
