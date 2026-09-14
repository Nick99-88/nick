import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../chat_local_db/chat_local_db.dart';
import 'chat_storage_service.dart';
import 'chat_sync_manager.dart';
import 'message_outbox_queue.dart';
import 'message_action_service.dart';
import 'call_signaling_service.dart';
import 'call_kit_service.dart';
import '../../services/socket/enhanced_socket_service.dart';
import '../../core/storage.dart';

enum ChatSystemStatus { uninitialized, initializing, ready, error, offline }

class ChatSystemInitializer {
  static final ChatSystemInitializer instance = ChatSystemInitializer._init();
  ChatSystemInitializer._init();

  ChatSystemStatus _status = ChatSystemStatus.uninitialized;
  ChatSystemStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _disappearingMessagesTimer;

  Future<void> initialize() async {
    if (_status == ChatSystemStatus.ready) {
      print('💬 ChatSystem: Already initialized');
      return;
    }

    _status = ChatSystemStatus.initializing;
    print('💬 ChatSystem: Starting initialization...');

    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null || token.isEmpty) {
        _setError('No authentication token found');
        return;
      }

      await ChatLocalService.instance.initialize();
      print('💬 ChatSystem: Local service initialized');

      await ChatStorageService.instance.initialize();
      print('💬 ChatSystem: Storage service initialized');

      await ChatSyncManager.instance.initialize();
      print('💬 ChatSystem: Sync manager initialized');

      await MessageOutboxQueue.instance.initialize();
      print('💬 ChatSystem: Outbox queue initialized');

      CallSignalingService.instance.initialize();
      CallKitService.instance.initialize();
      await _connectWebSocket();

      _setupConnectivityListener();
      _startDisappearingMessagesTimer();

      _status = ChatSystemStatus.ready;
      print('💬 ChatSystem: Initialization complete');
    } catch (e, stackTrace) {
      _setError('Initialization failed: $e');
      print('💬 ChatSystem: Initialization error: $e\n$stackTrace');
    }
  }

  Future<void> _connectWebSocket() async {
    try {
      if (!EnhancedSocketService.isConnected()) {
        await EnhancedSocketService.connect(
          source: 'ChatSystemInitializer',
          closeExisting: false,
        );
        print('💬 ChatSystem: WebSocket connected');
      }
    } catch (e) {
      print('💬 ChatSystem: WebSocket connection failed: $e');
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty) {
        _handleConnectivityChange(results.first);
      }
    });
  }

  Future<void> _handleConnectivityChange(ConnectivityResult result) async {
    if (result == ConnectivityResult.none) {
      _status = ChatSystemStatus.offline;
      print('💬 ChatSystem: Network disconnected');
    } else {
      if (_status == ChatSystemStatus.offline) {
        print('💬 ChatSystem: Network reconnected, syncing...');
        await _connectWebSocket();
        await MessageOutboxQueue.instance.triggerProcess();
        await ChatSyncManager.instance.sendLastSeen();
      }
      _status = ChatSystemStatus.ready;
    }
  }

  void _startDisappearingMessagesTimer() {
    _disappearingMessagesTimer?.cancel();
    _disappearingMessagesTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      MessageActionService.instance.processDisappearingMessages();
    });
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _disappearingMessagesTimer?.cancel();
    await MessageOutboxQueue.instance.dispose();
    ChatSyncManager.instance.dispose();
    await EnhancedSocketService.disconnect();
    _status = ChatSystemStatus.uninitialized;
    print('💬 ChatSystem: Disposed');
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = ChatSystemStatus.error;
  }

  Future<bool> isReady() async {
    if (_status == ChatSystemStatus.uninitialized) {
      await initialize();
    }
    return _status == ChatSystemStatus.ready || _status == ChatSystemStatus.offline;
  }
}
