import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../core/storage.dart';
import '../../core/constants.dart';
import '../../services/auth/firebase_phone_service.dart';
import '../../services/socket/enhanced_socket_service.dart';
import '../../services/social/block_service.dart';
import '../../chat_local_db/chat_local_db.dart';
import '../../screens/social/chat_screen.dart';
import '../../screens/social/ai_assistant_screen.dart';
import 'calls_tab.dart';
import 'channels_list_screen.dart';
import 'search_channel_screen.dart';
import 'create_channel_screen.dart';
import '../../chat_local_db/models/local_channel.dart';
import '../../chat_local_db/repositories/channel_repository.dart';
import 'server_chat_id_screen.dart';
import 'lock/lock_preference_service.dart';
import 'lock/lock_settings_screen.dart';
import 'lock/lock_screen.dart';
import 'locked_chats_screen.dart';
import 'change_phone_screen.dart';


class LocalChatIdScreen extends StatefulWidget {
  const LocalChatIdScreen({super.key});

  @override
  State<LocalChatIdScreen> createState() => _LocalChatIdScreenState();
}

class _LocalChatIdScreenState extends State<LocalChatIdScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  String _phoneNumber = '';
  bool _isLoading = true;
  List<LocalChat> _chatContacts = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _refreshTimer;

  bool _isSelectionMode = false;
  final Set<String> _selectedPhones = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectSocket();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_selectedIndex == 0) _loadContactsFromLocalDB();
    });
    blockService.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    EnhancedSocketService.setProfilePictureUpdatedCallback(null);
    _searchController.dispose();
    super.dispose();
  }

  void _connectSocket() {
    EnhancedSocketService.setProfilePictureUpdatedCallback(_handleProfilePictureUpdate);
    EnhancedSocketService.connect(source: 'LocalChatIdScreen');
  }

  void _handleProfilePictureUpdate(Map<String, dynamic> data) {
    final phone = data['phone_number'] as String?;
    final url = data['profile_picture_url'] as String?;
    final version = data['picture_version'] as int?;
    if (phone == null || url == null) return;

    final index = _chatContacts.indexWhere((c) => c.phoneNumber == phone);
    if (index == -1) return;

    _downloadProfilePicture(url, phone).then((localPath) {
      if (localPath == null || !mounted) return;
      final updated = _chatContacts[index].copyWith(
        profileImageUrl: localPath,
        profilePictureVersion: version ?? _chatContacts[index].profilePictureVersion,
        updatedAt: DateTime.now().toIso8601String(),
      );
      ChatRepository().updateChat(updated);
      setState(() => _chatContacts[index] = updated);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _selectedIndex == 0) {
      _loadContactsFromLocalDB();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final phone = await StarlightStorage.getVerifiedPhone();
    if (mounted) {
      setState(() => _phoneNumber = phone ?? 'Unknown');
    }

    await _loadContactsFromLocalDB();
    if (_chatContacts.isNotEmpty) {
      _syncVersions();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool _isPhoneKey(String value) {
    if (value.isEmpty) return false;
    return !RegExp(r'^[A-Z0-9]{8}$').hasMatch(value);
  }

  Future<void> _loadContactsFromLocalDB() async {
    try {
      final chatRepository = ChatRepository();
      final messageRepository = MessageRepository();
      final chats = await chatRepository.getAllChats(includeArchived: true);
      final enriched = <LocalChat>[];
      for (final chat in chats) {
        if (!_isPhoneKey(chat.phoneNumber)) continue;
        if (chat.phoneNumber.isNotEmpty) {
          final latest = await messageRepository.getLatestMessageByPhone(chat.phoneNumber);
          if (latest != null) {
            enriched.add(chat.copyWith(
              lastMessage: latest.isSent ? 'You: ${latest.content}' : latest.content,
              lastMessageTime: latest.createdAt,
              lastMessageType: latest.messageType,
            ));
            continue;
          }
        }
        enriched.add(chat);
      }
      enriched.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.lastMessageTime.compareTo(a.lastMessageTime);
      });
      if (mounted) {
        setState(() => _chatContacts = enriched);
      }
    } catch (e) {
      debugPrint("Error loading contacts from local DB: $e");
    }
  }

  Future<void> _navigateToLockSettings() async {
    final pref = await LockPreferenceService.get();
    if (!pref.isEnabled) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LockSettingsScreen()),
      );
    } else {
      setState(() => _isSelectionMode = true);
    }
  }

  void _navigateToChat(LocalChat contact) {
    ChatRepository().resetUnreadCount(contact.phoneNumber);
    final isUuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(contact.phoneNumber);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          friendId: contact.peerUserId.isNotEmpty ? contact.peerUserId : contact.phoneNumber,
          friendName: contact.contactName.isNotEmpty ? contact.contactName : contact.phoneNumber,
          friendRole: 'User',
          friendPhone: isUuid ? null : contact.phoneNumber,
          friendProfilePicture: contact.profileImageUrl.isNotEmpty ? contact.profileImageUrl : null,
        ),
      ),
    ).then((_) => _loadContactsFromLocalDB());
  }

  void _navigateToChatWithLock(LocalChat contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LockScreen(
          chatName: contact.contactName.isNotEmpty ? contact.contactName : contact.phoneNumber,
          onUnlocked: () => Navigator.pop(context),
          onCancel: null,
        ),
      ),
    ).then((unlocked) {
      if (unlocked != null && mounted) {
        _navigateToChat(contact);
      }
    });
  }

  Future<void> _changePhoneNumber() async {
    final oldPhone = await StarlightStorage.getVerifiedPhone();
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ChangePhoneScreen()),
    );
    if (changed == true && mounted) {
      final newPhone = await StarlightStorage.getVerifiedPhone();
      if (newPhone != null && newPhone != oldPhone) {
        await ChatRepository().updatePhoneNumber(oldPhone ?? '', newPhone);
      }
      await _loadContactsFromLocalDB();
      if (_chatContacts.isNotEmpty) _syncVersions();
    }
  }

  String _formatPhoneNumber(String phone) {
    if (phone.isEmpty) return phone;
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length == 12 && cleaned.startsWith('92')) {
      return '+92 ${cleaned.substring(2, 5)} ${cleaned.substring(5)}';
    } else if (cleaned.length == 10 && cleaned.startsWith('0')) {
      return '+92 ${cleaned.substring(1, 4)} ${cleaned.substring(4)}';
    } else if (cleaned.length == 9 && !cleaned.startsWith('0')) {
      return '+92 ${cleaned.substring(0, 3)} ${cleaned.substring(3)}';
    }
    return phone;
  }

  void _showFullImage(String imagePath) {
    if (imagePath.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: FileImage(File(imagePath)) is ImageProvider
                  ? Image.file(File(imagePath), fit: BoxFit.contain)
                  : Container(),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        final hour = dt.hour;
        final min = dt.minute.toString().padLeft(2, '0');
        final ampm = hour >= 12 ? 'pm' : 'am';
        final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        return '$h:$min$ampm';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[dt.weekday - 1];
      } else {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (_) {
      return '';
    }
  }

  Future<void> _syncVersions() async {
    if (_chatContacts.isEmpty) return;
    try {
      final payload = _chatContacts.map((c) => {
        'phone_number': c.phoneNumber,
        'profile_picture_version': c.profilePictureVersion,
        'block_version': c.blockVersion,
        'name_version': c.nameVersion,
        'last_message_version': c.lastMessageVersion,
      }).toList();

      final token = await StarlightStorage.getUserToken();
      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/chat/verify-contacts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'contacts': payload, 'sync_versions': true}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updates = data['version_updates'] as List<dynamic>?;
        if (updates != null && updates.isNotEmpty) {
          await _applyVersionUpdates(updates);
        }
      }
    } catch (e) {
      debugPrint("Version sync failed: $e");
    }
  }

  Future<void> _applyVersionUpdates(List<dynamic> updates) async {
    final repo = ChatRepository();
    for (final u in updates) {
      final phone = u['phone_number'] as String?;
      if (phone == null || phone.isEmpty) continue;
      final index = _chatContacts.indexWhere((c) => c.phoneNumber == phone);
      if (index == -1) continue;
      var chat = _chatContacts[index];

      bool changed = false;

      if (u['profile_picture_url'] != null && (u['profile_picture_version'] as int?) != null) {
        final url = u['profile_picture_url'] as String;
        final version = u['profile_picture_version'] as int;
        if (url.isNotEmpty && version > chat.profilePictureVersion) {
          final localPath = await _downloadProfilePicture(url, phone);
          if (localPath != null) {
            chat = chat.copyWith(
              profileImageUrl: localPath,
              profilePictureVersion: version,
              updatedAt: DateTime.now().toIso8601String(),
            );
            changed = true;
          }
        }
      }

      if (u['name'] != null && (u['name_version'] as int?) != null) {
        chat = chat.copyWith(
          contactName: u['name'] as String,
          nameVersion: u['name_version'] as int,
          updatedAt: DateTime.now().toIso8601String(),
        );
        changed = true;
      }

      if (u['is_blocked'] != null && (u['block_version'] as int?) != null) {
        chat = chat.copyWith(
          isBlocked: u['is_blocked'] as bool,
          blockVersion: u['block_version'] as int,
          updatedAt: DateTime.now().toIso8601String(),
        );
        changed = true;
      }

      if (u['last_message'] != null && (u['last_message_version'] as int?) != null) {
        chat = chat.copyWith(
          lastMessage: u['last_message'] as String,
          lastMessageTime: u['last_message_time'] as String? ?? chat.lastMessageTime,
          lastMessageType: u['last_message_type'] as String? ?? chat.lastMessageType,
          lastMessageVersion: u['last_message_version'] as int,
          updatedAt: DateTime.now().toIso8601String(),
        );
        changed = true;
      }

      if (changed) {
        await repo.updateChat(chat);
        _chatContacts[index] = chat;
      }
    }
    if (mounted) setState(() {});
  }

  Future<String?> _downloadProfilePicture(String serverUrl, String phoneNumber) async {
    try {
      final token = await StarlightStorage.getUserToken();
      final fullUrl = serverUrl.startsWith('http') ? serverUrl : '${StarlightConstants.apiBaseUrl}$serverUrl';
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final profileDir = Directory('${directory.path}/profile_pictures');
        if (!await profileDir.exists()) await profileDir.create(recursive: true);
        final filename = '${phoneNumber.replaceAll("+", "")}.jpg';
        final filePath = '${profileDir.path}/$filename';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        // Clear Flutter's image cache for this file so it re-decodes
        imageCache.clear();
        imageCache.clearLiveImages();
        return filePath;
      }
    } catch (e) {
      debugPrint("Download profile picture error: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitSelectionMode,
                color: const Color(0xFF263238),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
                color: const Color(0xFF263238),
              ),
        title: _isSelectionMode
            ? Text('${_selectedPhones.length} selected')
            : Text(
                _selectedIndex == 0 ? 'Chats' : _selectedIndex == 1 ? 'Groups' : _selectedIndex == 2 ? 'Channels' : 'Calls',
                style: const TextStyle(
                  color: Color(0xFF263238),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
        actions: _isSelectionMode
            ? []
            : [
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.sync_rounded, color: Colors.grey),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ServerChatIdScreen()),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onSelected: (value) async {
              if (value == 'change_phone') _changePhoneNumber();
              if (value == 'lock_chat') _navigateToLockSettings();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'phone',
                enabled: false,
                child: Text(
                  _formatPhoneNumber(_phoneNumber),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'change_phone',
                child: Row(
                  children: [
                    Icon(Icons.phone_android, size: 18),
                    SizedBox(width: 12),
                    Text('Change Number'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'lock_chat',
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 18),
                    SizedBox(width: 12),
                    Text('Lock Chats'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: [
                _buildChatsTab(),
                _buildGroupsTab(),
                _buildChannelsTab(),
                const CallsTab(),
              ],
            ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
            child: GNav(
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() => _selectedIndex = index);
                if (index == 0) _loadContactsFromLocalDB();
              },
              gap: 4,
              activeColor: const Color(0xFF075E54),
              iconSize: 22,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              tabBackgroundColor: const Color(0xFF075E54).withOpacity(0.08),
              color: Colors.black45,
              duration: const Duration(milliseconds: 300),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF075E54),
              ),
              tabs: const [
                GButton(icon: Icons.chat_bubble_outline_rounded, text: 'Chats'),
                GButton(icon: Icons.group_outlined, text: 'Groups'),
                GButton(icon: Icons.campaign_outlined, text: 'Channels'),
                GButton(icon: Icons.call_outlined, text: 'Calls'),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: (_selectedIndex == 0 && !_isSelectionMode)
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                );
              },
              backgroundColor: const Color(0xFF075E54),
              child: const Icon(Icons.auto_awesome, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildChatsTab() {
    final locked = _chatContacts.where((c) => c.isLocked).toList();
    final archived = _chatContacts.where((c) => c.isArchived).toList();
    final active = _chatContacts.where((c) => !c.isArchived && !c.isLocked).toList();
    final source = _searchQuery.isEmpty
        ? active
        : active.where((c) {
            final q = _searchQuery.toLowerCase();
            return c.contactName.toLowerCase().contains(q) ||
                c.phoneNumber.contains(_searchQuery);
          }).toList();

    final showLocked = locked.isNotEmpty && _searchQuery.isEmpty;
    final archivedUnreadCount = archived.fold(0, (sum, c) => sum + c.unreadCount);
    final lockedUnreadCount = locked.fold(0, (sum, c) => sum + c.unreadCount);
    final showArchived = archived.isNotEmpty && _searchQuery.isEmpty;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search by name or phone',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        // Sticky archived tile below search bar
        if (showArchived)
          _archivedTile(archivedUnreadCount),
        // Sticky locked tile between archive and list
        if (showLocked)
          _lockedTile(lockedUnreadCount),
        // Contacts list
        Expanded(
          child: source.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.chat_bubble_outline_rounded,
                          size: 64, color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty ? 'No contacts found' : 'No chats yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Sync your contacts to start chatting',
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ServerChatIdScreen()),
                            ),
                            icon: const Icon(Icons.sync_rounded, size: 18),
                            label: const Text('Sync Contacts'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF075E54),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 4),
                  itemCount: source.length,
                  itemBuilder: (context, index) {
                    return _contactTile(source[index]);
                  },
                ),
        ),
        if (_isSelectionMode)
          SafeArea(
            child: _buildSelectionBottomBar(),
          ),
      ],
    );
  }

  Widget _lockedTile(int unreadCount) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LockedChatsScreen()),
        ).then((_) => _loadContactsFromLocalDB());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(Icons.lock_rounded, color: Colors.amber[700], size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Locked chats',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF263238)),
              ),
            ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber[700],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _archivedTile(int unreadCount) {
    return InkWell(
      onTap: _showArchivedChats,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(Icons.archive_rounded, color: Colors.grey[600], size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Archived',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF263238)),
              ),
            ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _actionButton(Icons.delete_outline_rounded, 'Delete', _deleteSelected),
            _actionButton(Icons.lock_outline_rounded, 'Lock', _lockSelected),
            _actionButton(Icons.archive_outlined, 'Archive', _archiveSelected),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: const Color(0xFF075E54)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF075E54))),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              'Create Group',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a group conversation\nwith your friends and colleagues',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.group_add_rounded, size: 18),
              label: const Text('New Group'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF075E54),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelsTab() {
    return FutureBuilder<List<LocalChannel>>(
      future: ChannelRepository().getActiveChannels(),
      builder: (context, snapshot) {
        final channels = snapshot.data ?? [];
        return Column(
          children: [
            // Top actions row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _channelActionButton(
                    icon: Icons.search,
                    label: 'Search',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchChannelScreen()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _channelActionButton(
                    icon: Icons.add,
                    label: 'Create',
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateChannelScreen()),
                      );
                      if (result == true) setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Channels header
            if (channels.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'My Channels',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChannelsListScreen()),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('View All'),
                    ),
                  ],
                ),
              ),
            // Channels list
            Expanded(
              child: channels.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.campaign_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text('No channels yet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF263238))),
                          const SizedBox(height: 8),
                          Text('Create or search for channels to join',
                              style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: channels.length.clamp(0, 5),
                      itemBuilder: (context, index) => _channelListTile(channels[index]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _channelActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF075E54).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF075E54), size: 24),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF263238))),
          ],
        ),
      ),
    );
  }

  Widget _channelListTile(LocalChannel channel) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF075E54).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.campaign, color: Color(0xFF075E54), size: 24),
      ),
      title: Text(
        channel.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        channel.lastMessage.isNotEmpty ? channel.displayLastMessage : '${channel.memberCount} members',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: channel.unreadCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: const BoxDecoration(
                color: Color(0xFF075E54),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Text('${channel.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            )
          : null,
      onTap: () {}, // TODO: Open channel chat
    );
  }

  Widget _contactTile(LocalChat contact) {
    final isSelected = _selectedPhones.contains(contact.phoneNumber);
    final isSelfChat = _phoneNumber.isNotEmpty && contact.phoneNumber == _phoneNumber;
    final isBlockedByMe = blockService.haveIBlocked(contact.peerUserId);
    final amIBlockedByThem = blockService.amIBlockedBy(contact.peerUserId);
    final isAnyBlocked = isBlockedByMe || amIBlockedByThem;
    
    final displayName = isSelfChat
        ? 'You'
        : (contact.contactName.isNotEmpty ? contact.contactName : contact.phoneNumber);
    
    // Don't show profile picture if blocked
    final hasPicture = contact.profileImageUrl.isNotEmpty && !isAnyBlocked;
    final hasUnread = contact.unreadCount > 0 && !amIBlockedByThem;

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleSelection(contact.phoneNumber);
        } else if (amIBlockedByThem) {
          // Show blocked message
          _showBlockedDialog(contact);
        } else if (contact.isLocked) {
          _navigateToChatWithLock(contact);
        } else {
          _navigateToChat(contact);
        }
      },
      onLongPress: _isSelectionMode ? null : () => _enterSelectionMode(contact.phoneNumber),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Opacity(
          opacity: (contact.isLocked || amIBlockedByThem) && !_isSelectionMode ? 0.55 : 1.0,
          child: Row(
            children: [
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(contact.phoneNumber),
                      activeColor: const Color(0xFF075E54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              Stack(
                children: [
                  GestureDetector(
                    onTap: hasPicture ? () => _showFullImage(contact.profileImageUrl) : null,
                    child: CircleAvatar(
                      key: ValueKey('${contact.phoneNumber}_${contact.profilePictureVersion}'),
                      radius: 26,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: hasPicture ? FileImage(File(contact.profileImageUrl)) : null,
                      child: !hasPicture
                          ? Icon(
                              amIBlockedByThem ? Icons.block : Icons.person,
                              color: amIBlockedByThem ? Colors.red : Colors.grey[400],
                              size: 24,
                            )
                          : null,
                    ),
                  ),
                  if (hasUnread && !amIBlockedByThem)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Color(0xFF25D366),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  if (contact.isLocked && !amIBlockedByThem)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.amber[700],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.lock_rounded, size: 10, color: Colors.white),
                      ),
                    ),
                  if (isBlockedByMe)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.block, size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: amIBlockedByThem ? Colors.red : const Color(0xFF263238),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isBlockedByMe) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.block, size: 14, color: Colors.red[400]),
                              ],
                            ],
                          ),
                        ),
                        if (amIBlockedByThem)
                          Text(
                            'Blocked',
                            style: TextStyle(fontSize: 11, color: Colors.red[400], fontWeight: FontWeight.w500),
                          )
                        else if (contact.lastMessageTime.isNotEmpty)
                          Text(
                            _formatTime(contact.lastMessageTime),
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            amIBlockedByThem
                                ? 'You are blocked by this user'
                                : (isBlockedByMe ? 'You blocked this user' : contact.displayLastMessage),
                            style: TextStyle(
                              fontSize: 13,
                              color: (amIBlockedByThem || isBlockedByMe) ? Colors.red[300] : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${contact.unreadCount}',
                              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _enterSelectionMode(String phone) {
    setState(() {
      _isSelectionMode = true;
      _selectedPhones.add(phone);
    });
  }

  void _toggleSelection(String phone) {
    setState(() {
      if (_selectedPhones.contains(phone)) {
        _selectedPhones.remove(phone);
        if (_selectedPhones.isEmpty) _isSelectionMode = false;
      } else {
        _selectedPhones.add(phone);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedPhones.clear();
    });
  }

  void _shareSelected() async {
    _exitSelectionMode();
  }

  void _deleteSelected() async {
    if (_selectedPhones.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete chats?'),
        content: Text('Delete ${_selectedPhones.length} chat(s)? Messages will be deleted for you.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ChatRepository();
    for (final phone in _selectedPhones.toList()) {
      await repo.deleteChat(phone);
    }
    _exitSelectionMode();
    _loadContactsFromLocalDB();
  }

  Future<void> _lockSelected() async {
    if (_selectedPhones.isEmpty) return;
    final repo = ChatRepository();
    for (final phone in _selectedPhones.toList()) {
      final chat = _chatContacts.where((c) => c.phoneNumber == phone).firstOrNull;
      if (chat != null) {
        await repo.toggleLock(phone, !chat.isLocked);
      }
    }
    _exitSelectionMode();
    await _loadContactsFromLocalDB();
  }

  Future<void> _archiveSelected() async {
    if (_selectedPhones.isEmpty) return;
    final repo = ChatRepository();
    for (final phone in _selectedPhones.toList()) {
      await repo.toggleArchive(phone, true);
    }
    _exitSelectionMode();
    await _loadContactsFromLocalDB();
  }

  void _showLockedChats() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const _LockedChatsScreen(),
      ),
    ).then((_) => _loadContactsFromLocalDB());
  }

  void _showArchivedChats() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const _ArchivedChatsScreen(),
      ),
    ).then((_) => _loadContactsFromLocalDB());
  }

  void _showBlockedDialog(LocalChat contact) {
    final isBlockedByMe = blockService.haveIBlocked(contact.peerUserId);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.red),
            const SizedBox(width: 8),
            Text(isBlockedByMe ? 'User Blocked' : 'You are blocked'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBlockedByMe)
              Text('You have blocked ${contact.contactName.isNotEmpty ? contact.contactName : contact.phoneNumber}')
            else
              Text('You cannot message ${contact.contactName.isNotEmpty ? contact.contactName : contact.phoneNumber} because they have blocked you'),
          ],
        ),
        actions: [
          if (isBlockedByMe)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showUnblockDialog(contact);
              },
              child: Text('Unblock', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog(LocalChat contact) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.block, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Block ${contact.contactName.isNotEmpty ? contact.contactName : contact.phoneNumber}?',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Select block duration:'),
            const SizedBox(height: 12),
            _blockDurationOption(contact, '1 hour', '1h'),
            _blockDurationOption(contact, '8 hours', '8h'),
            _blockDurationOption(contact, '24 hours', '24h'),
            _blockDurationOption(contact, '7 days', '7d'),
            _blockDurationOption(contact, '30 days', '30d'),
            _blockDurationOption(contact, 'Forever', 'forever'),
          ],
        ),
      ),
    );
  }

  Widget _blockDurationOption(LocalChat contact, String label, String duration) {
    return ListTile(
      title: Text(label),
      leading: const Icon(Icons.timer_outlined),
      onTap: () async {
        Navigator.pop(context);
        final success = await blockService.blockUser(contact.peerUserId, duration);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User blocked for $label')),
          );
          await _loadContactsFromLocalDB();
        }
      },
    );
  }

  void _showUnblockDialog(LocalChat contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unblock user?'),
        content: Text('Do you want to unblock ${contact.contactName.isNotEmpty ? contact.contactName : contact.phoneNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await blockService.unblockUser(contact.peerUserId);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User unblocked')),
                );
                await _loadContactsFromLocalDB();
              }
            },
            child: Text('Unblock', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ArchivedChatsScreen extends StatefulWidget {
  const _ArchivedChatsScreen();

  @override
  State<_ArchivedChatsScreen> createState() => _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends State<_ArchivedChatsScreen> {
  List<LocalChat> _archived = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final chats = await ChatRepository().getAllChats(includeArchived: true);
    if (mounted) setState(() => _archived = chats.where((c) => c.isArchived && !RegExp(r'^[A-Z0-9]{8}$').hasMatch(c.phoneNumber)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
          color: const Color(0xFF263238),
        ),
        title: const Text('Archived Chats', style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onPressed: () {},
          ),
        ],
      ),
      body: _archived.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No archived chats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8),
              itemCount: _archived.length,
              itemBuilder: (context, index) {
                final contact = _archived[index];
                return _archivedContactTile(contact);
              },
            ),
    );
  }

  Widget _archivedContactTile(LocalChat contact) {
    final displayName = contact.contactName.isNotEmpty ? contact.contactName : contact.phoneNumber;
    return Dismissible(
      key: ValueKey(contact.phoneNumber),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: const Color(0xFF075E54),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Icon(Icons.unarchive_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Unarchive', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      onDismissed: (_) async {
        await ChatRepository().toggleArchive(contact.phoneNumber, false);
        _load();
      },
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[200],
          backgroundImage: contact.profileImageUrl.isNotEmpty ? FileImage(File(contact.profileImageUrl)) : null,
          child: contact.profileImageUrl.isEmpty
              ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '#',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF263238)))
              : null,
        ),
        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(contact.displayLastMessage, style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: const Icon(Icons.unarchive_rounded, color: Colors.grey),
          onPressed: () async {
            await ChatRepository().toggleArchive(contact.phoneNumber, false);
            _load();
          },
        ),
      ),
    );
  }
}

