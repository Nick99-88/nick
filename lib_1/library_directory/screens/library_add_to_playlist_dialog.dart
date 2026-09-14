import 'package:flutter/material.dart';
import '../models/book_models.dart';
import '../services/library_service.dart';

class AddToPlaylistDialog extends StatefulWidget {
  final String bookId;
  const AddToPlaylistDialog({super.key, required this.bookId});

  @override
  State<AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends State<AddToPlaylistDialog> {
  List<LibraryPlaylist> _playlists = [];
  bool _loading = true;
  final _nameCtrl = TextEditingController();
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final playlists = await LibraryService.getMyPlaylists();
      if (mounted) setState(() { _playlists = playlists; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createAndAdd() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _creating = true);
    try {
      final pl = await LibraryService.createPlaylist(name);
      await LibraryService.addToPlaylist(pl.id, widget.bookId);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _addToExisting(LibraryPlaylist pl) async {
    try {
      await LibraryService.addToPlaylist(pl.id, widget.bookId);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add to Playlist"),
      content: SizedBox(
        width: 300,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_playlists.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text("No playlists yet. Create one below.",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _playlists.length,
                        itemBuilder: (ctx, i) {
                          final pl = _playlists[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.playlist_play, size: 20),
                            title: Text(pl.title, style: const TextStyle(fontSize: 13)),
                            trailing: Text("${pl.itemCount}", style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            onTap: () => _addToExisting(pl),
                          );
                        },
                      ),
                    ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            hintText: "New playlist name",
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _creating ? null : _createAndAdd,
                        child: _creating
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text("Create & Add", style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
      ],
    );
  }
}
