import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../chat_local_db/chat_local_db.dart';
import '../screens/social/chat_screen.dart';

class LockedChatsScreen extends StatefulWidget {
  const LockedChatsScreen({super.key});

  @override
  State<LockedChatsScreen> createState() => _LockedChatsScreenState();
}

class _LockedChatsScreenState extends State<LockedChatsScreen> with WidgetsBindingObserver {
  static const String _sessionKey = 'locked_chats_session';
  bool _isAuthenticated = false;
  bool _isLoading = true;
  List<LocalChat> _lockedChats = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearSession();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.detached) {
      _clearSession();
    }
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final session = prefs.getString(_sessionKey);
    
    if (session != null) {
      // Check if session is still valid (within 5 minutes)
      final sessionTime = DateTime.tryParse(session);
      if (sessionTime != null && DateTime.now().difference(sessionTime).inMinutes < 5) {
        setState(() => _isAuthenticated = true);
        await _loadLockedChats();
      } else {
        await _clearSession();
        await _authenticate();
      }
    } else {
      await _authenticate();
    }
  }

  Future<void> _authenticate() async {
    try {
      final localAuth = LocalAuthentication();
      final authenticated = await localAuth.authenticate(
        localizedReason: 'Authenticate to access locked chats',
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
      
      if (authenticated) {
        // Store session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_sessionKey, DateTime.now().toIso8601String());
        
        setState(() => _isAuthenticated = true);
        await _loadLockedChats();
      } else {
        setState(() => _error = 'Authentication failed');
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = 'Authentication error: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<void> _loadLockedChats() async {
    try {
      final chatRepository = ChatRepository();
      final messageRepository = MessageRepository();
      final chats = await chatRepository.getAllChats(includeArchived: true);
      
      final locked = chats.where((c) => c.isLocked).toList();
      final enriched = <LocalChat>[];
      
      for (final chat in locked) {
        if (chat.phoneNumber.isNotEmpty && !RegExp(r'^[A-Z0-9]{8}$').hasMatch(chat.phoneNumber)) {
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
      
      enriched.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      
      if (mounted) {
        setState(() => _lockedChats = enriched);
      }
    } catch (e) {
      debugPrint("Error loading locked chats: $e");
    }
  }

  void _unlockChat(LocalChat contact) async {
    final repo = ChatRepository();
    await repo.toggleLock(contact.phoneNumber, false);
    await _loadLockedChats();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
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
          title: const Text('Locked Chats', style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
        title: const Text('Locked Chats', style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold)),
      ),
      body: _lockedChats.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_open_rounded, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No locked chats',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lock chats to keep them private',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _lockedChats.length,
              itemBuilder: (context, index) {
                final contact = _lockedChats[index];
                return _lockedContactTile(contact);
              },
            ),
    );
  }

  Widget _lockedContactTile(LocalChat contact) {
    final displayName = contact.contactName.isNotEmpty ? contact.contactName : contact.phoneNumber;
    final hasPicture = contact.profileImageUrl.isNotEmpty;
    final hasUnread = contact.unreadCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey[200],
          backgroundImage: hasPicture ? FileImage(File(contact.profileImageUrl)) : null,
          child: !hasPicture
              ? Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '#',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF263238),
                  ),
                )
              : null,
        ),
        title: Text(
          displayName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF263238),
          ),
        ),
        subtitle: Text(
          contact.lastMessage.isNotEmpty ? contact.lastMessage : contact.phoneNumber,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasUnread)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${contact.unreadCount}',
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.lock_open_rounded, color: Colors.amber),
              onPressed: () => _unlockChat(contact),
            ),
          ],
        ),
        onTap: () {
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
          ).then((_) => _loadLockedChats());
        },
      ),
    );
  }
}