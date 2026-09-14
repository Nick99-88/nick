import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../models/video_models.dart';
import '../services/video_service.dart';
import '../widgets/video_widgets.dart';
import 'video_player_screen.dart';
import 'video_upload_screen.dart';
import 'video_library_screen.dart';
import 'channel_screen.dart';
import 'shorts_home_screen.dart';

class VideoDirectory extends StatefulWidget {
  const VideoDirectory({super.key});

  @override
  State<VideoDirectory> createState() => _VideoDirectoryState();
}

class _VideoDirectoryState extends State<VideoDirectory> {
  int _currentIndex = 0;
  List<VideoPost> _feed = [];
  List<VideoPost> _trending = [];
  List<VideoPost> _subscriptions = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        VideoService.getFeed(),
        VideoService.getTrending(),
        VideoService.getSubscriptionsFeed(),
      ]);

      if (mounted) {
        setState(() {
          _feed = results[0];
          _trending = results[1];
          _subscriptions = results[2];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final results = await VideoService.searchVideos(query);
      if (mounted) {
        setState(() {
          _feed = results;
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
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search videos...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _search(),
              )
            : Text(
                'Starlight Videos',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
        centerTitle: true,
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () => setState(() => _isSearching = true),
            ),
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
                _loadData();
              },
            ),
          IconButton(
            icon: const Icon(Icons.video_library, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VideoLibraryScreen()),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildCurrentTab(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0F0F0F),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 2) {
            _navigateToUpload();
          } else {
            setState(() => _currentIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.subscriptions), label: 'Subscribed'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle, size: 36, color: StarlightTheme.primaryBlue), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.local_fire_department), label: 'Trending'),
          BottomNavigationBarItem(icon: Icon(Icons.movie), label: 'Shorts'),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return _buildFeedTab();
      case 1:
        return _buildSubscriptionsTab();
      case 3:
        return _buildTrendingTab();
      case 4:
        return _buildShortsTab();
      default:
        return _buildFeedTab();
    }
  }

  Widget _buildFeedTab() {
    if (_feed.isEmpty) {
      return VideoWidgets.buildEmptyState(
        icon: Icons.video_library,
        title: 'No videos yet',
        subtitle: 'Be the first to upload!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _feed.length,
      itemBuilder: (context, index) {
        final video = _feed[index];
        return VideoWidgets.buildVideoCard(
          context,
          video,
          onTap: () => _navigateToPlayer(video),
          onUploaderTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChannelScreen(channelId: video.uploaderId, initialName: video.uploaderName),
          )),
        );
      },
    );
  }

  Widget _buildSubscriptionsTab() {
    if (_subscriptions.isEmpty) {
      return VideoWidgets.buildEmptyState(
        icon: Icons.subscriptions,
        title: 'No subscriptions',
        subtitle: 'Subscribe to channels to see their videos here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _subscriptions.length,
      itemBuilder: (context, index) {
        final video = _subscriptions[index];
        return VideoWidgets.buildVideoCard(
          context,
          video,
          onTap: () => _navigateToPlayer(video),
          onUploaderTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChannelScreen(channelId: video.uploaderId, initialName: video.uploaderName),
          )),
        );
      },
    );
  }

  Widget _buildTrendingTab() {
    if (_trending.isEmpty) {
      return VideoWidgets.buildEmptyState(
        icon: Icons.local_fire_department,
        title: 'No trending videos',
        subtitle: 'Check back later',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _trending.length,
      itemBuilder: (context, index) {
        final video = _trending[index];
        return VideoWidgets.buildVideoCard(
          context,
          video,
          onTap: () => _navigateToPlayer(video),
          onUploaderTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChannelScreen(channelId: video.uploaderId, initialName: video.uploaderName),
          )),
        );
      },
    );
  }

  Widget _buildShortsTab() {
    return const ShortsHomeScreen();
  }

  void _navigateToPlayer(VideoPost video) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: video)),
    );
  }

  void _navigateToUpload() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VideoUploadScreen()),
    );
    if (result == true && mounted) {
      _loadData();
    }
  }
}
