import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../models/book_models.dart';
import '../services/library_service.dart';
import '../services/library_ad_service.dart';
import 'channel_profile_screen.dart';

/// 📂 Generic library file viewer — used for any file the Syncfusion PDF
/// viewer and the image viewer can't render (Word docs, Excel sheets,
/// PowerPoint decks, audio, archives, …). We can't render the bytes
/// in-app, so the screen shows the metadata card and offers an
/// "Open in browser" action that streams the file from the backend.
class LibraryGenericFileScreen extends StatefulWidget {
  final Book book;
  const LibraryGenericFileScreen({super.key, required this.book});

  @override
  State<LibraryGenericFileScreen> createState() => _LibraryGenericFileScreenState();
}

class _LibraryGenericFileScreenState extends State<LibraryGenericFileScreen> {
  late Book _book;

  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<BookComment> _comments = [];
  bool _loadingComments = true;
  bool _postingComment = false;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _initializeViewTracking();
    _loadComments();
  }

  @override
  void dispose() {
    LibraryAdService.cancelDwellTimer();
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _initializeViewTracking() async {
    // Show reward ad for monetized content
    if (_book.monetizationType == 'ads_only' || _book.monetizationType == 'user_decision') {
      await LibraryAdService.showRewardAd(context);
    }
    // Start 15-second dwell timer before recording view
    LibraryAdService.startDwellTimer(_book.id, (views) {
      if (mounted) setState(() => _book = _book.copyWith(viewsCount: views));
    });
  }

  Future<void> _loadComments() async {
    try {
      final res = await LibraryService.getComments(_book.id);
      if (!mounted) return;
      setState(() {
        _comments = res['comments'] as List<BookComment>;
        _loadingComments = false;
      });
    } catch (_) {
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _comments.insert(0, newComment);
        _postingComment = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _postingComment = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _openInBrowser() async {
    // 🏛️ Check if the file is already downloaded to local storage. If so, open natively!
    if (_book.fileUrl.isNotEmpty) {
      final file = File(_book.fileUrl);
      if (await file.exists()) {
        try {
          final result = await OpenFile.open(_book.fileUrl);
          if (result.type != ResultType.done) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Could not open file: ${result.message}"), backgroundColor: Colors.red),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error launching file handler: $e"), backgroundColor: Colors.red),
            );
          }
        }
        return;
      }
    }

    // 🏛️ Fallback: online mode redirect to the web URL stream
    final url = _book.absoluteFileUrl;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open file in browser")),
      );
    }
  }

  Future<void> _copyUrl() async {
    await Clipboard.setData(ClipboardData(text: _book.absoluteFileUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("File URL copied to clipboard")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text("LIBRARY DOCUMENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _book),
        ),
      ),
      body: ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16),
        children: [
          _previewCard(),
          const SizedBox(height: 16),
          Text(
            _book.title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF263238)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _kindColor().withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  _kindLabel().toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _kindColor()),
                ),
              ),
              const SizedBox(width: 8),
              Text("👁️ ${_book.viewsCount} views  •  By ${_book.author}",
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const Divider(height: 24),
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
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ChannelProfileScreen(channelId: _book.channelId)),
            ),
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
          _loadingComments
              ? const Center(child: CircularProgressIndicator())
              : _comments.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text("No discussion comments yet.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                    )
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
    );
  }

  Widget _previewCard() {
    final color = _kindColor();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.08), color.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 100,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(_kindIcon(), color: color, size: 44),
          ),
          const SizedBox(height: 12),
          Text(
            _book.fileName.isNotEmpty ? _book.fileName : "${_book.id}.${_book.resolvedExt}",
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(_kindHint(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StarlightTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white, size: 16),
                  label: const Text("Open in Browser", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: _openInBrowser,
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: "Copy file URL",
                icon: const Icon(Icons.copy_rounded, size: 20),
                onPressed: _copyUrl,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _kindLabel() {
    switch (_book.fileKind) {
      case 'spreadsheet':
        return 'Spreadsheet';
      case 'presentation':
        return 'Presentation';
      case 'audio':
        return 'Audio';
      case 'archive':
        return 'Archive';
      case 'document':
        return _book.resolvedExt.toUpperCase();
      default:
        return _book.resolvedExt.isEmpty ? 'File' : _book.resolvedExt.toUpperCase();
    }
  }

  String _kindHint() {
    switch (_book.fileKind) {
      case 'spreadsheet':
        return "Excel/CSV — preview isn't supported in-app. Open in your browser or spreadsheet app.";
      case 'presentation':
        return "Slide deck — preview isn't supported in-app. Open in your browser or PowerPoint.";
      case 'audio':
        return 'Audio file — open in your browser or default media player.';
      case 'archive':
        return 'Compressed archive — open in your browser to download.';
      case 'document':
        if (_book.resolvedExt == 'pdf') return "PDF document — open in your browser or PDF viewer.";
        return "Document file — open in your browser to download and view in your word processor.";
      default:
        return 'File — open in your browser to view or download.';
    }
  }

  IconData _kindIcon() {
    switch (_book.fileKind) {
      case 'spreadsheet':
        return Icons.table_chart_rounded;
      case 'presentation':
        return Icons.slideshow_rounded;
      case 'audio':
        return Icons.audiotrack_rounded;
      case 'archive':
        return Icons.folder_zip_rounded;
      case 'document':
        return Icons.article_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color _kindColor() {
    switch (_book.fileKind) {
      case 'spreadsheet':
        return Colors.green;
      case 'presentation':
        return Colors.orange;
      case 'audio':
        return Colors.teal;
      case 'archive':
        return Colors.brown;
      case 'document':
        return Colors.blue;
      default:
        return Colors.blueGrey;
    }
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
