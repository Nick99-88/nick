import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import 'chat_message_screen.dart';
import 'chat_verification_screen.dart';
import '../../../services/chat/chat_service.dart';
import '../../../services/auth/chat_access_service.dart';
import '../../../services/socket/socket_service.dart';
import '../../../chat_local_db/chat_local_db.dart';
import '../../../services/fcm_service.dart';
import '../../../core/storage.dart';

class TeacherChatListScreen extends StatefulWidget {
  const TeacherChatListScreen({super.key});

  @override
  State<TeacherChatListScreen> createState() => _TeacherChatListScreenState();
}

class _TeacherChatListScreenState extends State<TeacherChatListScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _isInitialized = false;
  bool _isCheckingAccess = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final ChatService _chatService = ChatService();
  bool _isLoading = false;
  List<LocalChat> _chats = [];

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
    // Prevent multiple simultaneous checks
    if (_isCheckingAccess) return;
    _isCheckingAccess = true;

    bool hasAccess = await ChatAccessService.hasChatAccess();

    if (!hasAccess) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TeacherChatVerificationScreen()),
        );
      }
      return;
    }
    
    // 🏛️ The 5-Tab Starlight Chat Architecture for Teachers
    // Initialize tab controller before setting state
    if (mounted) {
      setState(() {
        _tabController = TabController(length: 5, vsync: this);
        _isInitialized = true;
      });
    }
    _searchController.addListener(() {
      if (mounted) {
        setState(() => _searchQuery = _searchController.text.toLowerCase());
      }
    });

    // 🏛️ Check and register FCM token if missing
    await _checkAndRegisterFCMToken();

    // Connect WebSocket for real-time features
    _connectSocket();

    _loadChats();
  }

  // 🏛️ Check and register FCM token (always ensure backend sync)
  Future<void> _checkAndRegisterFCMToken() async {
    try {
      print('🏛️ Teacher Chat List: Initializing FCM service to ensure backend registration...');
      
      // Always initialize FCM service to ensure token is registered with backend
      // Backend will handle deduplication and updates
      await FCMService().initialize(context);
      
      print('🏛️ Teacher Chat List: FCM token registration/check completed');
    } catch (e) {
      print('🏛️ Teacher Chat List: Error checking/registering FCM token - $e');
      // Don't let FCM errors block chat list loading
    }
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);
    try {
      print('🏛️ Chat List: Loading chats from local database only');
      
      final chats = await ChatRepository().getAllChats();
      print('🏛️ Chat List: Retrieved ${chats.length} chats from local database');
      
      setState(() {
        _chats = chats;
      });
      
      print('🏛️ Chat List: Loaded ${chats.length} chats from local database');
    } catch (e) {
      print('🏛️ Chat List: Error loading chats - $e');
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
    if (_isInitialized && _tabController != null) {
      _tabController?.dispose();
    }
    _searchController.dispose();
    _phoneController.dispose();
    SocketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading if not yet initialized (access check in progress)
    if (!_isInitialized || _tabController == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: StarlightTheme.primaryBlue,
          title: const Text("Teacher Messaging", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Checking chat access..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: StarlightTheme.primaryBlue,
        elevation: 2,
        title: _isSearching
            ? _buildSearchField()
            : const Text("Teacher Messaging", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
          tabs: const [
            Tab(text: "CHATS"),
            Tab(text: "STUDENTS"),
            Tab(text: "PARENTS"),
            Tab(text: "STAFF"),
            Tab(text: "OFFICIAL"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatList(), // Main Recent Chats
          _placeholderTab("Student Directory"),
          _placeholderTab("Parent Contacts"),
          _placeholderTab("Staff Members"),
          _placeholderTab("Official Notices"),
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
              "No chats yet",
              style: TextStyle(fontSize: 20, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              "Tap the + button to start chatting",
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
        
        return ListTile(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeacherChatMessageScreen(
                chatId: 0,
                userName: chat.displayName,
              ),
            ),
          ),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: StarlightTheme.primaryBlue,
                child: Text(
                  chat.displayName[0].toUpperCase(),
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
            chat.displayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            chat.displayLastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (chat.lastMessageTime.isNotEmpty)
                Text(
                  _formatTime(chat.lastMessageTime),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              const SizedBox(height: 4),
              if (chat.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: Text("${chat.unreadCount}", style: const TextStyle(color: Colors.white, fontSize: 10)),
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
    
    if (difference.inMinutes < 1) return "Just now";
    if (difference.inHours < 1) return "${difference.inMinutes}m ago";
    if (difference.inDays < 1) return "${difference.inHours}h ago";
    return "${dateTime.day}/${dateTime.month}";
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: const InputDecoration(
        hintText: "Search conversations...",
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white60),
      ),
      style: const TextStyle(color: Colors.white, fontSize: 18),
    );
  }

  Widget _buildMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onSelected: (val) {
        if (val == 'profile') {
          // TODO: Navigate to teacher profile
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: "new_group", child: Text("New Group")),
        const PopupMenuItem(value: "official", child: Text("Official Broadcast")),
        const PopupMenuItem(value: "profile", child: Text("My Status")),
        const PopupMenuItem(value: "settings", child: Text("Chat Settings")),
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
                const Text(
                  "Add Contact by Phone",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Enter phone number to search",
                  style: TextStyle(color: Colors.grey),
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
                data['message'] ?? "Number not found",
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
                      "Phone: ${user['phone']}",
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
              label: const Text("Start Chat"),
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
            content: Text("Chat request sent to $displayName"),
            backgroundColor: Colors.green,
          ),
        );
        _loadChats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
