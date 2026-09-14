import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../core/theme.dart';
import '../models/book_models.dart';
import '../services/library_service.dart';
import '../services/library_ad_service.dart';
import 'channel_profile_screen.dart';

class BookVideoPlayerScreen extends StatefulWidget {
  final Book book;

  const BookVideoPlayerScreen({super.key, required this.book});

  @override
  State<BookVideoPlayerScreen> createState() => _BookVideoPlayerScreenState();
}

class _BookVideoPlayerScreenState extends State<BookVideoPlayerScreen> {
  late Book _book;
  String? _localPath;
  bool _loadingFile = true;

  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<BookComment> _comments = [];
  bool _loadingComments = true;
  bool _postingComment = false;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _initializeVideo();
    _loadComments();
  }

  @override
  void dispose() {
    LibraryAdService.cancelDwellTimer();
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
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

    // 3. Download book PDF (always fetched via HTTP, even when the backend
    //    stores a server-relative path like `/library/files/{id}`).
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
        _localPath = downloadUrl; // Fallback: try the URL directly
        _loadingFile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingFile = false);
    }
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final res = await LibraryService.getComments(_book.id);
      setState(() {
        _comments = res['comments'] as List<BookComment>;
        _loadingComments = false;
      });
    } catch (_) {
      setState(() => _loadingComments = false);
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

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _postingComment = true);
    _commentCtrl.clear();

    try {
      final newComment = await LibraryService.addComment(_book.id, text);
      setState(() {
        _comments.insert(0, newComment);
        _postingComment = false;
      });
    } catch (e) {
      setState(() => _postingComment = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text("REFERENCE EXAMINER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _book),
        ),
      ),
      body: Column(
        children: [
          // 1. YouTube-style Video/Document Player (Top Half)
          Container(
            height: MediaQuery.of(context).size.height * 0.32,
            color: Colors.black,
            child: _loadingFile
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _localPath == null
                    ? const Center(child: Text("Could not load Reference PDF", style: TextStyle(color: Colors.white)))
                    : SfPdfViewer.file(
                        File(_localPath!),
                        enableDoubleTapZooming: true,
                      ),
          ),

          // Banner Ad Space
          if (_book.monetizationType == 'ads_only' || _book.monetizationType == 'user_decision')
            const BannerAdPlaceholder(),

          // 2. Document Info Card, Metrics & Comments (Bottom Half)
          Expanded(
            child: ListView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              children: [
                // Title and Metadata
                Text(
                  _book.title,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF263238)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: StarlightTheme.primaryBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                      child: Text(_book.topic, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue)),
                    ),
                    const SizedBox(width: 8),
                    Text("👁️ ${_book.viewsCount} views  •  By ${_book.author}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const Divider(height: 24),

                 // Social Metrics Buttons Row
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                   children: [
                     _metricButton(
                       icon: _book.userLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                       label: "${_book.likesCount}",
                       color: _book.userLiked ? StarlightTheme.primaryBlue : Colors.grey,
                       onTap: _handleLike,
                     ),
                     _metricButton(
                       icon: _book.userDisliked ? Icons.thumb_down_rounded : Icons.thumb_down_alt_outlined,
                       label: "${_book.dislikesCount}",
                       color: _book.userDisliked ? Colors.red : Colors.grey,
                       onTap: _handleDislike,
                     ),
                     _metricButton(
                       icon: _book.userSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                       label: "Save",
                       color: _book.userSaved ? Colors.amber.shade700 : Colors.grey,
                       onTap: _handleSave,
                     ),
                     _metricButton(
                       icon: Icons.comment_rounded,
                       label: "Comments",
                       color: Colors.grey,
                       onTap: () {},
                     ),
                   ],
                 ),
                const Divider(height: 24),

                 // Library Info Bar
                 InkWell(
                   onTap: () {
                     Navigator.push(context, MaterialPageRoute(builder: (context) => ChannelProfileScreen(channelId: _book.channelId)));
                   },
                   borderRadius: BorderRadius.circular(12),
                   child: Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                     child: Row(
                       children: [
                         CircleAvatar(
                           radius: 18,
                           backgroundColor: StarlightTheme.primaryBlue.withOpacity(0.1),
                           child: const Icon(Icons.menu_book_rounded, color: StarlightTheme.primaryBlue, size: 18),
                         ),
                         const SizedBox(width: 12),
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(_book.channelName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                               const Text("Library Profile", style: TextStyle(fontSize: 10, color: Colors.grey)),
                             ],
                           ),
                         ),
                         const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                       ],
                     ),
                   ),
                 ),
                const Divider(height: 24),

                // Comment Box Input
                const Text("COMMENTS & DISCUSSION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        decoration: InputDecoration(
                          hintText: "Add your thought or review...",
                          hintStyle: const TextStyle(fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                          fillColor: Colors.white,
                          filled: true,
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _postingComment
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send, color: StarlightTheme.primaryBlue),
                      onPressed: _postingComment ? null : _submitComment,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Comments List thread
                _loadingComments
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                        ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text("No discussion comments yet.", style: TextStyle(fontSize: 12, color: Colors.grey))))
                        : Column(
                            children: _comments.map((c) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(c.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: StarlightTheme.primaryBlue)),
                                        Text(_formatTime(c.createdAt), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(c.commentText, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return "${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "";
    }
  }
}
