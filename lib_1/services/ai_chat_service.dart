import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/constants.dart';
import '../core/storage.dart';

class AiChatService {
  static final AiChatService instance = AiChatService._();
  AiChatService._();

  String get _baseUrl => StarlightConstants.apiBaseUrl;

  Future<String> _getToken() async {
    final token = await StarlightStorage.getUserToken();
    if (token == null) throw Exception('Not authenticated');
    return token;
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  // ─── REST: Sessions CRUD ───

  Future<Map<String, dynamic>> createSession({String mode = 'think'}) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$_baseUrl/ai-chat/sessions'),
      headers: _headers(token),
      body: jsonEncode({'mode': mode}),
    );
    if (res.statusCode != 200) throw Exception('Failed to create session');
    return jsonDecode(res.body);
  }

  Future<List<Map<String, dynamic>>> listSessions() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_baseUrl/ai-chat/sessions'),
      headers: _headers(token),
    );
    if (res.statusCode != 200) throw Exception('Failed to load sessions');
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['sessions']);
  }

  Future<Map<String, dynamic>> getSession(String sessionId) async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_baseUrl/ai-chat/sessions/$sessionId'),
      headers: _headers(token),
    );
    if (res.statusCode != 200) throw Exception('Failed to load session');
    return jsonDecode(res.body);
  }

  Future<void> updateSession(String sessionId, {String? title, String? mode}) async {
    final token = await _getToken();
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (mode != null) body['mode'] = mode;
    await http.patch(
      Uri.parse('$_baseUrl/ai-chat/sessions/$sessionId'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
  }

  Future<void> deleteSession(String sessionId) async {
    final token = await _getToken();
    await http.delete(
      Uri.parse('$_baseUrl/ai-chat/sessions/$sessionId'),
      headers: _headers(token),
    );
  }

  // ─── REST: Send message (non-streaming fallback) ───

  Future<Map<String, dynamic>> sendMessage(String sessionId, String content) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$_baseUrl/ai-chat/sessions/$sessionId/messages'),
      headers: _headers(token),
      body: jsonEncode({'content': content}),
    );
    if (res.statusCode != 200) throw Exception('Failed to send message');
    return jsonDecode(res.body);
  }

  // ─── WebSocket: Streaming chat ───

  WebSocketChannel? _channel;
  final _streamController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _streamController.stream;

  bool get isConnected => _channel != null;

  Future<void> connect() async {
    if (_channel != null) return;
    final token = await _getToken();
    final wsUrl = _baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$wsUrl/ai-chat/ws/$token');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (data) {
        final msg = jsonDecode(data as String);
        _streamController.add(msg);
      },
      onDone: () {
        _channel = null;
      },
      onError: (e) {
        _channel = null;
      },
    );
  }

  void sendMessageStream(String sessionId, String content, {String mode = 'think'}) {
    if (_channel == null) throw Exception('WebSocket not connected');
    _channel!.sink.add(jsonEncode({
      'session_id': sessionId,
      'content': content,
      'mode': mode,
    }));
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _streamController.close();
  }
}
