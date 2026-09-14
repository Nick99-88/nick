import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../models/video_models.dart';
import '../services/video_service.dart';
import '../services/video_analytics_service.dart';
import '../widgets/video_widgets.dart';
import '../widgets/starlight_video_player.dart';
import '../widgets/download_dialog.dart';
import '../services/global_audio_service.dart';
import 'audio_player_screen.dart';
import 'channel_screen.dart';

class VideoPlayerScreen extends StatefulWidget {
  final VideoPost video;
  final bool isAudio;

  const VideoPlayerScreen({super.key, required this.video, this.isAudio = false});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _isProcessing = false;
  int _processingProgress = 0;
  String? _hlsUrl;
  String? _audioOnlyUrl;
  Map<String, String> _availableQualities = {};

  List<VideoComment> _comments = [];
  bool _loadingComments = false;
  bool _hasMoreComments = true;
  int _commentPage = 1;
  VideoComment? _replyToComment;
  final Set<String> _expandedReplies = {};
  final _commentController = TextEditingController();
  bool _showFullDescription = false;
  bool _showAllComments = false;

  late VideoPost _currentVideo;
  List<VideoPost> _moreVideos = [];
  bool _loadingMoreVideos = false;
  int _nextVideoIndex = 0;

  late int _likes;
  late int _dislikes;
  late bool _isLiked;
  late bool _isDisliked;
  late bool _isSubscribed;
  bool _isOwnVideo = false;
  bool _isFullScreen = false;
  final _videoPlayerKey = GlobalKey<StarlightVideoPlayerState>();
  Timer? _statusTimer;
  VideoAnalyticsTracker? _analyticsTracker;

  @override
  void initState() {
    super.initState();
    _currentVideo = widget.video;
    _likes = _currentVideo.likes;
    _dislikes = _currentVideo.dislikes;
    _isLiked = _currentVideo.isLiked;
    _isDisliked = _currentVideo.isDisliked;
    _isSubscribed = _currentVideo.isSubscribed;
    _initOwnVideo();
    _analyticsTracker = VideoAnalyticsTracker(_currentVideo.id);
    _checkVideoStatus();
    _loadComments();
    _loadMoreVideos();
    _incrementViews();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _commentController.dispose();
    _analyticsTracker?.dispose();
    GlobalAudioService.instance.stop();
    super.dispose();
  }

  String _resolveUrl(String url) {
    if (url.startsWith('/data/') || url.startsWith('/storage/') || url.startsWith('file://')) return url;
    return url.startsWith('/')
        ? '${StarlightConstants.apiBaseUrl}$url'
        : url;
  }

  Future<void> _checkVideoStatus() async {
    final videoUrl = _currentVideo.videoUrl;
    if (videoUrl.startsWith('/data/') || videoUrl.startsWith('/storage/') || videoUrl.startsWith('file://')) {
      setState(() {
        _hlsUrl = videoUrl;
        _audioOnlyUrl = widget.isAudio || videoUrl.endsWith('.mp3') ? videoUrl : null;
        _isInitialized = true;
        _isLoading = false;
      });
      return;
    }

    try {
      final hlsInfo = await VideoService.getHlsPlaylist(_currentVideo.id);

      if (hlsInfo.ready && hlsInfo.hlsUrl != null) {
        setState(() {
          _hlsUrl = hlsInfo.hlsUrl;
          _audioOnlyUrl = hlsInfo.audioOnlyUrl;
          _availableQualities = hlsInfo.qualities;
          _isInitialized = true;
          _isLoading = false;
        });
      } else {
        try {
          final status = await VideoService.getUploadStatus(_currentVideo.id);
          if (status.status == 'processing' || status.status == 'retrying') {
            setState(() {
              _isProcessing = true;
              _processingProgress = status.progress;
              _isLoading = false;
            });
          } else {
            setState(() {
              _hlsUrl = _resolveUrl(_currentVideo.videoUrl);
              _isInitialized = true;
              _isLoading = false;
            });
          }
        } catch (_) {
          setState(() {
            _hlsUrl = _resolveUrl(_currentVideo.videoUrl);
            _isInitialized = true;
            _isLoading = false;
          });
        }
        _pollHlsReady();
      }
    } catch (e) {
      setState(() {
        _hlsUrl = _resolveUrl(_currentVideo.videoUrl);
        _isInitialized = true;
        _isLoading = false;
      });
      _pollHlsReady();
    }
  }

