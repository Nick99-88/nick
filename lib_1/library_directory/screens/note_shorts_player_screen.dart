import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../core/theme.dart';
import '../models/book_models.dart';
import '../services/library_service.dart';
import '../services/library_ad_service.dart';
import 'book_comments_screen.dart';
import 'channel_profile_screen.dart';

class NoteShortsPlayerScreen extends StatefulWidget {
  final Book book;

  const NoteShortsPlayerScreen({super.key, required this.book});

  @override
  State<NoteShortsPlayerScreen> createState() => _NoteShortsPlayerScreenState();
}

class _NoteShortsPlayerScreenState extends State<NoteShortsPlayerScreen> {
  late Book _book;
  String? _localPath;
  bool _loadingFile = true;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _initializeShorts();
  }

  Future<void> _initializeShorts() async {
    // 🏛️ Check if the file is already a valid local path (e.g., loaded offline from SQLite)
    if (_book.fileUrl.isNotEmpty) {
      final file = File(_book.fileUrl);
      if (await file.exists()) {
        setState(() {
          _localPath = _book.fileUrl;
          _loadingFile = false;
        });
        return;
      }
    }

    // 1. Show reward ad for monetized content
    if (_book.monetizationType == 'ads_only' || _book.monetizationType == 'user_decision') {
      await LibraryAdService.showRewardAd(context);
    }

    // 2. Start 15-second dwell timer before recording view
    LibraryAdService.startDwellTimer(_book.id, (views) {
      if (mounted) setState(() => _book = _book.copyWith(viewsCount: views));
    });

    // 3. Download note PDF (always via HTTP — backend stores a relative
    //    `/library/files/{id}` path that the model resolves to an absolute URL).
    try {
      final downloadUrl = _book.absoluteFileUrl;
      if (downloadUrl.startsWith("http://") || downloadUrl.startsWith("https://")) {
        final response = await http.get(Uri.parse(downloadUrl));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/${_book.id}.pdf');
          await tempFile.writeAsBytes(response.bodyBytes);
          if (!mounted) return;
          setState(() {
            _localPath = tempFile.path;
            _loadingFile = false;
          });
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _localPath = downloadUrl;
        _loadingFile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingFile = false);
    }
  }

  Future<void> _handleLike() async {
    try {
      final res = await LibraryService.toggleLike(_book.id);
      setState(() {
        _book = _book.copyWith(
          likesCount: res['likes'],
          dislikesCount: res['dislikes'],
          userLiked: res['user_liked'],
          userDisliked: false,
        );
      });
    } catch (_) {}
  }

  Future<void> _handleDislike() async {
    try {
      final res = await LibraryService.toggleDislike(_book.id);
      setState(() {
        _book = _book.copyWith(
          likesCount: res['likes'],
          dislikesCount: res['dislikes'],
          userLiked: false,
          userDisliked: res['user_disliked'],
        );
      });
    } catch (_) {}
  }

  Future<void> _handleSave() async {
    try {
      final res = await LibraryService.toggleSave(_book.id);
      setState(() {
        _book = _book.copyWith(userSaved: res['saved']);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['saved'] ? "Saved to bookmarks" : "Removed from bookmarks"),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _handleReport() async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Report Shorts Content", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(hintText: "Reason for report..."),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Report")),
        ],
      ),
    );

    if (confirm == true && reasonCtrl.text.trim().isNotEmpty) {
      try {
        final res = await LibraryService.reportBook(_book.id, reasonCtrl.text.trim());
        setState(() {
          _book = _book.copyWith(
            reportsCount: res['reports_count'],
            userReported: true,
          );
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Short Note reported")));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. PDF Short Examiner
          _loadingFile
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _localPath == null
                  ? const Center(child: Text("Could not load Note PDF", style: TextStyle(color: Colors.white)))
                  : Positioned.fill(
                      child: SfPdfViewer.file(
                        File(_localPath!),
                        enableDoubleTapZooming: true,
                      ),
                    ),

          // 2. Back Button
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 28),
              onPressed: () => Navigator.pop(context, _book),
            ),
          ),

          // 3. Shorts Vertical Action Bar (Floating on Right)
          Positioned(
            bottom: 40,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Publisher Profile Avatar
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ChannelProfileScreen(channelId: _book.channelId)));
                  },
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), shape: BoxShape.circle),
                    child: const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.menu_book_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Likes Action
                _shortsActionButton(
                  icon: _book.userLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                  label: "${_book.likesCount}",
                  color: _book.userLiked ? Colors.orange : Colors.white,
                  onTap: _handleLike,
                ),

                 // Dislikes Action
                 _shortsActionButton(
                   icon: _book.userDisliked ? Icons.thumb_down_rounded : Icons.thumb_down_alt_outlined,
                   label: "${_book.dislikesCount}",
                   color: _book.userDisliked ? Colors.red : Colors.white,
                   onTap: _handleDislike,
                 ),

                 // Save Action
                 _shortsActionButton(
                   icon: _book.userSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                   label: _book.userSaved ? "Saved" : "Save",
                   color: _book.userSaved ? Colors.orange : Colors.white,
                   onTap: _handleSave,
                 ),

                 // Comments Action
                 _shortsActionButton(
                   icon: Icons.comment_rounded,
                   label: "Review",
                  color: Colors.white,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => BookCommentsScreen(book: _book)));
                  },
                ),

                // Reports Action
                _shortsActionButton(
                  icon: _book.userReported ? Icons.flag_rounded : Icons.flag_outlined,
                  label: "Report",
                  color: _book.userReported ? Colors.red : Colors.white,
                  onTap: _book.userReported ? null : _handleReport,
                ),
              ],
            ),
          ),

          // 4. Shorts Overlay Description (Bottom Left)
          Positioned(
            bottom: 40,
            left: 16,
            right: 80,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                        child: const Text("SHORT NOTE", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      Text("👁️ ${_book.viewsCount} views", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _book.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Topic: ${_book.topic} | By ${_book.author}",
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shortsActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.black.withOpacity(0.6),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
            ),
          ],
        ),
      ),
    );
  }
}
