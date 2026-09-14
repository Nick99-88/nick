import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../services/shorts_service.dart';
import '../services/shorts_cache_manager.dart';

class ShortsPlayerScreen extends StatefulWidget {
  final List<ShortsPost> shorts;
  final int initialIndex;

  const ShortsPlayerScreen({
    super.key,
    required this.shorts,
    this.initialIndex = 0,
  });

  @override
  State<ShortsPlayerScreen> createState() => _ShortsPlayerScreenState();
}

class _ShortsPlayerScreenState extends State<ShortsPlayerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late PageController _pageController;
  int _currentIndex = 0;
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, bool> _initialized = {};
  final Set<int> _downloading = {};
  bool _disposed = false;

  final _commentController = TextEditingController();
  List<ShortsComment> _comments = [];
  bool _loadingComments = false;
  bool _showComments = false;
  ShortsComment? _replyTo;
  bool _showDescription = false;

  final ShortsCacheManager _cacheManager = ShortsCacheManager.instance;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    _loadUserId();
    _pageController = PageController(initialPage: _currentIndex);
    _initAllControllers();
  }

  Future<void> _loadUserId() async {
    final id = await StarlightStorage.getUserIdString();
    if (mounted) setState(() => _currentUserId = id);
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _commentController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cacheManager.onAppResume();
    }
  }

  void _initAllControllers() {
    final toLoad = [_currentIndex, _currentIndex + 1, _currentIndex - 1];
    for (final i in toLoad) {
      if (i >= 0 && i < widget.shorts.length && !_controllers.containsKey(i) && !_downloading.contains(i)) {
        _initController(i);
      }
    }
  }

  String _resolveUrl(String url) {
    if (url.startsWith('/data/') || url.startsWith('/storage/') || url.startsWith('file://')) return url;
    return url.startsWith('/')
        ? '${StarlightConstants.apiBaseUrl}$url'
        : url;
  }

  Future<String?> _downloadVideo(String shortId, String videoUrl) async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/shorts_cache/$shortId');
    await cacheDir.create(recursive: true);
    final file = File('${cacheDir.path}/video.mp4');

    if (await file.exists() && await file.length() > 0) {
      return file.path;
    }

    final resolvedUrl = _resolveUrl(videoUrl);
    debugPrint('Downloading short $shortId from $resolvedUrl');

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(resolvedUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        debugPrint('Download failed with status ${response.statusCode}');
        return null;
      }

      final sink = file.openWrite();
      int bytesReceived = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        bytesReceived += chunk.length;
      }
      await sink.flush();
      await sink.close();
      debugPrint('Downloaded short $shortId: $bytesReceived bytes');

      return file.path;
    } catch (e) {
      debugPrint('Download error for $shortId: $e');
      await file.delete().catchError((_) {});
      return null;
    } finally {
      client.close();
    }
  }

  Future<void> _initController(int index) async {
    if (_disposed || index < 0 || index >= widget.shorts.length) return;
    final short = widget.shorts[index];
    if (short.videoUrl.isEmpty) return;

    setState(() => _downloading.add(index));

    try {
      String? localPath = await _cacheManager.getLocalVideoPath(short.id);

      if (localPath == null) {
        localPath = await _downloadVideo(short.id, short.videoUrl);
      }

      if (_disposed) return;
      if (localPath == null || !await File(localPath).exists()) {
        debugPrint('No local video for ${short.id}, falling back to network');
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(_resolveUrl(short.videoUrl)),
        );
        _controllers[index] = controller;
        await controller.setLooping(true);
        await controller.setVolume(1.0);
        await controller.initialize();
        if (_disposed) return;
        if (index == _currentIndex) await controller.play();
        setState(() {
          _initialized[index] = true;
          _downloading.remove(index);
        });
        return;
      }

      final controller = VideoPlayerController.file(File(localPath));
      _controllers[index] = controller;

      await controller.setLooping(true);
      await controller.setVolume(1.0);
      await controller.initialize();
      if (_disposed) return;
      if (index == _currentIndex) await controller.play();
      setState(() {
        _initialized[index] = true;
        _downloading.remove(index);
      });
    } catch (e) {
      debugPrint('Shorts player init error for $index: $e');
      if (mounted) setState(() => _downloading.remove(index));
    }
  }

  void _onPageChanged(int index) {
    if (_disposed) return;

    final oldIndex = _currentIndex;
    _currentIndex = index;

    _controllers[oldIndex]?.pause();
    _controllers[index]?.play();

    _cleanupDistantControllers();
    _initAllControllers();

    HapticFeedback.lightImpact();
  }

  void _cleanupDistantControllers() {
    final keysToRemove = <int>[];
    for (final key in _controllers.keys) {
      if ((key - _currentIndex).abs() > 2) {
        _controllers[key]?.dispose();
        keysToRemove.add(key);
        _initialized.remove(key);
      }
    }
    for (final key in keysToRemove) {
      _controllers.remove(key);
    }
  }

  void _togglePlayPause() {
    final controller = _controllers[_currentIndex];
    if (controller == null) return;
    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  Future<void> _toggleLike(ShortsPost short) async {
    try {
      final result = await ShortsService.toggleLike(short.id);
      if (_disposed) return;
      setState(() {
        final idx = widget.shorts.indexOf(short);
        if (idx >= 0) {
          final old = widget.shorts[idx];
          widget.shorts[idx] = ShortsPost(
            id: old.id,
            title: old.title,
            description: old.description,
            videoUrl: old.videoUrl,
            thumbnailUrl: old.thumbnailUrl,
            uploaderId: old.uploaderId,
            uploaderName: old.uploaderName,
            uploaderAvatar: old.uploaderAvatar,
            views: old.views,
            likes: result['likes'] ?? old.likes,
            dislikes: old.dislikes,
            isLiked: result['is_liked'] ?? !old.isLiked,
            isDisliked: old.isDisliked,
            commentCount: old.commentCount,
            createdAt: old.createdAt,
            duration: old.duration,
            category: old.category,
            tags: old.tags,
          );
        }
      });
    } catch (e) {
      debugPrint('Like failed: $e');
    }
  }

  void _showCommentsSheet(ShortsPost short) {
    _loadComments(short.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _buildCommentsSheet(ctx, short),
    );
  }

  Future<void> _loadComments(String shortId) async {
    setState(() => _loadingComments = true);
    try {
      _comments = await ShortsService.getComments(shortId);
    } catch (e) {
      debugPrint('Load comments failed: $e');
    }
    if (mounted) setState(() => _loadingComments = false);
  }

  void _showDescriptionSheet(ShortsPost short) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _buildDescriptionSheet(ctx, short),
    );
  }

  Widget _buildDefaultThumb() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[900]!, Colors.black],
        ),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_fill, color: StarlightTheme.primaryBlue, size: 64),
          SizedBox(height: 8),
          Text('Loading Short...', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDescriptionSheet(BuildContext ctx, ShortsPost short) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (ctx, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                short.title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                short.description.isNotEmpty ? short.description : 'No description',
                style: GoogleFonts.poppins(color: Colors.grey[300], fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (short.tags.isNotEmpty) ...[
                Text(
                  'Tags',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: short.tags.map((tag) => Chip(
                    label: Text('#$tag', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    backgroundColor: StarlightTheme.primaryBlue.withOpacity(0.3),
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentsSheet(BuildContext ctx, ShortsPost short) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(
                    'Comments',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loadingComments
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : _comments.isEmpty
                      ? Center(
                          child: Text(
                            'No comments yet',
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _comments.length,
                          itemBuilder: (ctx, i) => _buildCommentItem(_comments[i]),
                        ),
            ),
            _buildCommentInput(ctx, short.id),
          ],
        );
      },
    );
  }

  Widget _buildCommentItem(ShortsComment comment) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: StarlightTheme.primaryBlue,
            child: comment.userAvatar != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(comment.userAvatar!, width: 32, height: 32, fit: BoxFit.cover),
                  )
                : Text(
                    comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.userName,
                  style: GoogleFonts.poppins(
                    color: Colors.grey[400],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  comment.text,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  comment.timeAgo,
                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Icon(
                comment.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                color: comment.isLiked ? StarlightTheme.primaryBlue : Colors.grey,
                size: 16,
              ),
              if (comment.likes > 0)
                Text(
                  '${comment.likes}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(BuildContext ctx, String shortId) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 8,
        top: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _replyTo != null ? 'Reply to ${_replyTo!.userName}...' : 'Add a comment...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: InputBorder.none,
              ),
              maxLines: null,
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: StarlightTheme.primaryBlue),
            onPressed: () async {
              final text = _commentController.text.trim();
              if (text.isEmpty) return;

              try {
                await ShortsService.addComment(shortId, text, parentId: _replyTo?.id);
                _commentController.clear();
                _replyTo = null;
                _loadComments(shortId);
                Navigator.pop(ctx);
              } catch (e) {
                debugPrint('Comment failed: $e');
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        itemCount: widget.shorts.length,
        itemBuilder: (context, index) {
          final short = widget.shorts[index];
          final controller = _controllers[index];
          final isInit = _initialized[index] ?? false;

          return Stack(
            fit: StackFit.expand,
            children: [
              if (isInit && controller != null)
                GestureDetector(
                  onTap: _togglePlayPause,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                )
              else
                Container(
                  color: Colors.black,
                  child: Center(
                    child: short.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            _resolveUrl(short.thumbnailUrl),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => _buildDefaultThumb(),
                          )
                        : _buildDefaultThumb(),
                  ),
                ),

              if (!isInit && _downloading.contains(index))
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: StarlightTheme.primaryBlue, strokeWidth: 3),
                      const SizedBox(height: 12),
                      StreamBuilder<double>(
                        stream: _cacheManager.getProgressStream(short.id),
                        builder: (context, snap) {
                          final progress = snap.data ?? 0.0;
                          if (progress <= 0) {
                            return const Text('Preparing...', style: TextStyle(color: Colors.grey, fontSize: 12));
                          }
                          return Text(
                            'Downloading ${(progress * 100).toInt()}%',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          );
                        },
                      ),
                    ],
                  ),
                )
              else if (!isInit)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),

              _buildDownloadOverlay(short, index),

              _buildRightActionBar(short),

              _buildBottomOverlay(short),

              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Text(
                      'Shorts',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDownloadOverlay(ShortsPost short, int index) {
    if (_downloading.contains(index)) {
      return Positioned(
        top: MediaQuery.of(context).padding.top + 56,
        right: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: StarlightTheme.primaryBlue,
                ),
              ),
              SizedBox(width: 6),
              Text(
                'Loading...',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildRightActionBar(ShortsPost short) {
    return Positioned(
      right: 8,
      bottom: MediaQuery.of(context).size.height * 0.15,
      child: Column(
        children: [
          _actionButton(
            icon: short.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
            label: short.likesFormatted,
            color: short.isLiked ? StarlightTheme.primaryBlue : Colors.white,
            onTap: () => _toggleLike(short),
          ),
          const SizedBox(height: 20),
          _actionButton(
            icon: Icons.thumb_down_outlined,
            label: '',
            color: short.isDisliked ? Colors.red : Colors.white,
            onTap: () => ShortsService.toggleDislike(short.id),
          ),
          const SizedBox(height: 20),
          _actionButton(
            icon: Icons.comment_outlined,
            label: '${short.commentCount}',
            color: Colors.white,
            onTap: () => _showCommentsSheet(short),
          ),
          const SizedBox(height: 20),
          _actionButton(
            icon: Icons.share,
            label: '',
            color: Colors.white,
            onTap: () => Share.share(
              'https://starlightai.app/shorts/${short.id}',
              subject: short.title,
            ),
          ),
          const SizedBox(height: 20),
          _actionButton(
            icon: Icons.more_vert,
            label: '',
            color: Colors.white,
            onTap: () => _showMoreOptions(short),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(color: color, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomOverlay(ShortsPost short) {
    return Positioned(
      left: 12,
      right: 72,
      bottom: MediaQuery.of(context).padding.bottom + 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: StarlightTheme.primaryBlue,
                child: short.uploaderAvatar != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          short.uploaderAvatar!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Text(
                        short.uploaderName.isNotEmpty
                            ? short.uploaderName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
              ),
              const SizedBox(width: 8),
              Text(
                short.uploaderName.isNotEmpty ? short.uploaderName : 'Unknown',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 12),
              if (_currentUserId != short.uploaderId)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white70),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Subscribe',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            short.title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          if (short.description.isNotEmpty)
            GestureDetector(
              onTap: () => _showDescriptionSheet(short),
              child: Text(
                short.description,
                style: GoogleFonts.poppins(color: Colors.grey[300], fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.play_arrow, color: Colors.grey[400], size: 14),
              const SizedBox(width: 4),
              Text(
                '${short.viewsFormatted} views',
                style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 11),
              ),
              const SizedBox(width: 12),
              Text(
                short.timeAgo,
                style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(ShortsPost short) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.orange),
              title: Text('Report', style: GoogleFonts.poppins(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reported')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: Text('Not Interested', style: GoogleFonts.poppins(color: Colors.white)),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.grey),
              title: Text('Copy Link', style: GoogleFonts.poppins(color: Colors.white)),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}
