import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../models/book_models.dart';
import '../services/library_service.dart';
import 'book_comments_screen.dart';
import 'library_ad_gate_dialog.dart';
import 'library_add_to_playlist_dialog.dart';
import 'library_purchase_dialog.dart';
import 'library_tiktok_player_screen.dart';

class ChannelProfileScreen extends StatefulWidget {
  final String channelId;

  const ChannelProfileScreen({super.key, required this.channelId});

  @override
  State<ChannelProfileScreen> createState() => _ChannelProfileScreenState();
}

class _ChannelProfileScreenState extends State<ChannelProfileScreen> {
  LibraryChannel? _channel;
  List<Book> _allBooks = [];
  List<Book> _books = [];
  bool _loading = true;

  // 🏛️ Flag indicating whether the current logged-in user is the owner of this channel
  bool _isOwner = false;

  String _filterType = 'all'; // 'all', 'note', 'book'

  @override
  void initState() {
    super.initState();
    _loadChannelDetails();
  }

  Future<void> _loadChannelDetails() async {
    setState(() => _loading = true);
    try {
      // 1. Fetch own channel first to perform ID comparisons
      String? ownChannelId;
      try {
        final ownRes = await LibraryService.checkChannel();
        if (ownRes['has_channel'] == true && ownRes['channel'] != null) {
          ownChannelId = ownRes['channel']['id'];
        }
      } catch (_) {}

      // 2. Fetch target channel details
      final res = await LibraryService.getChannelDetails(widget.channelId);
      if (res['channel'] != null) {
        setState(() {
          _channel = LibraryChannel.fromJson(res['channel']);
          _isOwner = ownChannelId != null && ownChannelId == _channel!.id;
          if (res['books'] is List) {
            _allBooks = (res['books'] as List).map((b) => Book.fromJson(b)).toList();
            _applyFilter();
          }
          _loading = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleSubscribe() async {
    try {
      final res = await LibraryService.toggleSubscribe(_channel!.id);
      setState(() {
        _channel = _channel!.copyWith(userSubscribed: res['subscribed']);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['subscribed'] ? "Subscribed to library successfully!" : "Unsubscribed from library"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Subscription action failed: $e")));
      }
    }
  }

  void _updateBookById(Book updated) {
    final idx = _allBooks.indexWhere((b) => b.id == updated.id);
    if (idx != -1) _allBooks[idx] = updated;
    _applyFilter();
  }

  Future<void> _handleLike(Book book, int index) async {
    try {
      final res = await LibraryService.toggleLike(book.id);
      _updateBookById(book.copyWith(
        likesCount: res['likes'],
        dislikesCount: res['dislikes'],
        userLiked: res['user_liked'],
        userDisliked: false,
      ));
    } catch (_) {}
  }

  Future<void> _handleDislike(Book book, int index) async {
    try {
      final res = await LibraryService.toggleDislike(book.id);
      _updateBookById(book.copyWith(
        likesCount: res['likes'],
        dislikesCount: res['dislikes'],
        userLiked: false,
        userDisliked: res['user_disliked'],
      ));
    } catch (_) {}
  }

  Future<void> _handleSave(Book book, int index) async {
    try {
      final res = await LibraryService.toggleSave(book.id);
      _updateBookById(book.copyWith(userSaved: res['saved']));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['saved'] ? "Document saved to bookmarks" : "Document removed from bookmarks"),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _toggleForceStop(Book book) async {
    try {
      await LibraryService.forceStopContent(book.id);
      if (!mounted) return;
      _updateBookById(book.copyWith(forceStopped: !book.forceStopped));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(book.forceStopped ? "Content restored" : "Content force stopped"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteContent(Book book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Publication", style: TextStyle(fontSize: 16)),
        content: Text("Delete \"${book.title}\" permanently?", style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await LibraryService.deleteContent(book.id);
      if (!mounted) return;
      setState(() {
        _allBooks.removeWhere((b) => b.id == book.id);
        _applyFilter();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Deleted"), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _examineDocument(Book book) async {
    // Check access permissions
    try {
      final access = await LibraryService.getBookAccess(book.id);
      if (access['can_view'] != true) {
        if (!mounted) return;
        final price = (book.price * 1).toInt();
        final monetization = access['monetization'] ?? 'sell';
        final purchased = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => LibraryPurchaseDialog(
            bookId: book.id,
            bookTitle: book.title,
            price: price > 0 ? price : 10,
            monetization: monetization,
          ),
        );
        if (purchased == true) {
          final retryAccess = await LibraryService.getBookAccess(book.id);
          if (retryAccess['can_view'] == true && retryAccess['show_ads'] == true && mounted) {
            final adResult = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => const AdGateDialog(),
            );
            if (adResult != true) return;
          } else if (retryAccess['can_view'] != true) {
            return;
          }
        } else {
          return;
        }
      } else if (access['show_ads'] == true) {
        if (!mounted) return;
        final adResult = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const AdGateDialog(),
        );
        if (adResult != true) return;
      }
    } catch (_) {}

    // Unified TikTok-style player for all document types
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LibraryTiktokPlayerScreen(book: book)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_channel == null) {
      return const Scaffold(
        body: Center(child: Text("Library not found")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: StarlightTheme.primaryBlue,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: StarlightTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 35),
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _channel!.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      "By ${_channel!.ownerName}",
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Channel Bio description Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("LIBRARY PROFILE BIO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 6),
                      Text(_channel!.description, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statItem("${_allBooks.length}", "Publications"),
                          _statItem("${_allBooks.fold(0, (sum, b) => sum + b.likesCount)}", "Total Likes"),
                          _statItem(_formatDate(_channel!.createdAt), "Launched"),
                        ],
                      ),
                      if (!_isOwner) ...[
                        const SizedBox(height: 16),
                        // 🔔 SUBSCRIBE BUTTON (Hidden if user owns the library)
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: OutlinedButton.icon(
                            onPressed: _toggleSubscribe,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _channel!.userSubscribed ? Colors.transparent : StarlightTheme.primaryBlue,
                              foregroundColor: _channel!.userSubscribed ? StarlightTheme.primaryBlue : Colors.white,
                              side: const BorderSide(color: StarlightTheme.primaryBlue, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: Icon(_channel!.userSubscribed ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, size: 18),
                            label: Text(
                              _channel!.userSubscribed ? "SUBSCRIBED" : "SUBSCRIBE TO LIBRARY",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Filter chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _filterChip('All', 'all'),
                  const SizedBox(width: 6),
                  _filterChip('Notes', 'note'),
                  const SizedBox(width: 6),
                  _filterChip('Documents', 'book'),
                  if (_isOwner) ...[
                    const SizedBox(width: 6),
                    _filterChip('Stopped', 'stopped'),
                  ],
                ],
              ),
            ),
          ),

          // Published books List
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(_filterType == 'stopped' ? Icons.block : Icons.library_books, size: 16, color: _filterType == 'stopped' ? Colors.redAccent : StarlightTheme.primaryBlue),
                  const SizedBox(width: 6),
                  Text(
                    _filterType == 'stopped' ? "STOPPED CONTENT (${_books.length})" : "PUBLISHED DOCUMENTS (${_books.length})",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _filterType == 'stopped' ? Colors.redAccent : Colors.black87),
                  ),
                ],
              ),
            ),
          ),

          _books.isEmpty
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text("No documents published yet", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final book = _books[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: book.thumbnailUrl.isNotEmpty
                                          ? Image.network(
                                              book.absoluteThumbnailUrl,
                                              width: 55,
                                              height: 70,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                width: 45,
                                                height: 55,
                                                color: _fileKindColor(book).withOpacity(0.12),
                                                child: Icon(_fileKindIcon(book), color: _fileKindColor(book), size: 24),
                                              ),
                                            )
                                          : Container(
                                              width: 45,
                                              height: 55,
                                              decoration: BoxDecoration(
                                                color: _fileKindColor(book).withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(_fileKindIcon(book), color: _fileKindColor(book), size: 24),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    book.title,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                      decoration: book.forceStopped ? TextDecoration.lineThrough : null,
                                                      color: book.forceStopped ? Colors.red : Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                                PopupMenuButton<String>(
                                                  icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                                                  onSelected: (val) {
                                                    if (val == 'playlist') {
                                                      showDialog(context: context, builder: (_) => AddToPlaylistDialog(bookId: book.id));
                                                    }
                                                    if (val == 'force_stop') _toggleForceStop(book);
                                                    if (val == 'delete') _deleteContent(book);
                                                  },
                                                  itemBuilder: (_) => [
                                                    const PopupMenuItem(
                                                      value: 'playlist',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.playlist_add, size: 18, color: Colors.blue),
                                                          SizedBox(width: 8),
                                                          Text("Add to Playlist", style: TextStyle(fontSize: 13)),
                                                        ],
                                                      ),
                                                    ),
                                                    if (_isOwner) ...[
                                                      PopupMenuItem(
                                                        value: 'force_stop',
                                                        child: Row(
                                                          children: [
                                                            Icon(book.forceStopped ? Icons.restore : Icons.block, size: 18, color: Colors.orangeAccent),
                                                            const SizedBox(width: 8),
                                                            Text(book.forceStopped ? "Restore" : "Force Stop", style: const TextStyle(fontSize: 13)),
                                                          ],
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'delete',
                                                        child: Row(
                                                          children: [
                                                            const Icon(Icons.delete_forever, size: 18, color: Colors.redAccent),
                                                            const SizedBox(width: 8),
                                                            const Text("Delete", style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(color: StarlightTheme.primaryBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                                                child: Text(book.topic, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue)),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(color: _fileKindColor(book).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                                                child: Text(
                                                  _fileKindLabel(book),
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _fileKindColor(book)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                 const Divider(height: 20),
                                 // Social Actions row 1 (Likes, Dislikes, Comments, Save)
                                 Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                     Row(
                                       children: [
                                         IconButton(
                                           icon: Icon(book.userLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined, size: 18, color: book.userLiked ? StarlightTheme.primaryBlue : Colors.grey),
                                           onPressed: () => _handleLike(book, i),
                                           tooltip: "Like",
                                         ),
                                         Text("${book.likesCount}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                         const SizedBox(width: 8),
                                         IconButton(
                                           icon: Icon(book.userDisliked ? Icons.thumb_down_rounded : Icons.thumb_down_alt_outlined, size: 18, color: book.userDisliked ? Colors.red : Colors.grey),
                                           onPressed: () => _handleDislike(book, i),
                                           tooltip: "Dislike",
                                         ),
                                         Text("${book.dislikesCount}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                         const SizedBox(width: 8),
                                         IconButton(
                                           icon: const Icon(Icons.comment_outlined, size: 18, color: Colors.grey),
                                           onPressed: () {
                                             Navigator.push(context, MaterialPageRoute(builder: (context) => BookCommentsScreen(book: book)));
                                           },
                                           tooltip: "Comments & Reviews",
                                         ),
                                       ],
                                     ),
                                     IconButton(
                                       icon: Icon(book.userSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded, size: 18, color: book.userSaved ? Colors.amber.shade700 : Colors.grey),
                                       onPressed: () => _handleSave(book, i),
                                       tooltip: "Save note",
                                     ),
                                   ],
                                 ),
                                 const SizedBox(height: 12),
                                 // Primary CTA Button (SizedBox width double.infinity, completely prevents horizontal overflow)
                                 SizedBox(
                                   width: double.infinity,
                                   height: 38,
                                   child: ElevatedButton.icon(
                                     style: ElevatedButton.styleFrom(
                                       backgroundColor: StarlightTheme.primaryBlue,
                                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                       elevation: 0,
                                     ),
                                     icon: const Icon(Icons.menu_book_rounded, size: 14, color: Colors.white),
                                     label: Text(
                                       _examineLabel(book).toUpperCase(),
                                       style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                                     ),
                                     onPressed: () => _examineDocument(book),
                                   ),
                                 ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: _books.length,
                  ),
                ),
        ],
      ),
    );
  }

  void _applyFilter() {
    if (_filterType == 'stopped') {
      _books = _allBooks.where((b) => b.forceStopped).toList();
    } else if (_filterType == 'all') {
      _books = List.from(_allBooks);
    } else {
      _books = _allBooks.where((b) => b.docType == _filterType).toList();
    }
  }

  Widget _filterChip(String label, String value) {
    final active = _filterType == value;
    return InkWell(
      onTap: () {
        setState(() => _filterType = value);
        _applyFilter();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? StarlightTheme.primaryBlue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: active ? Colors.white : Colors.black54),
        ),
      ),
    );
  }

  Widget _statItem(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: StarlightTheme.primaryBlue)),
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (_) {
      return "N/A";
    }
  }

  IconData _fileKindIcon(Book book) {
    switch (book.fileKind) {
      case 'image': return Icons.image_rounded;
      case 'spreadsheet': return Icons.table_chart_rounded;
      case 'presentation': return Icons.slideshow_rounded;
      case 'audio': return Icons.audiotrack_rounded;
      case 'archive': return Icons.folder_zip_rounded;
      case 'document':
        return book.resolvedExt == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.article_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  Color _fileKindColor(Book book) {
    switch (book.fileKind) {
      case 'image': return Colors.purple;
      case 'spreadsheet': return Colors.green;
      case 'presentation': return Colors.orange;
      case 'audio': return Colors.teal;
      case 'archive': return Colors.brown;
      case 'document':
        return book.resolvedExt == 'pdf' ? Colors.red : Colors.blue;
      default: return Colors.blueGrey;
    }
  }

  String _fileKindLabel(Book book) {
    final ext = book.resolvedExt;
    if (ext.isEmpty) return 'FILE';
    return ext.toUpperCase();
  }

  String _examineLabel(Book book) {
    switch (book.fileKind) {
      case 'image': return 'View';
      case 'archive': return 'Download';
      case 'audio': return 'Play';
      case 'spreadsheet': return 'Open';
      case 'presentation': return 'Open';
      case 'document':
        return book.resolvedExt == 'pdf' ? 'Examine' : 'Open';
      default: return 'Open';
    }
  }
}
