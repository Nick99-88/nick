import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:share_plus/share_plus.dart';
import 'package:starlight_flutter/chat_system/services/proximity_wake_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart' as p;
import 'package:open_file/open_file.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../services/chat/chat_service.dart';
import '../../services/socket/enhanced_socket_service.dart';
import '../../services/chat/backend_chat_service.dart';
import '../../services/social/block_service.dart';
import '../../chat_system/services/call_signaling_service.dart';
import '../../chat_system/services/socket_event_bus.dart';
import '../../chat_system/services/fcm_chat_saver.dart';
import '../../chat_system/services/audio_playback_service.dart';
import '../../chat_system/services/media_transfer_service.dart';
import '../../widgets/profile_avatar.dart';
import '../../chat_local_db/chat_local_db.dart';
import '../../chat_local_db/storage/chat_media_storage.dart';
import '../../chatting_platform/contact_profile_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ChatScreen extends StatefulWidget {
  final String friendId;
  final String? friendName;
  final String? friendRole;
  final String? friendPhone;
  final bool fromInbox;
  final String? friendProfilePicture;
  final String? friendPublicId;

  const ChatScreen({
    super.key,
    required this.friendId,
    this.friendName,
    this.friendRole,
    this.friendPhone,
    this.fromInbox = false,
    this.friendProfilePicture,
    this.friendPublicId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _recorder = AudioRecorder();
  final ImagePicker _imagePicker = ImagePicker();
  final ChatLocalService _localDb = ChatLocalService.instance;
  final MessageRepository _msgRepo = MessageRepository();
  final ChatRepository _chatRepo = ChatRepository();
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isSending = false;
  String? _currentUserId;
  String? _currentUserPhone;
  String? _clientUuid;

  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  Timer? _typingTimer;
  bool _hasText = false;

  // Media preview state
  final List<_PendingMedia> _pendingMedia = [];
  final TextEditingController _mediaDescriptionController = TextEditingController();

  // Media clustering state
  bool _isGroupingMedia = false;
  List<_ChatMessage> _groupedMediaMessages = [];

  // Selection mode
  bool _selectionMode = false;
  final Set<String> _selectedMessages = {};

  bool _isRecording = false;
  bool _isCancelled = false;
  DateTime? _recordStartTime;
  Timer? _recordTimer;
  int _recordSeconds = 0;

  // Voice recording indicator from peer
  bool _isVoiceRecording = false;
  Timer? _voiceRecordingTimer;

  bool _friendOnline = false;
  String? _lastSeen;
  Timer? _presenceTimer;

  // Local DB
  String _localChatPhone = ''; // friendId used as chat key in local DB
  bool _localDbInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserAndConnect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel?.sink.close();
    _controller.dispose();
    _mediaDescriptionController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _recordTimer?.cancel();
    _voiceRecordingTimer?.cancel();
    _presenceTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isConnected) {
      _connectWebSocket();
    }
    if (state == AppLifecycleState.paused && _isRecording) {
      _stopRecording();
    }
  }

  Future<void> _loadUserAndConnect() async {
    _currentUserId = await StarlightStorage.getUserIdString();
    _currentUserPhone = await StarlightStorage.getVerifiedPhone();
    _clientUuid = DateTime.now().microsecondsSinceEpoch.toString();
    await _initLocalDb();
    _connectWebSocket();
    _loadHistory();
  }

  bool get _usePhoneBasedChat => !widget.fromInbox && widget.friendPhone != null && widget.friendPhone!.isNotEmpty;

  String get _currentChatId => _usePhoneBasedChat ? widget.friendPhone! : widget.friendId;

  String get _currentUserPeerId => _usePhoneBasedChat ? widget.friendId : '';

  bool get _isSelfChat => (_currentUserPhone != null && widget.friendPhone != null &&
      _currentUserPhone == widget.friendPhone) ||
      (_currentUserId != null && widget.friendId == _currentUserId);

  Future<void> _initLocalDb() async {
    try {
      await _localDb.initialize();
      _localChatPhone = widget.fromInbox ? widget.friendPublicId! : widget.friendPhone!;
      _localDbInitialized = true;
      try {
        await _chatRepo.getOrCreateChat(_localChatPhone, contactName: widget.friendName, peerUserId: _currentUserPeerId);
      } catch (e) {
        print('📦 LocalDB getOrCreateChat error (non-fatal): $e');
      }
    } catch (e) {
      print('📦 LocalDB init error: $e');
      _localDbInitialized = false;
    }
  }

  void _loadHistory() async {
    print('🔌 ChatWS: _loadHistory called — friendId=${widget.friendId}, friendPhone=${widget.friendPhone}, fromInbox=${widget.fromInbox}');
    print('🔌 ChatWS: _usePhoneBasedChat=$_usePhoneBasedChat → localChatPhone="$_localChatPhone"');
    try {
      // Try loading from local SQLite first
      if (_localDbInitialized) {
        final localMsgs = await _msgRepo.getMessagesByPhone(_localChatPhone, limit: 200);
        if (localMsgs.isNotEmpty && mounted) {
          print('📦 LocalDB: Loaded ${localMsgs.length} messages using key="$_localChatPhone"');
          for (final lm in localMsgs) {
            if (!lm.isDeleted && !lm.deleteForMe) {
              print('📦 LocalDB:   [${lm.messageType}] id=${lm.id} uuid=${lm.clientUuid} content="${lm.content.length > 50 ? lm.content.substring(0, 50) : lm.content}" mediaRemoteUrl="${lm.mediaRemoteUrl}" mediaLocalPath="${lm.mediaLocalPath}" status=${lm.status}');
            }
          }
          setState(() {
            _messages.clear();
            for (final lm in localMsgs) {
              if (!lm.isDeleted && !lm.deleteForMe) {
                _messages.add(_localToChatMsg(lm));
              }
            }
          });
          _scrollToBottom();
          _sendMarkRead();
          return;
        }
      }

      // No local messages — bootstrap from server
      List<dynamic>? fetchedMessages;
      if (_usePhoneBasedChat) {
        final msgs = await BackendChatService().getMessagesByPhone(_localChatPhone);
        fetchedMessages = msgs;
      } else {
        final service = ChatService();
        final result = await service.getMessagesByFriendId(_localChatPhone);
        fetchedMessages = result['messages'] as List<dynamic>?;
      }
      print('🔌 ChatWS: History loaded: ${fetchedMessages?.length ?? 0} messages');

      if (!mounted) return;

      final messages = fetchedMessages ?? [];
      if (messages.isNotEmpty) {
        final batch = <_ChatMessage>[];
        for (final m in messages) {
          final msg = _ChatMessage(
            id: m['message_id']?.toString() ?? m['id']?.toString() ?? '',
            text: m['content']?.toString() ?? '',
            isUser: m['is_self'] == true,
            timestamp: DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
            status: m['status']?.toString() ?? 'sent',
            messageType: m['message_type']?.toString() ?? 'text',
            mediaUrl: m['media_url']?.toString() ?? '',
            thumbnailUrl: m['thumbnail_url']?.toString() ?? '',
            fileName: m['file_name']?.toString(),
            serverId: m['id']?.toString(),
          );
          batch.add(msg);
          // Also save to local DB
          if (_localDbInitialized) {
            try {
              await _msgRepo.insertMessage(_chatMsgToLocal(msg, peerUserId: m['sender_id']?.toString(), serverId: msg.serverId));
            } catch (_) {}
          }
        }
        if (mounted) {
          setState(() => _messages.addAll(batch));
          _scrollToBottom();
          _sendMarkRead();
        }
      }
    } catch (e) {
      print('🔌 ChatWS: Failed to load history: $e');
    }
  }

  void _sendMarkRead() {
    final currentId = widget.friendPhone != null && widget.friendPhone!.isNotEmpty
        ? widget.friendId
        : _currentChatId;

    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({
        'action': 'mark_read',
        'chat_id': '',
        'sender_id': currentId,
      }));
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ── Local DB helpers ──────────────────────────────────────────────────

  LocalMessage _chatMsgToLocal(_ChatMessage msg, {int? dbId, String? peerUserId, String? serverId}) {
    return LocalMessage(
      id: dbId,
      chatPhoneNumber: _localChatPhone,
      peerUserId: peerUserId ?? widget.friendId,
      sequenceId: 0,
      clientUuid: msg.id,
      messageType: msg.messageType,
      messageDirection: msg.isUser ? 'sent' : 'received',
      content: msg.text,
      mediaLocalPath: msg.filePath ?? '',
      mediaRemoteUrl: msg.mediaUrl,
      mediaFileName: msg.fileName ?? '',
      mediaThumbnailPath: msg.thumbnailUrl,
      mediaDurationMs: (msg.duration ?? 0) * 1000,
      status: msg.status,
      serverMessageId: serverId ?? msg.serverId ?? '',
      createdAt: msg.timestamp.toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  _ChatMessage _localToChatMsg(LocalMessage lm) {
    return _ChatMessage(
      id: lm.clientUuid.isNotEmpty ? lm.clientUuid : lm.serverMessageId,
      text: lm.content,
      isUser: lm.isSent,
      timestamp: DateTime.tryParse(lm.createdAt) ?? DateTime.now(),
      status: lm.status,
      messageType: lm.messageType,
      mediaUrl: lm.mediaRemoteUrl,
      thumbnailUrl: lm.mediaThumbnailPath,
      fileName: lm.mediaFileName.isNotEmpty ? lm.mediaFileName : null,
      filePath: lm.mediaLocalPath.isNotEmpty ? lm.mediaLocalPath : null,
      serverId: lm.serverMessageId.isNotEmpty ? lm.serverMessageId : null,
      downloaded: lm.mediaLocalPath.isNotEmpty,
      duration: lm.mediaDurationMs > 0 ? (lm.mediaDurationMs / 1000).round() : null,
    );
  }

  Future<void> _saveMessageToLocalDb(_ChatMessage msg, String displayText, String msgType) async {
    if (!_localDbInitialized) {
      print('📦 LocalDB save skipped: _localDbInitialized = false');
      return;
    }

    print('📦 LocalDB saving: type=$msgType key="$_localChatPhone" peerUserId=$_currentUserPeerId fromInbox=${widget.fromInbox}');

    try {
      await _chatRepo.getOrCreateChat(_localChatPhone, contactName: widget.friendName, peerUserId: _currentUserPeerId);
    } catch (e) {
      print('📦 LocalDB getOrCreateChat retry error: $e');
    }

    try {
      var localMsg = _chatMsgToLocal(msg);
      if (msgType == 'voice' && msg.filePath != null && msg.filePath!.isNotEmpty) {
        try {
          final file = File(msg.filePath!);
          if (await file.exists()) {
            final permanentPath = await ChatMediaStorage.instance.getSavePath('voice', msg.fileName ?? 'voice.m4a');
            await file.copy(permanentPath);
            localMsg = localMsg.copyWith(mediaLocalPath: permanentPath);
          }
        } catch (e) {
          print('📦 Voice file copy error: $e');
        }
      }
      final insertedId = await _msgRepo.insertMessage(localMsg);
      await _chatRepo.updateLastMessage(_localChatPhone, displayText, msgType);
      print('📦 LocalDB: saved [${msg.messageType}] id=$insertedId key="$_localChatPhone" peerUserId=${localMsg.peerUserId} chatPhone=${localMsg.chatPhoneNumber} content="${msg.text.length > 50 ? msg.text.substring(0, 50) : msg.text}" mediaUrl="${msg.mediaUrl}" filePath="${msg.filePath ?? ''}"');
    } catch (e) {
      print('📦 LocalDB save error: $e');
    }
  }

  void _connectWebSocket() async {
    final token = await StarlightStorage.getUserToken();
    if (token == null || !mounted) return;

    try {
      final uri = Uri.parse('${StarlightConstants.chatSocketUrl}/$token');
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (data) {
          if (!mounted) return;
          final event = jsonDecode(data);
          _handleEvent(event);
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _isConnected = false);
          _scheduleReconnect();
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _isConnected = false);
        },
      );

      setState(() => _isConnected = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConnected = false);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_isConnected) _connectWebSocket();
    });
  }

  void _checkFriendOnline() {
    final currentId = widget.friendPhone != null && widget.friendPhone!.isNotEmpty
        ? widget.friendId
        : _currentChatId;

    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({
        'action': 'check_online',
        'peer_user_id': currentId,
      }));
    }
  }

  String _formatLastSeen(DateTime? dt) {
    if (dt == null) return 'Offline';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Last seen yesterday';
    return 'Last seen ${dt.day}/${dt.month}/${dt.year}';
  }

  void _handleEvent(Map<String, dynamic> event) {
    final action = event['event'] ?? event['action'];

    switch (action) {
      case 'connected':
      case 'connection_created':
      setState(() => _isConnected = true);

      // Check friend's online status immediately and every 15s
      _checkFriendOnline();
      _presenceTimer?.cancel();
      _presenceTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkFriendOnline());
      
      // Auto-resend pending messages
      _resendPendingMessages();
        break;
      case 'new_message':
        _handleIncomingMessage(event);
        break;
      case 'msg_ack':
        _handleAck(event);
        break;
      case 'typing':
        _handleTyping(event);
        break;
      case 'recording':
        _handleVoiceRecording(event, true);
        break;
      case 'stop_recording':
        _handleVoiceRecording(event, false);
        break;
      case 'message_delivered':
        _handleStatusUpdate(event, 'delivered');
        break;
      case 'message_status':
        final data = event['data'] ?? event;
        _handleStatusUpdate(event, data['status']?.toString() ?? 'delivered');
        break;
      case 'message_error':
        final errorData = event['data'] ?? event;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${errorData['error'] ?? 'Unknown error'}'), backgroundColor: Colors.red),
          );
        }
        break;

      // Forward call events to SocketEventBus → CallSignalingService
      case 'call_incoming':
      case 'call_accepted':
      case 'call_rejected':
      case 'call_busy':
      case 'call_ended':
      case 'call_missed':
      case 'webrtc_signal':
        print('📞 ChatWS: Forwarding $action to SocketEventBus');
        SocketEventBus.instance.publish(action, event['data'] ?? event);
        break;

      case 'online_status':
        final data = event['data'] ?? event;
        final isOnline = data['is_online'] == true;
        final lastSeenStr = data['last_seen']?.toString();
        if (mounted) {
          setState(() {
            _friendOnline = isOnline;
            if (!isOnline && lastSeenStr != null) {
              _lastSeen = _formatLastSeen(DateTime.tryParse(lastSeenStr));
            } else if (isOnline) {
              _lastSeen = null;
            }
          });
        }
        print('🌐 ChatWS: Friend ${widget.friendId} online=$isOnline lastSeen=$lastSeenStr');
        break;
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> event) {
    final data = event['data'] ?? event;
    final senderId = data['sender_id']?.toString();
    final content = data['content']?.toString() ?? '';

    // Save to local DB using centralized saver (handles phone number or chat_id)
    FcmChatSaver.saveChatMessage(data);

    if (senderId == widget.friendId && mounted) {
      final msg = _ChatMessage(
        id: data['message_id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        text: content,
        isUser: false,
        timestamp: DateTime.now(),
        messageType: data['message_type']?.toString() ?? 'text',
        mediaUrl: data['media_url']?.toString() ?? '',
        thumbnailUrl: data['thumbnail_url']?.toString() ?? '',
        fileName: data['file_name']?.toString(),
        duration: data['duration'] is int ? data['duration'] as int : int.tryParse(data['duration']?.toString() ?? ''),
      );

      // Also save directly using this chat's local key to ensure it persists
      // (FcmChatSaver may save under a different key when fromInbox is true)
      _saveMessageToLocalDb(msg, content, msg.messageType);

      setState(() => _messages.add(msg));
      _scrollToBottom();
      _sendMarkRead();

      // Reset unread since we're viewing this chat
      if (_localDbInitialized) {
        try {
          _chatRepo.resetUnreadCount(_localChatPhone);
        } catch (e) {
          print('📦 LocalDB reset unread error: $e');
        }
      }
    }
  }

  void _handleAck(Map<String, dynamic> event) {
    final data = event['data'] ?? event;
    final clientUuid = data['client_uuid']?.toString();
    final serverMsgId = data['message_id']?.toString();
    final ackStatus = data['status']?.toString() ?? 'sent';
    if (mounted) {
      setState(() {
        _isSending = false;
        if (clientUuid != null) {
          final idx = _messages.indexWhere((m) => m.id == clientUuid);
          if (idx != -1) {
            _messages[idx].status = ackStatus;
            if (serverMsgId != null) _messages[idx].serverId = serverMsgId;
          }
        }
      });

      // Update local DB
      if (_localDbInitialized && clientUuid != null) {
        try {
          _msgRepo.getMessageByClientUuid(clientUuid).then((localMsg) {
            if (localMsg != null && localMsg.id != null) {
              _msgRepo.updateMessageStatus(localMsg.id!, ackStatus);
              if (serverMsgId != null) {
                _msgRepo.updateServerMessageId(localMsg.id!, serverMsgId);
              }
            }
          });
        } catch (e) {
          print('📦 LocalDB ack update error: $e');
        }
      }
    }
  }

  void _handleTyping(Map<String, dynamic> event) {
    final data = event['data'] ?? event;
    final senderId = data['sender_id']?.toString();
    if (senderId == widget.friendId && mounted) {
      setState(() => _isTyping = true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isTyping = false);
      });
    }
  }

  void _handleVoiceRecording(Map<String, dynamic> event, bool isRecording) {
    final data = event['data'] ?? event;
    final senderId = data['sender_id']?.toString();
    print('🎙️ Voice Recording: Received event - isRecording=$isRecording, senderId=$senderId, friendId=${widget.friendId}');
    if (senderId == widget.friendId && mounted) {
      print('🎙️ Voice Recording: Setting _isVoiceRecording=$isRecording');
      setState(() => _isVoiceRecording = isRecording);
      _voiceRecordingTimer?.cancel();
      if (isRecording) {
        _voiceRecordingTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            print('🎙️ Voice Recording: Auto-clearing after 5 seconds');
            setState(() => _isVoiceRecording = false);
          }
        });
      }
    } else {
      print('🎙️ Voice Recording: Ignoring - senderId=$senderId does not match friendId=${widget.friendId}');
    }
  }

  void _handleStatusUpdate(Map<String, dynamic> event, String status) {
    if (mounted) {
      setState(() {
        for (var msg in _messages) {
          if (msg.isUser) {
            if (status == 'read') {
              msg.status = 'read';
            } else if (status == 'delivered' && msg.status != 'read') {
              msg.status = 'delivered';
            }
          }
        }
      });

      // Update local DB for sent messages
      if (_localDbInitialized) {
        final data = event['data'] ?? event;
        final serverMsgId = data['message_id']?.toString();
        if (serverMsgId != null) {
          _msgRepo.getMessageByServerId(serverMsgId).then((localMsg) {
            if (localMsg != null && localMsg.id != null) {
              _msgRepo.updateMessageStatusByServerId(serverMsgId, status);
            }
          });
        }
      }
    }
  }

  // ── Send text message ────────────────────────────────────────────────────

  void _sendMessage() {
    final text = _controller.text.trim();
    print('🔌 ChatWS: _sendMessage called, text="$text", _isConnected=$_isConnected, _channel=${_channel != null}');
    if (text.isEmpty) {
      print('🔌 ChatWS: _sendMessage cancelled - empty text');
      return;
    }

    final clientUuid = DateTime.now().microsecondsSinceEpoch.toString();
    print('🔌 ChatWS: _sendMessage sending uuid=$clientUuid');

    final isSelfChat = _isSelfChat;
    final status = isSelfChat ? 'read' : 'sending';

    final msg = _ChatMessage(id: clientUuid, text: text, isUser: true, timestamp: DateTime.now(), status: status);
    setState(() {
      _messages.add(msg);
      _isSending = true;
      _hasText = false;
    });
    _controller.clear();
    _scrollToBottom();

    // Save to local DB (fire & forget)
    _saveMessageToLocalDb(msg, text, 'text');

    if (isSelfChat) {
      setState(() {
        _isSending = false;
      });
      return;
    }

    if (_channel != null && _isConnected) {
      final payload = {
        'action': 'send_message',
        'recipient_id': widget.friendId,
        'content': text,
        'client_uuid': clientUuid,
      };
      print('🔌 ChatWS: _sendMessage payload: $payload');
      _channel!.sink.add(jsonEncode(payload));
      _startAckTimeout(clientUuid);
    } else {
      print('🔌 ChatWS: _sendMessage - WebSocket not connected, message queued for retry');
      // Don't start ACK timeout — message was never sent over the wire
      // MessageOutboxQueue will pick it up from local DB within 30s
      // _resendPendingMessages() will also pick it up on reconnect
      _connectWebSocket();
    }
  }

  void _startAckTimeout(String clientUuid, {bool failed = false}) {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        final idx = _messages.indexWhere((m) => m.id == clientUuid);
        if (idx != -1 && _messages[idx].status == 'sending') {
          final msg = _messages[idx];
          setState(() {
            _messages[idx].status = 'failed';
            _isSending = false;
          });
          // Auto-retry
          _retryMessage(msg);
        }
      }
    });
  }

  void _sendMediaMessage(String mediaUrl, String messageType, {String? fileName, String? caption, String? thumbnailUrl, int? duration, String? filePath}) {
    final clientUuid = DateTime.now().microsecondsSinceEpoch.toString();

    final isSelfChat = _isSelfChat;
    final status = isSelfChat ? 'read' : 'sending';

    final msg = _ChatMessage(
      id: clientUuid, text: caption ?? '', isUser: true, timestamp: DateTime.now(),
      status: status, messageType: messageType, mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl ?? '', fileName: fileName, duration: duration,
      filePath: filePath, downloaded: filePath != null && filePath.isNotEmpty,
    );
    setState(() {
      _messages.add(msg);
      _isSending = true;
    });
    _scrollToBottom();

    // Save to local DB
    _saveMessageToLocalDb(msg, caption ?? mediaUrl, messageType);

    if (isSelfChat) {
      setState(() {
        _isSending = false;
      });
      return;
    }

    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({
        'action': 'send_message',
        'recipient_id': widget.friendId,
        'content': caption ?? '',
        'message_type': messageType,
        'media_url': mediaUrl,
        'thumbnail_url': thumbnailUrl ?? '',
        'file_name': fileName ?? '',
        'client_uuid': clientUuid,
        if (duration != null) 'duration': duration,
      }));
      _startAckTimeout(clientUuid);
    }
  }

  // ── File/Image Attachment ────────────────────────────────────────────────

  void _pickImage() async {
    Navigator.pop(context);
    try {
      final List<XFile> picked = await _imagePicker.pickMultiImage(imageQuality: 70);
      for (final item in picked) {
        _addPendingMedia(File(item.path), 'image', fileName: p.basename(item.path));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Image pick failed: $e')));
    }
  }

  void _takePhoto() async {
    Navigator.pop(context);
    try {
      final XFile? picked = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 70);
      if (picked != null) _addPendingMedia(File(picked.path), 'image', fileName: p.basename(picked.path));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Camera failed: $e')));
    }
  }

  void _pickVideo() async {
    Navigator.pop(context);
    try {
      final List<XFile> picked = await _imagePicker.pickMultiVideo(); // videos only
      for (final item in picked) {
        final file = File(item.path);
        final size = await file.length();
        if (size > 50 * 1024 * 1024) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video too large. Max 50MB.'), backgroundColor: Colors.red));
          continue;
        }
        _addPendingMedia(file, 'video', fileName: p.basename(item.path));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Video pick failed: $e')));
    }
  }

  void _pickFile() async {
    Navigator.pop(context);
    try {
      final result = await FilePicker.pickFiles(allowMultiple: true);
      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.path != null) {
            String type = 'document';
            final ext = p.extension(file.name).toLowerCase();
            if (['.mp4', '.mov', '.avi', '.mkv'].contains(ext)) type = 'video';
            else if (['.mp3', '.wav', '.ogg', '.m4a', '.aac'].contains(ext)) type = 'voice';
            _addPendingMedia(File(file.path!), type, fileName: file.name);
          }
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File pick failed: $e')));
    }
  }

  void _addPendingMedia(File file, String type, {required String fileName}) {
    final size = file.lengthSync();
    setState(() {
      _pendingMedia.add(_PendingMedia(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        file: file,
        type: type,
        fileName: fileName,
        fileSize: size,
      ));
    });
  }

  void _removePendingMedia(String id) {
    setState(() {
      _pendingMedia.removeWhere((m) => m.id == id);
    });
  }

  Future<void> _sendPendingMedia() async {
    final description = _mediaDescriptionController.text.trim();
    _mediaDescriptionController.clear();

    for (final media in _pendingMedia) {
      if (media.type == 'video' && media.fileSize > 5 * 1024 * 1024) {
        await _uploadVideoChunked(media.file, media.fileName, media.fileSize, caption: description);
      } else {
        await _uploadAndSend(media.file, media.type, fileName: media.fileName, caption: description);
      }
    }

    setState(() {
      _pendingMedia.clear();
    });
  }

  // ── Video Chunk Upload ────────────────────────────────────────────────

  Future<void> _uploadVideoChunked(File file, String fileName, int fileSize, {String? caption}) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final clientUuid = DateTime.now().microsecondsSinceEpoch.toString();

      // Save to local DB before upload
      int? dbId;
      if (_localDbInitialized) {
        try {
          await _chatRepo.getOrCreateChat(_localChatPhone, contactName: widget.friendName, peerUserId: _currentUserPeerId);
          final msg = _ChatMessage(
            id: clientUuid, text: caption ?? '', isUser: true, timestamp: DateTime.now(),
            status: 'sending', messageType: 'video', mediaUrl: '', fileName: fileName,
            filePath: file.path, fileSize: fileSize,
          );
          final localMsg = _chatMsgToLocal(msg);
          dbId = await _msgRepo.insertMessage(localMsg);
          await _chatRepo.updateLastMessage(_localChatPhone, caption ?? '', 'video');
          print('📦 LocalDB: saved video pre-upload [id=$dbId] clientUuid=$clientUuid');
        } catch (e) {
          print('📦 LocalDB video pre-upload save error: $e');
        }
      }

      setState(() {
        _messages.add(_ChatMessage(
          id: clientUuid, text: '', isUser: true, timestamp: DateTime.now(),
          status: 'sending', messageType: 'video', mediaUrl: '', fileName: fileName,
          uploadProgress: 0, filePath: file.path, fileSize: fileSize,
        ));
        _isSending = true;
      });
      _scrollToBottom();

      // Init session
      final initResp = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/chat/chunk/init?file_name=$fileName&file_size=$fileSize&message_type=video'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (initResp.statusCode != 200) {
        _markMessageFailed(clientUuid);
        return;
      }

      final initData = jsonDecode(initResp.body);
      final sessionId = initData['session_id'];
      final chunkSize = initData['chunk_size'];
      final totalChunks = initData['total_chunks'];

      if (mounted) {
        final idx = _messages.indexWhere((m) => m.id == clientUuid);
        if (idx != -1) setState(() => _messages[idx].sessionId = sessionId);
      }

      await _uploadChunksWithResume(clientUuid, sessionId, file, chunkSize, totalChunks, token, caption: caption, dbId: dbId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Video upload failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _uploadChunksWithResume(
    String clientUuid, 
    String sessionId, 
    File file, 
    int chunkSize, 
    int totalChunks, 
    String token, 
    {String? caption, int? dbId}
) async {
    final bytes = await file.readAsBytes();

    for (int i = 0; i < totalChunks; i++) {
      // Check if chunk already uploaded
      final checkResp = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/chat/chunk/$sessionId/status'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (checkResp.statusCode == 200) {
        final statusData = jsonDecode(checkResp.body);
        final received = List<int>.from(statusData['received_chunks'] ?? []);
        if (received.contains(i)) {
          final progress = ((i + 1) / totalChunks * 100).round();
          if (mounted) {
            final idx = _messages.indexWhere((m) => m.id == clientUuid);
            if (idx != -1) setState(() => _messages[idx].uploadProgress = progress);
          }
          continue;
        }
      }

      final start = i * chunkSize;
      final end = (start + chunkSize).clamp(0, bytes.length);
      final chunkBytes = bytes.sublist(start, end);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${StarlightConstants.apiBaseUrl}/chat/chunk/$sessionId/$i'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes('file', chunkBytes, filename: 'chunk_$i'));

      final streamed = await request.send();
      if (streamed.statusCode != 200) {
        _markMessageFailed(clientUuid);
        return;
      }

      final progress = ((i + 1) / totalChunks * 100).round();
      if (mounted) {
        final idx = _messages.indexWhere((m) => m.id == clientUuid);
        if (idx != -1) setState(() => _messages[idx].uploadProgress = progress);
      }
    }

    // Complete
    final completeResp = await http.post(
      Uri.parse('${StarlightConstants.apiBaseUrl}/chat/chunk/$sessionId/complete'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (completeResp.statusCode == 200) {
      final completeData = jsonDecode(completeResp.body);
      final mediaUrl = completeData['media_url'] as String;
      final thumbnailUrl = completeData['thumbnail_url'] as String? ?? '';

      // Update local DB entry
      if (dbId != null) {
        try {
          await _msgRepo.updateMessageField(dbId, 'status', 'sent');
          await _msgRepo.updateMessageField(dbId, 'media_remote_url', mediaUrl);
          if (thumbnailUrl.isNotEmpty) {
            await _msgRepo.updateMessageField(dbId, 'media_thumbnail_path', thumbnailUrl);
          }
        } catch (e) {
          print('📦 LocalDB video update error: $e');
        }
      }

      // Keep temp message in UI (don't remove — _handleAck will update status later)
      final fileName = file.path.split('/').last;
      final isSelfChat = _isSelfChat;
      if (mounted) {
        final idx = _messages.indexWhere((m) => m.id == clientUuid);
        if (idx != -1) {
          setState(() {
            _messages[idx].uploadProgress = null;
            _messages[idx].mediaUrl = mediaUrl;
            _messages[idx].thumbnailUrl = thumbnailUrl;
            _messages[idx].status = isSelfChat ? 'read' : 'sent';
            _isSending = false;
          });
        }
      }

      if (!isSelfChat && _channel != null && _isConnected) {
        _channel!.sink.add(jsonEncode({
          'action': 'send_message',
          'recipient_id': widget.friendId,
          'content': caption ?? '',
          'message_type': 'video',
          'media_url': mediaUrl,
          'thumbnail_url': thumbnailUrl,
          'file_name': fileName,
          'client_uuid': clientUuid,
        }));
        _startAckTimeout(clientUuid);
      }
    } else {
      _markMessageFailed(clientUuid);
    }
  }

  Future<void> _retryUpload(_ChatMessage msg) async {
    if (msg.filePath == null) return;
    final file = File(msg.filePath!);
    if (!await file.exists()) return;

    setState(() { msg.status = 'sending'; msg.uploadProgress = 0; _isSending = true; });

    if (msg.sessionId != null) {
      // Resume from existing session
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final statusResp = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/chat/chunk/${msg.sessionId}/status'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (statusResp.statusCode == 200) {
        final statusData = jsonDecode(statusResp.body);
        await _uploadChunksWithResume(
          msg.id, msg.sessionId!, file,
          statusData['chunk_size'], statusData['total_chunks'], token,
        );
        return;
      }
    }

    // Start fresh
    final fileSize = msg.fileSize ?? await file.length();
    await _uploadVideoChunked(file, msg.fileName ?? 'video.mp4', fileSize, caption: msg.text);
  }

  void _markMessageFailed(String clientUuid) {
    if (mounted) {
      final idx = _messages.indexWhere((m) => m.id == clientUuid);
      if (idx != -1) setState(() { _messages[idx].status = 'failed'; _isSending = false; });
    }
    // Update local DB status to failed
    if (_localDbInitialized) {
      try {
        _msgRepo.getMessageByClientUuid(clientUuid).then((localMsg) {
          if (localMsg != null && localMsg.id != null) {
            _msgRepo.updateMessageStatus(localMsg.id!, 'failed');
            print('📦 LocalDB: marked failed clientUuid=$clientUuid id=${localMsg.id}');
          }
        });
      } catch (e) {
        print('📦 LocalDB mark failed error: $e');
      }
    }
  }

  final Map<String, http.Client> _activeUploads = {};

  Future<void> _uploadAndSend(File file, String messageType, {String? fileName, String? caption, int? duration, String? replaceClientUuid}) async {
    final clientUuid = replaceClientUuid ?? DateTime.now().microsecondsSinceEpoch.toString();
    final name = fileName ?? p.basename(file.path);

    // Save to local DB before upload (so failed messages survive reload)
    int? dbId;
    if (_localDbInitialized && replaceClientUuid == null) {
      try {
        await _chatRepo.getOrCreateChat(_localChatPhone, contactName: widget.friendName, peerUserId: _currentUserPeerId);
        final msg = _ChatMessage(
          id: clientUuid, text: caption ?? '', isUser: true, timestamp: DateTime.now(),
          status: 'sending', messageType: messageType, mediaUrl: '', fileName: name,
          filePath: file.path, duration: duration,
        );
        var localMsg = _chatMsgToLocal(msg);
        if (messageType == 'voice' && file.path.isNotEmpty) {
          try {
            if (await file.exists()) {
              final permanentPath = await ChatMediaStorage.instance.getSavePath('voice', name);
              await file.copy(permanentPath);
              localMsg = localMsg.copyWith(mediaLocalPath: permanentPath);
            }
          } catch (e) {
            print('📦 Voice file copy error: $e');
          }
        }
        dbId = await _msgRepo.insertMessage(localMsg);
        await _chatRepo.updateLastMessage(_localChatPhone, caption ?? '', messageType);
        print('📦 LocalDB: saved pre-upload [id=$dbId] clientUuid=$clientUuid');
      } catch (e) {
        print('📦 LocalDB pre-upload save error: $e');
      }
    } else if (_localDbInitialized && replaceClientUuid != null) {
      // Retry: update existing DB entry back to 'sending'
      try {
        final existing = await _msgRepo.getMessageByClientUuid(replaceClientUuid);
        if (existing != null && existing.id != null) {
          dbId = existing.id;
          await _msgRepo.updateMessageStatus(dbId!, 'sending');
          // Update the local media path in case file was re-recorded
          if (messageType == 'voice' && file.path.isNotEmpty) {
            try {
              if (await file.exists()) {
                final permanentPath = await ChatMediaStorage.instance.getSavePath('voice', name);
                await file.copy(permanentPath);
                await _msgRepo.updateMediaLocalPath(dbId!, permanentPath);
              }
            } catch (e) {
              print('📦 Voice file copy error on retry: $e');
            }
          }
          print('📦 LocalDB: retry reset clientUuid=$replaceClientUuid id=$dbId');
        }
      } catch (e) {
        print('📦 LocalDB retry reset error: $e');
      }
    }

    setState(() {
      _messages.add(_ChatMessage(
        id: clientUuid, text: '', isUser: true, timestamp: DateTime.now(),
        status: 'sending', messageType: messageType, mediaUrl: '', fileName: name,
        uploadProgress: 0, filePath: file.path, duration: duration,
      ));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) { _markMessageFailed(clientUuid); return; }

      final totalBytes = await file.length();
      final uri = Uri.parse('${StarlightConstants.apiBaseUrl}/chat/upload-media-by-user/${widget.friendId}?message_type=$messageType');

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      int sentBytes = 0;
      final trackedStream = file.openRead().transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
            sentBytes += data.length;
            final pct = (sentBytes / totalBytes * 100).round().clamp(0, 99);
            print('📤 ChatUpload: $name $pct% ($sentBytes/$totalBytes)');
            if (mounted) {
              final idx = _messages.indexWhere((m) => m.id == clientUuid);
              if (idx != -1) setState(() => _messages[idx].uploadProgress = pct);
            }
            sink.add(data);
          },
        ),
      );

      request.files.add(http.MultipartFile(
        'file', trackedStream, totalBytes, filename: name,
      ));

      final client = http.Client();
      _activeUploads[clientUuid] = client;

      print('📤 ChatUpload: Starting upload for $name ($totalBytes bytes)');
      final streamedResponse = await client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      _activeUploads.remove(clientUuid);

      print('📤 ChatUpload: Response ${response.statusCode} for $name');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final mediaUrl = data['media_url'] as String;
          final thumbnailUrl = data['thumbnail_url'] as String? ?? '';
          print('📤 ChatUpload: Success $name → $mediaUrl thumb=$thumbnailUrl');

          // Update local DB entry: sent status + media url
          if (dbId != null) {
            try {
              await _msgRepo.updateMessageField(dbId!, 'status', 'sent');
              await _msgRepo.updateMessageField(dbId!, 'media_remote_url', mediaUrl);
            } catch (e) {
              print('📦 LocalDB update on success error: $e');
            }
          }

          // Keep temp message in UI (don't remove — _handleAck will update status to 'sent' later)
          final isSelfChat = _isSelfChat;
          if (mounted) {
            final idx = _messages.indexWhere((m) => m.id == clientUuid);
            if (idx != -1) {
              setState(() {
                _messages[idx].uploadProgress = null;
                _messages[idx].mediaUrl = mediaUrl;
                _messages[idx].thumbnailUrl = thumbnailUrl;
                _messages[idx].status = isSelfChat ? 'read' : 'sent';
                _isSending = false;
              });
            }
          }

          if (!isSelfChat && _channel != null && _isConnected) {
            _channel!.sink.add(jsonEncode({
              'action': 'send_message',
              'recipient_id': widget.friendId,
              'content': caption ?? '',
              'message_type': messageType,
              'media_url': mediaUrl,
              'thumbnail_url': thumbnailUrl,
              'file_name': name,
              'client_uuid': clientUuid,
              if (duration != null) 'duration': duration,
            }));
            _startAckTimeout(clientUuid);
          }
      } else {
        print('📤 ChatUpload: Failed $name → ${response.body}');
        _markMessageFailed(clientUuid);
      }
    } catch (e) {
      print('📤 ChatUpload: Error $name → $e');
      _activeUploads.remove(clientUuid);
      _markMessageFailed(clientUuid);
    }
  }

