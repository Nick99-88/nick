import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../models/video_models.dart';
import '../services/video_download_service.dart';
import '../widgets/video_widgets.dart';
import 'video_player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final _service = VideoDownloadService.instance;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final downloads = _service.downloads;
    final inProgress = _service.inProgress;

    if (downloads.isEmpty && inProgress.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_outlined, size: 72, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text('No downloads yet',
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Download videos to watch offline',
                style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: inProgress.length + downloads.length,
      itemBuilder: (context, index) {
        if (index < inProgress.length) {
          final info = inProgress[index];
          return _InProgressItem(info: info);
        }
        final entry = downloads[index - inProgress.length];
        return _DownloadItem(
          entry: entry,
          onTap: () {
            final file = File(entry['local_path']);
            if (file.existsSync()) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoPlayerScreen(
                    isAudio: entry['type'] == 'audio',
                    video: VideoPost(
                      id: entry['video_id'],
                      title: entry['title'],
                      videoUrl: entry['local_path'],
                      uploaderId: '',
                      uploaderName: entry['uploader_name'],
                      thumbnailUrl: entry['thumbnail_url'],
                      createdAt: entry['downloaded_at'],
                    ),
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('File not found. It may have been deleted.'),
                    backgroundColor: Colors.red),
              );
            }
          },
          onDelete: () async {
            await _service.deleteDownload(entry['id']);
          },
        );
      },
    );
  }
}

class _InProgressItem extends StatelessWidget {
  final InProgressInfo info;

  const _InProgressItem({required this.info});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 120,
                height: 68,
                color: Colors.grey[850],
                child: info.type == 'audio'
                    ? const Icon(Icons.audiotrack, size: 32, color: Colors.grey)
                    : const Icon(Icons.movie, size: 32, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.title,
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: info.progress,
                      backgroundColor: Colors.grey[800],
                      valueColor: const AlwaysStoppedAnimation(StarlightTheme.primaryBlue),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${(info.progress * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: StarlightTheme.primaryBlue),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadItem extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DownloadItem({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAudio = entry['type'] == 'audio';
    final file = File(entry['local_path']);
    final fileExists = file.existsSync();
    final fileSize = _formatBytes(entry['file_size'] ?? 0);

    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: fileExists ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 120,
                  height: 68,
                  color: Colors.grey[850],
                  child: isAudio
                      ? const Icon(Icons.audiotrack, size: 32, color: Colors.grey)
                      : _buildThumbnail(entry),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry['title'] ?? '',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(isAudio ? Icons.audiotrack : Icons.videocam, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(entry['quality'] ?? '', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                        const SizedBox(width: 12),
                        Text(fileSize, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    if (!fileExists)
                      Text('File missing', style: GoogleFonts.poppins(color: Colors.red, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(Map<String, dynamic> entry) {
    final thumbPath = entry['thumbnail_path']?.toString() ?? '';
    if (thumbPath.isNotEmpty) {
      final thumbFile = File(thumbPath);
      if (thumbFile.existsSync()) {
        return Image.file(thumbFile, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.movie, size: 32, color: Colors.grey));
      }
    }
    final thumbUrl = entry['thumbnail_url']?.toString() ?? '';
    if (thumbUrl.isNotEmpty) {
      final resolved = thumbUrl.startsWith('http://') || thumbUrl.startsWith('https://')
          ? thumbUrl
          : '${StarlightConstants.apiBaseUrl}${thumbUrl.startsWith('/') ? thumbUrl : '/$thumbUrl'}';
      return Image.network(resolved, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.movie, size: 32, color: Colors.grey));
    }
    return const Icon(Icons.movie, size: 32, color: Colors.grey);
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}