class _LockedChatsScreen extends StatefulWidget {
  const _LockedChatsScreen();

  @override
  State<_LockedChatsScreen> createState() => _LockedChatsScreenState();
}

class _LockedChatsScreenState extends State<_LockedChatsScreen> {
  List<LocalChat> _locked = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final chats = await ChatRepository().getAllChats(includeArchived: true);
    if (mounted) setState(() => _locked = chats.where((c) => c.isLocked).toList());
  }

  Future<void> _unlockChat(LocalChat contact) async {
    final displayName = contact.contactName.isNotEmpty ? contact.contactName : contact.phoneNumber;
    final unlocked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LockScreen(
          chatName: displayName,
          onUnlocked: () => Navigator.pop(context, true),
          onCancel: () => Navigator.pop(context, false),
        ),
      ),
    );
    if (unlocked == true) {
      await ChatRepository().toggleLock(contact.phoneNumber, false);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
          color: const Color(0xFF263238),
        ),
        title: const Text('Locked Chats', style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onPressed: () {},
          ),
        ],
      ),
      body: _locked.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No locked chats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8),
              itemCount: _locked.length,
              itemBuilder: (context, index) {
                final contact = _locked[index];
                return _lockedContactTile(contact);
              },
            ),
    );
  }

  Widget _lockedContactTile(LocalChat contact) {
    final displayName = contact.contactName.isNotEmpty ? contact.contactName : contact.phoneNumber;
    return Dismissible(
      key: ValueKey(contact.phoneNumber),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.amber[700]!,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Icon(Icons.lock_open_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Unlock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      onDismissed: (_) async {
        await _unlockChat(contact);
      },
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[200],
          backgroundImage: contact.profileImageUrl.isNotEmpty ? FileImage(File(contact.profileImageUrl)) : null,
          child: contact.profileImageUrl.isEmpty
              ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '#',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF263238)))
              : null,
        ),
        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Locked', style: TextStyle(color: Colors.amber[700], fontSize: 13)),
        trailing: IconButton(
          icon: Icon(Icons.lock_open_rounded, color: Colors.grey),
          onPressed: () async {
            await _unlockChat(contact);
          },
        ),
      ),
    );
  }
}
