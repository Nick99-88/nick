import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../models/book_models.dart';
import '../services/library_service.dart';
import 'channel_profile_screen.dart';
import 'library_ad_gate_dialog.dart';
import 'library_tiktok_player_screen.dart';

class LibraryPlaylistTab extends StatefulWidget {
  const LibraryPlaylistTab({super.key});
  @override
  State<LibraryPlaylistTab> createState() => _LibraryPlaylistTabState();
}

class _LibraryPlaylistTabState extends State<LibraryPlaylistTab> {
  List<LibraryPlaylist> _playlists = [];
  bool _loading = true;
  String? _selectedPlaylistId;
  LibraryPlaylist? _selectedPlaylist;
  List<Book> _books = [];
  bool _loadingBooks = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final playlists = await LibraryService.getMyPlaylists();
      if (mounted) {
        setState(() {
          _playlists = playlists;
          _loading = false;
          if (playlists.isNotEmpty) {
            _selectPlaylist(playlists.first.id);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectPlaylist(String id) async {
    setState(() {
      _selectedPlaylistId = id;
      _loadingBooks = true;
    });
    try {
      final pl = await LibraryService.getPlaylist(id);
      if (mounted) {
        setState(() {
          _selectedPlaylist = pl;
          _books = pl.books ?? [];
          _loadingBooks = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBooks = false);
    }
  }

  Future<void> _openBook(Book book) async {
    Book latestBook;
    try {
      latestBook = await LibraryService.getBook(book.id);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not load document"), backgroundColor: Colors.red));
      return;
    }
    // Check access permissions
    try {
      final access = await LibraryService.getBookAccess(book.id);
      if (access['can_view'] != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(access['access_type'] == 'needs_rent' ? 'This document requires an active rental' : 'Purchase or rent required to view this document'),
          backgroundColor: Colors.orange,
        ));
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

    final updatedBook = await Navigator.push<Book>(
      context,
      MaterialPageRoute(builder: (context) => LibraryTiktokPlayerScreen(book: latestBook)),
    );
    if (updatedBook != null && mounted) {
      setState(() {
        final idx = _books.indexWhere((b) => b.id == book.id);
        if (idx != -1) _books[idx] = updatedBook;
      });
    }
  }

  Future<void> _removeFromPlaylist(Book book) async {
    if (_selectedPlaylistId == null) return;
    try {
      await LibraryService.removeFromPlaylist(_selectedPlaylistId!, book.id);
      setState(() => _books.removeWhere((b) => b.id == book.id));
    } catch (_) {}
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (_selectedPlaylistId == null) return;
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final book = _books.removeAt(oldIndex);
      _books.insert(newIndex, book);
    });
    await LibraryService.reorderPlaylist(_selectedPlaylistId!, _books.map((b) => b.id).toList());
  }

  Future<void> _createPlaylist() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("New Playlist"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: "Playlist name",
                hintText: "e.g. Study Notes",
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: "Description (optional)",
                hintText: "What is this playlist about?",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        final pl = await LibraryService.createPlaylist(
          nameCtrl.text.trim(),
          description: descCtrl.text.trim(),
        );
        setState(() => _playlists.insert(0, pl));
        _selectPlaylist(pl.id);
      } catch (_) {}
    }
    nameCtrl.dispose();
    descCtrl.dispose();
  }

  Future<void> _deletePlaylist(LibraryPlaylist pl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Playlist?"),
        content: Text('Delete "${pl.title}" and all its items?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await LibraryService.deletePlaylist(pl.id);
        setState(() {
          _playlists.removeWhere((p) => p.id == pl.id);
          if (_selectedPlaylistId == pl.id) {
            _selectedPlaylistId = null;
            _selectedPlaylist = null;
            _books = [];
            if (_playlists.isNotEmpty) _selectPlaylist(_playlists.first.id);
          }
        });
      } catch (_) {}
    }
  }

  Future<void> _editPlaylist(LibraryPlaylist pl) async {
    final nameCtrl = TextEditingController(text: pl.title);
    final descCtrl = TextEditingController(text: pl.description);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Playlist"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Name", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        await LibraryService.updatePlaylist(
          pl.id,
          name: nameCtrl.text.trim(),
          description: descCtrl.text.trim(),
        );
        _load();
      } catch (_) {}
    }
    nameCtrl.dispose();
    descCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        // Playlist chips bar
        Container(
          height: 48,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _playlists.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              if (i == _playlists.length) {
                return ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text("New", style: TextStyle(fontSize: 12)),
                  onPressed: _createPlaylist,
                );
              }
              final pl = _playlists[i];
              final selected = pl.id == _selectedPlaylistId;
              return ChoiceChip(
                avatar: Icon(Icons.playlist_play, size: 16, color: selected ? Colors.white : StarlightTheme.primaryBlue),
                label: Text(
                  "${pl.title} (${pl.itemCount})",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: selected ? Colors.white : Colors.black87),
                ),
                selected: selected,
                selectedColor: StarlightTheme.primaryBlue,
                onSelected: (_) => _selectPlaylist(pl.id),
              );
            },
          ),
        ),

        // Content
        Expanded(
          child: _selectedPlaylist == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.playlist_play, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text("No playlists yet", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: _createPlaylist,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text("Create your first playlist"),
                      ),
                    ],
                  ),
                )
              : _buildPlaylistContent(),
        ),
      ],
    );
  }

  Widget _buildPlaylistContent() {
    return Column(
      children: [
        // Playlist header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade50,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedPlaylist!.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Text("${_books.length} items", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _editPlaylist(_selectedPlaylist!);
                  if (v == 'delete') _deletePlaylist(_selectedPlaylist!);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 18), title: Text("Edit", style: TextStyle(fontSize: 13)))),
                  const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, size: 18, color: Colors.red), title: Text("Delete", style: TextStyle(fontSize: 13, color: Colors.red)))),
                ],
              ),
            ],
          ),
        ),

        // Books list with reorder
        Expanded(
          child: _loadingBooks
              ? const Center(child: CircularProgressIndicator())
              : _books.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_library, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text("This playlist is empty", style: TextStyle(color: Colors.grey.shade500)),
                          const SizedBox(height: 4),
                          Text("Add books from the explore menu", style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                        ],
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _books.length,
                      onReorder: _onReorder,
                      proxyDecorator: (child, index, animation) => Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: child,
                      ),
                      itemBuilder: (ctx, i) {
                        final book = _books[i];
                        return _bookTile(book, i);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _bookTile(Book book, int index) {
    return Dismissible(
      key: ValueKey(book.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade50,
        child: const Icon(Icons.remove_circle_outline, color: Colors.red),
      ),
      confirmDismiss: (_) async {
        await _removeFromPlaylist(book);
        return false;
      },
      child: Card(
        key: ValueKey(book.id),
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: ReorderableDragStartListener(
            index: index,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: StarlightTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text("${index + 1}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: StarlightTheme.primaryBlue)),
              ),
            ),
          ),
          title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: Text(book.author.isNotEmpty ? book.author : "Unknown", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          trailing: IconButton(
            icon: Icon(Icons.close, size: 18, color: Colors.grey.shade400),
            onPressed: () => _removeFromPlaylist(book),
          ),
          onTap: () => _openBook(book),
        ),
      ),
    );
  }
}