Future<void> _retryMediaUpload(_ChatMessage msg) async {
    if (msg.filePath == null) return;
    final file = File(msg.filePath!);
    if (!await file.exists()) return;

    setState(() { msg.status = 'sending'; msg.uploadProgress = 0; _isSending = true; });

    final caption = msg.text; // preserve caption on retry
    if (msg.messageType == 'video' && (msg.fileSize ?? 0) > 5 * 1024 * 1024) {
      await _uploadVideoChunked(file, msg.fileName ?? 'video.mp4', msg.fileSize!, caption: caption);
    } else {
      await _uploadAndSend(file, msg.messageType, fileName: msg.fileName, caption: caption, replaceClientUuid: msg.id);
    }
  }

  // ── Voice Recording ──────────────────────────────────────────────────────

  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (status.isPermanentlyDenied) {
      openAppSettings();
      return false;
    }
    return status.isGranted;
  }

  void _toggleRecording() async {
    if (_isRecording) {
      _stopRecording();
    } else {
      if (!await _requestMicPermission()) return;
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      setState(() {
        _isRecording = true;
        _isCancelled = false;
        _recordStartTime = DateTime.now();
        _recordSeconds = 0;
      });
      _sendRecordingStatus(true);
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _recordSeconds++);
      });
    }
  }

  void _cancelUpload(String clientUuid) {
    final client = _activeUploads.remove(clientUuid);
    client?.close();
    if (mounted) {
      final idx = _messages.indexWhere((m) => m.id == clientUuid);
      if (idx != -1) setState(() { _messages[idx].status = 'failed'; });
    }
  }

  void _stopRecording() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    setState(() => _isRecording = false);
    _sendRecordingStatus(false);

    if (_isCancelled || path == null) return;
    if (_recordSeconds < 1) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording too short'), duration: Duration(seconds: 1)));
      return;
    }
    final voiceFileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _uploadAndSend(File(path), 'voice', fileName: voiceFileName, duration: _recordSeconds);
  }

  void _cancelRecording() {
    setState(() => _isCancelled = true);
    _stopRecording();
  }

  String _formatRecordTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _sendTyping() {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({'action': 'typing', 'recipient_id': widget.friendId}));
    }
  }

  void _sendRecordingStatus(bool isRecording) {
    print('🎙️ Voice Recording: Sending status - isRecording=$isRecording, recipient_id=${widget.friendId}, sender_id=$_currentUserId');
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({
        'action': isRecording ? 'recording' : 'stop_recording',
        'recipient_id': widget.friendId,
        'sender_id': _currentUserId,
      }));
    } else {
      // Queue recording status if not connected
      print('🎙️ Voice Recording: Socket not connected, status queued');
    }
  }

  Future<void> _startCall(String callType) async {
    if (_channel == null || !_isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call unavailable - not connected to server')),
        );
      }
      return;
    }

    final type = callType == 'video' ? CallType.video : CallType.voice;

    // Set the send channel to use this chat screen's WebSocket
    CallSignalingService.instance.setSendViaChatChannel((json) async {
      if (_channel != null && _isConnected) {
        print('📞 Call: Sending via chat WebSocket channel');
        _channel!.sink.add(json);
      } else {
        print('📞 Call: Chat WebSocket not connected, attempting EnhancedSocketService');
        try {
          EnhancedSocketService.sendRawMessage(json);
        } catch (e) {
          print('📞 Call: EnhancedSocketService failed - $e');
        }
      }
    });

    try {
      await CallSignalingService.instance.startCall(
        peerUserId: widget.friendId,
        peerPhone: '',
        peerName: widget.friendName ?? '',
        peerAvatar: widget.friendProfilePicture ?? '',
        type: type,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call failed: $e')),
        );
      }
    }
  }

  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedMessages.clear();
    });
  }

  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessages.contains(messageId)) {
        _selectedMessages.remove(messageId);
        if (_selectedMessages.isEmpty) _selectionMode = false;
      } else {
        _selectedMessages.add(messageId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedMessages.clear();
    });
  }

  void _deleteSelectedMessages() {
    final toDelete = _messages.where((m) => _selectedMessages.contains(m.id)).toList();
    for (final msg in toDelete) {
      _deleteMessage(msg);
    }
    _exitSelectionMode();
  }

  void _shareSelectedMessages() {
    final selected = _messages.where((m) => _selectedMessages.contains(m.id) && m.filePath != null).toList();
    _exitSelectionMode();
    if (selected.length == 1) {
      Share.shareXFiles([XFile(selected.first.filePath!)], text: 'Shared from Starlight');
    } else if (selected.isNotEmpty) {
      Share.shareXFiles(selected.map((m) => XFile(m.filePath!)).toList(), text: 'Shared from Starlight');
    }
  }

  void _showMediaSelectionSheet(List<_ChatMessage> mediaMessages) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MediaSelectionSheet(
        mediaMessages: mediaMessages,
        onDelete: _deleteMessage,
      ),
    );
  }

  void _deleteMessage(_ChatMessage msg) async {
    setState(() => _messages.removeWhere((m) => m.id == msg.id));

    if (_localDbInitialized) {
      try {
        final localMsg = await _msgRepo.getMessageByClientUuid(msg.id);
        if (localMsg != null && localMsg.id != null) {
          // Delete local media files
          await ChatMediaStorage.instance.deleteMediaForMessage(
            mediaPath: localMsg.mediaLocalPath.isNotEmpty ? localMsg.mediaLocalPath : null,
            thumbnailPath: localMsg.mediaThumbnailPath.isNotEmpty ? localMsg.mediaThumbnailPath : null,
          );
          await _msgRepo.softDeleteMessage(localMsg.id!);
        }
      } catch (_) {}
    }
  }

  void _deleteLocalMessage(_ChatMessage msg) async {
    setState(() => _messages.removeWhere((m) => m.id == msg.id));
    if (_localDbInitialized) {
      try {
        final localMsg = await _msgRepo.getMessageByClientUuid(msg.id);
        if (localMsg != null && localMsg.id != null) {
          // Delete local media files
          await ChatMediaStorage.instance.deleteMediaForMessage(
            mediaPath: localMsg.mediaLocalPath.isNotEmpty ? localMsg.mediaLocalPath : null,
            thumbnailPath: localMsg.mediaThumbnailPath.isNotEmpty ? localMsg.mediaThumbnailPath : null,
          );
          await _msgRepo.softDeleteMessage(localMsg.id!);
        }
      } catch (_) {}
    }
  }

  Future<void> _downloadMedia(_ChatMessage msg) async {
    if (msg.mediaUrl.isEmpty) return;
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;
      final url = '${StarlightConstants.apiBaseUrl}${msg.mediaUrl}';

      // Get save path
      final mediaStorage = ChatMediaStorage.instance;
      final fname = msg.fileName ?? 'file';
      String savePath;
      if (msg.messageType == 'image') {
        savePath = await mediaStorage.getSavePath('image', fname);
      } else if (msg.messageType == 'video') {
        savePath = await mediaStorage.getSavePath('video', fname);
      } else if (msg.messageType == 'voice') {
        savePath = await mediaStorage.getSavePath('voice', fname);
      } else {
        savePath = await mediaStorage.getSavePath('document', fname);
      }

      // Set downloading state
      if (mounted) {
        setState(() {
          msg.downloading = true;
        });
      }

      // Download file directly
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);

        // Update message state
        if (mounted) {
          setState(() {
            msg.filePath = savePath;
            msg.downloaded = true;
            msg.downloading = false;
          });
        }

        // Update local DB with the saved path
        if (_localDbInitialized) {
          try {
            final localMsg = await _msgRepo.getMessageByClientUuid(msg.id);
            if (localMsg != null && localMsg.id != null) {
              await _msgRepo.updateMediaLocalPath(localMsg.id!, savePath);
            }
          } catch (_) {}
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Downloaded'), backgroundColor: Colors.green),
          );
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Download error: $e');
      if (mounted) {
        setState(() {
          msg.downloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _downloadVoiceForPlay(_ChatMessage msg) async {
    if (msg.mediaUrl.isEmpty) return null;
    if (msg.filePath != null) {
      final f = File(msg.filePath!);
      if (await f.exists()) return msg.filePath;
    }
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return null;
      final url = '${StarlightConstants.apiBaseUrl}${msg.mediaUrl}';
      final mediaStorage = ChatMediaStorage.instance;
      final savePath = await mediaStorage.getSavePath('voice', msg.fileName ?? 'voice.m4a');
      final response = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        await File(savePath).writeAsBytes(response.bodyBytes);
        if (mounted) {
          setState(() {
            msg.filePath = savePath;
            msg.downloaded = true;
          });
        }
        if (_localDbInitialized) {
          try {
            final localMsg = await _msgRepo.getMessageByClientUuid(msg.id);
            if (localMsg != null && localMsg.id != null) {
              await _msgRepo.updateMediaLocalPath(localMsg.id!, savePath);
            }
          } catch (_) {}
        }
        return savePath;
      }
    } catch (e) {
      print('Voice download error: $e');
    }
    return null;
  }

  void _openMediaFromContext(String url) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = url.split('/').last;
      final localFile = File('${tempDir.path}/$fileName');

      if (!await localFile.exists()) {
        final token = await StarlightStorage.getUserToken();
        final response = await http.get(
          Uri.parse(url),
          headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        );
        if (response.statusCode == 200) {
          await localFile.writeAsBytes(response.bodyBytes);
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: ${response.statusCode}')));
          return;
        }
      }

      final isVideo = fileName.endsWith('.mp4') || fileName.endsWith('.mov') ||
          fileName.endsWith('.mkv') || fileName.endsWith('.webm') ||
          fileName.endsWith('.m4v') || fileName.endsWith('.3gp');

      if (isVideo && mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _VideoPlayerScreen(videoPath: localFile.path),
        ));
        return;
      }

      final result = await OpenFile.open(localFile.path);
      print('📂 Open media: ${result.type} - ${result.message}');
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot open: ${result.message}')));
      }
    } catch (e) {
      print('📂 Open media: Error - $e');
    }
  }

  void _showMessageOptions(BuildContext context, _ChatMessage msg, Offset position) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Material(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (msg.status == 'failed')
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Retry'),
                  onTap: () { Navigator.pop(ctx); _retryMessage(msg); },
                ),
              if (msg.isUser)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete', style: TextStyle(color: Colors.red)),
                  onTap: () { Navigator.pop(ctx); _deleteMessage(msg); },
                ),
              if (!msg.isUser)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete for me', style: TextStyle(color: Colors.red)),
                  onTap: () { Navigator.pop(ctx); _deleteLocalMessage(msg); },
                ),
              if (!msg.isUser && msg.messageType != 'text')
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Save to device'),
                  onTap: () { Navigator.pop(ctx); _openMediaFromContext('${StarlightConstants.apiBaseUrl}${msg.mediaUrl}'); },
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChatOptions(BuildContext context) {
    final isBlockedByMe = blockService.haveIBlocked(widget.friendId);
    
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Material(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBlockedByMe)
                ListTile(
                  leading: const Icon(Icons.lock_open, color: Colors.green),
                  title: const Text('Unblock User'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _unblockUser();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_sweep, color: Colors.red),
                title: const Text('Clear Chat'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear Chat'),
                      content: const Text('Delete all messages in this chat?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Clear', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true) return;

                  setState(() => _messages.clear());

                  if (_localDbInitialized) {
                    try {
                      await _msgRepo.deleteMessagesByPhone(_localChatPhone);
                    } catch (_) {}
                  }

                  try {
                    final token = await StarlightStorage.getUserToken();
                    if (token == null) return;
                    await http.delete(
                      Uri.parse('${StarlightConstants.apiBaseUrl}/chat/clear-chat/${widget.friendId}'),
                      headers: {'Authorization': 'Bearer $token'},
                    );
                  } catch (e) {
                    print('Clear chat server error: $e');
                  }

                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat cleared')));
                },
              ),
              if (!widget.fromInbox) ...[
                if (!isBlockedByMe)
                  ListTile(
                    leading: const Icon(Icons.block, color: Colors.red),
                    title: const Text('Block User'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _blockUser();
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.share, color: StarlightTheme.primaryBlue),
                  title: const Text('Share Contact'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showShareContactInChat();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _unblockUser() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unblock user?'),
        content: Text('Do you want to unblock ${widget.friendName ?? ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await blockService.unblockUser(widget.friendId);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User unblocked')),
                );
                setState(() {});
              }
            },
            child: Text('Unblock', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showShareContactPicker() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/friend-requests/friends'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) return;

      final List friends = jsonDecode(response.body);
      final selected = <String>{};

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Share Contact'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: friends.length,
                itemBuilder: (_, i) {
                  final f = friends[i];
                  final fid = f['id']?.toString() ?? '';
                  final fname = f['name']?.toString() ?? f['display_name']?.toString() ?? fid;
                  final isSelected = selected.contains(fid);
                  return CheckboxListTile(
                    value: isSelected,
                    title: Text(fname),
                    onChanged: (v) {
                      setDialogState(() {
                        if (v == true) {
                          selected.add(fid);
                        } else {
                          selected.remove(fid);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: selected.isEmpty ? null : () {
                  Navigator.pop(ctx);
                  for (final fid in selected) {
                    final friend = friends.firstWhere((f) => f['id']?.toString() == fid, orElse: () => friends[0]);
                    _sendContactMessage(fid, friend['name']?.toString() ?? fid);
                  }
                },
                child: const Text('Send'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('Share contact error: $e');
    }
  }

  String _formatLinksInMessage(String text) {
    if (text.isEmpty) return text;
    
    final urlRegex = RegExp(r'(?<=\s|^)https?:\/\/[^\s]+', multiLine: true);
    final wwwRegex = RegExp(r'(?<=\s|^)www\.[^\s]+', multiLine: true);
    final emailRegex = RegExp(r'(?<![\w])[_\w.]+@[\w.]+\.[a-zA-Z]{2,}(?=[\s]|$)', multiLine: true);
    
    String result = text;
    
    for (final match in urlRegex.allMatches(text)) {
      final url = match.group(0)!;
      final start = match.start;
      final end = match.end;
      final formatted = '<a href="$url" style="color: #2196F3; text-decoration: underline; font-weight: 600">$url</a>';
      result = result.replaceRange(start, end, formatted);
    }
    
    for (final match in wwwRegex.allMatches(result)) {
      final url = match.group(0)!;
      final start = match.start;
      final end = match.end;
      final formatted = '<a href="https://$url" style="color: #2196F3; text-decoration: underline; font-weight: 600">$url</a>';
      result = result.replaceRange(start, end, formatted);
    }
    
    for (final match in emailRegex.allMatches(result)) {
      final email = match.group(0)!;
      final start = match.start;
      final end = match.end;
      final formatted = '<a href="mailto:$email" style="color: #2196F3; text-decoration: underline; font-weight: 600">$email</a>';
      result = result.replaceRange(start, end, formatted);
    }
    
    return result;
  }

  String _formatMessageForDisplay(String text, {bool isUser = false}) {
    String formatted = _formatLinksInMessage(text);
    return formatted;
  }

  void _showShareContactInChat() async {
    try {
      final chatRepository = ChatRepository();
      final chats = await chatRepository.getAllChats(includeArchived: true);
      
      if (!mounted) return;
      
      if (chats.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No contacts available to share')),
        );
        return;
      }
      
      final selectedContacts = <LocalChat>{};
      String searchQuery = '';
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheetState) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (ctx, scrollController) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Share Contact',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        onChanged: (value) {
                          setSheetState(() => searchQuery = value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by name or phone',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setSheetState(() => searchQuery = '');
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
                    ],
                  ),
                ),
                if (selectedContacts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          '${selectedContacts.length} selected',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setSheetState(() => selectedContacts.clear());
                          },
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: chats.where((c) {
                      if (searchQuery.isEmpty) return true;
                      final q = searchQuery.toLowerCase();
                      return c.contactName.toLowerCase().contains(q) ||
                          c.phoneNumber.contains(searchQuery);
                    }).length,
                    itemBuilder: (context, index) {
                      final filteredChats = chats.where((c) {
                        if (searchQuery.isEmpty) return true;
                        final q = searchQuery.toLowerCase();
                        return c.contactName.toLowerCase().contains(q) ||
                            c.phoneNumber.contains(searchQuery);
                      }).toList();
                      
                      final contact = filteredChats[index];
                      final isSelected = selectedContacts.contains(contact);
                      final displayName = contact.contactName.isNotEmpty 
                          ? contact.contactName 
                          : contact.phoneNumber;
                      
                      return CheckboxListTile(
                        value: isSelected,
                        secondary: CircleAvatar(
                          backgroundColor: const Color(0xFF075E54),
                          child: Text(
                            displayName[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(displayName),
                        subtitle: Text(_formatPhoneNumber(contact.phoneNumber)),
                        onChanged: (value) {
                          setSheetState(() {
                            if (value == true) {
                              selectedContacts.add(contact);
                            } else {
                              selectedContacts.remove(contact);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                if (selectedContacts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          for (final contact in selectedContacts) {
                            _sendShareContactMessage(
                              contact.contactName,
                              contact.phoneNumber,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF075E54),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Send to ${widget.friendName ?? ''}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      print('Share contact in chat error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading contacts: $e')),
        );
      }
    }
  }

  void _sendShareContactMessage(String contactName, String contactPhone) {
    final clientUuid = DateTime.now().microsecondsSinceEpoch.toString();
    final content = jsonEncode({
      'name': contactName,
      'phone': contactPhone,
    });
    
    // Add to local messages immediately
    final msg = _ChatMessage(
      id: clientUuid,
      text: content,
      isUser: true,
      timestamp: DateTime.now(),
      status: 'sending',
      messageType: 'share_contact',
    );
    setState(() => _messages.add(msg));
    _scrollToBottom();
    
    // Save to local DB first
    _saveMessageToLocalDb(msg, content, 'share_contact');
    
    // Send via socket
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({
        'action': 'send_message',
        'recipient_id': widget.friendId,
        'content': content,
        'message_type': 'share_contact',
        'client_uuid': clientUuid,
      }));
    } else {
      // Mark as failed if not connected
      setState(() => msg.status = 'failed');
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

  void _sendContactMessage(String userId, String userName) {
    if (_channel != null && _isConnected) {
      final clientUuid = DateTime.now().microsecondsSinceEpoch.toString();
      final payload = {
        'action': 'send_message',
        'recipient_id': userId,
        'content': '👤 Contact: $userName',
        'message_type': 'contact',
        'client_uuid': clientUuid,
      };
      _channel!.sink.add(jsonEncode(payload));
      print('📤 ChatWS: contact message sent to $userName');
    }
  }

  void _blockUser() {
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
                  'Block ${widget.friendName ?? ''}?',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Select block duration:'),
            const SizedBox(height: 12),
            _blockDurationOption('1 hour', '1h'),
            _blockDurationOption('8 hours', '8h'),
            _blockDurationOption('24 hours', '24h'),
            _blockDurationOption('7 days', '7d'),
            _blockDurationOption('30 days', '30d'),
            _blockDurationOption('Forever', 'forever'),
          ],
        ),
      ),
    );
  }

  Widget _blockDurationOption(String label, String duration) {
    return ListTile(
      title: Text(label),
      leading: const Icon(Icons.timer_outlined),
      onTap: () async {
        Navigator.pop(context);
        final success = await blockService.blockUser(widget.friendId, duration);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User blocked for $label')),
          );
          Navigator.pop(context);
        }
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          if (_pendingMedia.isNotEmpty) _buildMediaPreviewBar(),
          _isRecording ? _buildRecordingBar() : _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_selectionMode) {
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF263238)),
          onPressed: _exitSelectionMode,
        ),
        title: Text('${_selectedMessages.length} selected', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF263238))),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFF263238)),
            onPressed: _selectedMessages.isNotEmpty ? _shareSelectedMessages : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _selectedMessages.isNotEmpty ? _deleteSelectedMessages : null,
          ),
        ],
      );
    }
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leadingWidth: 40,
      title: GestureDetector(
        onTap: widget.fromInbox ? null : () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContactProfileScreen(
                friendId: widget.friendId,
                friendName: widget.friendName ?? '',
                friendPhone: widget.friendPhone,
                friendProfilePicture: widget.friendProfilePicture,
              ),
            ),
          );
        },
        child: Row(
          children: [
            ProfileAvatar(
              userId: widget.friendId,
              name: widget.friendName ?? '',
              radius: 18,
              localImagePath: widget.friendProfilePicture,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.friendName ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: StarlightTheme.primaryBlue), overflow: TextOverflow.ellipsis, maxLines: 1),
                  Text(
                    _friendOnline ? 'Online' : (_lastSeen ?? 'Offline'),
                    style: TextStyle(fontSize: 11, color: _friendOnline ? Colors.green : Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!_isSelfChat) ...[
          IconButton(
            icon: const Icon(Icons.phone_outlined, color: StarlightTheme.primaryBlue),
            onPressed: () => _startCall('voice'),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: StarlightTheme.primaryBlue),
            onPressed: () => _startCall('video'),
          ),
        ],
        IconButton(icon: const Icon(Icons.more_vert, color: StarlightTheme.primaryBlue), onPressed: () => _showChatOptions(context)),
      ],
    );
  }

  // ── Media Clustering ────────────────────────────────────────────────────────

  List<_ChatMessage> _groupMediaMessages() {
    if (_messages.isEmpty) return [];
    if (_selectionMode) return List.from(_messages);

    final List<_ChatMessage> grouped = [];
    List<_ChatMessage> currentGroup = [];
    String? currentUserId;
    String? currentMediaType;

    for (final message in _messages) {
      if (message.messageType == 'image' || message.messageType == 'video') {
        final userId = message.isUser.toString();
        final mediaType = message.messageType;

        // Check if this continues the current group (same user, any media type)
        if (currentGroup.isNotEmpty &&
            currentUserId == userId) {
          currentGroup.add(message);
        } else {
          // End current group and start new one
          if (currentGroup.isNotEmpty) {
            grouped.addAll(currentGroup);
            currentGroup = [];
          }
          currentGroup.add(message);
          currentUserId = userId;
        }
      } else {
        // Non-media message - end group and add it
        if (currentGroup.isNotEmpty) {
          grouped.addAll(currentGroup);
          currentGroup = [];
        }
        grouped.add(message);
        currentUserId = null;
        currentMediaType = null;
      }
    }

    if (currentGroup.isNotEmpty) {
      grouped.addAll(currentGroup);
    }

    return grouped;
  }

  bool _isMediaClusterStart(int index, List<_ChatMessage> messages) {
    if (index >= messages.length) return false;
    final msg = messages[index];
    if (msg.messageType != 'image' && msg.messageType != 'video') return false;
    if (index == 0) return true;
    final prev = messages[index - 1];
    return prev.isUser != msg.isUser || (prev.messageType != 'image' && prev.messageType != 'video');
  }

  int _findMediaClusterEnd(int index, List<_ChatMessage> messages) {
    if (index >= messages.length) return index + 1;
    final startMsg = messages[index];
    final userId = startMsg.isUser.toString();
    int endIndex = index + 1;
    while (endIndex < messages.length) {
      final msg = messages[endIndex];
      if (msg.messageType == 'image' || msg.messageType == 'video') {
        if (msg.isUser.toString() == userId) {
          endIndex++;
          continue;
        } else {
          break;
        }
      } else {
        break;
      }
    }
    return endIndex;
  }

  Widget _buildMediaCluster(List<_ChatMessage> mediaMessages, DateTime timestamp, {bool isUser = false, bool isScrollable = false}) {
    final hasMultipleItems = mediaMessages.length > 1;
    final firstMessage = mediaMessages.first;
    final isVideo = firstMessage.messageType == 'video';

    // Count images and videos in cluster
    final imageCount = mediaMessages.where((m) => m.messageType == 'image').length;
    final videoCount = mediaMessages.where((m) => m.messageType == 'video').length;

    final clusterWidget = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Icon(
                  imageCount > 0 && videoCount > 0 ? Icons.photo_library : (videoCount > 0 ? Icons.videocam : Icons.photo),
                  size: 16, color: StarlightTheme.primaryBlue),
                const SizedBox(width: 6),
                Text(
                  hasMultipleItems
                    ? '${mediaMessages.length} media'
                    : (videoCount > 0 ? 'Video' : 'Photo'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: StarlightTheme.primaryBlue),
                ),
                if (hasMultipleItems && (imageCount > 0 && videoCount > 0)) ...[
                  const SizedBox(width: 6),
                  Text(
                    '($imageCount ${imageCount == 1 ? 'photo' : 'photos'}, $videoCount ${videoCount == 1 ? 'video' : 'videos'})',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
                const Spacer(),
                if (hasMultipleItems)
                  TextButton(
                    onPressed: () => _showMediaCarousel(mediaMessages),
                    child: const Text('View all', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: isScrollable ? 140 : 140,
            child: GridView.builder(
              physics: isScrollable ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio: 1,
              ),
itemCount: isScrollable ? mediaMessages.length : (mediaMessages.length > 4 ? 4 : mediaMessages.length),
              itemBuilder: (context, index) {
                final media = mediaMessages[index];
                final isLast = index == mediaMessages.length - 1;
                final hasMore = mediaMessages.length > 4 && index == 3;

                // Helper to build media widget
                Widget buildMediaWidget(_ChatMessage media) {
                  bool showThumb = !media.isUser && !media.downloaded && media.thumbnailUrl.isNotEmpty;
                  if (media.messageType == 'video') {
                    if (showThumb) {
                      return Image.network(
                        '${StarlightConstants.apiBaseUrl}${media.thumbnailUrl}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade900,
                          child: const Center(child: Icon(Icons.videocam, color: Colors.grey, size: 28)),
                        ),
                      );
                    }
                    // For sent or downloaded videos, use local file if available
                    if (media.filePath != null && File(media.filePath!).existsSync()) {
                      // Generate thumbnail from local video file
                      final localVideoPath = media.filePath!;
                      return FutureBuilder<String?>(
                        future: () async {
                          final tempDir = await getTemporaryDirectory();
                          final thumbPath = '${tempDir.path}/thumb_${media.id}.jpg';
                          final thumbFile = File(thumbPath);
                          if (await thumbFile.exists()) return thumbPath;
                          return VideoThumbnail.thumbnailFile(
                            video: localVideoPath,
                            thumbnailPath: tempDir.path,
                            imageFormat: ImageFormat.JPEG,
                            quality: 75,
                            maxWidth: 200,
                            maxHeight: 200,
                          );
                        }(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            return Image.file(File(snapshot.data!), fit: BoxFit.cover);
                          }
                          return Container(
                            color: Colors.grey.shade100,
                            child: const Center(child: Icon(Icons.videocam, color: Colors.grey, size: 28)),
                          );
                        },
                      );
                    }
                    // Fallback: generate thumbnail from network URL
                    final videoUrl = '${StarlightConstants.apiBaseUrl}${media.mediaUrl}';
                    return FutureBuilder<String?>(
                      future: () async {
                        final tempDir = await getTemporaryDirectory();
                        return VideoThumbnail.thumbnailFile(
                          video: videoUrl,
                          thumbnailPath: tempDir.path,
                          imageFormat: ImageFormat.JPEG,
                          quality: 75,
                          maxWidth: 200,
                          maxHeight: 200,
                        );
                      }(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return Image.file(File(snapshot.data!), fit: BoxFit.cover);
                        }
                        return Container(
                          color: Colors.grey.shade100,
                          child: const Center(child: Icon(Icons.videocam, color: Colors.grey, size: 28)),
                        );
                      },
                    );
                  }
                  // Image
                  if (showThumb) {
                    return Image.network(
                      '${StarlightConstants.apiBaseUrl}${media.thumbnailUrl}',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, color: Colors.grey, size: 28),
                      ),
                    );
                  }
                  // For sent or downloaded images, use local file if available
                  if (media.filePath != null && File(media.filePath!).existsSync()) {
                    return Image.file(File(media.filePath!), fit: BoxFit.cover);
                  }
                  return Image.network(
                    '${StarlightConstants.apiBaseUrl}${media.mediaUrl}',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade100,
                      child: const Icon(Icons.broken_image, color: Colors.grey, size: 28),
                    ),
                  );
                }

                if (hasMore) {
                  return GestureDetector(
                    onTap: () => _showMediaCarousel(mediaMessages, initialPage: 3),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade100,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: buildMediaWidget(mediaMessages[3]),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.black.withOpacity(0.6),
                          ),
                          child: Center(
                            child: Text(
                              '+${mediaMessages.length - 4}',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return GestureDetector(
                  onTap: () => _showMediaCarousel(mediaMessages, initialPage: index),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade100,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: buildMediaWidget(media),
                        ),
                      ),
                      if (isLast && hasMultipleItems)
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Caption texts from media items
          ...mediaMessages.where((m) => m.text.isNotEmpty).map((m) => Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Text(
              m.text,
              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.3),
            ),
          )),
          if (mediaMessages.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatTimestamp(timestamp),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  if (firstMessage.status == 'sent')
                    const Icon(Icons.done, size: 14, color: StarlightTheme.primaryBlue),
                  if (firstMessage.status == 'delivered')
                    const Icon(Icons.done_all, size: 14, color: StarlightTheme.primaryBlue),
                  if (firstMessage.status == 'read')
                    const Icon(Icons.done_all, size: 14, color: StarlightTheme.primaryBlue),
                ],
              ),
            ),
        ],
      ),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: clusterWidget,
    );
  }

  void _showMediaCarousel(List<_ChatMessage> mediaMessages, {int initialPage = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              '${mediaMessages.length} ${mediaMessages.first.messageType == 'video' ? 'videos' : 'photos'}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          body: PageView.builder(
            controller: PageController(initialPage: initialPage),
            itemCount: mediaMessages.length,
              itemBuilder: (context, index) {
                final media = mediaMessages[index];
                final mediaType = media.messageType;
                return Center(
                  child: mediaType == 'image'
                    ? InteractiveViewer(
                        child: media.filePath != null
                          ? Image.file(File(media.filePath!), fit: BoxFit.contain)
                          : Image.network('${StarlightConstants.apiBaseUrl}${media.mediaUrl}'),
                      )
                    : Center(
                        child: IconButton(
                          iconSize: 80,
                          icon: const Icon(Icons.play_circle_fill, color: Colors.white),
                          onPressed: () async {
                            String videoPath = media.filePath ?? '';
                            // Use local file if available and exists
                            if (videoPath.isNotEmpty && await File(videoPath).exists()) {
                              if (context.mounted) {
                                Navigator.of(context).push(MaterialPageRoute(
                                  fullscreenDialog: true,
                                  builder: (_) => _VideoPlayerScreen(videoPath: videoPath),
                                ));
                              }
                              return;
                            }
                            // Download to temp if not available locally
                            final token = await StarlightStorage.getUserToken();
                            final url = '${StarlightConstants.apiBaseUrl}${media.mediaUrl}';
                            final tempDir = await getTemporaryDirectory();
                            final fileName = url.split('/').last;
                            final localFile = File('${tempDir.path}/$fileName');
                            if (!await localFile.exists()) {
                              final response = await http.get(
                                Uri.parse(url),
                                headers: token != null ? {'Authorization': 'Bearer $token'} : {},
                              );
                              if (response.statusCode == 200) {
                                await localFile.writeAsBytes(response.bodyBytes);
                              }
                            }
                            videoPath = localFile.path;
                            if (context.mounted) {
                              Navigator.of(context).push(MaterialPageRoute(
                                fullscreenDialog: true,
                                builder: (_) => _VideoPlayerScreen(videoPath: videoPath),
                              ));
                            }
                          },
                        ),
                      ),
                );
              },
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 2) {
      return difference.inDays == 1 ? 'Yesterday' : 'Today';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year % 100}';
    }
  }

  Widget _buildMessageList() {
    final List<_ChatMessage> processedMessages = _groupMediaMessages();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: processedMessages.length + (_isTyping || _isVoiceRecording ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == processedMessages.length && (_isTyping || _isVoiceRecording)) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              const SizedBox(width: 44),
              if (_isTyping && _isVoiceRecording) ...[
                const _TypingBubble(),
                const SizedBox(width: 8),
                const _VoiceRecordingBubble(),
              ] else if (_isTyping) ...[
                const _TypingBubble(),
              ] else ...[
                const _VoiceRecordingBubble(),
              ],
            ]),
          );
        }
        final msg = processedMessages[index];
        final showDate = index == 0 || !_isSameDay(processedMessages[index - 1].timestamp, msg.timestamp);

        // Check if this is the start of a media cluster
        final isMediaClusterStart = _isMediaClusterStart(index, processedMessages);
        if (isMediaClusterStart) {
          final endIndex = _findMediaClusterEnd(index, processedMessages);
          final clusterMessages = processedMessages.sublist(index, endIndex);

          // If only 1 media, render as normal individual bubble
          if (clusterMessages.length == 1) {
            final singleMsg = clusterMessages.first;
            final isSelected = _selectedMessages.contains(singleMsg.id);
            return Column(
              children: [
                if (showDate) _DateSeparator(date: singleMsg.timestamp),
                GestureDetector(
                  onTap: _selectionMode ? () => _toggleMessageSelection(singleMsg.id) : null,
                  onLongPress: () {
                    if (_selectionMode) {
                      _toggleMessageSelection(singleMsg.id);
                    } else {
                      _enterSelectionMode();
                      _toggleMessageSelection(singleMsg.id);
                    }
                  },
                  child: Stack(
                    children: [
                      _ChatBubble(
                        message: singleMsg,
                        onRetry: singleMsg.status == 'failed' ? () => _retryMessage(singleMsg) : null,
                        onCancel: (singleMsg.uploadProgress != null && singleMsg.uploadProgress! < 100) ? () => _cancelUpload(singleMsg.id) : null,
                        onDelete: (m) => _deleteMessage(m),
                        onLongPress: _selectionMode
                            ? (m, pos) => _toggleMessageSelection(singleMsg.id)
                            : (m, pos) => _showMessageOptions(context, m, pos),
                        onDownload: (singleMsg.mediaUrl.isNotEmpty && !singleMsg.isUser && !singleMsg.downloaded) ? () => _downloadMedia(singleMsg) : null,
                        onVoiceDownload: (singleMsg.messageType == 'voice' && singleMsg.mediaUrl.isNotEmpty && !singleMsg.downloaded)
                            ? () => _downloadVoiceForPlay(singleMsg)
                            : null,
                      ),
                      if (_selectionMode)
                        Positioned(
                          top: 8,
                          right: singleMsg.isUser ? 8 : null,
                          left: singleMsg.isUser ? null : 8,
                          child: Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF075E54) : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? const Color(0xFF075E54) : Colors.grey.shade400, width: 2),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }

          // 2-3 media: fixed grid box; >3: scrollable grid
          final clusterSelectedCount = clusterMessages.where((m) => _selectedMessages.contains(m.id)).length;
          final allClusterSelected = clusterSelectedCount == clusterMessages.length;
          final someClusterSelected = clusterSelectedCount > 0 && !allClusterSelected;

          return Column(
            children: [
              if (showDate) _DateSeparator(date: msg.timestamp),
              GestureDetector(
                onTap: _selectionMode
                    ? () {
                        if (allClusterSelected) {
                          for (final m in clusterMessages) _selectedMessages.remove(m.id);
                          if (_selectedMessages.isEmpty) _selectionMode = false;
                        } else {
                          for (final m in clusterMessages) _selectedMessages.add(m.id);
                        }
                        setState(() {});
                      }
                    : null,
                onLongPress: _selectionMode
                    ? () {
                        if (allClusterSelected) {
                          for (final m in clusterMessages) _selectedMessages.remove(m.id);
                          if (_selectedMessages.isEmpty) _selectionMode = false;
                        } else {
                          for (final m in clusterMessages) _selectedMessages.add(m.id);
                        }
                        setState(() {});
                      }
                    : () {
                        _showMediaSelectionSheet(clusterMessages);
                      },
                child: Stack(
                  children: [
                    _buildMediaCluster(clusterMessages, msg.timestamp, isUser: msg.isUser, isScrollable: clusterMessages.length > 3),
                    if (_selectionMode)
                      Positioned(
                        top: 4,
                        right: !msg.isUser ? 4 : null,
                        left: msg.isUser ? 4 : null,
                        child: Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: allClusterSelected ? const Color(0xFF075E54) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: allClusterSelected ? const Color(0xFF075E54) : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: allClusterSelected
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : someClusterSelected
                                  ? Icon(Icons.remove, size: 16, color: Colors.grey.shade600)
                                  : null,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        }

        // Skip messages that are part of a cluster (not the start)
        if (msg.messageType == 'image' || msg.messageType == 'video') {
          // Check if this message is part of a cluster that already started earlier
          if (index > 0) {
            final prevMsg = processedMessages[index - 1];
            // Skip any media message from same user that follows another media message (same or different type)
            if (prevMsg.isUser == msg.isUser && (prevMsg.messageType == 'image' || prevMsg.messageType == 'video')) {
              return const SizedBox.shrink(); // Skip - already rendered in cluster
            }
          }
        }

        final isSelected = _selectedMessages.contains(msg.id);
        return Column(
          children: [
            if (showDate) _DateSeparator(date: msg.timestamp),
            GestureDetector(
              onTap: _selectionMode ? () => _toggleMessageSelection(msg.id) : null,
              onLongPress: () {
                if (_selectionMode) {
                  _toggleMessageSelection(msg.id);
                } else {
                  _enterSelectionMode();
                  _toggleMessageSelection(msg.id);
                }
              },
              child: Stack(
                children: [
                  _ChatBubble(
                    message: msg,
                    onRetry: msg.status == 'failed' ? () => _retryMessage(msg) : null,
                    onCancel: (msg.uploadProgress != null && msg.uploadProgress! < 100) ? () => _cancelUpload(msg.id) : null,
                    onDelete: (m) => _deleteMessage(m),
                    onLongPress: _selectionMode
                        ? (m, pos) => _toggleMessageSelection(msg.id)
                        : (m, pos) => _showMessageOptions(context, m, pos),
                    onDownload: (msg.mediaUrl.isNotEmpty && !msg.isUser && !msg.downloaded) ? () => _downloadMedia(msg) : null,
                    onVoiceDownload: (msg.messageType == 'voice' && msg.mediaUrl.isNotEmpty && !msg.downloaded)
                        ? () => _downloadVoiceForPlay(msg)
                        : null,
                  ),
                  if (_selectionMode)
                    Positioned(
                      top: 8,
                      right: msg.isUser ? 8 : null,
                      left: msg.isUser ? null : 8,
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF075E54) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: isSelected ? const Color(0xFF075E54) : Colors.grey.shade400, width: 2),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
  void _retryMessage(_ChatMessage msg) {
    setState(() { msg.status = 'sending'; _isSending = true; });

    if (msg.messageType == 'video' && msg.filePath != null) {
      _retryUpload(msg);
      return;
    }

    if (msg.messageType != 'text' && msg.messageType != 'share_contact' && msg.filePath != null) {
      _retryMediaUpload(msg);
      return;
    }

    // Text or share_contact message retry
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({
        'action': 'send_message',
        'recipient_id': widget.friendId,
        'content': msg.text,
        'message_type': msg.messageType,
        'client_uuid': msg.id,
      }));
      _startAckTimeout(msg.id);
    } else {
      print('🔌 ChatWS: _retryMessage - WebSocket not connected, queued for retry');
      _connectWebSocket();
      // Don't start ACK timeout — let MessageOutboxQueue or _resendPendingMessages handle it
    }
  }

  void _resendPendingMessages() {
    if (!_isConnected || _channel == null) return;
    
    final pendingMessages = _messages.where((m) => 
      m.isUser && 
      (m.status == 'sending' || m.status == 'failed') &&
      m.messageType == 'text'
    ).toList();
    
    if (pendingMessages.isEmpty) return;
    
    print('📤 ChatWS: Resending ${pendingMessages.length} pending text messages');
    
    for (final msg in pendingMessages) {
      setState(() => msg.status = 'sending');
      
      _channel!.sink.add(jsonEncode({
        'action': 'send_message',
        'recipient_id': widget.friendId,
        'content': msg.text,
        'message_type': msg.messageType,
        'client_uuid': msg.id,
      }));
      
      _startAckTimeout(msg.id);
    }
  }

  Widget _buildMediaPreviewBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('${_pendingMedia.length} item${_pendingMedia.length > 1 ? 's' : ''} selected',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
              const Spacer(),
              TextButton.icon(
                onPressed: _sendPendingMedia,
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Send'),
                style: TextButton.styleFrom(foregroundColor: StarlightTheme.primaryBlue),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pendingMedia.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final media = _pendingMedia[index];
                return Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade100,
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: media.type == 'image'
                          ? Image.file(media.file, fit: BoxFit.cover, width: 80, height: 72)
                          : media.type == 'video'
                          ? FutureBuilder<String?>(
                              future: () async {
                                final tempDir = await getTemporaryDirectory();
                                return VideoThumbnail.thumbnailFile(
                                  video: media.file.path,
                                  thumbnailPath: tempDir.path,
                                  imageFormat: ImageFormat.JPEG,
                                  quality: 50,
                                  maxWidth: 160,
                                  maxHeight: 160,
                                );
                              }(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data != null) {
                                  return Image.file(File(snapshot.data!), fit: BoxFit.cover, width: 80, height: 72);
                                }
                                return Center(
                                  child: Icon(Icons.videocam, color: Colors.grey.shade400, size: 28),
                                );
                              },
                            )
                          : Center(
                              child: Icon(
                                media.type == 'voice' ? Icons.mic : Icons.insert_drive_file,
                                color: StarlightTheme.primaryBlue,
                                size: 28,
                              ),
                            ),
                    ),
                    Positioned(
                      top: 2, right: 2,
                      child: GestureDetector(
                        onTap: () => _removePendingMedia(media.id),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _mediaDescriptionController,
            decoration: InputDecoration(
              hintText: 'Add a caption...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true, fillColor: const Color(0xFFF4F7FE),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            maxLines: 2,
            minLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(8, 6, 8, 10 + bottomPad),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: _showAttachmentSheet,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: StarlightTheme.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.attach_file_rounded, color: StarlightTheme.primaryBlue, size: 20),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (val) {
                _sendTyping();
                final hasTextNow = val.trim().isNotEmpty;
                if (hasTextNow != _hasText) setState(() => _hasText = hasTextNow);
              },
              decoration: InputDecoration(
                hintText: "Type a message...",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                filled: true, fillColor: const Color(0xFFF4F7FE),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _sendMessage(),
              maxLines: 5, minLines: 1,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              if (_hasText) {
                print('🔌 ChatWS: Send button tapped');
                _sendMessage();
              } else {
                _toggleRecording();
              }
            },
            onLongPress: _hasText ? null : _toggleRecording,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red : StarlightTheme.primaryBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _hasText ? Icons.send_rounded : (_isRecording ? Icons.stop : Icons.mic),
                color: Colors.white, size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingBar() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 14 + bottomPad),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _cancelRecording,
            child: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
          ),
          const SizedBox(width: 12),
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(_formatRecordTime(_recordSeconds), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(color: StarlightTheme.primaryBlue, shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _attachmentOption(Icons.photo, 'Gallery', _pickImage),
                _attachmentOption(Icons.camera_alt, 'Camera', _takePhoto),
                _attachmentOption(Icons.videocam, 'Video', _pickVideo),
                _attachmentOption(Icons.insert_drive_file, 'File', _pickFile),
              ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: StarlightTheme.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: StarlightTheme.primaryBlue, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

// ── Message Model ─────────────────────────────────────────────────────────

class _ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  String status;
  String messageType;
  String mediaUrl;
  String thumbnailUrl;
  String? fileName;
  int? uploadProgress;
  String? sessionId;
  String? filePath;
  int? fileSize;
  bool? downloading;
  String? serverId;
  bool downloaded;
  int? duration;

  _ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.status = 'sent',
    this.messageType = 'text',
    this.mediaUrl = '',
    this.thumbnailUrl = '',
    this.fileName,
    this.uploadProgress,
    this.sessionId,
    this.filePath,
    this.fileSize,
    this.downloading,
    this.serverId,
    this.downloaded = false,
    this.duration,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ── Pending Media Model ────────────────────────────────────────────────────

class _PendingMedia {
  final String id;
  final File file;
  final String type; // 'image', 'video', 'document', 'voice'
  final String fileName;
  final int fileSize;

  _PendingMedia({
    required this.id,
    required this.file,
    required this.type,
    required this.fileName,
    required this.fileSize,
  });
}

// ── Chat Bubble ───────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  final void Function(_ChatMessage)? onDelete;
  final void Function(_ChatMessage, Offset)? onLongPress;
  final VoidCallback? onDownload;
  final Future<String?> Function()? onVoiceDownload;
  const _ChatBubble({required this.message, this.onRetry, this.onCancel, this.onDelete, this.onLongPress, this.onDownload, this.onVoiceDownload});

  void _openMedia(String url, BuildContext context, {String? localFilePath}) async {
    try {
      // Use local file if provided and exists
      if (localFilePath != null && await File(localFilePath).exists()) {
        final isVideo = localFilePath.endsWith('.mp4') || localFilePath.endsWith('.mov') ||
            localFilePath.endsWith('.mkv') || localFilePath.endsWith('.webm') ||
            localFilePath.endsWith('.m4v') || localFilePath.endsWith('.3gp');
        if (isVideo) {
          if (context.mounted) {
            Navigator.of(context).push(MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => _VideoPlayerScreen(videoPath: localFilePath),
            ));
          }
          return;
        }
        final result = await OpenFile.open(localFilePath);
        print('📂 Open media: ${result.type} - ${result.message}');
        if (result.type != ResultType.done && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot open: ${result.message}')));
        }
        return;
      }
      
      final tempDir = await getTemporaryDirectory();
      final fileName = url.split('/').last;
      final localFile = File('${tempDir.path}/$fileName');

      if (!await localFile.exists()) {
        final token = await StarlightStorage.getUserToken();
        final response = await http.get(
          Uri.parse(url),
          headers: token != null ? {'Authorization': 'Bearer $token'} : {},
        );
        if (response.statusCode == 200) {
          await localFile.writeAsBytes(response.bodyBytes);
        } else {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: ${response.statusCode}')));
          return;
        }
      }

      final isVideo = fileName.endsWith('.mp4') || fileName.endsWith('.mov') ||
          fileName.endsWith('.mkv') || fileName.endsWith('.webm') ||
          fileName.endsWith('.m4v') || fileName.endsWith('.3gp');

      if (isVideo) {
        if (context.mounted) {
          Navigator.of(context).push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => _VideoPlayerScreen(videoPath: localFile.path),
          ));
        }
        return;
      }

      final result = await OpenFile.open(localFile.path);
      print('📂 Open media: ${result.type} - ${result.message}');
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot open: ${result.message}')));
      }
    } catch (e) {
      print('📂 Open media: Error - $e');
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Open failed: $e')));
    }
  }

  Widget _buildLinkifiedText(String text, {bool isUser = false}) {
    final urlRegex = RegExp(r'https?:\/\/[^\s]+');
    final baseStyle = TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 14, height: 1.3);
    final linkStyle = TextStyle(color: isUser ? Colors.white70 : const Color(0xFF2196F3), fontSize: 14, height: 1.3, decoration: TextDecoration.underline);

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in urlRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start), style: baseStyle));
      }
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.tryParse(url);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final isMedia = message.messageType != 'text';
    final isVoice = message.messageType == 'voice';
    final isImage = message.messageType == 'image';
    final isVideo = message.messageType == 'video';

    return GestureDetector(
      onTap: message.status == 'failed' ? onRetry : null,
      onLongPress: () {
        final box = context.findRenderObject() as RenderBox?;
        final pos = box != null ? box.size.center(Offset.zero) : Offset.zero;
        onLongPress?.call(message, pos);
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!message.isUser) ...[
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: StarlightTheme.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.person, color: StarlightTheme.primaryBlue, size: 16),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                padding: EdgeInsets.symmetric(horizontal: isMedia ? 4 : 14, vertical: isMedia ? 4 : 10),
                decoration: BoxDecoration(
                  color: message.isUser
                      ? (message.status == 'failed' ? Colors.red.shade400 : StarlightTheme.primaryBlue)
                      : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                    bottomRight: Radius.circular(message.isUser ? 4 : 16),
                  ),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isImage && message.mediaUrl.isNotEmpty)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          message.isUser || message.downloaded
                              ? GestureDetector(
                                  onTap: () => _openMedia('${StarlightConstants.apiBaseUrl}${message.mediaUrl}', context, localFilePath: message.filePath),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: message.filePath != null
                                        ? Image.file(File(message.filePath!), width: 220, height: 220, fit: BoxFit.cover)
                                        : Image.network(
                                            '${StarlightConstants.apiBaseUrl}${message.mediaUrl}',
                                            width: 220, height: 220, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              width: 220, height: 120,
                                              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                                              child: const Icon(Icons.broken_image, color: Colors.grey),
                                            ),
                                          ),
                                  ),
                                )
                              : GestureDetector(
                                  onTap: onDownload,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      children: [
                                        SizedBox(
                                          width: 220, height: 220,
                                          child: message.thumbnailUrl.isNotEmpty
                                              ? Image.network(
                                                  '${StarlightConstants.apiBaseUrl}${message.thumbnailUrl}',
                                                  width: 220, height: 220, fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(
                                                    color: Colors.grey.shade200,
                                                    child: const Icon(Icons.broken_image, color: Colors.grey, size: 28),
                                                  ),
                                                )
                                              : Container(
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(Icons.image, color: Colors.grey, size: 28),
                                                ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.35),
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.cloud_download, color: Colors.white, size: 36),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          if (message.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 10, right: 10, top: 4, bottom: 2),
                              child: Text(message.text, style: TextStyle(color: message.isUser ? Colors.white : Colors.black87, fontSize: 14, height: 1.3)),
                            ),
                        ],
                      )
                    else if (isVideo && message.mediaUrl.isNotEmpty)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          message.isUser || message.downloaded
                              ? GestureDetector(
                                  onTap: () => _openMedia('${StarlightConstants.apiBaseUrl}${message.mediaUrl}', context, localFilePath: message.filePath),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 220, height: 160,
                                      color: Colors.black87,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Use local thumbnail if video file exists locally
                                          if (message.filePath != null && File(message.filePath!).existsSync())
                                            FutureBuilder<String?>(
                                              future: () async {
                                                final tempDir = await getTemporaryDirectory();
                                                final thumbPath = '${tempDir.path}/thumb_${message.id}.jpg';
                                                final thumbFile = File(thumbPath);
                                                if (await thumbFile.exists()) return thumbPath;
                                                return VideoThumbnail.thumbnailFile(
                                                  video: message.filePath!,
                                                  thumbnailPath: tempDir.path,
                                                  imageFormat: ImageFormat.JPEG,
                                                  quality: 75,
                                                  maxWidth: 220,
                                                  maxHeight: 160,
                                                );
                                              }(),
                                              builder: (context, snapshot) {
                                                if (snapshot.hasData && snapshot.data != null) {
                                                  return Image.file(File(snapshot.data!), width: 220, height: 160, fit: BoxFit.cover);
                                                }
                                                return const SizedBox.shrink();
                                              },
                                            )
                                          else if (message.thumbnailUrl.isNotEmpty)
                                            Image.network(
                                              '${StarlightConstants.apiBaseUrl}${message.thumbnailUrl}',
                                              width: 220, height: 160, fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                            ),
                                          const Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
                                          Positioned(
                                            bottom: 4, right: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                              child: const Text('Video', style: TextStyle(color: Colors.white, fontSize: 10)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : GestureDetector(
                                  onTap: onDownload,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      children: [
                                        SizedBox(
                                          width: 220, height: 160,
                                          child: message.thumbnailUrl.isNotEmpty
                                              ? Image.network(
                                                  '${StarlightConstants.apiBaseUrl}${message.thumbnailUrl}',
                                                  width: 220, height: 160, fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(
                                                    color: Colors.grey.shade900,
                                                    child: const Icon(Icons.videocam, color: Colors.grey, size: 28),
                                                  ),
                                                )
                                              : Container(
                                                  color: Colors.grey.shade900,
                                                  child: const Icon(Icons.videocam, color: Colors.grey, size: 28),
                                                ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.35),
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.cloud_download, color: Colors.white, size: 36),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          if (message.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 10, right: 10, top: 4, bottom: 2),
                              child: _buildLinkifiedText(message.text, isUser: message.isUser),
                            ),
                        ],
                      )
                    else if (isVideo && message.mediaUrl.isEmpty && message.status != 'failed')
                      _buildDownloadButton(context)
                    else if (isVoice && (message.mediaUrl.isNotEmpty || message.filePath != null))
                      _VoicePlayer(
                        url: message.mediaUrl.isNotEmpty ? '${StarlightConstants.apiBaseUrl}${message.mediaUrl}' : '',
                        isUser: message.isUser, duration: message.duration, filePath: message.filePath,
                        onBeforePlay: onVoiceDownload,
                      )
                    else if (message.messageType == 'share_contact')
                      _buildShareContactWidget(context)
                    else if (isMedia)
                      GestureDetector(
                        onTap: () => _openMedia('${StarlightConstants.apiBaseUrl}${message.mediaUrl}', context, localFilePath: message.filePath),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.insert_drive_file, size: 28, color: message.isUser ? Colors.white : StarlightTheme.primaryBlue),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  message.fileName ?? 'File',
                                  style: TextStyle(color: message.isUser ? Colors.white : Colors.black87, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        child: _buildLinkifiedText(message.text, isUser: message.isUser),
                      ),
                    if (message.uploadProgress != null && message.uploadProgress! < 100)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: message.uploadProgress! / 100,
                                    backgroundColor: Colors.white30,
                                    valueColor: AlwaysStoppedAnimation(message.isUser ? Colors.white : StarlightTheme.primaryBlue),
                                    minHeight: 3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: onCancel,
                                  child: Icon(Icons.cancel, size: 18, color: message.isUser ? Colors.white70 : Colors.red.shade300),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('Uploading ${message.uploadProgress}%', style: TextStyle(fontSize: 10, color: message.isUser ? Colors.white70 : Colors.grey)),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 2, left: 6, top: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.status == 'failed') ...[
                            const Icon(Icons.error_outline, size: 12, color: Colors.redAccent),
                            const SizedBox(width: 4),
                          ],
                          Text(_formatTime(message.timestamp), style: TextStyle(fontSize: 9, color: message.isUser ? Colors.white70 : Colors.grey.shade400)),
                          if (message.isUser) ...[
                            const SizedBox(width: 4),
                            Icon(_getStatusIcon(message.status), size: 12, color: _getStatusColor(message.status)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (message.isUser) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'sending': return Icons.access_time;
      case 'sent': return Icons.done;
      case 'delivered': return Icons.done_all;
      case 'read': return Icons.done_all;
      case 'failed': return Icons.error_outline;
      default: return Icons.done;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'sending': return Colors.white54;
      case 'sent': return Colors.white70;
      case 'delivered': return Colors.white70;
      case 'read': return const Color(0xFF4FC3F7);
      case 'failed': return Colors.red.shade200;
      default: return Colors.white70;
    }
  }

  String _formatTime(DateTime dt) {
    final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  Widget _buildShareContactWidget(BuildContext context) {
    try {
      final contactData = jsonDecode(message.text);
      final name = contactData['name'] ?? 'Unknown';
      final phone = contactData['phone'] ?? '';
      
      return FutureBuilder<List<LocalChat>>(
        future: _checkIfContactExists(phone),
        builder: (context, snapshot) {
          final exists = snapshot.data?.isNotEmpty ?? false;
          
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: message.isUser 
                  ? Colors.white.withOpacity(0.15)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: message.isUser 
                    ? Colors.white.withOpacity(0.2)
                    : Colors.grey[200]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: message.isUser 
                          ? Colors.white.withOpacity(0.2)
                          : const Color(0xFF075E54).withOpacity(0.1),
                      child: Icon(
                        Icons.person,
                        color: message.isUser ? Colors.white : const Color(0xFF075E54),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: message.isUser ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatPhoneNumber(phone),
                            style: TextStyle(
                              fontSize: 12,
                              color: message.isUser 
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (exists) {
                        _openChatWithContact(context, phone);
                      } else {
                        _addContactToPhone(context, name, phone);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: message.isUser 
                          ? Colors.white.withOpacity(0.2)
                          : const Color(0xFF075E54),
                      foregroundColor: message.isUser 
                          ? Colors.white
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      exists ? 'Open Chat' : 'Add Contact',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      return Text(
        message.text,
        style: TextStyle(color: message.isUser ? Colors.white : Colors.black87),
      );
    }
  }

  Future<List<LocalChat>> _checkIfContactExists(String phone) async {
    try {
      final chatRepository = ChatRepository();
      final chats = await chatRepository.getAllChats();
      return chats.where((c) => c.phoneNumber == phone).toList();
    } catch (e) {
      return [];
    }
  }

  void _openChatWithContact(BuildContext context, String phone) {
    // Pop the current chat screen and navigate to the new chat
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          friendId: phone,
          friendName: '',
          friendRole: 'User',
          friendPhone: phone,
        ),
      ),
    );
  }

  void _addContactToPhone(BuildContext context, String name, String phone) async {
    try {
      if (!await FlutterContacts.requestPermission()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacts permission denied')),
          );
        }
        return;
      }

      final contact = Contact()
        ..displayName = name
        ..phones = [Phone(phone)];
      
      await contact.insert();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contact "$name" added')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add contact: $e')),
        );
      }
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

  Widget _buildDownloadButton(BuildContext context) {
    final fileName = message.fileName ?? 'video.mp4';
    final fileUrl = '${StarlightConstants.apiBaseUrl}/chat/chunk/download/${message.mediaUrl.split('/').last}';

    return GestureDetector(
      onTap: () async {
        try {
          final resp = await http.get(Uri.parse(fileUrl));
          if (resp.statusCode == 200) {
            final dir = await getTemporaryDirectory();
            final file = File('${dir.path}/$fileName');
            await file.writeAsBytes(resp.bodyBytes);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloaded: $fileName')));
            }
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red));
          }
        }
      },
      child: Container(
        width: 220, height: 80,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_download, color: StarlightTheme.primaryBlue, size: 32),
            const SizedBox(height: 4),
            Text(fileName, style: TextStyle(fontSize: 11, color: Colors.grey.shade700), overflow: TextOverflow.ellipsis, maxLines: 1),
            Text('Tap to download', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }
}

// ── Media Selection Sheet ───────────────────────────────────────────────

class _MediaSelectionSheet extends StatefulWidget {
  final List<_ChatMessage> mediaMessages;
  final void Function(_ChatMessage) onDelete;

  const _MediaSelectionSheet({
    required this.mediaMessages,
    required this.onDelete,
  });

  @override
  State<_MediaSelectionSheet> createState() => _MediaSelectionSheetState();
}

class _MediaSelectionSheetState extends State<_MediaSelectionSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.mediaMessages.map((m) => m.id));
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _share() {
    final paths = widget.mediaMessages
        .where((m) => _selected.contains(m.id) && m.filePath != null)
        .map((m) => XFile(m.filePath!))
        .toList();
    if (paths.isNotEmpty) {
      Share.shareXFiles(paths, text: 'Shared from Starlight');
    }
  }

  void _delete() {
    for (final msg in widget.mediaMessages.where((m) => _selected.contains(m.id))) {
      widget.onDelete(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_selected.length} of ${widget.mediaMessages.length} selected',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (_selected.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.share, color: Color(0xFF263238)),
                    onPressed: () { Navigator.pop(context); _share(); },
                  ),
                if (_selected.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () { Navigator.pop(context); _delete(); },
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: GridView.builder(
                itemCount: widget.mediaMessages.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final media = widget.mediaMessages[index];
                  final isSel = _selected.contains(media.id);
                  return GestureDetector(
                    onTap: () => _toggle(media.id),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            color: Colors.grey.shade200,
                            child: media.filePath != null && File(media.filePath!).existsSync()
                                ? Image.file(File(media.filePath!), fit: BoxFit.cover)
                                : Image.network('${StarlightConstants.apiBaseUrl}${media.mediaUrl}', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300)),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF075E54) : Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                              border: Border.all(color: isSel ? const Color(0xFF075E54) : Colors.grey.shade400, width: 2),
                            ),
                            child: isSel
                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Voice Player Widget ──────────────────────────────────────────────────

class _VoicePlayer extends StatefulWidget {
  final String url;
  final bool isUser;
  final int? duration;
  final String? filePath;
  final Future<String?> Function()? onBeforePlay;
  const _VoicePlayer({required this.url, required this.isUser, this.duration, this.filePath, this.onBeforePlay});

  @override
  State<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  final AudioPlaybackService _audioService = AudioPlaybackService.instance;
  bool _isPlaying = false;
  bool _isDownloading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isDragging = false;
  double _dragValue = 0;
  Timer? _positionTimer;

  bool get _isMyUrl {
    final current = _audioService.currentUrl;
    if (current == null) return false;
    if (current == widget.url) return true;
    if (widget.filePath != null && current == widget.filePath) return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (widget.duration != null) _duration = Duration(seconds: widget.duration!);

    _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted && !_isDragging) {
        final myUrl = _isMyUrl;
        final playing = myUrl && _audioService.isPlaying;
        final pos = myUrl ? _audioService.position : Duration.zero;
        final dur = _audioService.duration;
        setState(() {
          _isPlaying = playing;
          _position = pos;
          if (dur > Duration.zero) _duration = dur;
        });
      }
    });
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    // Don't stop the global audio service - let it continue in background
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1;
    final displayPosition = _isDragging ? Duration(milliseconds: (_dragValue * total).toInt()) : _position;
    final currentMs = displayPosition.inMilliseconds.clamp(0, total);

    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          GestureDetector(
                onTap: () async {
                  if (_isPlaying) {
                    await _audioService.pause();
                  } else {
                    if (_position >= _duration && _duration > Duration.zero) {
                      await _audioService.seek(Duration.zero);
                    }
                    String playUrl = widget.url;
                    bool localFileExists = false;
                    if (widget.filePath != null && widget.filePath!.isNotEmpty) {
                      final f = File(widget.filePath!);
                      localFileExists = await f.exists();
                      if (localFileExists) playUrl = widget.filePath!;
                    }
                    if (!localFileExists && widget.url.isNotEmpty && widget.onBeforePlay != null) {
                      setState(() => _isDownloading = true);
                      try {
                        final localPath = await widget.onBeforePlay!();
                        if (localPath != null) playUrl = localPath;
                      } finally {
                        if (mounted) setState(() => _isDownloading = false);
                      }
                    }
                    await _audioService.play(playUrl, title: 'Voice Message');
                  }
                },
                child: _isDownloading
                    ? SizedBox(
                        width: 32, height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(widget.isUser ? Colors.white : StarlightTheme.primaryBlue),
                        ),
                      )
                    : Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle,
                        color: widget.isUser ? Colors.white : StarlightTheme.primaryBlue, size: 32),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    trackHeight: 2, activeTrackColor: widget.isUser ? Colors.white70 : StarlightTheme.primaryBlue,
                    inactiveTrackColor: widget.isUser ? Colors.white30 : Colors.grey.shade300,
                    thumbColor: widget.isUser ? Colors.white : StarlightTheme.primaryBlue,
                    overlayColor: Colors.transparent,
                  ),
                  child: Slider(
                    value: currentMs.toDouble(),
                    max: total.toDouble(),
                    onChangeStart: (v) { _isDragging = true; _dragValue = v; },
                    onChanged: (v) { setState(() { _dragValue = v; }); },
                    onChangeEnd: (v) async {
                      _isDragging = false;
                      final seekPos = Duration(milliseconds: v.toInt());
                      await _audioService.seek(seekPos);
                      _position = seekPos;
                      if (!_isPlaying) {
                        await _audioService.resume();
                      }
                    },
                  ),
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: TextStyle(fontSize: 9, color: widget.isUser ? Colors.white70 : Colors.grey.shade500),
              ),
            ],
          ),
        );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Typing Bubble ─────────────────────────────────────────────────────────

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 2), width: 7, height: 7,
          decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle),
        )),
      ),
    );
  }
}

class _VoiceRecordingBubble extends StatelessWidget {
  const _VoiceRecordingBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade400)),
          ),
          const SizedBox(width: 8),
          Icon(Icons.mic, size: 16, color: Colors.red.shade400),
          const SizedBox(width: 4),
          Text('Recording...', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Date Separator ────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  String _formatDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(messageDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) {
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return days[date.weekday - 1];
    }
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
        child: Text(_formatDate(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
      ),
    );
  }
}

// ── Video Player Screen ──────────────────────────────────────────────────

class _VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  const _VideoPlayerScreen({required this.videoPath});
  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() => _isInitialized = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _controller.value.isPlaying ? _controller.pause() : _controller.play();
                        });
                      },
                      child: AnimatedOpacity(
                        opacity: _controller.value.isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: const CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.play_arrow, color: Colors.white, size: 48),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
      bottomSheet: _isInitialized
          ? Container(
              color: Colors.black,
              padding: const EdgeInsets.all(8),
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(playedColor: StarlightTheme.primaryBlue),
              ),
            )
          : null,
    );
  }
}
