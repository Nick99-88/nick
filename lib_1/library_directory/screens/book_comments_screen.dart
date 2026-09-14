import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../models/book_models.dart';
import '../services/library_service.dart';

class BookCommentsScreen extends StatefulWidget {
  final Book book;

  const BookCommentsScreen({super.key, required this.book});

  @override
  State<BookCommentsScreen> createState() => _BookCommentsScreenState();
}

class _BookCommentsScreenState extends State<BookCommentsScreen> {
  final _commentCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  
  List<BookComment> _comments = [];
  bool _loading = true;
  bool _submitting = false;

  // 🏛️ Metadata about current users to evaluate pin privileges and badges
  String _bookOwnerId = '';
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final data = await LibraryService.getComments(widget.book.id);
      setState(() {
        _comments = data['comments'] as List<BookComment>;
        _bookOwnerId = data['book_owner_id'] as String;
        _currentUserId = data['current_user_id'] as String;
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _handlePinComment(BookComment comment, int index) async {
    try {
      final res = await LibraryService.togglePinComment(comment.id);
      final isPinned = res['is_pinned'] == true;
      
      // Pinning toggles existing pinned comment on server, so let's reload comments to ensure proper sort order!
      await _loadComments();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPinned ? "Comment pinned to top!" : "Comment unpinned"),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pin action failed: $e")));
      }
    }
  }

  Future<void> _handleLikeComment(BookComment comment, int index) async {
    try {
      final res = await LibraryService.toggleLikeComment(comment.id);
      setState(() {
        _comments[index] = comment.copyWith(
          likesCount: res['likes'],
          dislikesCount: res['dislikes'],
          userLiked: res['user_liked'],
          userDisliked: false,
        );
      });
    } catch (_) {}
  }

  Future<void> _handleDislikeComment(BookComment comment, int index) async {
    try {
      final res = await LibraryService.toggleDislikeComment(comment.id);
      setState(() {
        _comments[index] = comment.copyWith(
          likesCount: res['likes'],
          dislikesCount: res['dislikes'],
          userLiked: false,
          userDisliked: res['user_disliked'],
        );
      });
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _submitting = true);
    _commentCtrl.clear();
    
    try {
      final newComment = await LibraryService.addComment(widget.book.id, text);
      setState(() {
        _comments.add(newComment);
        _submitting = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error posting comment: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.book.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
            const Text("User Comments & Feedback", style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.comment_bank_outlined, size: 50, color: Colors.grey),
                            SizedBox(height: 8),
                            Text("No comments yet.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            Text("Be the first to share your thoughts!", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        itemBuilder: (ctx, i) {
                          final c = _comments[i];
                          final isBookOwner = _currentUserId.isNotEmpty && _currentUserId == _bookOwnerId;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: c.isPinned
                                  ? Border.all(color: Colors.amber.shade300, width: 1.5)
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 📌 PINNED COMMENT INDICATOR
                                if (c.isPinned) ...[
                                  Row(
                                    children: [
                                      Icon(Icons.push_pin_rounded, size: 12, color: Colors.amber.shade800),
                                      const SizedBox(width: 4),
                                      Text(
                                        "PINNED BY AUTHOR",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: Colors.amber.shade900, letterSpacing: 0.5),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                ],

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          c.userName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: StarlightTheme.primaryBlue),
                                        ),
                                        // 🎓 AUTHOR / OWNER BADGE
                                        if (c.isAuthorComment) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: StarlightTheme.primaryBlue, borderRadius: BorderRadius.circular(6)),
                                            child: const Text(
                                              "AUTHOR",
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 8, color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          _formatTime(c.createdAt),
                                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                                        ),
                                        // 📌 PIN ACTION (Only visible if current user owns the library)
                                        if (isBookOwner) ...[
                                          const SizedBox(width: 6),
                                          GestureDetector(
                                            onTap: () => _handlePinComment(c, i),
                                            child: Icon(
                                              c.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                                              size: 14,
                                              color: c.isPinned ? Colors.amber.shade800 : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  c.commentText,
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                ),
                                const Divider(height: 16),
                                // 👍👎 COMMENT LIKES & DISLIKES
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _handleLikeComment(c, i),
                                      child: Row(
                                        children: [
                                          Icon(
                                            c.userLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                                            size: 13,
                                            color: c.userLiked ? StarlightTheme.primaryBlue : Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${c.likesCount}",
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: () => _handleDislikeComment(c, i),
                                      child: Row(
                                        children: [
                                          Icon(
                                            c.userDisliked ? Icons.thumb_down_rounded : Icons.thumb_down_alt_outlined,
                                            size: 13,
                                            color: c.userDisliked ? Colors.red : Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${c.dislikesCount}",
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      decoration: InputDecoration(
                        hintText: "Add your review or comment...",
                        hintStyle: const TextStyle(fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        isDense: true,
                        fillColor: const Color(0xFFF5F7FA),
                        filled: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _submitting ? null : _submitComment,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: StarlightTheme.primaryBlue,
                      child: _submitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
