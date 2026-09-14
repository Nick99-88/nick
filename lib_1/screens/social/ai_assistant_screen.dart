import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme.dart';
import '../../services/ai_chat_service.dart';

DateTime _parseUtc(String s) => s.isEmpty ? DateTime.now() : DateTime.parse(s).toLocal();

// ──────────────────────────────────────────────
// Data Models
// ──────────────────────────────────────────────

class AIChatAttachment {
  final String name;
  final String path;
  final String type;

  AIChatAttachment({required this.name, required this.path, required this.type});

  Map<String, dynamic> toJson() => {'name': name, 'path': path, 'type': type};

  factory AIChatAttachment.fromJson(Map<String, dynamic> json) => AIChatAttachment(
    name: json['name'] as String,
    path: json['path'] as String,
    type: json['type'] as String,
  );
}

class AIChatMessage {
  String id;
  String text;
  final bool isUser;
  final DateTime timestamp;
  final List<AIChatAttachment> attachments;

  AIChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    List<AIChatAttachment>? attachments,
  }) : timestamp = timestamp ?? DateTime.now(),
       attachments = attachments ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'attachments': attachments.map((a) => a.toJson()).toList(),
  };

  factory AIChatMessage.fromJson(Map<String, dynamic> json) => AIChatMessage(
    id: json['id'] as String,
    text: json['content'] as String? ?? json['text'] as String? ?? '',
    isUser: (json['role'] as String? ?? json['isUser']?.toString()) == 'user',
    timestamp: _parseUtc(json['created_at'] as String? ?? json['timestamp'] as String? ?? ''),
    attachments: (json['attachments'] as List?)?.map((a) => AIChatAttachment.fromJson(a as Map<String, dynamic>)).toList() ?? [],
  );
}

class AIChatSession {
  final String id;
  String title;
  String mode;
  final List<AIChatMessage> messages;
  final DateTime createdAt;
  DateTime updatedAt;

