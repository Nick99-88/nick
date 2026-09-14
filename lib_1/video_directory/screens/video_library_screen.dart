import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../models/video_models.dart';
import '../services/video_service.dart';
import '../services/shorts_service.dart';
import '../widgets/video_widgets.dart';
import '../widgets/video_upload_progress.dart';
import '../services/video_download_service.dart';
import 'video_player_screen.dart';
import 'shorts_player_screen.dart';
import 'playlist_detail_screen.dart';
import 'channel_screen.dart';
import 'downloads_screen.dart';

class VideoLibraryScreen extends StatefulWidget {
  const VideoLibraryScreen({super.key});

  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen> {
  int _currentIndex = 0;
  Channel? _myChannel;
  List<VideoPost> _myVideos = [];
  List<VideoPost> _likedVideos = [];
  List<VideoPost> _history = [];
  List<Map<String, dynamic>> _playlists = [];
  List<Map<String, dynamic>> _pendingUploads = [];
  List<ShortsPost> _myShorts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        VideoService.getUserVideos('me'),
        VideoService.getLikedVideos(),
        VideoService.getWatchHistory(),
        ShortsService.getMyShorts(),
      ]);

      Channel? channel;
      try {
        channel = await VideoService.getChannel('me');
      } catch (e) {
        debugPrint('📹 Library _loadData: getChannel failed (normal for new users) — $e');
      }

      if (mounted) {
        final my = results[0] as List<VideoPost>;
        final liked = results[1] as List<VideoPost>;
        final history = results[2] as List<VideoPost>;
        final shorts = results[3] as List<ShortsPost>;
        setState(() {
          _myVideos = my;
          _likedVideos = liked;
          _history = history;
          _myShorts = shorts;
          _myChannel = channel;
        });
      }

      await _loadPlaylists();
    } catch (e) {
      debugPrint('📹 Library _loadData: EXCEPTION — $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reloadVideosOnly() async {
    try {
      final results = await Future.wait([
        VideoService.getUserVideos('me'),
        VideoService.getLikedVideos(),
        VideoService.getWatchHistory(),
        VideoService.getPendingUploads(),
      ]);
      if (mounted) {
        setState(() {
          _myVideos = results[0] as List<VideoPost>;
          _likedVideos = results[1] as List<VideoPost>;
          _history = results[2] as List<VideoPost>;
          _pendingUploads = results[3] as List<Map<String, dynamic>>;
        });
      }
      await _loadPlaylists();
    } catch (e) {
      debugPrint('📹 _reloadVideosOnly: $e');
    }
  }

  Future<void> _loadPlaylists() async {
    try {
      final playlists = await VideoService.getPlaylists();
      if (mounted) {
        setState(() {
          _playlists = playlists.map((p) => {
            'id': p.id,
            'title': p.title,
            'thumbnail': p.thumbnailUrl,
            'videoCount': p.videoCount,
            'updatedAt': p.updatedAt,
          }).toList();
          _isLoading = false;
        });
      }
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
        title: Text(
          _myChannel?.name ?? 'My Channel',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildCurrentTab(),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF0F0F0F),
        indicatorColor: StarlightTheme.primaryBlue.withAlpha(51),
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person, color: Colors.grey), selectedIcon: Icon(Icons.person, color: StarlightTheme.primaryBlue), label: 'My Channel'),
          NavigationDestination(icon: Icon(Icons.thumb_up, color: Colors.grey), selectedIcon: Icon(Icons.thumb_up, color: StarlightTheme.primaryBlue), label: 'Liked'),
          NavigationDestination(icon: Icon(Icons.history, color: Colors.grey), selectedIcon: Icon(Icons.history, color: StarlightTheme.primaryBlue), label: 'History'),
          NavigationDestination(icon: Icon(Icons.playlist_play, color: Colors.grey), selectedIcon: Icon(Icons.playlist_play, color: StarlightTheme.primaryBlue), label: 'Playlists'),
          NavigationDestination(icon: Icon(Icons.download_outlined, color: Colors.grey), selectedIcon: Icon(Icons.download_outlined, color: StarlightTheme.primaryBlue), label: 'Downloads'),
        ],
      ),
    );
  }

  Widget _buildShortPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[900]!, Colors.black],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_fill, color: StarlightTheme.primaryBlue, size: 32),
            SizedBox(height: 4),
            Text('Short', style: TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0: return _buildMyChannelTab();
      case 1: return _buildVideoList(_likedVideos, 'No liked videos');
      case 2: return _buildVideoList(_history, 'No watch history');
      case 3: return _buildPlaylistsTab();
      case 4: return _buildDownloadsTab();
      default: return _buildMyChannelTab();
    }
  }

  Widget _buildDownloadsTab() {
    return const DownloadsScreen();
  }

  Widget _buildMyChannelTab() {
    if (_myChannel == null || !_myChannel!.hasChannel) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VideoWidgets.buildEmptyState(
              icon: Icons.person,
              title: 'No channel yet',
              subtitle: 'Create your channel to start sharing videos',
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showCreateChannelDialog,
              icon: const Icon(Icons.add),
              label: Text('Create Channel', style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                backgroundColor: StarlightTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
            ),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChannelScreen(channelId: _myChannel!.id, initialName: _myChannel!.name)),
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: StarlightTheme.primaryBlue,
                  child: Text(
                    _myChannel!.name.isNotEmpty ? _myChannel!.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _myChannel!.name,
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatCount(_myChannel!.subscriberCount)} subscribers',
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChannelScreen(channelId: _myChannel!.id, initialName: _myChannel!.name)),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text('View Channel', style: GoogleFonts.poppins()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StarlightTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_pendingUploads.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Pending Uploads',
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ..._pendingUploads.map((p) => _buildPendingUploadCard(p)),
          const Divider(color: Colors.grey, height: 1),
        ],
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'My Videos',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        if (_myVideos.isEmpty)
          VideoWidgets.buildEmptyState(
            icon: Icons.video_library,
            title: 'No videos uploaded yet',
            subtitle: 'Upload your first video',
          )
        else
          ..._myVideos.map((v) => VideoWidgets.buildVideoCard(
            context, v,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: v))),
            onAddToPlaylist: () => _addVideoToPlaylist(v),
            onDelete: () => _deleteVideo(v),
          )),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'My Shorts',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        if (_myShorts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: VideoWidgets.buildEmptyState(
              icon: Icons.play_circle_outline,
              title: 'No shorts uploaded yet',
              subtitle: 'Upload your first short',
            ),
          )
        else
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _myShorts.length,
              itemBuilder: (context, index) {
                final short = _myShorts[index];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShortsPlayerScreen(
                        shorts: _myShorts,
                        initialIndex: index,
                      ),
                    ),
                  ),
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A1A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: short.thumbnailUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          short.thumbnailUrl.startsWith('/')
                                              ? '${StarlightConstants.apiBaseUrl}${short.thumbnailUrl}'
                                              : short.thumbnailUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          errorBuilder: (_, __, ___) => _buildShortPlaceholder(),
                                        ),
                                      )
                                    : _buildShortPlaceholder(),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _deleteShort(short),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          short.title,
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPendingUploadCard(Map<String, dynamic> pending) {
    final sessionId = pending['session_id'] as String;
    final title = pending['title'] as String? ?? '';
    final filename = pending['filename'] as String? ?? '';
    final totalSize = pending['total_size'] as int? ?? 0;
    final uploadedBytes = pending['uploaded_bytes'] as int? ?? 0;
    final progress = pending['progress'] as double? ?? 0;

    return FutureBuilder<Map<String, dynamic>?>(
      future: StarlightStorage.getUploadState(sessionId),
      builder: (context, snapshot) {
        final filePath = snapshot.data?['file_path'] as String?;
        final fileExists = filePath != null && File(filePath).existsSync();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cloud_upload, color: Colors.orange, size: 28),
            ),
            title: Text(
              title.isNotEmpty ? title : filename,
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '$progress%',
                      style: GoogleFonts.poppins(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          backgroundColor: Colors.grey[800],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatBytes(uploadedBytes)} / ${_formatBytes(totalSize)}',
                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ),
            trailing: fileExists
                ? TextButton(
                    onPressed: () => _resumeUpload(sessionId, filePath!, totalSize),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                    child: Text('Resume', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  )
                : IconButton(
                    onPressed: () => _removePending(sessionId),
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _resumeUpload(String sessionId, String filePath, int totalSize) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video file no longer found'), backgroundColor: Colors.red),
        );
      }
      setState(() => _pendingUploads.removeWhere((p) => p['session_id'] == sessionId));
      return;
    }

    final actualSize = file.lengthSync();
    if (actualSize != totalSize) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File size mismatch (expected ${_formatBytes(totalSize)}, got ${_formatBytes(actualSize)}). File may have been modified.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoUploadProgressScreen(
          videoFile: file,
          sessionId: sessionId,
          totalSize: totalSize,
        ),
      ),
    );
  }

  Future<void> _removePending(String sessionId) async {
    try {
      await VideoService.cancelChunkUpload(sessionId);
    } catch (_) {}
    await StarlightStorage.clearUploadState(sessionId);
    setState(() => _pendingUploads.removeWhere((p) => p['session_id'] == sessionId));
  }

  void _showCreateChannelDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Create Channel', style: GoogleFonts.poppins(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Channel Name',
                labelStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Color(0xFF2A2A2A),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                labelStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Color(0xFF2A2A2A),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              try {
                final channel = await VideoService.updateChannel(
                  name: name,
                  description: descController.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() => _myChannel = channel);
                _reloadVideosOnly();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: StarlightTheme.primaryBlue),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList(List<VideoPost> videos, String emptyMessage, {bool showDelete = false}) {
    debugPrint('📹 _buildVideoList: count=${videos.length} emptyMessage=$emptyMessage');
    if (videos.isEmpty) {
      return VideoWidgets.buildEmptyState(
        icon: Icons.video_library,
        title: emptyMessage,
        subtitle: 'Videos will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        debugPrint('📹 rendering card $index: id=${video.id} title=${video.title}');
        return VideoWidgets.buildVideoCard(
          context,
          video,
          onTap: () {
            debugPrint('📹 tapped video: id=${video.id} title=${video.title}');
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: video)),
            );
          },
          onAddToPlaylist: () => _addVideoToPlaylist(video),
          onDelete: showDelete ? () => _deleteVideo(video) : null,
          onUploaderTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChannelScreen(channelId: video.uploaderId, initialName: video.uploaderName),
          )),
        );
      },
    );
  }

  Future<void> _deleteShort(ShortsPost short) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete Short', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${short.title}"? This cannot be undone.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ShortsService.deleteShort(short.id);
      setState(() {
        _myShorts.removeWhere((s) => s.id == short.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Short deleted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteVideo(VideoPost video) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Delete Video', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${video.title}"? This cannot be undone.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await VideoService.deleteVideo(video.id);
      setState(() {
        _myVideos.removeWhere((v) => v.id == video.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video deleted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addVideoToPlaylist(VideoPost video) async {
    try {
      final playlists = await VideoService.getPlaylists();
      if (playlists.isEmpty) {
        final create = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: Text('No Playlists', style: GoogleFonts.poppins(color: Colors.white)),
            content: Text('Create a playlist first?', style: GoogleFonts.poppins(color: Colors.grey)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
            ],
          ),
        );
        if (create == true) _createPlaylist();
        return;
      }

      final selected = await showDialog<Playlist>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text('Add to Playlist', style: GoogleFonts.poppins(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(playlists[i].title, style: GoogleFonts.poppins(color: Colors.white)),
                subtitle: Text('${playlists[i].videoCount} videos', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                leading: const Icon(Icons.playlist_play, color: StarlightTheme.primaryBlue),
                onTap: () => Navigator.pop(ctx, playlists[i]),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ],
        ),
      );

      if (selected == null) return;
      await VideoService.addVideoToPlaylist(selected.id, video.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added to "${selected.title}"'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildPlaylistsTab() {
    if (_playlists.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          VideoWidgets.buildEmptyState(
            icon: Icons.playlist_play,
            title: 'No playlists',
            subtitle: 'Create playlists to organize your videos',
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _createPlaylist,
            icon: const Icon(Icons.add),
            label: const Text('Create Playlist'),
            style: ElevatedButton.styleFrom(
              backgroundColor: StarlightTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _createPlaylist,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Playlist'),
              style: ElevatedButton.styleFrom(
                backgroundColor: StarlightTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _playlists.length,
            itemBuilder: (context, index) {
              final playlist = _playlists[index];
              return _buildPlaylistCard(playlist);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistCard(Map<String, dynamic> playlist) {
    return InkWell(
      onTap: () => _openPlaylist(playlist),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.playlist_play, color: Colors.grey, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist['title'],
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${playlist['videoCount']} videos • Updated ${_formatDate(playlist['updatedAt'])}',
                    style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onPressed: () => _showPlaylistOptions(playlist),
            ),
          ],
        ),
      ),
    );
  }

  void _createPlaylist() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text('New Playlist', style: GoogleFonts.poppins(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Playlist name',
              hintStyle: TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Color(0xFF2A2A2A),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  try {
                    await VideoService.createPlaylist(name);
                    Navigator.pop(context);
                    _loadData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _openPlaylist(Map<String, dynamic> playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailScreen(playlistId: playlist['id'], title: playlist['title']),
      ),
    );
  }

  void _showPlaylistOptions(Map<String, dynamic> playlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: Text('Rename', style: GoogleFonts.poppins(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _renamePlaylist(playlist);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deletePlaylist(playlist);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _renamePlaylist(Map<String, dynamic> playlist) {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: playlist['title']);
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text('Rename Playlist', style: GoogleFonts.poppins(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Playlist name',
              hintStyle: TextStyle(color: Colors.grey),
              filled: true,
              fillColor: Color(0xFF2A2A2A),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  try {
                    await VideoService.updatePlaylist(playlist['id'], name);
                    Navigator.pop(context);
                    _loadData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deletePlaylist(Map<String, dynamic> playlist) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Delete Playlist', style: GoogleFonts.poppins(color: Colors.white)),
        content: Text('Delete "${playlist['title']}"?', style: GoogleFonts.poppins(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
              onPressed: () async {
              try {
                await VideoService.deletePlaylist(playlist['id']);
                if (context.mounted) Navigator.pop(context);
                setState(() {
                  _playlists.removeWhere((p) => p['id'] == playlist['id']);
                });
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete playlist: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      final abs = diff.isNegative ? -diff : diff;
      if (abs.inDays > 365) return '${(abs.inDays ~/ 365)}y ago';
      if (abs.inDays > 30) return '${(abs.inDays ~/ 30)}mo ago';
      if (abs.inDays > 0) return '${abs.inDays}d ago';
      return 'Today';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toInt()} KB';
    return '$bytes B';
  }
}
