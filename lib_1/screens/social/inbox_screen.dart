import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../services/social/friend_request_service.dart';
import '../../widgets/profile_avatar.dart';
import 'chat_screen.dart';
import '../../chat_local_db/repositories/chat_repository.dart';
import '../../chat_local_db/models/models.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final FriendRequestService _service = FriendRequestService();
  final ChatRepository _chatRepo = ChatRepository();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _filteredFriends = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocalThenFetch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalThenFetch() async {
    // 1. Load from local DB immediately
    final localFriends = await _chatRepo.getFriends();
    if (mounted) {
      setState(() {
        _friends = localFriends.map((c) => {
          'id': c.peerUserId,
          'public_id': '',
          'name': c.contactName,
          'role': 'User',
          'avatar': c.profileImageUrl,
        }).toList();
        _filteredFriends = _friends;
        _isLoading = false;
      });
    }
    // 2. Fetch from server in background
    _fetchFromServer();
  }

  Future<void> _fetchFriends() async {
    // If there's already a refresh in progress, don't start another one
    if (_isRefreshing) return;
    
    // For refresh, clear existing friends and show loading
    if (_isRefreshing) {
      setState(() => _isLoading = true);
    }
    await _fetchFromServer();
  }

  Future<void> _fetchFromServer() async {
    if (_isRefreshing) return;
    if (mounted) setState(() => _isRefreshing = true);
    try {
      final friends = await _service.getFriends();
      // Save to local DB
      await _chatRepo.saveFriends(friends);
      if (mounted) {
        setState(() {
          _friends = friends;
          _filteredFriends = friends;
          _isLoading = false;
          _isRefreshing = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _friends.isEmpty 
              ? e.toString().replaceFirst('Exception: ', '') 
              : null;
          _isRefreshing = false;
        });
      }
    }
  }

  void _refreshFriends() {
    if (_isRefreshing) return;
    _fetchFromServer();
  }

  void _filterFriends(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = _friends;
      } else {
        _filteredFriends = _friends
            .where((f) => (f['name'] ?? '').toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _openChat(Map<String, dynamic> friend) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          friendId: friend['id'],
          friendName: friend['name'] ?? 'Unknown',
          friendRole: friend['role'] ?? 'User',
          friendPhone: friend['phone'],
          friendPublicId: friend['public_id']?.toString(),
          fromInbox: false,
        ),
      ),
    );
  }

  void _openChatFromSystem(Map<String, dynamic> friend) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          friendId: friend['id'],
          friendName: friend['name'] ?? 'Unknown',
          friendRole: friend['role'] ?? 'User',
          friendPublicId: friend['public_id']?.toString(),
          fromInbox: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: StarlightTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inbox_rounded, color: StarlightTheme.primaryBlue, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Inbox',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: StarlightTheme.primaryBlue,
              ),
            ),
          ),
          if (_friends.isNotEmpty)
            Text(
              '${_friends.length} friends',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _fetchFriends,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: StarlightTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.refresh, color: StarlightTheme.primaryBlue, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        onChanged: _filterFriends,
        decoration: InputDecoration(
          hintText: 'Search friends...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
          filled: true,
          fillColor: const Color(0xFFF4F7FE),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshFriends,
              style: ElevatedButton.styleFrom(backgroundColor: StarlightTheme.primaryBlue),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_filteredFriends.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              _friends.isEmpty ? 'No friends yet' : 'No results found',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              _friends.isEmpty ? 'Add friends from the Explore tab' : 'Try a different search',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchFriends,
      color: StarlightTheme.primaryBlue,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _filteredFriends.length,
        itemBuilder: (context, index) {
          final friend = _filteredFriends[index];
          return _buildFriendTile(friend);
        },
      ),
    );
  }

  Widget _buildFriendTile(Map<String, dynamic> friend) {
    final friendId = friend['id'] ?? '';
    final name = friend['name'] ?? 'Unknown';
    final role = friend['role'] ?? 'User';
    final lastSeen = friend['last_seen'];

    final isOnline = lastSeen != null &&
        DateTime.now().difference(DateTime.tryParse(lastSeen) ?? DateTime(2000)).inMinutes < 5;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => _openChatFromSystem(friend),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Stack(
            children: [
              ProfileAvatar(userId: friendId, name: name, radius: 24),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                friend['public_id']?.toString() ?? '',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: StarlightTheme.primaryBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: StarlightTheme.primaryBlue,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}
