import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../models/video_models.dart';

class VideoWidgets {
  static Widget buildVideoCard(
    BuildContext context,
    VideoPost video, {
    required VoidCallback onTap,
    VoidCallback? onAddToPlaylist,
    VoidCallback? onDelete,
    VoidCallback? onUploaderTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumbnail(video),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onUploaderTap,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: StarlightTheme.primaryBlue,
                    child: Text(
                      video.uploaderName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${video.uploaderName} • ${video.viewsFormatted} views • ${_formatDate(video.createdAt)}',
                        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (onAddToPlaylist != null || onDelete != null)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                    color: const Color(0xFF1A1A1A),
                    onSelected: (value) {
                      if (value == 'add_to_playlist') onAddToPlaylist?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (_) => [
                      if (onAddToPlaylist != null)
                        const PopupMenuItem(value: 'add_to_playlist', child: ListTile(
                          leading: Icon(Icons.playlist_add, color: Colors.white),
                          title: Text('Add to playlist', style: TextStyle(color: Colors.white)),
                          dense: true, contentPadding: EdgeInsets.zero,
                        )),
                      if (onDelete != null)
                        const PopupMenuItem(value: 'delete', child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.redAccent),
                          title: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                          dense: true, contentPadding: EdgeInsets.zero,
                        )),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildThumbnail(VideoPost video) {
    final thumbUrl = video.thumbnailUrl.startsWith('/')
        ? '${StarlightConstants.apiBaseUrl}${video.thumbnailUrl}'
        : video.thumbnailUrl;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: thumbUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: thumbUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: Colors.grey[900],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.video_library, color: Colors.grey, size: 48),
                    ),
                  )
                : Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.video_library, color: Colors.grey, size: 48),
                  ),
          ),
        ),
        if (video.duration > 0)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatDuration(video.duration),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  static Widget buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  static String _formatDate(String dateStr) {
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

  static String _formatDuration(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
