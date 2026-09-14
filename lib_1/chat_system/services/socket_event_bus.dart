import 'dart:async';

typedef SocketEventCallback = void Function(Map<String, dynamic> data);

class SocketEventBus {
  static final SocketEventBus instance = SocketEventBus._init();
  SocketEventBus._init();

  final Map<String, List<SocketEventCallback>> _listeners = {};

  void subscribe(String event, SocketEventCallback callback) {
    _listeners.putIfAbsent(event, () => []);
    _listeners[event]!.add(callback);
  }

  void unsubscribe(String event, SocketEventCallback callback) {
    _listeners[event]?.remove(callback);
  }

  void unsubscribeAll(String event) {
    _listeners[event]?.clear();
  }

  void publish(String event, Map<String, dynamic> data) {
    final callbacks = _listeners[event];
    if (callbacks != null) {
      for (final callback in List.from(callbacks)) {
        try {
          callback(data);
        } catch (e) {
          print('🚌 SocketEventBus: Error in $event callback: $e');
        }
      }
    }
  }

  void clear() {
    _listeners.clear();
  }
}
