import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../core/theme.dart';
import '../../../core/storage.dart';
import '../../../core/constants.dart';

class InstitutionLeaderboardScreen extends StatefulWidget {
  final VoidCallback onClose;
  final String? institutionId;
  const InstitutionLeaderboardScreen({super.key, required this.onClose, this.institutionId});

  @override
  State<InstitutionLeaderboardScreen> createState() => _InstitutionLeaderboardScreenState();
}

class _InstitutionLeaderboardScreenState extends State<InstitutionLeaderboardScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _pulseController;
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;
  String? _loadedInstId;

  // Cache per category so tabs don't re-fetch images on switch
  final Map<String, List<Map<String, dynamic>>> _cache = {};
  bool _isRefreshing = false;

  static const _categories = ['board_exams', 'events', 'scholarships'];

  // True when opened by owner from their own directory (no institutionId passed)
  bool get _isOwnerView => widget.institutionId == null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500), lowerBound: 0.85, upperBound: 1.0)
      ..repeat(reverse: true);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _loadEntries();
    });
    _loadEntries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String get _currentCategory => _categories[_tabController.index];

  Color get _categoryPalette => [const Color(0xFF1565C0), const Color(0xFF7B1FA2), const Color(0xFF2E7D32)][_tabController.index];

  List<Color> get _categoryGradients => [const [Color(0xFF1565C0), Color(0xFF42A5F5)], const [Color(0xFF7B1FA2), Color(0xFFCE93D8)], const [Color(0xFF2E7D32), Color(0xFF66BB6A)]][_tabController.index];

  Future<void> _loadEntries({bool forceRefresh = false}) async {
    final category = _currentCategory;
    // Serve from cache if available and not forcing refresh
    if (!forceRefresh && _cache.containsKey(category)) {
      setState(() {
        _entries = _cache[category]!;
        _isLoading = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    try {
      final token = await StarlightStorage.getUserToken();
      String url = '${StarlightConstants.apiBaseUrl}/leaderboard/list?category=$category';
      if (widget.institutionId != null) {
        url += '&institution_id=${widget.institutionId}';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          final entries = List<Map<String, dynamic>>.from(data['entries'] ?? []);
          if (category == 'board_exams') {
            entries.sort((a, b) {
              final aFields = a['fields'];
              final bFields = b['fields'];
              int aRank = 0, bRank = 0;
              if (aFields is Map) aRank = (aFields['_rank'] as int?) ?? 0;
              if (bFields is Map) bRank = (bFields['_rank'] as int?) ?? 0;
              if (aRank > 0 && bRank > 0) return aRank.compareTo(bRank);
              if (aRank > 0) return -1;
              if (bRank > 0) return 1;
              return 0;
            });
          }
          _cache[category] = entries;
          setState(() => _entries = entries);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refreshCurrentTab() async {
    // Force refresh current tab and clear its cache
    _cache.remove(_currentCategory);
    await _loadEntries(forceRefresh: false);
  }

  Future<void> _addEntry({Map<String, dynamic>? existingData}) async {
    final entryId = existingData?['id'] as String?;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      useSafeArea: false,
      builder: (ctx) => _AddEntryDialog(
        category: _currentCategory,
        palette: _categoryPalette,
        existingData: existingData,
        entryId: entryId,
      ),
    );
    if (result != null) {
      try {
        final token = await StarlightStorage.getUserToken();
        if (result['id'] != null) {
          await http.put(
            Uri.parse('${StarlightConstants.apiBaseUrl}/leaderboard/update/${result['id']}'),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
            body: jsonEncode(result),
          );
        } else {
          await http.post(
            Uri.parse('${StarlightConstants.apiBaseUrl}/leaderboard/create'),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
            body: jsonEncode(result),
          );
        }
        _cache.remove(_currentCategory);
        _loadEntries();
      } catch (_) {}
    }
  }

  Future<void> _deleteEntry(String entryId, String studentName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Entry", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text("Remove \"$studentName\" from the leaderboard?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final token = await StarlightStorage.getUserToken();
      await http.delete(
        Uri.parse('${StarlightConstants.apiBaseUrl}/leaderboard/delete/$entryId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      _cache.remove(_currentCategory);
      _loadEntries();
    } catch (_) {}
  }

  void _showDetailSheet(Map<String, dynamic> entry) {
    final name = entry['student_name'] ?? 'Student';
    final subject = entry['subject'] ?? '';
    final marks = entry['marks'] ?? '';
    final imageB64 = entry['image_base64'] as String?;
    final category = entry['category'] ?? _currentCategory;
    Map<String, dynamic> fields = {};
    if (entry['fields'] is Map) {
      fields = Map<String, dynamic>.from(entry['fields']);
    } else if (entry['fields'] is String && (entry['fields'] as String).isNotEmpty) {
      try { fields = Map<String, dynamic>.from(jsonDecode(entry['fields'] as String)); } catch (_) {}
    }
    List<String> eventImages = [];
    if ((category == 'events' || category == 'scholarships') && fields['_images'] is List) {
      eventImages = List<String>.from(fields['_images']);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
    if (widget.institutionId == null)
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: _categoryPalette, size: 20),
                      tooltip: 'Edit',
                      onPressed: () {
                        Navigator.pop(ctx);
                        _addEntry(existingData: entry);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 20),
                      tooltip: 'Delete',
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteEntry(entry['id'], name);
                      },
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                children: [
                  if (category == 'events' || category == 'scholarships') ...[
                    if (eventImages.isNotEmpty)
                      SizedBox(
                        height: 200,
                        child: PageView.builder(
                          itemCount: eventImages.length,
                          itemBuilder: (_, i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              image: DecorationImage(
                                image: MemoryImage(base64Decode(eventImages[i].split(',').last)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: _categoryPalette.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Icon(Icons.image_outlined, color: _categoryPalette.withOpacity(0.2), size: 48),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                    if (subject.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(subject, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ],
                    if (category == 'scholarships' && marks.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.purple.shade400, Colors.purple.shade700]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.workspace_premium, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(marks, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                    if (fields['Description'] != null && fields['Description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _categoryPalette.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          fields['Description'].toString(),
                          style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5),
                        ),
                      ),
                    ],
                  ] else ...[
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _categoryPalette.withOpacity(0.2), width: 2),
                            image: imageB64 != null && imageB64.isNotEmpty
                                ? DecorationImage(image: MemoryImage(base64Decode(imageB64.split(',').last)), fit: BoxFit.cover)
                                : null,
                            color: imageB64 == null || imageB64.isEmpty ? _categoryPalette.withOpacity(0.08) : null,
                          ),
                          child: imageB64 == null || imageB64.isEmpty
                              ? Icon(Icons.person_rounded, color: _categoryPalette.withOpacity(0.3), size: 28)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              if (subject.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(subject, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                              ],
                              if (marks.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.green.shade500, Colors.teal.shade700],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(marks, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                              if (category == 'scholarships' && fields['Description'] != null && fields['Description'].toString().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  fields['Description'].toString(),
                                  style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (fields.entries.where((e) => e.key != '_images' && e.key != 'Description').isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text("Additional Fields", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _categoryPalette)),
                    const SizedBox(height: 12),
                    ...fields.entries.where((e) => e.key != '_images' && e.key != 'Description').map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _categoryPalette.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.label_outline, color: _categoryPalette, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.key, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text(e.value.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: widget.onClose,
          color: const Color(0xFF263238),
        ),
        title: const Text("INSTITUTION LEADERBOARD",
            style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.12))),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                gradient: LinearGradient(colors: _categoryGradients),
                borderRadius: BorderRadius.circular(20),
              ),
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF78909C),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
              tabs: const [
                Tab(text: "Board Exams"),
                Tab(text: "Events"),
                Tab(text: "Scholarships"),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _isOwnerView
          ? FloatingActionButton.extended(
              onPressed: _addEntry,
              backgroundColor: _categoryPalette,
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              label: const Text("Add Record", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            )
          : FloatingActionButton(
              onPressed: _refreshCurrentTab,
              backgroundColor: _categoryPalette,
              mini: true,
              tooltip: 'Refresh',
              child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(strokeWidth: 3, color: _categoryPalette),
                  ),
                  const SizedBox(height: 20),
                  Text("Loading leaderboard...", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
            )
          : _entries.isEmpty
              ? _buildEmptyState()
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    if (_entries.length >= 3) _buildPodiumSliver(),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                          childAspectRatio: 0.78,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => _buildFancyCard(_entries[i], i + 1),
                          childCount: _entries.length,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _categoryPalette.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.emoji_events_outlined, size: 48, color: _categoryPalette.withOpacity(0.4)),
          ),
          const SizedBox(height: 20),
          Text("No records yet", style: TextStyle(color: Colors.grey[600], fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            _isOwnerView
                ? "Tap + to celebrate your first achievement"
                : "This institution has no records in this category yet",
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (_isOwnerView) ...[
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _addEntry,
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Add First Record"),
              style: OutlinedButton.styleFrom(
                foregroundColor: _categoryPalette,
                side: BorderSide(color: _categoryPalette),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPodiumSliver() {
    final top3 = _entries.take(3).toList();
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _categoryPalette.withOpacity(0.12),
              _categoryPalette.withOpacity(0.04),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _categoryPalette.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildPodiumStep(top3.length > 1 ? top3[1] : null, 2, 100),
                const SizedBox(width: 8),
                _buildPodiumStep(top3[0], 1, 120),
                const SizedBox(width: 8),
                _buildPodiumStep(top3.length > 2 ? top3[2] : null, 3, 90),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumStep(Map<String, dynamic>? entry, int rank, double height) {
    if (entry == null) return SizedBox(width: 90, height: height);
    final name = entry['student_name'] ?? 'Student';
    final imageB64 = entry['image_base64'] as String?;
    final medalColors = [
      [Colors.amber.shade600, Colors.orange.shade800],
      [const Color(0xFF90A4AE), const Color(0xFF546E7A)],
      [const Color(0xFFA1887F), const Color(0xFF6D4C41)],
    ][rank - 1];

    return SizedBox(
      width: 90,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rank == 1)
            ScaleTransition(
              scale: _pulseController,
              child: Icon(Icons.emoji_events, size: 32, color: medalColors[0]),
            )
          else
            Icon(Icons.emoji_events, size: 26, color: medalColors[0]),
          const SizedBox(height: 6),
          _LazyBase64Image(
            imageB64: (imageB64 != null && imageB64.isNotEmpty) ? imageB64 : null,
            size: 48,
            borderColor: medalColors[0],
            borderWidth: 2.5,
            placeholder: Icon(Icons.person, color: Colors.grey[400], size: 22),
          ),
          const SizedBox(height: 6),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: medalColors),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: medalColors[0].withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Text("#$rank", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFancyCard(Map<String, dynamic> entry, int listIndex) {
    final name = entry['student_name'] ?? 'Student';
    final marks = entry['marks'] ?? '';
    final subject = entry['subject'] ?? '';
    final imageB64 = entry['image_base64'] as String?;
    final category = entry['category'] ?? _currentCategory;
    Map<String, dynamic> fields = {};
    if (entry['fields'] is Map) {
      fields = Map<String, dynamic>.from(entry['fields']);
    } else if (entry['fields'] is String && (entry['fields'] as String).isNotEmpty) {
      try { fields = Map<String, dynamic>.from(jsonDecode(entry['fields'] as String)); } catch (_) {}
    }
    final extraFieldsShown = fields.entries.where((e) => e.key != '_images' && e.key != 'Description' && e.key != '_rank').take(1).toList();
    final hasMoreFields = fields.entries.where((e) => e.key != '_images' && e.key != 'Description' && e.key != '_rank').length > 1;
    List<String> eventImages = [];
    if ((category == 'events' || category == 'scholarships') && fields['_images'] is List) {
      eventImages = List<String>.from(fields['_images']);
    }

    final entryRank = (category == 'board_exams' && fields['_rank'] is int)
        ? fields['_rank'] as int
        : (listIndex <= 3 ? listIndex : 0);

    final medalColors = [
      Colors.amber.shade600,
      const Color(0xFF90A4AE),
      const Color(0xFFA1887F),
    ];
    final cardAccent = category == 'board_exams' && entryRank > 0
        ? medalColors[entryRank - 1]
        : _categoryPalette;
    return GestureDetector(
      onTap: () => _showDetailSheet(entry),
      onLongPress: widget.institutionId == null ? () {
        final name = entry['student_name'] ?? 'Student';
        _deleteEntry(entry['id'], name);
      } : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: (category == 'board_exams' && entryRank > 0 ? medalColors[entryRank - 1] : _categoryPalette).withOpacity(entryRank <= 3 ? 0.12 : 0.04),
              blurRadius: entryRank <= 3 ? 20 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: Colors.white,
            surfaceTintColor: cardAccent.withOpacity(0.03),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCardHeader(entry, entryRank),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (category == 'events' || category == 'scholarships') ...[
                          if (eventImages.isNotEmpty)
                            ClipRect(
                              child: SizedBox(
                                height: 44,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ...eventImages.take(2).toList().asMap().entries.map((e) => Padding(
                                      padding: EdgeInsets.only(right: e.key == 0 ? 4 : 0),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.memory(
                                          base64Decode(e.value.split(',').last),
                                          width: 40,
                                          height: 44,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )),
                                    if (eventImages.length > 2)
                                      Container(
                                        width: 40,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: _categoryPalette.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Center(
                                          child: Text('+${eventImages.length - 2}', style: TextStyle(color: _categoryPalette, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Container(
                              height: 60,
                              decoration: BoxDecoration(
                                color: _categoryPalette.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Icon(Icons.image_outlined, color: _categoryPalette.withOpacity(0.3), size: 28),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(subject.isNotEmpty ? subject : 'Event', style: TextStyle(fontSize: 10, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ] else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _LazyBase64Image(
                                imageB64: (imageB64 != null && imageB64.isNotEmpty) ? imageB64 : null,
                                size: 44,
                                borderColor: _categoryPalette.withOpacity(0.2),
                                borderWidth: 2,
                                placeholder: Icon(Icons.person_rounded, color: _categoryPalette.withOpacity(0.3), size: 22),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(subject.isNotEmpty ? subject : (category == 'events' ? 'Event Participant' : 'N/A'),
                                        style: TextStyle(fontSize: 10, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Spacer(),
                        if (marks.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: category == 'board_exams' && entryRank > 0
                                    ? [medalColors[entryRank - 1], medalColors[entryRank - 1].withOpacity(0.7)]
                                    : category == 'scholarships'
                                        ? [Colors.purple.shade400, Colors.purple.shade700]
                                        : category == 'events'
                                            ? [Colors.orange.shade400, Colors.deepOrange.shade600]
                                            : [Colors.green.shade500, Colors.teal.shade700],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ...extraFieldsShown.map((f) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.fiber_manual_record, size: 6, color: _categoryPalette.withOpacity(0.4)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${f.key}: ${f.value}',
                                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )),
                        if (hasMoreFields)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('+${fields.entries.where((e) => e.key != '_images' && e.key != 'Description' && e.key != '_rank').length - 1} more', style: TextStyle(fontSize: 9, color: cardAccent, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(Map<String, dynamic> entry, int listIndex) {
    final marks = entry['marks'] ?? '';
    final category = entry['category'] ?? _currentCategory;
    Map<String, dynamic> fields = {};
    if (entry['fields'] is Map) {
      fields = Map<String, dynamic>.from(entry['fields']);
    } else if (entry['fields'] is String && (entry['fields'] as String).isNotEmpty) {
      try { fields = Map<String, dynamic>.from(jsonDecode(entry['fields'] as String)); } catch (_) {}
    }
    final entryRank = (category == 'board_exams' && fields['_rank'] is int)
        ? fields['_rank'] as int
        : (listIndex <= 3 ? listIndex : 0);
    final rank = entryRank;

    Color headerColor;
    if (rank == 1) {
      headerColor = Colors.amber;
    } else if (rank == 2) {
      headerColor = const Color(0xFF90A4AE);
    } else if (rank == 3) {
      headerColor = const Color(0xFFA1887F);
    } else {
      headerColor = _categoryPalette.withOpacity(0.2);
    }

    return Container(
      height: 32,
      decoration: BoxDecoration(
        gradient: rank >= 1 && rank <= 3
            ? LinearGradient(colors: [headerColor, headerColor.withOpacity(0.7)])
            : LinearGradient(
                colors: [_categoryPalette.withOpacity(0.08), _categoryPalette.withOpacity(0.02)],
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            alignment: Alignment.center,
            child: rank == 1
                ? const Icon(Icons.emoji_events, color: Colors.white, size: 16)
                : rank == 2
                    ? const Icon(Icons.emoji_events, color: Colors.white, size: 16)
                    : rank == 3
                        ? const Icon(Icons.emoji_events, color: Colors.white, size: 16)
                        : Text(
                            '${_entries.indexOf(entry) + 1}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _categoryPalette.withOpacity(0.5)),
                          ),
          ),
          const Expanded(child: SizedBox()),
          if (marks.isNotEmpty && rank <= 3)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(marks, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

/// Lazily decodes a base64 image string in the background,
/// showing a placeholder until the image is ready.
class _LazyBase64Image extends StatefulWidget {
  final String? imageB64;
  final double size;
  final Color borderColor;
  final double borderWidth;
  final BoxShape shape;
  final Widget? placeholder;

  const _LazyBase64Image({
    required this.imageB64,
    required this.size,
    required this.borderColor,
    this.borderWidth = 2.0,
    this.shape = BoxShape.circle,
    this.placeholder,
  });

  @override
  State<_LazyBase64Image> createState() => _LazyBase64ImageState();
}

class _LazyBase64ImageState extends State<_LazyBase64Image> {
  bool _imageLoaded = false;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    if (widget.imageB64 != null && widget.imageB64!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _decodeImage());
    }
  }

  Future<void> _decodeImage() async {
    try {
      final raw = widget.imageB64!.split(',').last;
      final bytes = base64Decode(raw);
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _imageLoaded = true;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _imageLoaded && _imageBytes != null;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: widget.shape,
        border: Border.all(color: widget.borderColor, width: widget.borderWidth),
        image: hasImage
            ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
            : null,
        color: hasImage ? null : widget.borderColor.withOpacity(0.08),
      ),
      child: hasImage
          ? null
          : (widget.placeholder ?? Icon(Icons.person, color: widget.borderColor.withOpacity(0.3), size: widget.size * 0.45)),
    );
  }
}

class _AddEntryDialog extends StatefulWidget {
  final String category;
  final Color palette;
  final Map<String, dynamic>? existingData;
  final String? entryId;
  const _AddEntryDialog({required this.category, required this.palette, this.existingData, this.entryId});

  @override
  State<_AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<_AddEntryDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _marksCtrl;
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _eventDescCtrl;
  String? _imageB64;
  final List<String> _eventImages = [];
  final List<_FieldPair> _extraFields = [];
  int _rankValue = 0;

  @override
  void initState() {
    super.initState();
    final data = widget.existingData;
    Map<String, dynamic> fields = {};
    if (data != null) {
      if (data['fields'] is Map) {
        fields = Map<String, dynamic>.from(data['fields']);
      } else if (data['fields'] is String && (data['fields'] as String).isNotEmpty) {
        try { fields = Map<String, dynamic>.from(jsonDecode(data['fields'] as String)); } catch (_) {}
      }
    }

    _nameCtrl = TextEditingController(text: data != null ? (data['student_name'] ?? '') : '');
    _marksCtrl = TextEditingController(text: data != null ? (data['marks'] ?? '') : '');
    _subjectCtrl = TextEditingController(text: data != null ? (data['subject'] ?? '') : '');
    _eventDescCtrl = TextEditingController(text: fields['Description'] ?? '');
    _imageB64 = data != null ? (data['image_base64'] as String? ?? '') : null;
    if (_imageB64?.isEmpty == true) _imageB64 = null;

    if (fields['_images'] is List) {
      _eventImages.addAll(List<String>.from(fields['_images']));
    }
    _rankValue = fields['_rank'] is int ? fields['_rank'] as int : 0;

    if (fields.isNotEmpty) {
      for (final e in fields.entries) {
        if (e.key != '_images' && e.key != 'Description' && e.key != '_rank') {
          _extraFields.add(_FieldPair(
            TextEditingController(text: e.key),
            TextEditingController(text: e.value.toString()),
          ));
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _marksCtrl.dispose();
    _subjectCtrl.dispose();
    _eventDescCtrl.dispose();
    for (final f in _extraFields) {
      f.keyCtrl.dispose();
      f.valueCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _imageB64 = "data:image/jpeg;base64,${base64Encode(bytes)}");
    }
  }

  Future<void> _pickEventImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 50);
    for (final f in picked) {
      final bytes = await f.readAsBytes();
      setState(() => _eventImages.add("data:image/jpeg;base64,${base64Encode(bytes)}"));
    }
  }

  void _removeEventImage(int i) {
    setState(() => _eventImages.removeAt(i));
  }

  void _addField() {
    setState(() => _extraFields.add(_FieldPair(TextEditingController(), TextEditingController())));
  }

  void _removeField(int i) {
    _extraFields[i].keyCtrl.dispose();
    _extraFields[i].valueCtrl.dispose();
    setState(() => _extraFields.removeAt(i));
  }

  Widget _buildRankChip(int rank, IconData icon, Color color, String label) {
    final selected = _rankValue == rank;
    return GestureDetector(
      onTap: () => setState(() => _rankValue = rank),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.grey[300]!, width: selected ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? color : Colors.grey[400]),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? color : Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _buildFields() {
    final map = <String, dynamic>{};
    if (_rankValue > 0) {
      map['_rank'] = _rankValue;
    }
    if (_eventDescCtrl.text.trim().isNotEmpty && widget.category != 'board_exams') {
      map['Description'] = _eventDescCtrl.text.trim();
    }
    if (widget.category != 'board_exams' && _eventImages.isNotEmpty) {
      map['_images'] = List<String>.from(_eventImages);
    }
    for (final f in _extraFields) {
      final k = f.keyCtrl.text.trim();
      final v = f.valueCtrl.text.trim();
      if (k.isNotEmpty && v.isNotEmpty) map[k] = v;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final idx = ['board_exams', 'events', 'scholarships'].indexOf(widget.category);
    final isEdit = widget.entryId != null;
    final labels = isEdit
        ? ['Edit Board Exam Result', 'Edit Event', 'Edit Scholarship'][idx]
        : ['Add Board Exam Result', 'Add Event', 'Add Scholarship'][idx];
    final icon = [Icons.menu_book_rounded, Icons.stadium_rounded, Icons.school_rounded][idx];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: widget.palette.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: widget.palette, size: 26),
              ),
              const SizedBox(height: 14),
              Text(labels, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 24),
              if (widget.category == 'board_exams') ...[
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 88, height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _imageB64 != null ? null : Colors.grey[100],
                          image: _imageB64 != null
                              ? DecorationImage(
                                  image: MemoryImage(base64Decode(_imageB64!.split(',').last)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          border: Border.all(color: widget.palette.withOpacity(0.25), width: 2),
                        ),
                        child: _imageB64 == null
                            ? Icon(Icons.camera_alt_rounded, color: Colors.grey[400], size: 30)
                            : null,
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: widget.palette, shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.edit, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.palette.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: widget.palette.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.photo_library_outlined, color: widget.palette, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text("${widget.category == 'scholarships' ? 'Scholarship' : 'Event'} Photos",
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: widget.palette)),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _pickEventImages,
                            icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                            label: const Text("Add", style: TextStyle(fontSize: 11)),
                            style: TextButton.styleFrom(foregroundColor: widget.palette, padding: const EdgeInsets.symmetric(horizontal: 8)),
                          ),
                        ],
                      ),
                      if (_eventImages.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 80,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _eventImages.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) => Stack(
                              children: [
                                Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    image: DecorationImage(
                                      image: MemoryImage(base64Decode(_eventImages[i].split(',').last)),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 2, right: 2,
                                  child: GestureDetector(
                                    onTap: () => _removeEventImage(i),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              if (widget.category == 'board_exams')
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Student Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              if (widget.category == 'board_exams') const SizedBox(height: 14),
              if (widget.category == 'board_exams') ...[
                TextField(
                  controller: _subjectCtrl,
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.book_outlined, size: 20),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _marksCtrl,
                  decoration: InputDecoration(
                    labelText: 'Marks / Grade',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.grade_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                Text("Medal Rank", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700])),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildRankChip(1, Icons.emoji_events, Colors.amber.shade600, "Gold"),
                      const SizedBox(width: 8),
                      _buildRankChip(2, Icons.emoji_events, const Color(0xFF90A4AE), "Silver"),
                      const SizedBox(width: 8),
                      _buildRankChip(3, Icons.emoji_events, const Color(0xFFA1887F), "Bronze"),
                      if (_rankValue > 0) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => setState(() => _rankValue = 0),
                          style: TextButton.styleFrom(foregroundColor: Colors.grey, padding: const EdgeInsets.symmetric(horizontal: 8)),
                          child: const Text("Clear", style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else if (widget.category == 'scholarships') ...[
                TextField(
                  controller: _subjectCtrl,
                  decoration: InputDecoration(
                    labelText: 'Scholarship Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.workspace_premium_outlined, size: 20),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _marksCtrl,
                  decoration: InputDecoration(
                    labelText: 'Award / Amount',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.monetization_on_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _eventDescCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Scholarship Description',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description_outlined, size: 20),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ] else ...[
                TextField(
                  controller: _subjectCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Event Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event_outlined, size: 20),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _eventDescCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Event Description',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description_outlined, size: 20),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Text("Extra Fields", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700])),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addField,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text("Add Field", style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: widget.palette),
                  ),
                ],
              ),
              ...List.generate(_extraFields.length, (i) {
                final f = _extraFields[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: f.keyCtrl,
                          decoration: InputDecoration(
                            hintText: 'Field name',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: f.valueCtrl,
                          decoration: InputDecoration(
                            hintText: 'Value',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _removeField(i),
                        icon: Icon(Icons.remove_circle_outline, size: 20, color: Colors.red[300]),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (widget.category == 'board_exams' && _nameCtrl.text.trim().isEmpty) return;
                    final data = <String, dynamic>{
                      'id': widget.entryId,
                      'category': widget.category,
                      'student_name': widget.category == 'board_exams' ? _nameCtrl.text.trim() : _subjectCtrl.text.trim(),
                      'subject': _subjectCtrl.text.trim(),
                      'marks': _marksCtrl.text.trim(),
                      'image_base64': _imageB64 ?? '',
                      'fields': _buildFields(),
                    };
                    Navigator.pop(context, data);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.palette,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  child: Text(
                    widget.entryId != null ? "Update Entry" : "Save to Leaderboard",
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldPair {
  final TextEditingController keyCtrl;
  final TextEditingController valueCtrl;
  _FieldPair(this.keyCtrl, this.valueCtrl);
}
