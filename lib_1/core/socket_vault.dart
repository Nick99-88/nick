import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:starlight_flutter/core/constants.dart';

class StarlightSocket {
  static final StarlightSocket _instance = StarlightSocket._internal();
  factory StarlightSocket() => _instance;
  StarlightSocket._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  bool get isLive => _isConnected;
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  /// 🚀 Initialize the Real-Time Pipe
  Future<void> init(String token) async {
    if (_isConnected) return;

    // Use token in query param for auth
    final String url = "${StarlightConstants.socketUrl}/$token";

    try {
      debugPrint("📡 Starlight Pipe: Connecting to Engine...");
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _channel!.stream.listen(
        (message) {
          _isConnected = true;
          try {
            final data = jsonDecode(message);
            _eventController.add(data);
            debugPrint("📥 Socket: $data");
          } catch (e) {
            debugPrint("❌ Socket Parse Error: $e");
          }
        },
        onDone: () {
          _isConnected = false;
          debugPrint("📡 Socket: Offline. Attempting re-entry in 5s...");
        },
        onError: (err) {
          _isConnected = false;
          debugPrint("❌ Socket Error: $err");
        },
      );
    } catch (e) {
      _isConnected = false;
      debugPrint("🏛️ Socket Connection Failed: $e");
    }
  }

  /// 🏛️ Compatibility method: renamed 'listen' to 'on' to match existing calls
  StreamSubscription on(String eventName, Function(dynamic data) callback) {
    return _eventController.stream.listen((payload) {
      if (payload['event'] == eventName) {
        callback(payload['data']);
      }
    });
  }

  /// 🏛️ Compatibility method: renamed 'sendAction' to 'emit'
  void emit(String event, dynamic data) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({
        "event": event,
        "data": data
      }));
    }
  }

  /// 🏛️ Legacy method used in some parts of the app
  StreamSubscription listen(String eventName, Function(dynamic data) callback) => on(eventName, callback);

  /// 🏛️ Legacy method used in some parts of the app
  void sendAction(String action, dynamic data) => emit(action, data);

  /// 🏛️ Sync user location for social presence
  void updateLocation(String location) {
    sendAction("update_location", {"location": location});
  }

  void close() {
    _channel?.sink.close();
    _isConnected = false;
  }
}