  AIChatSession({
    required this.id,
    this.title = 'New Chat',
    this.mode = 'think',
    List<AIChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : messages = messages ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  String get lastPreview {
    if (messages.isEmpty) return 'No messages yet';
    final last = messages.last;
    return '${last.isUser ? "You: " : "AI: "}${last.text.length > 50 ? "${last.text.substring(0, 50)}..." : last.text}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'mode': mode,
    'messages': messages.map((m) => m.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

// ──────────────────────────────────────────────
// Main Screen
// ──────────────────────────────────────────────

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AiChatService _service = AiChatService.instance;

  List<AIChatSession> _sessions = [];
  int _activeSessionIndex = 0;
  bool _isLoading = false;
  bool _dataLoaded = false;
  bool _isStreaming = false;
  String _streamBuffer = '';
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;

  AIChatSession get _activeSession => _sessions[_activeSessionIndex];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSessions();
    _connectWebSocket();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    _scrollController.dispose();
    _wsSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _service.disconnect();
    } else if (state == AppLifecycleState.resumed) {
      _connectWebSocket();
    }
  }

  Future<void> _connectWebSocket() async {
    try {
      await _service.connect();
      _wsSubscription?.cancel();
      _wsSubscription = _service.messageStream.listen(_handleWsMessage);
    } catch (e) {
      debugPrint('WebSocket connect failed: $e');
    }
  }

  void _handleWsMessage(Map<String, dynamic> msg) {
    final status = msg['status'];

    if (status == 'streaming') {
      final delta = msg['delta'] as String? ?? '';
      if (delta.isEmpty) {
        setState(() {
          _isStreaming = true;
          _streamBuffer = '';
          _isLoading = false;
          _activeSession.messages.add(AIChatMessage(
            id: 'streaming_${DateTime.now().microsecondsSinceEpoch}',
            text: '',
            isUser: false,
          ));
        });
      } else {
        setState(() {
          _streamBuffer += delta;
          _activeSession.messages.last.text = _streamBuffer;
        });
        _scrollToBottom();
      }
    } else if (status == 'done') {
      final message = msg['message'] as Map<String, dynamic>?;
      setState(() {
        _isStreaming = false;
        if (message != null && _activeSession.messages.isNotEmpty) {
          _activeSession.messages.last.text = message['content'] ?? _streamBuffer;
          _activeSession.messages.last.id = message['id'] ?? _activeSession.messages.last.id;
        }
        _activeSession.updatedAt = DateTime.now();
        _isLoading = false;
      });
      _scrollToBottom();
    } else if (status == 'error') {
      setState(() {
        _isStreaming = false;
        _isLoading = false;
        if (_activeSession.messages.isNotEmpty && !_activeSession.messages.last.isUser) {
          _activeSession.messages.last.text = 'Error: ${msg['message']}';
        }
      });
    }
  }

  Future<void> _loadSessions() async {
    try {
      final serverSessions = await _service.listSessions();
      if (!mounted) return;

      if (serverSessions.isEmpty) {
        final created = await _service.createSession(mode: 'think');
        _sessions = [_parseSession(created)];
      } else {
        _sessions = serverSessions.map((s) => _parseSessionSummary(s)).toList();
        if (_sessions.isNotEmpty) {
          final full = await _service.getSession(_sessions.first.id);
          _sessions[0] = _parseSession(full);
        }
      }
      setState(() {
        _activeSessionIndex = 0;
        _dataLoaded = true;
      });
    } catch (e) {
      debugPrint('Failed to load sessions: $e');
      if (!mounted) return;
      setState(() {
        _sessions = [_createLocalSession()];
        _activeSessionIndex = 0;
        _dataLoaded = true;
      });
    }
  }

  AIChatSession _parseSession(Map<String, dynamic> json) {
    final messages = (json['messages'] as List?)?.map((m) {
      final role = m['role'] as String? ?? (m['isUser'] == true ? 'user' : 'assistant');
      return AIChatMessage(
        id: m['id'] as String? ?? '',
        text: m['content'] as String? ?? m['text'] as String? ?? '',
        isUser: role == 'user',
        timestamp: _parseUtc(m['created_at'] as String? ?? m['timestamp'] as String? ?? ''),
        attachments: (m['attachments'] as List?)?.map((a) => AIChatAttachment.fromJson(a as Map<String, dynamic>)).toList() ?? [],
      );
    }).toList() ?? [];

    return AIChatSession(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'New Chat',
      mode: json['mode'] as String? ?? 'think',
      messages: messages,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  AIChatSession _parseSessionSummary(Map<String, dynamic> json) {
    return AIChatSession(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'New Chat',
      mode: json['mode'] as String? ?? 'think',
      createdAt: _parseUtc(json['created_at'] as String? ?? ''),
      updatedAt: _parseUtc(json['updated_at'] as String? ?? ''),
    );
  }

  AIChatSession _createLocalSession({String mode = 'think'}) {
    return AIChatSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      mode: mode,
      messages: [
        AIChatMessage(
          id: 'welcome_${DateTime.now().microsecondsSinceEpoch}',
          text: mode == 'think'
              ? "✨ **Star AI** — Think Mode\n\nI'll analyze your questions carefully and provide well-reasoned answers. Ask me anything!"
              : "✨ **Star AI** — Agentic Mode\n\nI can perform tasks, search information, and take actions on your behalf. Just tell me what you need!",
          isUser: false,
        ),
      ],
    );
  }

  void _switchToSession(int index) async {
    if (index < 0 || index >= _sessions.length) return;
    setState(() {
      _activeSessionIndex = index;
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final full = await _service.getSession(_sessions[index].id);
      if (!mounted) return;
      setState(() {
        _sessions[index] = _parseSession(full);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _newChat({String mode = 'think'}) async {
    try {
      final created = await _service.createSession(mode: mode);
      final session = _parseSession(created);
      setState(() {
        _sessions.insert(0, session);
        _activeSessionIndex = 0;
      });
    } catch (e) {
      setState(() {
        _sessions.insert(0, _createLocalSession(mode: mode));
        _activeSessionIndex = 0;
      });
    }
    _scrollToBottom();
  }

  void _deleteSession(int index) async {
    final sessionId = _sessions[index].id;
    if (_sessions.length == 1) {
      setState(() {
        _sessions = [_createLocalSession()];
        _activeSessionIndex = 0;
      });
    } else {
      setState(() {
        _sessions.removeAt(index);
        if (_activeSessionIndex >= _sessions.length) {
          _activeSessionIndex = _sessions.length - 1;
        } else if (index < _activeSessionIndex) {
          _activeSessionIndex--;
        }
      });
    }
    try {
      await _service.deleteSession(sessionId);
    } catch (_) {}
  }

  void _setMode(String mode) async {
    if (_activeSession.mode == mode) return;
    setState(() {
      _activeSession.mode = mode;
      _activeSession.messages.clear();
      _activeSession.messages.add(AIChatMessage(
        id: 'mode_${DateTime.now().microsecondsSinceEpoch}',
        text: mode == 'think'
            ? "🔄 **Star AI** — Switched to Think Mode\n\nI'll now analyze questions carefully before responding."
            : "🔄 **Star AI** — Switched to Agentic Mode\n\nI can now perform tasks and take actions for you.",
        isUser: false,
      ));
      _activeSession.updatedAt = DateTime.now();
    });
    try {
      await _service.updateSession(_activeSession.id, mode: mode);
    } catch (_) {}
  }

  Future<void> _attachFile() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Attach File', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _attachOption(ctx, Icons.photo_library, 'Gallery', () async {
                  Navigator.pop(ctx);
                  final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
                  if (picked != null) _addFileToChat(picked.path, picked.name, 'image');
                }),
                _attachOption(ctx, Icons.camera_alt, 'Camera', () async {
                  Navigator.pop(ctx);
                  final picked = await _imagePicker.pickImage(source: ImageSource.camera);
                  if (picked != null) _addFileToChat(picked.path, picked.name, 'image');
                }),
                _attachOption(ctx, Icons.description, 'Document', () async {
                  Navigator.pop(ctx);
                  final result = await FilePicker.pickFiles();
                  if (result != null && result.files.isNotEmpty) {
                    final file = result.files.first;
                    _addFileToChat(file.path ?? '', file.name, 'document');
                  }
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachOption(BuildContext ctx, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: StarlightTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: StarlightTheme.primaryBlue, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _addFileToChat(String path, String name, String type) {
    if (path.isEmpty) return;
    setState(() {
      _activeSession.messages.add(AIChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: type == 'image' ? 'Shared an image' : 'Shared a document: $name',
        isUser: true,
        attachments: [AIChatAttachment(name: name, path: path, type: type)],
      ));
      _activeSession.updatedAt = DateTime.now();
    });
    _scrollToBottom();
    _sendToBackend(type == 'image'
        ? "I can see the image you shared. How can I help you with it?"
        : "I've received the document '$name'. What would you like me to do with it?");
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading || _isStreaming) return;

    if (_activeSession.messages.where((m) => m.isUser).isEmpty) {
      _activeSession.title = text.length > 30 ? '${text.substring(0, 30)}...' : text;
      try {
        _service.updateSession(_activeSession.id, title: _activeSession.title);
      } catch (_) {}
    }

    setState(() {
      _activeSession.messages.add(AIChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: text,
        isUser: true,
      ));
      _activeSession.updatedAt = DateTime.now();
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    _sendToBackend(text);
  }

  void _sendToBackend(String content) {
    if (_service.isConnected) {
      _service.sendMessageStream(
        _activeSession.id,
        content,
        mode: _activeSession.mode,
      );
    } else {
      _connectWebSocket().then((_) {
        if (_service.isConnected) {
          _service.sendMessageStream(
            _activeSession.id,
            content,
            mode: _activeSession.mode,
          );
        } else {
          _fallbackRestResponse(content);
        }
      });
    }
  }

  Future<void> _fallbackRestResponse(String content) async {
    try {
      final result = await _service.sendMessage(_activeSession.id, content);
      if (!mounted) return;
      final aiMsg = result['ai_message'];
      setState(() {
        _activeSession.messages.add(AIChatMessage(
          id: aiMsg['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
          text: aiMsg['content'] ?? '',
          isUser: false,
          timestamp: _parseUtc(aiMsg['created_at'] ?? ''),
        ));
        _activeSession.updatedAt = DateTime.now();
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activeSession.messages.add(AIChatMessage(
          id: 'err_${DateTime.now().microsecondsSinceEpoch}',
          text: 'Failed to get response. Please try again.',
          isUser: false,
        ));
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─────────── BUILD ───────────

  @override
  Widget build(BuildContext context) {
    if (!_dataLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F7FE),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1, color: Colors.black12),
            Expanded(child: _buildMessageList()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ─────────── DRAWER ───────────

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDrawerHeader(),
            const Divider(height: 1),
            Expanded(child: _buildSessionList()),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: StarlightTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.history, color: StarlightTheme.primaryBlue, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Chat History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: StarlightTheme.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList() {
    if (_sessions.isEmpty) {
      return const Center(child: Text('No chats yet', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        final isActive = index == _activeSessionIndex;
        return Dismissible(
          key: ValueKey(session.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red.shade400,
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Chat'),
                content: Text('Delete "${session.title}"?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (_) => _deleteSession(index),
          child: ListTile(
            selected: isActive,
            selectedTileColor: StarlightTheme.primaryBlue.withOpacity(0.08),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isActive ? StarlightTheme.primaryBlue : StarlightTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                session.mode == 'agentic' ? Icons.rocket_launch : Icons.psychology,
                color: isActive ? Colors.white : StarlightTheme.primaryBlue,
                size: 18,
              ),
            ),
            title: Text(
              session.title,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              session.lastPreview,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              _formatTime(session.updatedAt),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            onTap: () {
              Navigator.pop(context);
              _switchToSession(index);
            },
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final time = '$h:$minute $period';

    if (date == today) return time;
    final diff = today.difference(date).inDays;
    if (diff == 1) return 'Yesterday';
    if (diff < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    }
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, $time';
  }

  // ─────────── HEADER ───────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.white,
      child: Row(
        children: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded, color: StarlightTheme.primaryBlue),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: StarlightTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _activeSession.mode == 'agentic' ? Icons.rocket_launch : Icons.psychology,
              color: StarlightTheme.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activeSession.title,
                  style: const TextStyle(
                    color: StarlightTheme.primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
        children: [
          GestureDetector(
            onTap: _attachFile,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: StarlightTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.attach_file_rounded, color: StarlightTheme.primaryBlue, size: 20),
            ),
          ),
          const SizedBox(width: 6),
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: _service.isConnected ? Colors.green : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _service.isConnected
                          ? (_activeSession.mode == 'agentic' ? 'Agentic AI' : 'Think Mode')
                          : 'Offline',
                      style: TextStyle(
                        color: _service.isConnected ? Colors.green : Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildModeToggle(),
          const SizedBox(width: 4),
          Container(
            decoration: BoxDecoration(
              color: StarlightTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.add_rounded, color: StarlightTheme.primaryBlue, size: 22),
              tooltip: 'New Chat',
              onPressed: () => _newChat(mode: _activeSession.mode),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    final isAgentic = _activeSession.mode == 'agentic';
    return GestureDetector(
      onTap: () => _setMode(isAgentic ? 'think' : 'agentic'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isAgentic ? Colors.orange.withOpacity(0.15) : StarlightTheme.primaryBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAgentic ? Colors.orange : StarlightTheme.primaryBlue,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAgentic ? Icons.rocket_launch : Icons.psychology,
              size: 14,
              color: isAgentic ? Colors.orange : StarlightTheme.primaryBlue,
            ),
            const SizedBox(width: 4),
            Text(
              isAgentic ? 'Agentic' : 'Think',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isAgentic ? Colors.orange : StarlightTheme.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────── MESSAGE LIST ───────────

  Widget _buildMessageList() {
    final messages = _activeSession.messages;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length && _isLoading) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                SizedBox(width: 48),
                _TypingIndicator(),
              ],
            ),
          );
        }
        return _ChatBubble(message: messages[index]);
      },
    );
  }

  // ─────────── INPUT BAR ───────────

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: "Ask me anything...",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF4F7FE),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              maxLines: 5,
              minLines: 1,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (_isLoading || _isStreaming) ? Colors.grey : StarlightTheme.primaryBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                (_isLoading || _isStreaming) ? Icons.hourglass_top : Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Chat Bubble
// ──────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final AIChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final hasAttachments = message.attachments.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: StarlightTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: StarlightTheme.primaryBlue, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser ? StarlightTheme.primaryBlue : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasAttachments) ...[
                    ...message.attachments.map((att) => _buildAttachmentPreview(att, context)),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview(AIChatAttachment att, BuildContext context) {
    if (att.type == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(att.path),
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 60,
            color: Colors.grey.shade200,
            child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: message.isUser ? Colors.white.withOpacity(0.15) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description, size: 18, color: message.isUser ? Colors.white : Colors.grey.shade700),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              att.name,
              style: TextStyle(fontSize: 12, color: message.isUser ? Colors.white : Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Typing Indicator
// ──────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: StarlightTheme.primaryBlue.withOpacity(
                    (0.3 + (_controller.value * 0.7 - (i * 0.2))).clamp(0.3, 1.0),
                  ),
                  shape: BoxShape.circle,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