  void _pollHlsReady() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        final hlsInfo = await VideoService.getHlsPlaylist(_currentVideo.id);
        if (hlsInfo.ready && hlsInfo.hlsUrl != null && mounted) {
          timer.cancel();
          setState(() {
            _isProcessing = false;
            _hlsUrl = hlsInfo.hlsUrl;
            _audioOnlyUrl = hlsInfo.audioOnlyUrl;
            _availableQualities = hlsInfo.qualities;
            _isInitialized = true;
          });
          return;
        }

        if (!mounted) { timer.cancel(); return; }

        final status = await VideoService.getUploadStatus(_currentVideo.id);
        if (!mounted) { timer.cancel(); return; }

        if (status.status == 'failed') {
          timer.cancel();
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Video processing failed: ${status.error}'), backgroundColor: Colors.red),
          );
        } else if (status.status == 'retrying') {
          setState(() {
            _isProcessing = true;
            _processingProgress = status.progress;
          });
          if (status.retryAttempt > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Retrying... (attempt ${status.retryAttempt})'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          setState(() => _processingProgress = status.progress);
        }
      } catch (e) {
        // Continue polling
      }
    });
  }

  Future<void> _loadComments({bool loadMore = false}) async {
    if (_loadingComments) return;
    if (!loadMore && _comments.isEmpty) {
      setState(() => _loadingComments = true);
    }

    if (loadMore) setState(() => _loadingComments = true);
    try {
      final page = loadMore ? _commentPage + 1 : 1;
      final result = await VideoService.getComments(_currentVideo.id, page: page, limit: 20);
      if (mounted) {
        setState(() {
          if (loadMore) {
            _comments.addAll(result.comments);
          } else {
            _comments = result.comments;
          }
          _commentPage = result.page;
          _hasMoreComments = result.hasMore;
          _loadingComments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingComments = false);
      }
    }
  }

  Future<void> _loadMoreVideos() async {
    setState(() => _loadingMoreVideos = true);
    try {
      final videos = await VideoService.getFeed(limit: 10);
      if (mounted) {
        setState(() {
          _moreVideos = videos.where((v) => v.id != _currentVideo.id).take(10).toList();
          _loadingMoreVideos = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMoreVideos = false);
    }
  }

  void _onVideoEnded() {
    _statusTimer?.cancel();
    _playNextVideo();
  }

  void _playNextVideo() {
    if (_moreVideos.isEmpty || _nextVideoIndex >= _moreVideos.length) return;
    final next = _moreVideos[_nextVideoIndex];
    _nextVideoIndex++;
    _currentVideo = next;
    _hlsUrl = null;
    _audioOnlyUrl = null;
    _availableQualities = {};
    _isInitialized = false;
    _isLoading = true;
    _isProcessing = false;
    _likes = next.likes;
    _dislikes = next.dislikes;
    _isLiked = next.isLiked;
    _isDisliked = next.isDisliked;
    _isSubscribed = next.isSubscribed;
    _isOwnVideo = false;
    _analyticsTracker?.dispose();
    _analyticsTracker = VideoAnalyticsTracker(next.id);
    _statusTimer?.cancel();
    setState(() {});
    _checkVideoStatus();
    _loadComments();
    _loadMoreVideos();
    _incrementViews();
  }

  Future<void> _incrementViews() async {
    try {
      await VideoService.incrementViews(_currentVideo.id);
    } catch (e) {
      debugPrint('Failed to increment views: $e');
    }
  }

  Future<void> _toggleLike() async {
    try {
      await VideoService.toggleLike(_currentVideo.id);
      setState(() {
        if (_isLiked) {
          _likes--;
          _isLiked = false;
        } else {
          _likes++;
          _isLiked = true;
          if (_isDisliked) {
            _dislikes--;
            _isDisliked = false;
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleDislike() async {
    try {
      await VideoService.toggleDislike(_currentVideo.id);
      setState(() {
        if (_isDisliked) {
          _dislikes--;
          _isDisliked = false;
        } else {
          _dislikes++;
          _isDisliked = true;
          if (_isLiked) {
            _likes--;
            _isLiked = false;
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _initOwnVideo() {
    final uuid = StarlightStorage.getCachedUserUuid();
    if (uuid != null) {
      _isOwnVideo = uuid == _currentVideo.uploaderId;
    } else {
      StarlightStorage.getUserUuid().then((uuid) {
        if (uuid != null && mounted) {
          setState(() => _isOwnVideo = uuid == _currentVideo.uploaderId);
        }
      });
    }
  }

  Future<void> _toggleSubscribe() async {
    try {
      final res = await VideoService.toggleSubscribe(_currentVideo.uploaderId);
      setState(() => _isSubscribed = res);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _updateComment(String id, {int? likes, bool? isLiked, bool? isDisliked}) {
    for (int i = 0; i < _comments.length; i++) {
      final c = _comments[i];
      if (c.id == id) {
        _comments[i] = VideoComment(
          id: c.id, videoId: c.videoId, userId: c.userId, userName: c.userName,
          userAvatar: c.userAvatar, text: c.text,
          likes: likes ?? c.likes, isLiked: isLiked ?? c.isLiked,
          isDisliked: isDisliked ?? c.isDisliked, isOwner: c.isOwner,
          createdAt: c.createdAt, replies: c.replies, replyCount: c.replyCount,
        );
        return;
      }
      // Search replies too
      for (int j = 0; j < c.replies.length; j++) {
        if (c.replies[j].id == id) {
          final r = c.replies[j];
          final updatedReplies = [...c.replies];
          updatedReplies[j] = VideoComment(
            id: r.id, videoId: r.videoId, userId: r.userId, userName: r.userName,
            userAvatar: r.userAvatar, text: r.text,
            likes: likes ?? r.likes, isLiked: isLiked ?? r.isLiked,
            isDisliked: isDisliked ?? r.isDisliked, isOwner: r.isOwner,
            createdAt: r.createdAt,
          );
          _comments[i] = VideoComment(
            id: c.id, videoId: c.videoId, userId: c.userId, userName: c.userName,
            userAvatar: c.userAvatar, text: c.text, likes: c.likes,
            isLiked: c.isLiked, isDisliked: c.isDisliked, isOwner: c.isOwner,
            createdAt: c.createdAt, replies: updatedReplies, replyCount: c.replyCount,
          );
          return;
        }
      }
    }
  }

  Future<void> _toggleCommentLike(VideoComment comment) async {
    try {
      await VideoService.toggleCommentLike(_currentVideo.id, comment.id);
      setState(() {
        if (comment.isLiked) {
          _updateComment(comment.id, likes: comment.likes - 1, isLiked: false);
        } else {
          _updateComment(comment.id, likes: comment.likes + 1, isLiked: true, isDisliked: false);
        }
      });
    } catch (_) {}
  }

  Future<void> _toggleCommentDislike(VideoComment comment) async {
    try {
      await VideoService.toggleCommentDislike(_currentVideo.id, comment.id);
      setState(() {
        if (comment.isDisliked) {
          _updateComment(comment.id, isDisliked: false);
        } else {
          _updateComment(comment.id, isDisliked: true, isLiked: false,
              likes: comment.isLiked ? comment.likes - 1 : comment.likes);
        }
      });
    } catch (_) {}
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      await VideoService.addComment(_currentVideo.id, text, parentId: _replyToComment?.id);
      _commentController.clear();
      setState(() => _replyToComment = null);
      _loadComments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _shareVideo() async {
    final url = 'https://app.institution.site/video/${_currentVideo.id}';
    final text = 'Watch "${_currentVideo.title}" on Starlight!';
    
    if (Platform.isAndroid || Platform.isIOS) {
      await Share.share(text, subject: _currentVideo.title, sharePositionOrigin: Rect.fromLTWH(0, 0, 200, 100));
    } else {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _downloadVideo() {
    showDownloadDialog(
      context,
      video: _currentVideo,
      availableQualities: _availableQualities,
    );
  }

  Future<void> _reportVideo() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Report Video', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            'Inappropriate content', 'Spam or misleading', 'Copyright violation', 'Harassment or hate speech',
          ].map((reason) => ListTile(
            title: Text(reason, style: const TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(context, reason),
          )).toList(),
        ),
      ),
    );

    if (reason != null && mounted) {
      try {
        await VideoService.reportVideo(_currentVideo.id, reason);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thank you.'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to report: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: _isFullScreen
          ? PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                _videoPlayerKey.currentState?.exitFullScreen();
                setState(() {
                  _isFullScreen = false;
                });
              },
              child: _buildVideoPlayer(),
            )
          : SafeArea(
              child: Column(
                children: [
                  _buildVideoPlayer(),
                  Expanded(child: _buildDetailsAndComments()),
                ],
              ),
            ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isLoading) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator(color: StarlightTheme.primaryBlue)),
        ),
      );
    }

    if (_isProcessing) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.video_settings, size: 48, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Processing video...',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: LinearProgressIndicator(
                  value: _processingProgress / 100,
                  backgroundColor: Colors.grey[800],
                  valueColor: const AlwaysStoppedAnimation<Color>(StarlightTheme.primaryBlue),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_processingProgress%',
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _hlsUrl == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 8),
                Text(
                  'Video unavailable',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final player = StarlightVideoPlayer(
      key: _videoPlayerKey,
      videoUrl: _hlsUrl!,
      audioOnlyUrl: _audioOnlyUrl,
      thumbnailUrl: _currentVideo.thumbnailUrl.isNotEmpty
          ? (_currentVideo.thumbnailUrl.startsWith('/')
              ? '${StarlightConstants.apiBaseUrl}${_currentVideo.thumbnailUrl}'
              : _currentVideo.thumbnailUrl)
          : null,
      title: _currentVideo.title,
      availableQualities: _availableQualities.isNotEmpty
          ? _availableQualities
          : {
              '360p': '${_hlsUrl!}${_hlsUrl!.contains('?') ? '&' : '?'}quality=360',
              '720p': '${_hlsUrl!}${_hlsUrl!.contains('?') ? '&' : '?'}quality=720',
              '1080p': '${_hlsUrl!}${_hlsUrl!.contains('?') ? '&' : '?'}quality=1080',
            },
      onPlay: () => _analyticsTracker?.resumeTracking(0),
      onPause: () => _analyticsTracker?.pauseTracking(0),
        onFullScreen: (full) {
          setState(() => _isFullScreen = full);
        },
      onQualityChange: (quality) => _analyticsTracker?.changeQuality(quality),
      onVideoEnd: _onVideoEnded,
    );

    if (_isFullScreen) return player;
    return AspectRatio(aspectRatio: 16 / 9, child: player);
  }

  Widget _buildDetailsAndComments() {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollEndNotification &&
            scrollNotification.metrics.pixels >= scrollNotification.metrics.maxScrollExtent - 200 &&
            _hasMoreComments &&
            !_loadingComments) {
          _loadComments(loadMore: true);
        }
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _currentVideo.title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${_currentVideo.viewsFormatted} views',
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDate(_currentVideo.createdAt),
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActionBar(),
          const Divider(color: Colors.grey, height: 24),
          _buildUploaderInfo(),
          const Divider(color: Colors.grey, height: 24),
          if (_currentVideo.description.isNotEmpty) ...[
            GestureDetector(
              onTap: () => setState(() => _showFullDescription = !_showFullDescription),
              child: Text(
                _currentVideo.description,
                style: GoogleFonts.poppins(color: Colors.grey[300], fontSize: 14),
                maxLines: _showFullDescription ? null : 3,
                overflow: _showFullDescription ? null : TextOverflow.ellipsis,
              ),
            ),
            if (_currentVideo.description.length > 150)
              GestureDetector(
                onTap: () => setState(() => _showFullDescription = !_showFullDescription),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _showFullDescription ? 'Show less' : 'Show more',
                    style: GoogleFonts.poppins(color: StarlightTheme.primaryBlue, fontSize: 13),
                  ),
                ),
              ),
          ],
          if (_currentVideo.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _currentVideo.tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.poppins(color: Colors.grey[300], fontSize: 12),
                ),
              )).toList(),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(color: Colors.grey, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Comments (${_comments.length})',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCommentInput(),
          const SizedBox(height: 12),
          if (_loadingComments && _comments.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (_comments.isNotEmpty) ...[
            _buildCommentItem(_comments.first),
            if (!_showAllComments && _comments.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _showAllComments = true),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: StarlightTheme.primaryBlue),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'View all ${_comments.length} comments',
                          style: GoogleFonts.poppins(color: StarlightTheme.primaryBlue, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_showAllComments)
              ..._comments.sublist(1).map((c) => _buildCommentItem(c)),
          ],
          if (_loadingComments && _comments.isNotEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
          if (!_hasMoreComments && _comments.isNotEmpty && _showAllComments)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No more comments', style: GoogleFonts.poppins(color: Colors.grey)),
              ),
            ),
          const SizedBox(height: 16),
          const Divider(color: Colors.grey, height: 1),
          const SizedBox(height: 16),
          Text(
            'More videos',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (_loadingMoreVideos)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else
            ..._moreVideos.map((v) => VideoWidgets.buildVideoCard(
              context, v,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: v)),
                );
              },
              onUploaderTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChannelScreen(channelId: v.uploaderId, initialName: v.uploaderName),
                ));
              },
            )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
        _buildActionButton(
          icon: _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
          label: _formatCount(_likes),
          onPressed: _toggleLike,
          color: _isLiked ? StarlightTheme.primaryBlue : Colors.white,
        ),
        _buildActionButton(
          icon: _isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
          label: _formatCount(_dislikes),
          onPressed: _toggleDislike,
          color: _isDisliked ? Colors.red : Colors.white,
        ),
        _buildActionButton(
          icon: Icons.headphones,
          label: 'Audio',
          onPressed: () {
            _videoPlayerKey.currentState?.pause();
            _statusTimer?.cancel();
            GlobalAudioService.instance.play(_currentVideo);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AudioPlayerScreen()),
            );
          },
        ),
        _buildActionButton(
          icon: Icons.download,
          label: 'Download',
          onPressed: _downloadVideo,
        ),
        _buildActionButton(
          icon: Icons.share,
          label: 'Share',
          onPressed: _shareVideo,
        ),
        _buildActionButton(
          icon: Icons.flag_outlined,
          label: 'Report',
          onPressed: _reportVideo,
          color: Colors.orange,
        ),
      ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: color ?? Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: color ?? Colors.white,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploaderInfo() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => _openChannel(_currentVideo.uploaderId, _currentVideo.uploaderName),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: StarlightTheme.primaryBlue,
            child: Text(
              _currentVideo.uploaderName.isNotEmpty ? _currentVideo.uploaderName[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _openChannel(_currentVideo.uploaderId, _currentVideo.uploaderName),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentVideo.uploaderName,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!_isOwnVideo)
          ElevatedButton(
            onPressed: _toggleSubscribe,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSubscribed ? Colors.grey : StarlightTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: Text(_isSubscribed ? 'Subscribed' : 'Subscribe'),
          ),
      ],
    );
  }

  void _openChannel(String userId, String userName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChannelScreen(channelId: userId, initialName: userName),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Column(
      children: [
        if (_replyToComment != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: StarlightTheme.primaryBlue.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.reply, size: 14, color: StarlightTheme.primaryBlue),
                const SizedBox(width: 6),
                Text(
                  'Replying to @${_replyToComment!.userName}',
                  style: GoogleFonts.poppins(color: StarlightTheme.primaryBlue, fontSize: 12),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _replyToComment = null),
                  child: const Icon(Icons.close, size: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: _replyToComment != null ? 'Write a reply...' : 'Add a comment...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onSubmitted: (_) => _addComment(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send, color: StarlightTheme.primaryBlue),
              onPressed: _addComment,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentItem(VideoComment comment, {bool isNested = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[700],
            child: Text(
              comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (comment.isOwner) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.push_pin, size: 14, color: StarlightTheme.primaryBlue),
                      const SizedBox(width: 3),
                      Text(
                        'Pinned',
                        style: GoogleFonts.poppins(color: StarlightTheme.primaryBlue, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      comment.timeAgo,
                      style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: GoogleFonts.poppins(color: Colors.grey[300], fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleCommentLike(comment),
                      child: Row(
                        children: [
                          Icon(Icons.thumb_up, size: 16, color: comment.isLiked ? StarlightTheme.primaryBlue : Colors.grey),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _toggleCommentDislike(comment),
                      child: Icon(Icons.thumb_down, size: 16, color: comment.isDisliked ? Colors.red : Colors.grey),
                    ),
                    if (!isNested) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          setState(() => _replyToComment = comment);
                        },
                        child: const Icon(Icons.reply, size: 16, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
                if (comment.replyCount > 0)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_expandedReplies.contains(comment.id)) {
                          _expandedReplies.remove(comment.id);
                        } else {
                          _expandedReplies.add(comment.id);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(
                            _expandedReplies.contains(comment.id) ? Icons.expand_less : Icons.expand_more,
                            size: 16,
                            color: StarlightTheme.primaryBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${comment.replyCount} ${comment.replyCount == 1 ? 'reply' : 'replies'}',
                            style: GoogleFonts.poppins(color: StarlightTheme.primaryBlue, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_expandedReplies.contains(comment.id))
                  ...comment.replies.map((reply) => Padding(
                    padding: const EdgeInsets.only(left: 40, top: 8),
                    child: _buildCommentItem(reply, isNested: true),
                  )),
              ],
            ),
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
      if (abs.inHours > 0) return '${abs.inHours}h ago';
      if (abs.inMinutes > 0) return '${abs.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
