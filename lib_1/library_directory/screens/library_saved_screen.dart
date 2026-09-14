import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../models/book_models.dart';
import '../services/library_service.dart';
import '../services/library_download_service.dart'; // 🏛️ Added local SQLite download helper
import 'book_comments_screen.dart';
import 'channel_profile_screen.dart';
import 'library_tiktok_player_screen.dart';

class LibrarySavedScreen extends StatefulWidget {
  const LibrarySavedScreen({super.key});

  @override
  State<LibrarySavedScreen> createState() => _LibrarySavedScreenState();
}

class _LibrarySavedScreenState extends State<LibrarySavedScreen> {
  List<Book> _books = [];
  bool _loading = true;

  // 🏛️ Tab toggle state: 0 = Online Bookmarked, 1 = Offline Downloaded (from local DB)
  int _activeTab = 0;

  // 🏛️ Maps & sets to track download spinner and offline availability
  final Map<String, bool> _downloadingMap = {};
  final Set<String> _downloadedIds = {};

  @override
  void initState() {
    super.initState();
    _loadSavedBooks();
  }

  Future<void> _loadSavedBooks() async {
    setState(() => _loading = true);
    try {
      // Refresh local downloads list from SQLite
      final locals = await LibraryDownloadService.fetchDownloadedBooks();
      _downloadedIds.clear();
      _downloadedIds.addAll(locals.map((b) => b.id));

      if (_activeTab == 0) {
        // Tab 0: Load bookmarked publications from the server
        final books = await LibraryService.getSavedBooks();
        if (mounted) {
          setState(() {
            _books = books;
            _loading = false;
          });
        }
      } else {
        // Tab 1: Load downloaded publications from the local SQLite DB!
        if (mounted) {
          setState(() {
            _books = locals;
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 📥 Download publication to phone storage and insert metadata into SQLite local DB
  Future<void> _downloadBook(Book book, int index) async {
    // Check access before downloading
    try {
      final access = await LibraryService.getBookAccess(book.id);
      if (access['can_download'] != true) {
        _showSnack("Download not allowed for this document", isError: true);
        return;
      }
    } catch (_) {
      _showSnack("Could not verify download permissions", isError: true);
      return;
    }

    setState(() {
      _downloadingMap[book.id] = true;
    });

    try {
      await LibraryDownloadService.downloadAndSaveBook(book);
      if (!mounted) return;
      setState(() {
        _downloadingMap[book.id] = false;
        _downloadedIds.add(book.id);
      });
      _showSnack("Downloaded '${book.title}' successfully! Available offline.");
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloadingMap[book.id] = false;
      });
      _showSnack("Download failed: $e", isError: true);
    }
  }

  /// 🗑️ Delete publication from phone storage and remove record from SQLite local DB
  Future<void> _deleteLocalBook(Book book, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Offline Note", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text("Are you sure you want to delete this downloaded file from your offline reading list?", style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await LibraryDownloadService.deleteDownloadedBook(book.id);
      if (!mounted) return;
      setState(() {
        _downloadedIds.remove(book.id);
        if (_activeTab == 1) {
          _books.removeAt(index); // Remove from offline list view immediately
        }
      });
      _showSnack("Deleted offline note successfully.");
    } catch (e) {
      _showSnack("Failed to delete file: $e", isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleLike(Book book, int index) async {
    if (_activeTab == 1) {
      _showSnack("Likes are only available when online.", isError: true);
      return;
    }
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
    if (_activeTab == 1) {
      _showSnack("Dislikes are only available when online.", isError: true);
      return;
    }
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
    if (_activeTab == 1) {
      // In local view, bookmark toggle is unsaving from DB
      await _deleteLocalBook(book, index);
      return;
    }
    try {
      final res = await LibraryService.toggleSave(book.id);
      if (!res['saved']) {
        setState(() {
          _books.removeAt(index);
        });
      }
      if (mounted) {
        _showSnack(res['saved'] ? "Saved to bookmarks" : "Removed from bookmarks");
      }
    } catch (_) {}
  }

  Future<void> _examineDocument(Book book, int index) async {
    Book targetBook = book;

    if (_activeTab == 0) {
      // Online mode: Fetch fresh copy from DB
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 12),
              Text("Fetching latest document status...", style: TextStyle(color: Colors.white, fontSize: 12, decoration: TextDecoration.none)),
            ],
          ),
        ),
      );

      try {
        targetBook = await LibraryService.getBook(book.id);
        if (mounted) Navigator.pop(context); // Dismiss loading
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Dismiss loading
          _showSnack("Error fetching document details: $e", isError: true);
        }
        return;
      }

      if (!targetBook.userSaved) {
        setState(() => _books.removeAt(index));
        return;
      }

      setState(() => _books[index] = targetBook);
    }

    // Unified TikTok-style player for all document types
    final updatedBook = await Navigator.push<Book>(
      context,
      MaterialPageRoute(builder: (context) => LibraryTiktokPlayerScreen(book: targetBook)),
    );
    if (updatedBook != null && mounted && _activeTab == 0) {
      if (!updatedBook.userSaved) {
        setState(() => _books.removeAt(index));
      } else {
        setState(() => _books[index] = updatedBook);
      }
    }
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
        _loadSavedBooks();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text("SAVED LIBRARY NOTES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF263238))),
        centerTitle: true,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          // 🏛️ Tab toggle segment bar (Online Bookmarks vs Offline Downloads)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(child: _tabButton(0, "BOOKMARKS", Icons.bookmark_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _tabButton(1, "OFFLINE READS", Icons.offline_pin_rounded)),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _books.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _activeTab == 0 ? Icons.bookmark_border_rounded : Icons.cloud_off_rounded,
                              size: 50,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _activeTab == 0 ? "No saved bookmarks" : "No offline downloads",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
                              child: Text(
                                _activeTab == 0
                                    ? "Notes you bookmark in the Library will appear here."
                                    : "Download study notes to read them offline anytime without internet.",
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _books.length,
                        itemBuilder: (ctx, i) {
                          final book = _books[i];
                          final isDownloaded = _downloadedIds.contains(book.id);
                          final isDownloading = _downloadingMap[book.id] == true;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header
                                  InkWell(
                                    onTap: _activeTab == 1
                                        ? null // Disable library routing in offline list
                                        : () {
                                            Navigator.push(context, MaterialPageRoute(builder: (context) => ChannelProfileScreen(channelId: book.channelId)));
                                          },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: _getPicColor(book.channelPic).withOpacity(0.15),
                                            child: Icon(Icons.menu_book_rounded, color: _getPicColor(book.channelPic), size: 14),
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(book.channelName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                                              if (_activeTab == 0)
                                                const Text("View Library Profile", style: TextStyle(fontSize: 9, color: StarlightTheme.primaryBlue, fontWeight: FontWeight.bold))
                                              else
                                                const Text("Available Offline", style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Divider(height: 16),
                                  // Details
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: book.thumbnailUrl.isNotEmpty
                                            ? Image.network(
                                                book.absoluteThumbnailUrl,
                                                width: 45,
                                                height: 55,
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
                                            Text(book.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                            const SizedBox(height: 4),
                                            Text("By: ${book.author}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                                                  child: Text(_fileKindLabel(book), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _fileKindColor(book))),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  // Social Actions Row
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
                                          if (_activeTab == 0) ...[
                                            IconButton(
                                              icon: const Icon(Icons.comment_outlined, size: 18, color: Colors.grey),
                                              onPressed: () {
                                                Navigator.push(context, MaterialPageRoute(builder: (context) => BookCommentsScreen(book: book)));
                                              },
                                              tooltip: "Comments & Reviews",
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          // 📥 DOWNLOAD BUTTON (Toggles or Shows state)
                                          if (isDownloading)
                                            const SizedBox(
                                              width: 18, height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: StarlightTheme.primaryBlue),
                                            )
                                          else if (isDownloaded)
                                            IconButton(
                                              icon: const Icon(Icons.offline_pin_rounded, size: 20, color: Colors.green),
                                              onPressed: () => _deleteLocalBook(book, i),
                                              tooltip: "Downloaded offline. Tap to delete file.",
                                            )
                                          else if (_activeTab == 0)
                                            IconButton(
                                              icon: const Icon(Icons.download_for_offline_outlined, size: 20, color: StarlightTheme.primaryBlue),
                                              onPressed: () => _downloadBook(book, i),
                                              tooltip: "Download for offline read",
                                            ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: Icon(_activeTab == 1 ? Icons.delete_outline_rounded : Icons.bookmark_rounded, size: 18, color: _activeTab == 1 ? Colors.red : Colors.amber),
                                        onPressed: () => _handleSave(book, i),
                                        tooltip: _activeTab == 1 ? "Delete offline file" : "Remove Bookmark",
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Primary CTA Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 38,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: StarlightTheme.primaryBlue,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        elevation: 0,
                                      ),
                                      icon: Icon(
                                        _activeTab == 1
                                            ? Icons.offline_pin_rounded
                                            : isDownloaded
                                                ? Icons.offline_pin_rounded
                                                : Icons.download_for_offline_outlined,
                                        size: 14, color: Colors.white),
                                      label: Text(
                                        _activeTab == 1
                                            ? "READ OFFLINE"
                                            : isDownloaded
                                                ? "READ OFFLINE"
                                                : isDownloading
                                                    ? "DOWNLOADING..."
                                                    : _examineLabel(book).toUpperCase(),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                                      ),
                                      onPressed: () {
                                        if (_activeTab == 1) {
                                          _examineDocument(book, i);
                                        } else if (isDownloaded) {
                                          _examineDocument(book, i);
                                        } else if (isDownloading) {
                                          // Do nothing while downloading
                                        } else {
                                          _downloadBook(book, i);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
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
}
