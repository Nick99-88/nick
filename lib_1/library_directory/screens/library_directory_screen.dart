import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../models/book_models.dart';
import '../services/library_service.dart';
import 'book_comments_screen.dart';
import 'channel_profile_screen.dart';
import 'create_channel_screen.dart';
import 'upload_book_screen.dart';
import 'library_home_screen.dart';
import 'library_studio_screen.dart';
import 'library_playlist_tab.dart';
import 'library_add_to_playlist_dialog.dart';
import 'library_ad_gate_dialog.dart';
import 'library_purchase_dialog.dart';
import 'library_tiktok_player_screen.dart';

class LibraryDirectoryScreen extends StatefulWidget {
  const LibraryDirectoryScreen({super.key});

  @override
  State<LibraryDirectoryScreen> createState() => _LibraryDirectoryScreenState();
}

class _LibraryDirectoryScreenState extends State<LibraryDirectoryScreen> {
  final _searchCtrl = TextEditingController();
  
  List<Book> _books = [];
  List<LibraryChannel> _subscribedChannels = [];
  bool _loading = true;
  bool _hasChannel = false;
  LibraryChannel? _userChannel;

  // 🏛️ Active view tab: 0 = Home (Trending + Shorts), 1 = Subscribed, 2 = Document Analysis
  int _activeTab = 0;

  String _filterType = 'all'; // 'all', 'note', 'book'
  bool _showMineOnly = false;

  // 🔍 Search results
  List<Book> _searchBooks = [];
  List<Map<String, dynamic>> _searchChannels = [];
  bool _searchLoading = false;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _checkChannelStatus();
    _loadBooks();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
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

