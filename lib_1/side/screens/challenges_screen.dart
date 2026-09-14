import 'package:flutter/material.dart';
import '../models/execution_result.dart';
import '../services/code_execution_service.dart';
import 'challenge_detail_screen.dart';
import 'create_challenge_screen.dart';

class SideChallengesScreen extends StatefulWidget {
  const SideChallengesScreen({super.key});

  @override
  State<SideChallengesScreen> createState() => _SideChallengesScreenState();
}

class _SideChallengesScreenState extends State<SideChallengesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CodingChallenge> _challenges = [];
  List<CodingChallenge> _savedChallenges = [];
  bool _isLoading = true;
  String _selectedDifficulty = 'All';
  String _selectedLanguage = 'All';
  final TextEditingController _searchCtrl = TextEditingController();

  final _difficulties = ['All', 'Easy', 'Medium', 'Hard'];
  final _languages = ['All', 'Python', 'JavaScript', 'C', 'Java'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadChallenges();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      if (_tabController.index == 1) _loadSaved(); else _loadChallenges();
    }
  }

  Future<void> _loadChallenges() async {
    setState(() => _isLoading = true);
    _challenges = await CodeExecutionService.getChallenges(
      language: _selectedLanguage,
      difficulty: _selectedDifficulty,
      search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
    );
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSaved() async {
    setState(() => _isLoading = true);
    _savedChallenges = await CodeExecutionService.getSavedChallenges();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        foregroundColor: const Color(0xFF1A237E),
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.emoji_events,
                  color: Color(0xFF1A237E), size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Challenges',
                style: TextStyle(
                    color: Color(0xFF1A237E),
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: 0.3)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF1A237E),
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: const Color(0xFF1A237E),
          unselectedLabelColor: Colors.grey[400],
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w400, fontSize: 13),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Saved'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilters(),
          Expanded(child: _buildList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateChallengeScreen()),
          );
          if (created == true) _loadChallenges();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('NEW CHALLENGE',
            style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(fontSize: 14, color: Color(0xFF212121)),
          decoration: InputDecoration(
            hintText: 'Search challenges...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon:
                const Icon(Icons.search, color: Color(0xFF1A237E), size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                    onPressed: () {
                      _searchCtrl.clear();
                      _loadChallenges();
                    },
                  )
                : null,
          ),
          onChanged: (_) => _loadChallenges(),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        children: [
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _difficulties.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) => _filterChip(
                _difficulties[i],
                _selectedDifficulty,
                _difficulties[i] == 'Easy'
                    ? const Color(0xFF2E7D32)
                    : _difficulties[i] == 'Medium'
                        ? const Color(0xFFF57F17)
                        : _difficulties[i] == 'Hard'
                            ? const Color(0xFFC62828)
                            : const Color(0xFF757575),
                (v) {
                  setState(() => _selectedDifficulty = v);
                  _loadChallenges();
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _languages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) => _filterChip(
                _languages[i],
                _selectedLanguage,
                const Color(0xFF1A237E),
                (v) {
                  setState(() => _selectedLanguage = v);
                  _loadChallenges();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String selected, Color color,
      void Function(String) onTap) {
    final isSel = selected == label;
    return GestureDetector(
      onTap: () => onTap(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSel ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSel ? color.withOpacity(0.4) : Colors.grey.shade200,
          ),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: isSel ? color : Colors.grey[500],
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.w600 : FontWeight.w400)),
        ),
      ),
    );
  }

  Widget _buildList() {
    final items = _tabController.index == 0 ? _challenges : _savedChallenges;
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1A237E)));
    }
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A237E).withOpacity(0.04),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.emoji_events_outlined,
                    size: 48, color: Color(0xFF1A237E).withOpacity(0.35)),
              ),
              const SizedBox(height: 16),
              Text(
                'No challenges found',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600]),
              ),
              const SizedBox(height: 6),
              Text(
                _tabController.index == 1
                    ? 'Save challenges to see them here'
                    : 'Tap + to create the first challenge',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF1A237E),
      onRefresh: _tabController.index == 0 ? _loadChallenges : _loadSaved,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
        itemCount: items.length,
        itemBuilder: (_, i) => _buildCard(items[i]),
      ),
    );
  }

  Widget _buildCard(CodingChallenge c) {
    final diffColor = c.difficulty == 'Easy'
        ? const Color(0xFF2E7D32)
        : c.difficulty == 'Medium'
            ? const Color(0xFFF57F17)
            : const Color(0xFFC62828);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChallengeDetailScreen(challengeId: c.id),
              ),
            );
            if (_tabController.index == 1) _loadSaved(); else _loadChallenges();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _badge(c.difficulty, diffColor),
                  const SizedBox(width: 6),
                  _badge(c.language.toUpperCase(), const Color(0xFF1A237E)),
                  const Spacer(),
                  if (c.isSaved)
                    const Icon(Icons.bookmark_rounded,
                        size: 15, color: Color(0xFFF57F17))
                ]),
                const SizedBox(height: 10),
                Text(c.title,
                    style: const TextStyle(
                        color: Color(0xFF212121),
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const SizedBox(height: 4),
                Text(c.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                        height: 1.4)),
                if (c.testCases.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 14, color: const Color(0xFF1A237E).withOpacity(0.5)),
                        const SizedBox(width: 6),
                        Text('${c.testCases.length} test cases',
                            style: TextStyle(
                                color: const Color(0xFF1A237E).withOpacity(0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}