import 'package:flutter/material.dart';
import 'package:starlight_flutter/core/theme.dart';
import 'package:starlight_flutter/l10n/strings.dart';
import 'chat_message_screen.dart';
import 'add_user_screen.dart';
import 'owner_chat_verification_screen.dart';
import '../profile_screen.dart';
import '../../../services/chat/chat_service.dart';
import '../../../services/auth/chat_access_service.dart';
import '../../../services/socket/socket_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final ChatService _chatService = ChatService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _chats = [];

  // Phone search state
  final TextEditingController _phoneController = TextEditingController();
  Map<String, dynamic>? _phoneSearchResult;
  bool _isSearchingPhone = false;

  @override
  void initState() {
    super.initState();
    // 🏛️ Check chat access before proceeding
    _checkChatAccess();
  }

  Future<void> _checkChatAccess() async {
    bool hasAccess = await ChatAccessService.hasChatAccess();
    
    if (!hasAccess) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OwnerChatVerificationScreen()),
        );
      }
      return;
    }
    
    // 🏛️ The 5-Tab Starlight Chat Architecture
    _tabController = TabController(length: 5, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });

    // Connect WebSocket for real-time features
    _connectSocket();

    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);
    try {
      final chats = await _chatService.getUserChats();
      setState(() => _chats = chats);
    } catch (e) {
      print('Error loading chats: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _connectSocket() async {
    await SocketService.connect();
    SocketService.setCallbacks(
      onPhoneSearchResult: (data) {
        if (mounted) {
          setState(() {
            _phoneSearchResult = data;
            _isSearchingPhone = false;
          });
        }
      },
    );
  }

  void _searchPhone(String phone) {
    if (phone.length >= 10) {
      setState(() => _isSearchingPhone = true);
      SocketService.searchPhone(phone);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _phoneController.dispose();
    SocketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: StarlightTheme.primaryBlue,
        elevation: 2,
        title: _isSearching
            ? _buildSearchField()
            : Text(tr('starlightMessaging'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchController.clear();
            }),
          ),
          _buildMenu(),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: tr('tabChats')),
            Tab(text: tr('tabTeachers')),
            Tab(text: tr('tabGroups')),
            Tab(text: tr('tabChannels')),
            Tab(text: tr('tabOfficial')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatList(), // Main Recent Chats
          _placeholderTab(tr('facultyDirectory')),
          _placeholderTab(tr('classGroups')),
          _placeholderTab(tr('broadcastChannels')),
          _placeholderTab(tr('officialNotices')),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green[600],
        child: const Icon(Icons.message_rounded, color: Colors.white),
        onPressed: () => _showNewChatSheet(context),
      ),
    );
  }

  Widget _buildChatList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              tr('noChatsYet'),
              style: TextStyle(fontSize: 20, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              tr('tapPlusToStartChatting'),
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
    
    return ListView.separated(
      itemCount: _chats.length,
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
      itemBuilder: (context, index) {
        final chat = _chats[index];
        final user = chat['user'];
        final lastMessage = chat['last_message'];
        
        return ListTile(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatMessageScreen(
                chatId: chat['chat_id'],
                userName: user['display_name'],
                peerUserId: user['id']?.toString(),
                peerPhone: user['phone']?.toString(),
              ),
            ),
          ),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: StarlightTheme.primaryBlue,
                child: Text(
                  user['display_name'][0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
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
            user['display_name'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            lastMessage?['content'] ?? tr('startConversation'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (lastMessage?['created_at'] != null)
                Text(
                  _formatTime(lastMessage['created_at']),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              const SizedBox(height: 4),
              if (lastMessage?['created_at'] != null)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: const Text("1", style: TextStyle(color: Colors.white, fontSize: 10)),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(String timestamp) {
    final dateTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) return tr('justNow');
    if (difference.inHours < 1) return tr('minutesAgo', {'n': '${difference.inMinutes}'});
    if (difference.inDays < 1) return tr('hoursAgo', {'n': '${difference.inHours}'});
    return "${dateTime.day}/${dateTime.month}";
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: tr('searchConversations'),
        border: InputBorder.none,
        hintStyle: const TextStyle(color: Colors.white60),
      ),
      style: const TextStyle(color: Colors.white, fontSize: 18),
    );
  }

  Widget _buildMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onSelected: (val) {
        if (val == 'profile') {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: "new_group", child: Text(tr('newGroup'))),
        PopupMenuItem(value: "official", child: Text(tr('officialBroadcast'))),
        PopupMenuItem(value: "profile", child: Text(tr('myStatus'))),
        PopupMenuItem(value: "settings", child: Text(tr('chatSettings'))),
      ],
    );
  }

  Widget _placeholderTab(String label) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_clock_outlined, size: 50, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _showNewChatSheet(BuildContext context) {
    _phoneController.clear();
    setState(() => _phoneSearchResult = null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  tr('startNewChat'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('searchByPhoneOrDirectory'),
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),

                // Phone input field
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  decoration: InputDecoration(
                    prefixText: "+92 ",
                    prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
                    hintText: "0XXX XXXXXXX",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: _isSearchingPhone
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    if (value.length >= 10) {
                      _searchPhone(value);
                    }
                  },
                ),

                const SizedBox(height: 20),

                // Search result
                if (_phoneSearchResult != null)
                  _buildPhoneSearchResult(),

                const SizedBox(height: 20),

                // Divider
                const Divider(),
                const SizedBox(height: 10),

                // Traditional options
                ListTile(
                  leading: const Icon(Icons.people, color: StarlightTheme.primaryBlue),
                  title: Text(tr('pendingRequests')),
                  subtitle: Text(tr('viewChatRequests')),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to pending requests screen
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneSearchResult() {
    final data = _phoneSearchResult!;
    final found = data['found'] as bool;

    if (!found) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                data['message'] ?? tr('numberNotFound'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
    }

    final user = data['user'] as Map<String, dynamic>;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: StarlightTheme.primaryBlue,
                child: Text(
                  user['name']?[0] ?? "?",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['display_name'] ?? user['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      user['role'] ?? "User",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      tr('phoneColon', {'phone': '${user['phone']}'}),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle, color: Colors.green),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _startChatWithUser(user['id'], user['display_name'] ?? user['name']);
              },
              icon: const Icon(Icons.chat),
              label: Text(tr('startChat')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startChatWithUser(int userId, String displayName) async {
    try {
      final result = await _chatService.createChatRequest(userId, displayName: displayName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('chatRequestSent', {'name': displayName})),
            backgroundColor: Colors.green,
          ),
        );
        _loadChats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('failed', {'error': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}