  Future<void> _loadBooks() async {
    if (_activeTab == 0) return; // Home tab doesn't need book loading
    
    setState(() => _loading = true);
    try {
      final List<Book> books;
      if (_activeTab == 2) {
        // 📊 Document Analysis: global with optional my-only filter
        books = await LibraryService.getBooks(
          search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
          limit: 200,
          mine: _showMineOnly ? true : null,
        );
      } else {
        // 🔔 Fetch publications only from channels the user has SUBSCRIBED to
        books = await LibraryService.getBooks(
          search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
          limit: 50,
          subscribed: true,
        );
      }
      setState(() {
        _books = _filterType == 'all' ? books : books.where((b) => b.docType == _filterType).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
    // Also fetch subscribed channels for tab 1
    if (_activeTab == 1 && mounted) {
      try {
        final channels = await LibraryService.getSubscribedChannels();
        if (mounted) setState(() => _subscribedChannels = channels);
      } catch (_) {}
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchBooks = [];
        _searchChannels = [];
        _searchLoading = false;
      });
      return;
    }
    setState(() => _searchLoading = true);
    try {
      final res = await LibraryService.searchAll(query);
      final booksRaw = (res['books'] as List?) ?? [];
      final channelsRaw = (res['channels'] as List?) ?? [];
      setState(() {
        _searchBooks = booksRaw.map((b) => Book.fromJson(Map<String, dynamic>.from(b))).toList();
        _searchChannels = channelsRaw.map((c) => Map<String, dynamic>.from(c)).toList();
        _searchLoading = false;
      });
    } catch (_) {
      setState(() {
        _searchLoading = false;
        _searchBooks = [];
        _searchChannels = [];
      });
    }
  }

  Future<void> _handleLike(Book book, int index) async {
    try {
      final res = await LibraryService.toggleLike(book.id);
      setState(() {
        _books[index] = book.copyWith(
          likesCount: res['likes'],
          dislikesCount: res['dislikes'],
          userLiked: res['user_liked'],
          userDisliked: false,
        );
      });
    } catch (_) {}
  }

  Future<void> _handleDislike(Book book, int index) async {
    try {
      final res = await LibraryService.toggleDislike(book.id);
      setState(() {
        _books[index] = book.copyWith(
          likesCount: res['likes'],
          dislikesCount: res['dislikes'],
          userLiked: false,
          userDisliked: res['user_disliked'],
        );
      });
    } catch (_) {}
  }

  Future<void> _handleSave(Book book, int index) async {
    try {
      final res = await LibraryService.toggleSave(book.id);
      setState(() {
        _books[index] = book.copyWith(userSaved: res['saved']);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['saved'] ? "Saved to bookmarks successfully" : "Removed from bookmarks"),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _handleReport(Book book, int index) async {
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
        final res = await LibraryService.reportBook(book.id, reasonCtrl.text.trim());
        setState(() {
          _books[index] = book.copyWith(
            reportsCount: res['reports_count'],
            userReported: true,
          );
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Document reported successfully")));
      } catch (_) {}
    }
  }

  Future<void> _examineDocument(Book book, int index) async {
    // 🏛️ Show loading dialog while fetching the latest document state from DB
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
              "Fetching document from DB...",
              style: TextStyle(color: Colors.white, decoration: TextDecoration.none, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    Book latestBook;
    try {
      latestBook = await LibraryService.getBook(book.id);
      if (mounted) Navigator.pop(context); // Dismiss loading dialog
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching document details: $e"), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Update local state with the fetched book details
    if (index >= 0) setState(() => _books[index] = latestBook);

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
          // Retry access check after purchase
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
    final updatedBook = await Navigator.push<Book>(
      context,
      MaterialPageRoute(builder: (context) => LibraryTiktokPlayerScreen(book: latestBook)),
    );
    if (updatedBook != null && mounted && index >= 0) setState(() => _books[index] = updatedBook);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text("STARLIGHT LIBRARY ENGINE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF263238))),
        centerTitle: true,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, size: 20),
            tooltip: "Library Studio",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LibraryStudioScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          // 🚀 CHANNEL LOGIC BANNER (Create or View my Channel Profile)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [StarlightTheme.primaryBlue, Color(0xFF1565C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: StarlightTheme.primaryBlue.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: const Icon(Icons.rocket_launch, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hasChannel ? _userChannel!.name : "Become a Publisher!",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                        Text(
                          _hasChannel ? "Manage your study notes & library publications" : "Create your own Library and publish books",
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: StarlightTheme.primaryBlue,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () async {
                      if (_hasChannel && _userChannel != null) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => ChannelProfileScreen(channelId: _userChannel!.id)));
                      } else {
                        final res = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => const CreateChannelScreen()));
                        if (res == true) _checkChannelStatus();
                      }
                    },
                    child: Text(
                      _hasChannel ? "Dashboard" : "Launch",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🔍 SEARCH ENGINE CARD
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: _activeTab == 1 ? "Search subscribed channels..." : _activeTab == 2 ? "Search your documents..." : "Search books, notes, topics...",
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 20, color: StarlightTheme.primaryBlue),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.grey.shade300)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                    fillColor: const Color(0xFFF5F7FA),
                    filled: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (val) {
                    _searchTimer?.cancel();
                    _searchTimer = Timer(const Duration(milliseconds: 400), () => _performSearch(val));
                    _loadBooks();
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _filterChip('All', 'all'),
                    const SizedBox(width: 6),
                    _filterChip('Notes', 'note'),
                    const SizedBox(width: 6),
                    _filterChip('Documents', 'book'),
                    if (_activeTab == 2) ...[
                      const SizedBox(width: 6),
                      _mineToggleChip(),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // 🏛Override Tab Selector (Home vs Subscribed vs Document Analysis)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _tabButton(0, "HOME", Icons.home_rounded),
                  const SizedBox(width: 8),
                  _tabButton(1, "SUBSCRIBED", Icons.notifications_active_rounded),
                  const SizedBox(width: 8),
                  _tabButton(2, "ANALYSIS", Icons.analytics_rounded),
                  const SizedBox(width: 8),
                  _tabButton(3, "PLAYLIST", Icons.playlist_play_rounded),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // 🔍 Search results overlay or tab content
          Expanded(
            child: _searchCtrl.text.isNotEmpty
                ? _buildSearchResults()
                : _activeTab == 0
                    ? const LibraryHomeScreen()
                    : _activeTab == 2
                        ? _buildAnalysisTab()
                        : _activeTab == 3
                            ? const LibraryPlaylistTab()
                    : _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _subscribedTabContent(),
          ),
        ],
      ),
      floatingActionButton: _hasChannel
          ? FloatingActionButton(
              backgroundColor: StarlightTheme.primaryBlue,
              child: const Icon(Icons.add, color: Colors.white),
              onPressed: () async {
                final res = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => const UploadBookScreen()));
                if (res == true) _loadBooks();
              },
            )
          : null,
    );
  }

  Color _getPicColor(String pic) {
    switch (pic) {
      case 'avatar_blue': return Colors.blue;
      case 'avatar_green': return Colors.green;
      case 'avatar_orange': return Colors.orange;
      case 'avatar_purple': return Colors.purple;
      case 'avatar_teal': return Colors.teal;
      default: return Colors.blue;
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

  Widget _buildSearchResults() {
    return _searchLoading
        ? const Center(child: CircularProgressIndicator())
        : _searchBooks.isEmpty && _searchChannels.isEmpty
            ? const SizedBox(
                height: 200,
                child: Center(child: Text('No results found', style: TextStyle(fontSize: 13, color: Colors.grey))),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  if (_searchChannels.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('CHANNELS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600, letterSpacing: 1)),
                    ),
                    ..._searchChannels.map((ch) => _buildChannelResultTile(ch)),
                    const SizedBox(height: 16),
                  ],
                  if (_searchBooks.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('DOCUMENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600, letterSpacing: 1)),
                    ),
                    ..._searchBooks.asMap().entries.map((e) => _buildSearchBookTile(e.value, e.key)),
                  ],
                ],
              );
  }

  Widget _buildChannelResultTile(Map<String, dynamic> ch) {
    final subscribed = ch['user_subscribed'] == true;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      leading: CircleAvatar(
        radius: 18,
        backgroundImage: ch['logo'] != null ? NetworkImage(ch['logo']) : null,
        child: ch['logo'] == null ? Text((ch['name'] ?? '?')[0].toUpperCase(), style: const TextStyle(fontSize: 13)) : null,
      ),
      title: Text(ch['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: ch['description'] != null ? Text(ch['description'], style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis) : null,
      onTap: () {
        _searchCtrl.clear();
        _performSearch('');
        Navigator.push(context, MaterialPageRoute(builder: (context) => ChannelProfileScreen(channelId: ch['id'])));
      },
      trailing: TextButton(
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        onPressed: () async {
          final res = await LibraryService.toggleSubscribe(ch['id']);
          setState(() {
            ch['user_subscribed'] = res['subscribed'] == true;
          });
        },
        child: Text(subscribed ? 'Subscribed' : 'Subscribe', style: TextStyle(fontSize: 11, color: subscribed ? Colors.grey : StarlightTheme.primaryBlue)),
      ),
    );
  }

  Widget _buildSearchBookTile(Book book, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: book.thumbnailUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(book.thumbnailUrl, width: 40, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 40, height: 50, child: Icon(Icons.article, color: Colors.grey))),
              )
            : Container(width: 40, height: 50, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.article, color: Colors.grey, size: 22)),
        title: Text(book.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(book.author, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
        onTap: () {
          _searchCtrl.clear();
          _performSearch('');
          Navigator.push(context, MaterialPageRoute(builder: (context) => ChannelProfileScreen(channelId: book.channelId)));
        },
      ),
    );
  }

  Widget _buildAnalysisTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final totalViews = _books.fold<int>(0, (s, b) => s + b.viewsCount);
    final totalLikes = _books.fold<int>(0, (s, b) => s + b.likesCount);
    final totalReports = _books.fold<int>(0, (s, b) => s + b.reportsCount);

    final sortedByViews = List<Book>.from(_books)
      ..sort((a, b) => b.viewsCount.compareTo(a.viewsCount));
    final sortedByLikes = List<Book>.from(_books)
      ..sort((a, b) => b.likesCount.compareTo(a.likesCount));
    final topViewed = sortedByViews.take(5).toList();
    final topLiked = sortedByLikes.take(5).toList();

    String viewsFormatted(int v) => v >= 1000000 ? '${(v / 1000000).toStringAsFixed(1)}M' : v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : '$v';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: StarlightTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.analytics_rounded, color: StarlightTheme.primaryBlue, size: 24),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Channel Analytics",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF263238))),
                  Text("All-time performance overview",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Metric cards row
          Row(
            children: [
              Expanded(child: _metricCard("Total views", viewsFormatted(totalViews), Icons.visibility, Colors.blue, totalViews > 0 ? (totalViews / (totalViews + totalLikes + totalReports) * 100).toStringAsFixed(0) : '0')),
              const SizedBox(width: 10),
              Expanded(child: _metricCard("Total likes", viewsFormatted(totalLikes), Icons.thumb_up, Colors.green, totalLikes > 0 ? (totalLikes / (totalViews + totalLikes) * 100).toStringAsFixed(0) : '0')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _metricCard("Documents", "${_books.length}", Icons.description, StarlightTheme.primaryBlue, '${_books.where((b) => b.docType == 'note').length} notes')),
              const SizedBox(width: 10),
              Expanded(child: _metricCard("Reports", viewsFormatted(totalReports), Icons.flag, Colors.red, '${_books.where((b) => b.reportsCount > 0).length} flagged')),
            ],
          ),
          const SizedBox(height: 24),

          // Section header
          _sectionHeader(Icons.trending_up_rounded, "Top-performing content", "Most viewed documents"),
          const SizedBox(height: 10),
          ...topViewed.asMap().entries.map((e) => _contentRow(
            rank: e.key + 1,
            book: e.value,
            metric: "👁 ${viewsFormatted(e.value.viewsCount)}",
            metricColor: Colors.blue,
            barFraction: topViewed.first.viewsCount > 0 ? e.value.viewsCount / topViewed.first.viewsCount : 0,
          )),
          const SizedBox(height: 24),

          _sectionHeader(Icons.favorite_rounded, "Most engaging", "Highest liked documents"),
          const SizedBox(height: 10),
          ...topLiked.asMap().entries.map((e) => _contentRow(
            rank: e.key + 1,
            book: e.value,
            metric: "❤ ${viewsFormatted(e.value.likesCount)}",
            metricColor: Colors.red,
            barFraction: topLiked.first.likesCount > 0 ? e.value.likesCount / topLiked.first.likesCount : 0,
          )),
          const SizedBox(height: 24),

          // Overall engagement rate
          _sectionHeader(Icons.pie_chart_rounded, "Engagement", "Likes per view ratio"),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 80, height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80, height: 80,
                        child: CircularProgressIndicator(
                          value: totalViews > 0 ? (totalLikes / totalViews).clamp(0, 1) : 0,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation(Colors.green),
                        ),
                      ),
                      Text("${totalViews > 0 ? (totalLikes / totalViews * 100).toStringAsFixed(1) : '0'}%",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statRow("Views", viewsFormatted(totalViews), Colors.blue),
                      const SizedBox(height: 6),
                      _statRow("Likes", viewsFormatted(totalLikes), Colors.green),
                      const SizedBox(height: 6),
                      _statRow("Ratio", "${totalViews > 0 ? (totalLikes / totalViews * 100).toStringAsFixed(1) : '0'}%", Colors.orange),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: color, height: 1)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Icon(icon, size: 18, color: StarlightTheme.primaryBlue),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF263238))),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ],
    );
  }

  Widget _contentRow({required int rank, required Book book, required String metric, required Color metricColor, required double barFraction}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: rank <= 3 ? [const Color(0xFFFFD700), const Color(0xFFC0C0C0), const Color(0xFFCD7F32)][rank - 1] : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text("#$rank", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: rank <= 3 ? Colors.black : Colors.grey.shade700)),
            ),
            const SizedBox(width: 10),
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: book.thumbnailUrl.isNotEmpty
                  ? Image.network(book.absoluteThumbnailUrl, width: 36, height: 36, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 36, height: 36,
                        color: _fileKindColor(book).withOpacity(0.2),
                        child: Icon(_fileKindIcon(book), size: 18, color: _fileKindColor(book)),
                      ),
                    )
                  : Container(
                      width: 36, height: 36,
                      color: _fileKindColor(book).withOpacity(0.2),
                      child: Icon(_fileKindIcon(book), size: 18, color: _fileKindColor(book)),
                    ),
            ),
            const SizedBox(width: 10),
            // Title + metric
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF263238)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(metric, style: TextStyle(fontSize: 10, color: metricColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Mini bar
            Container(
              width: 50, height: 6,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: barFraction.clamp(0, 1),
                child: Container(
                  decoration: BoxDecoration(
                    color: metricColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, Color color) {
    return Row(
      children: [
        Icon(Icons.circle, size: 6, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final active = _filterType == value;
    return InkWell(
      onTap: () {
        setState(() => _filterType = value);
        _loadBooks();
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

  Widget _mineToggleChip() {
    return InkWell(
      onTap: () {
        setState(() => _showMineOnly = !_showMineOnly);
        _loadBooks();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _showMineOnly ? StarlightTheme.primaryBlue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person, size: 12, color: _showMineOnly ? Colors.white : Colors.black54),
            const SizedBox(width: 4),
            Text(
              "My Uploads",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: _showMineOnly ? Colors.white : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subscribedTabContent() {
    if (_books.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: (_subscribedChannels.isNotEmpty ? 1 : 0) + _books.length,
        itemBuilder: (ctx, i) {
          // First item: channel avatars row
          if (i == 0 && _subscribedChannels.isNotEmpty) {
            return _buildSubscribedChannelsRow();
          }
          final book = _books[_subscribedChannels.isNotEmpty ? i - 1 : i];
          final idx = _subscribedChannels.isNotEmpty ? i - 1 : i;
          return _buildBookCard(book, idx);
        },
      );
    }
    // No books — show subscribed channels row or empty state
    if (_subscribedChannels.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildSubscribedChannelsRow(),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Icon(Icons.notifications_off_rounded, size: 40, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                const Text("No publications yet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey)),
                const SizedBox(height: 4),
                const Text("Wait for channels to publish new content", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      );
    }
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_rounded, size: 50, color: Colors.grey),
          SizedBox(height: 8),
          Text("No subscribed content", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Text("Subscribe to channels to see their publications here", style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSubscribedChannelsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text("Subscribed Channels", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
        ),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _subscribedChannels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (ctx, i) {
              final ch = _subscribedChannels[i];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelProfileScreen(channelId: ch.id))),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: ch.profilePic.isNotEmpty && ch.profilePic != 'default_avatar'
                          ? NetworkImage(ch.absoluteProfilePicUrl)
                          : null,
                      backgroundColor: Colors.grey.shade200,
                      child: ch.profilePic.isEmpty || ch.profilePic == 'default_avatar'
                          ? Icon(Icons.person, color: Colors.grey.shade500)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 56,
                      child: Text(ch.name, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const Divider(height: 24),
      ],
    );
  }

  Widget _buildBookCard(Book book, int i) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelProfileScreen(channelId: book.channelId))),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    book.absoluteChannelPicUrl.isNotEmpty
                        ? CircleAvatar(radius: 14, backgroundImage: NetworkImage(book.absoluteChannelPicUrl))
                        : CircleAvatar(radius: 14, backgroundColor: _getPicColor(book.channelPic).withOpacity(0.15), child: Icon(Icons.menu_book_rounded, color: _getPicColor(book.channelPic), size: 14)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(book.channelName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                        const Text("View Library Profile", style: TextStyle(fontSize: 9, color: StarlightTheme.primaryBlue, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: book.thumbnailUrl.isNotEmpty
                      ? Image.network(book.absoluteThumbnailUrl, width: 45, height: 55, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 45, height: 55, color: _fileKindColor(book).withOpacity(0.12),
                            child: Icon(_fileKindIcon(book), color: _fileKindColor(book), size: 24)))
                      : Container(width: 45, height: 55, decoration: BoxDecoration(color: _fileKindColor(book).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                          child: Icon(_fileKindIcon(book), color: _fileKindColor(book), size: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text("By: ${book.author}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6, runSpacing: 4,
                        children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: StarlightTheme.primaryBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                            child: Text(book.topic, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue))),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: _fileKindColor(book).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                            child: Text(_fileKindLabel(book), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _fileKindColor(book)))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(icon: Icon(book.userLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined, size: 18, color: book.userLiked ? StarlightTheme.primaryBlue : Colors.grey),
                        onPressed: () => _handleLike(book, i), tooltip: "Like"),
                    Text("${book.likesCount}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(width: 8),
                    IconButton(icon: Icon(book.userDisliked ? Icons.thumb_down_rounded : Icons.thumb_down_alt_outlined, size: 18, color: book.userDisliked ? Colors.red : Colors.grey),
                        onPressed: () => _handleDislike(book, i), tooltip: "Dislike"),
                    Text("${book.dislikesCount}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.comment_outlined, size: 18, color: Colors.grey),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookCommentsScreen(book: book))), tooltip: "Comments & Reviews"),
                    const SizedBox(width: 8),
                    IconButton(icon: Icon(book.userSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded, size: 18, color: book.userSaved ? Colors.amber.shade700 : Colors.grey),
                        onPressed: () => _handleSave(book, i), tooltip: "Save bookmark"),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'report' && !book.userReported) _handleReport(book, i);
                    if (val == 'playlist') showDialog(context: context, builder: (_) => AddToPlaylistDialog(bookId: book.id));
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'playlist', child: Row(children: [Icon(Icons.playlist_add, size: 16), SizedBox(width: 6), Text("Add to Playlist", style: TextStyle(fontSize: 12))])),
                    PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.flag_outlined, size: 16, color: book.userReported ? Colors.orange : Colors.grey), SizedBox(width: 6), Text(book.userReported ? "Reported" : "Report", style: TextStyle(fontSize: 12))])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 38,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: StarlightTheme.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                icon: const Icon(Icons.menu_book_rounded, size: 14, color: Colors.white),
                label: Text(_examineLabel(book).toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                onPressed: () => _examineDocument(book, i),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(int index, String title, IconData icon) {
    final active = _activeTab == index;
    final color = active ? StarlightTheme.primaryBlue : Colors.grey.shade600;
    return InkWell(
      onTap: () {
        if (_activeTab == index) return;
        setState(() {
          _activeTab = index;
        });
        _loadBooks();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? StarlightTheme.primaryBlue.withOpacity(0.08) : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? StarlightTheme.primaryBlue.withOpacity(0.2) : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }
}


