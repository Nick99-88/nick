import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../models/book_models.dart';
import '../services/library_service.dart';
import 'upload_book_screen.dart';
import 'library_ad_gate_dialog.dart';
import 'library_add_to_playlist_dialog.dart';
import 'library_tiktok_player_screen.dart';

class LibraryHomeScreen extends StatefulWidget {
  const LibraryHomeScreen({super.key});

  @override
  State<LibraryHomeScreen> createState() => _LibraryHomeScreenState();
}

class _LibraryHomeScreenState extends State<LibraryHomeScreen> {
  bool _loading = true;
  bool _hasChannel = false;
  LibraryChannel? _userChannel;
  
  List<Book> _trending = [];
  List<Book> _newNotes = [];
  List<Book> _globalFeed = [];

  @override
  void initState() {
    super.initState();
    _checkChannelStatus();
    _loadGlobalContent();
  }

  Future<void> _checkChannelStatus() async {
    try {
      final res = await LibraryService.checkChannel();
      if (mounted) {
        setState(() {
          _hasChannel = res['has_channel'] == true;
          if (_hasChannel && res['channel'] != null) {
            _userChannel = LibraryChannel.fromJson(res['channel']);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadGlobalContent() async {
    setState(() => _loading = true);
    try {
      final home = await LibraryService.getLibraryHome();
      final feed = await LibraryService.getBooks(limit: 50);
      if (mounted) {
        setState(() {
          _newNotes = home['new_notes'] ?? [];
          _trending = home['trending'] ?? [];
          _globalFeed = feed.where((b) => !b.forceStopped).toList();
          _loading = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _updateBookInList(Book book) {
    void tryUpdate(List<Book> list) {
      final idx = list.indexWhere((b) => b.id == book.id);
      if (idx != -1) list[idx] = book;
    }
    tryUpdate(_trending);
    tryUpdate(_newNotes);
    tryUpdate(_globalFeed);
  }

  Future<void> _handleLike(Book book) async {
    try {
      final res = await LibraryService.toggleLike(book.id);
      setState(() {
        _updateBookInList(book.copyWith(
          likesCount: res['likes'],
          dislikesCount: res['dislikes'],
          userLiked: res['user_liked'],
          userDisliked: false,
        ));
      });
    } catch (_) {}
  }

  Future<void> _handleDislike(Book book) async {
    try {
      final res = await LibraryService.toggleDislike(book.id);
      setState(() {
        _updateBookInList(book.copyWith(
          likesCount: res['likes'],
          dislikesCount: res['dislikes'],
          userLiked: false,
          userDisliked: res['user_disliked'],
        ));
      });
    } catch (_) {}
  }

  Future<void> _handleSave(Book book) async {
    try {
      final res = await LibraryService.toggleSave(book.id);
      setState(() {
        _updateBookInList(book.copyWith(userSaved: res['saved']));
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

  Future<void> _handleReport(Book book) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Report Inappropriate Content", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Please specify why you are reporting this document:", style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                hintText: "e.g. Inappropriate topic, incorrect content",
                hintStyle: TextStyle(fontSize: 12),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Report", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && reasonCtrl.text.trim().isNotEmpty) {
      try {
        await LibraryService.reportBook(book.id, reasonCtrl.text.trim());
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Document reported successfully")));
      } catch (_) {}
    }
  }

  Future<void> _examineDocument(Book book) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text(
              "Loading document...",
              style: TextStyle(color: Colors.white, decoration: TextDecoration.none, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    Book latestBook;
    try {
      latestBook = await LibraryService.getBook(book.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Check access permissions
    try {
      final access = await LibraryService.getBookAccess(book.id);
      if (access['can_view'] != true) {
        if (!mounted) return;
        final accessType = access['access_type'] ?? '';
        final msg = accessType == 'needs_rent'
            ? 'This document requires an active rental'
            : 'Purchase or rent required to view this document';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
        return;
      }
      if (access['show_ads'] == true) {
        if (!mounted) return;
        final adResult = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const AdGateDialog(),
        );
        if (adResult != true) return;
      }
    } catch (_) {}

    _updateBookInList(latestBook);

    // Unified TikTok-style player for all document types
    final updatedBook = await Navigator.push<Book>(
      context,
      MaterialPageRoute(builder: (context) => LibraryTiktokPlayerScreen(book: latestBook)),
    );
    if (updatedBook != null && mounted) {
      setState(() => _updateBookInList(updatedBook));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadGlobalContent,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_trending.isEmpty && _newNotes.isEmpty && _globalFeed.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.explore_rounded, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text("No documents yet",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF263238))),
                            const SizedBox(height: 8),
                            Text("Upload your first document to get started",
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                    ),
                  
                  // Trending Section
                  if (_trending.isNotEmpty)
                    _buildSection("🔥 Trending", _trending),
                  
                  // New Notes Section
                  if (_newNotes.isNotEmpty)
                    _buildSection("🆕 New Notes", _newNotes),
                  
                  // Global Feed Section
                  if (_globalFeed.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: Row(
                        children: [
                          const Icon(Icons.explore_rounded, size: 20, color: Color(0xFF263238)),
                          const SizedBox(width: 8),
                          const Text(
                            "🌍 Explore",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF263238)),
                          ),
                          const Spacer(),
                          Text(
                            "${_globalFeed.length} documents",
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    ..._globalFeed.map((book) => _buildFeedCard(book)),
                  ],
                  
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: _hasChannel
          ? FloatingActionButton(
              backgroundColor: StarlightTheme.primaryBlue,
              child: const Icon(Icons.add, color: Colors.white),
              onPressed: () async {
                final res = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => const UploadBookScreen()));
                if (res == true) _loadGlobalContent();
              },
            )
          : null,
    );
  }

  Widget _buildSection(String title, List<Book> books) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF263238)),
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: books.length,
            itemBuilder: (ctx, i) {
              final book = books[i];
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 12),
                child: _buildBookCard(book),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBookCard(Book book) {
    return GestureDetector(
      onTap: () => _examineDocument(book),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          Container(
            height: 155,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _fileKindColor(book).withOpacity(0.3),
            ),
            child: Stack(
              children: [
                if (book.thumbnailUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      book.absoluteThumbnailUrl,
                      width: 140,
                      height: 155,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, error, stack) => _buildDefaultThumbnail(book),
                    ),
                  )
                else
                  _buildDefaultThumbnail(book),
                // Play overlay for notes
                if (book.docType == 'note')
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                      ),
                    ),
                  ),
                // Monetization badge
                if (book.monetizationType != 'free')
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _monetizationBadge(book.monetizationType),
                  ),
                // Menu button
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: _buildCardMenu(book),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Title
          Text(
            book.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF263238)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // Author
          Text(
            book.author,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // Stats row
          Row(
            children: [
              Icon(Icons.visibility, size: 12, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text("${book.viewsCount}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(width: 8),
              Icon(Icons.thumb_up, size: 12, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text("${book.likesCount}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardMenu(Book book) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 16, color: Colors.grey),
      onSelected: (val) {
        if (val == 'report') _handleReport(book);
        if (val == 'playlist') {
          showDialog(
            context: context,
            builder: (_) => AddToPlaylistDialog(bookId: book.id),
          );
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'playlist', child: Row(
          children: [Icon(Icons.playlist_add, size: 16), SizedBox(width: 6), Text("Add to Playlist", style: TextStyle(fontSize: 12))],
        )),
        PopupMenuItem(value: 'report', child: Row(
          children: [Icon(Icons.flag_outlined, size: 16, color: Colors.grey), SizedBox(width: 6), Text("Report", style: TextStyle(fontSize: 12))],
        )),
      ],
    );
  }

  Widget _buildFeedCard(Book book) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _examineDocument(book),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: book.thumbnailUrl.isNotEmpty
                    ? Image.network(book.absoluteThumbnailUrl, width: 48, height: 60, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48, height: 60,
                          color: _fileKindColor(book).withOpacity(0.2),
                          child: Icon(_fileKindIcon(book), size: 24, color: _fileKindColor(book)),
                        ),
                      )
                    : Container(
                        width: 48, height: 60,
                        color: _fileKindColor(book).withOpacity(0.2),
                        child: Icon(_fileKindIcon(book), size: 24, color: _fileKindColor(book)),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(book.author, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.visibility, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text("${book.viewsCount}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(width: 10),
                        Icon(Icons.thumb_up, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text("${book.likesCount}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(width: 10),
                        Text(book.channelName, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ],
                ),
              ),
              _buildCardMenu(book),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monetizationBadge(String type) {
    String label;
    Color color;
    IconData icon;
    switch (type) {
      case 'ads_only':
        label = 'Ads';
        color = Colors.amber;
        icon = Icons.ads_click;
        break;
      case 'rent':
        label = 'Rent';
        color = Colors.blue;
        icon = Icons.folder_open;
        break;
      case 'sell':
        label = 'Buy';
        color = Colors.orange;
        icon = Icons.shopping_cart;
        break;
      case 'user_decision':
        label = 'Choose';
        color = Colors.purple;
        icon = Icons.touch_app;
        break;
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildDefaultThumbnail(Book book) {
    return Container(
      width: 140,
      height: 155,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _fileKindColor(book),
            _fileKindColor(book).withOpacity(0.6),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_fileKindIcon(book), color: Colors.white, size: 40),
          const SizedBox(height: 8),
          Text(
            book.resolvedExt.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
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
}
