import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../models/book_models.dart';
import '../services/library_service.dart';

class LibraryStudioScreen extends StatefulWidget {
  const LibraryStudioScreen({super.key});

  @override
  State<LibraryStudioScreen> createState() => _LibraryStudioScreenState();
}

class _LibraryStudioScreenState extends State<LibraryStudioScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  List<Book> _books = [];
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetchEarnings();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchEarnings() async {
    setState(() => _loading = true);
    try {
      final res = await LibraryService.getStudioEarnings();
      if (!mounted) return;
      setState(() {
        _data = res;
        if (res['books'] is List) {
          _books = (res['books'] as List).map((b) => Book.fromJson(b)).toList();
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Book> get _shorts => _books.where((b) => b.docType == 'note' && !b.forceStopped).toList();
  List<Book> get _docs => _books.where((b) => b.docType != 'note' && !b.forceStopped).toList();
  List<Book> get _stopped => _books.where((b) => b.forceStopped).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text("LIBRARY STUDIO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchEarnings,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    final totalEarnings = ((_data?['total_earnings'] ?? 0) as num).toInt().toString();
    final totalViews = _data?['total_views'] ?? 0;
    final totalLikes = _data?['total_likes'] ?? 0;

    return RefreshIndicator(
      onRefresh: _fetchEarnings,
      color: Colors.cyanAccent,
      child: Column(
        children: [
          // Stats Cards
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _statCard("Earnings", "🪙 $totalEarnings", Icons.monetization_on, Colors.amber)),
                    const SizedBox(width: 8),
                    Expanded(child: _statCard("Views", "$totalViews", Icons.visibility, Colors.cyanAccent)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _statCard("Likes", "$totalLikes", Icons.thumb_up, Colors.blueAccent)),
                    const SizedBox(width: 8),
                    Expanded(child: _statCard("Total", "${_books.length}", Icons.menu_book, Colors.orangeAccent)),
                  ],
                ),
              ],
            ),
          ),

          // Tab bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                color: StarlightTheme.primaryBlue.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: "Notes (${_shorts.length})"),
                Tab(text: "Documents (${_docs.length})"),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Content list
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildContentList(_shorts, "No short notes yet"),
                _buildContentList(_docs, "No documents yet"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentList(List<Book> items, String emptyMsg) {
    if (items.isEmpty) {
      return Center(
        child: Text(emptyMsg, style: const TextStyle(color: Colors.white38, fontSize: 13)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _bookTile(items[i]),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        ],
      ),
    );
  }

  Widget _bookTile(Book book) {
    final monoColor = _monetizationColor(book.monetizationType);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: monoColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_monetizationIcon(book.monetizationType), color: monoColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: monoColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                      child: Text(_monetizationLabel(book.monetizationType), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: monoColor)),
                    ),
                    const SizedBox(width: 8),
                    Text("👁️ ${book.viewsCount}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(width: 8),
                    Text("🪙 ${book.earnings.toInt()}", style: const TextStyle(fontSize: 10, color: Colors.amber)),
                    if (book.docType == 'note') ...[
                      const SizedBox(width: 8),
                      const Text("📄 Note", style: TextStyle(fontSize: 10, color: Colors.cyanAccent)),
                    ],
                  ],
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  String _monetizationLabel(String type) {
    switch (type) {
      case 'ads_only': return 'Ads Only';
      case 'rent': return 'Rent';
      case 'sell': return 'Sell';
      case 'user_decision': return 'User Decision';
      default: return 'Free';
    }
  }

  IconData _monetizationIcon(String type) {
    switch (type) {
      case 'ads_only': return Icons.ads_click;
      case 'rent': return Icons.folder_open;
      case 'sell': return Icons.shopping_cart;
      case 'user_decision': return Icons.touch_app;
      default: return Icons.money_off;
    }
  }

  Color _monetizationColor(String type) {
    switch (type) {
      case 'ads_only': return Colors.amber;
      case 'rent': return Colors.blue;
      case 'sell': return Colors.orange;
      case 'user_decision': return Colors.purple;
      default: return Colors.green;
    }
  }
}