import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:starlight_flutter/core/theme.dart';
import 'package:starlight_flutter/chat_local_db/chat_local_db.dart';
import 'package:starlight_flutter/chat_system/services/chat_sync_manager.dart';
import 'package:starlight_flutter/chat_system/services/message_outbox_queue.dart';
import 'package:starlight_flutter/chat_system/services/socket_event_bus.dart';
import 'package:starlight_flutter/services/socket/enhanced_socket_service.dart';
import 'package:starlight_flutter/services/auth/chat_access_service.dart';
import 'package:starlight_flutter/screens/social/chat_screen.dart';
import 'package:starlight_flutter/chat_system/screens/whatsapp_new_chat_screen.dart';

class WhatsAppChatListScreen extends StatefulWidget {
  const WhatsAppChatListScreen({super.key});

  @override
  State<WhatsAppChatListScreen> createState() => _WhatsAppChatListScreenState();
}

class _WhatsAppChatListScreenState extends State<WhatsAppChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isInitialized = false;
  List<LocalChat> _chats = [];
  List<LocalChat> _filteredChats = [];

  final ChatRepository _chatRepo = ChatRepository();
  final ChatSyncManager _syncManager = ChatSyncManager.instance;
  final MessageOutboxQueue _outboxQueue = MessageOutboxQueue.instance;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final hasAccess = await ChatAccessService.hasChatAccess();
    if (!hasAccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat access not verified')),
      );
      return;
    }

    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });

    await ChatLocalService.instance.initialize();
    await _syncManager.initialize();
    await _outboxQueue.initialize();

    _setupSocketCallbacks();
    await _connectSocket();
    await _loadChats();
    
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  void _setupSocketCallbacks() {
    _syncManager.onChatListUpdated = () {
      if (mounted) _loadChats();
    };

    SocketEventBus.instance.subscribe('new_message', (data) async {
      if (mounted) await _loadChats();
    });

    SocketEventBus.instance.subscribe('connection_created', (data) {
      if (mounted) _outboxQueue.triggerProcess();
    });

    SocketEventBus.instance.subscribe('connection_error', (data) {
      if (mounted) _connectSocket();
    });
  }

  Future<void> _connectSocket() async {
    if (EnhancedSocketService.isConnected()) return;
    try {
      await EnhancedSocketService.connect(
        source: 'WhatsAppChatList',
        closeExisting: false,
      );
    } catch (e) {
      print('💬 ChatList: Socket connection error: $e');
    }
  }

  Future<void> _loadChats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final chats = await _chatRepo.getAllChats(
        includeArchived: false,
        includeBlocked: false,
      );

      if (mounted) {
        setState(() {
          _chats = chats;
          _applyFilter();
        });
      }
    } catch (e) {
      print('💬 Error loading chats: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredChats = _chats;
    } else {
      _filteredChats = _chats.where((chat) {
        return chat.contactName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               chat.phoneNumber.contains(_searchQuery);
      }).toList();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(child: _buildChatList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: StarlightTheme.primaryBlue,
        child: const Icon(Icons.chat, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => WhatsAppNewChatScreen()),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(LocalChat chat) {
    if (chat.profileImageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: CachedNetworkImageProvider(chat.profileImageUrl),
        backgroundColor: Colors.grey.shade200,
      );
    }
    return CircleAvatar(
      radius: 28,
      backgroundColor: StarlightTheme.primaryBlue,
      child: Text(
        chat.contactName.isNotEmpty ? chat.contactName[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildChatList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_filteredChats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No chats yet', style: TextStyle(fontSize: 20, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('Tap the + button to start chatting', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChats,
      child: ListView.separated(
        itemCount: _filteredChats.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
        itemBuilder: (context, index) => _buildChatTile(_filteredChats[index]),
      ),
    );
  }

  Widget _buildArchivedChats() {
    final archivedChats = _chats.where((c) => c.isArchived).toList();

    if (archivedChats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No archived chats', style: TextStyle(fontSize: 20, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: archivedChats.length,
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
      itemBuilder: (context, index) => _buildChatTile(archivedChats[index], showArchiveAction: true),
    );
  }

  Widget _buildChatTile(LocalChat chat, {bool showArchiveAction = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              friendId: chat.peerUserId.isNotEmpty ? chat.peerUserId : chat.phoneNumber,
              friendName: chat.contactName.isNotEmpty ? chat.contactName : chat.phoneNumber,
              friendRole: '',
              friendPhone: chat.phoneNumber,
              fromInbox: false,
            ),
          ),
        ).then((_) => _loadChats());
      },
      onLongPress: () => _showChatOptions(chat),
      leading: Stack(
        children: [
          _buildAvatar(chat),
          if (chat.isPinned)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.push_pin, size: 12, color: Colors.grey),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chat.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _formatTimestamp(chat.lastMessageTime),
            style: TextStyle(
              fontSize: 12,
              color: chat.unreadCount > 0 ? StarlightTheme.primaryBlue : Colors.grey,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              chat.displayLastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ),
          if (chat.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: StarlightTheme.primaryBlue, borderRadius: BorderRadius.circular(12)),
              constraints: const BoxConstraints(minWidth: 20),
              child: Text(
                chat.unreadCount > 99 ? '99+' : chat.unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
      trailing: showArchiveAction
          ? IconButton(
              icon: const Icon(Icons.unarchive, color: Colors.grey),
              onPressed: () async {
                await _chatRepo.toggleArchive(chat.phoneNumber, false);
                _loadChats();
              },
            )
          : null,
    );
  }

  void _showChatOptions(LocalChat chat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(chat.contactName.isNotEmpty ? chat.contactName : chat.phoneNumber),
        content: const Text('Choose an action:'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.block, color: Colors.red),
            label: const Text('Block Contact', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(ctx);
              _chatRepo.toggleBlock(chat.phoneNumber, true);
              _loadChats();
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text('Delete Chat', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(ctx);
              _showDeleteChatDialog(chat);
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteChatDialog(LocalChat chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text('Delete all messages with ${chat.displayName}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ChatLocalService.instance.deleteChat(chat.phoneNumber);
              _loadChats();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSearch() {
    showSearch(context: context, delegate: _ChatSearchDelegate(_chats));
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'new_group':
      case 'starred':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Coming soon!')),
        );
        break;
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.inDays == 0) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dt.weekday - 1];
      } else {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (e) {
      return '';
    }
  }
}

class _ChatSearchDelegate extends SearchDelegate<String> {
  final List<LocalChat> _chats;

  _ChatSearchDelegate(this._chats);

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, ''),
  );

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    final results = _chats.where((chat) {
      return chat.contactName.toLowerCase().contains(query.toLowerCase()) ||
             chat.phoneNumber.contains(query);
    }).toList();

    if (results.isEmpty) {
      return Center(child: Text('No chats found for "$query"', style: TextStyle(color: Colors.grey.shade600)));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final chat = results[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(chat.contactName.isNotEmpty ? chat.contactName[0].toUpperCase() : '?'),
          ),
          title: Text(chat.displayName),
          subtitle: Text(chat.phoneNumber),
          onTap: () => close(context, chat.phoneNumber),
        );
      },
    );
  }
}
