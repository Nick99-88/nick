import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../services/shorts_service.dart';
import '../widgets/video_widgets.dart';
import 'shorts_player_screen.dart';
import 'shorts_upload_screen.dart';

class ShortsHomeScreen extends StatefulWidget {
  const ShortsHomeScreen({super.key});

  @override
  State<ShortsHomeScreen> createState() => _ShortsHomeScreenState();
}

class _ShortsHomeScreenState extends State<ShortsHomeScreen> {
  List<ShortsPost> _shorts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadShorts(refresh: true);
  }

  Future<void> _loadShorts({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      List<ShortsPost> newShorts;
      if (_selectedTab == 0) {
        newShorts = await ShortsService.getShortsFeed(page: _currentPage, limit: 15);
      } else {
        newShorts = await ShortsService.getTrendingShorts(limit: 15);
      }

      if (mounted) {
        setState(() {
          if (refresh) {
            _shorts = newShorts;
          } else {
            _shorts.addAll(newShorts);
          }
          _hasMore = newShorts.length >= 15;
          _currentPage++;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _openShorts(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShortsPlayerScreen(
          shorts: _shorts,
          initialIndex: index,
        ),
      ),
    );
  }

  void _navigateToUpload() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ShortsUploadScreen()),
    );
    if (result == true) {
      _loadShorts(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopBar(),
        _buildTabBar(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.play_circle_filled, color: StarlightTheme.primaryBlue, size: 24),
          const SizedBox(width: 6),
          Text(
            'Shorts',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 24),
            onPressed: _navigateToUpload,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildTab('For You', 0),
          const SizedBox(width: 16),
          _buildTab('Trending', 1),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final selected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        if (_selectedTab != index) {
          setState(() => _selectedTab = index);
          _loadShorts(refresh: true);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? StarlightTheme.primaryBlue : Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: selected ? Colors.white : Colors.grey[400],
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: StarlightTheme.primaryBlue));
    }

    if (_error != null && _shorts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[400], size: 48),
            const SizedBox(height: 12),
            Text(
              'Failed to load shorts',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              _error!,
              style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadShorts(refresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_shorts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, color: Colors.grey[600], size: 64),
            const SizedBox(height: 16),
            Text(
              'No Shorts Yet',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to upload a Short!',
              style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToUpload,
              icon: const Icon(Icons.add),
              label: const Text('Upload Short'),
              style: ElevatedButton.styleFrom(
                backgroundColor: StarlightTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadShorts(refresh: true),
      color: StarlightTheme.primaryBlue,
      child: _buildShortsGrid(),
    );
  }

  Widget _buildShortsGrid() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
          _loadShorts();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.56,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _shorts.length + (_isLoadingMore ? 2 : 0),
        itemBuilder: (context, index) {
          if (index >= _shorts.length) {
            return _buildLoadingCard();
          }
          return _buildShortCard(_shorts[index], index);
        },
      ),
    );
  }

  Widget _buildShortCard(ShortsPost short, int index) {
    return GestureDetector(
      onTap: () => _openShorts(index),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                    child: short.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            _resolveUrl(short.thumbnailUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        short.duration > 0 ? _formatDuration(short.duration) : '',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            short.viewsFormatted,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.thumb_up, color: Colors.white70, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            short.likesFormatted,
                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    short.title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 8,
                        backgroundColor: StarlightTheme.primaryBlue,
                        child: short.uploaderAvatar != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  short.uploaderAvatar!,
                                  width: 16,
                                  height: 16,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Text(
                                short.uploaderName.isNotEmpty ? short.uploaderName[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontSize: 8),
                              ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          short.uploaderName.isNotEmpty ? short.uploaderName : 'Unknown',
                          style: TextStyle(color: Colors.grey[400], fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[900]!, Colors.black],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_fill, color: StarlightTheme.primaryBlue, size: 40),
            SizedBox(height: 4),
            Text('Short', style: TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: StarlightTheme.primaryBlue, strokeWidth: 2),
      ),
    );
  }

  String _resolveUrl(String url) {
    if (url.startsWith('/data/') || url.startsWith('/storage/') || url.startsWith('file://')) return url;
    return url.startsWith('/')
        ? '${StarlightConstants.apiBaseUrl}$url'
        : url;
  }

  String _formatDuration(double seconds) {
    final d = Duration(seconds: seconds.toInt());
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
