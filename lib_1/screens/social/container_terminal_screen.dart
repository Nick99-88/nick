import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants.dart';

class ContainerTerminalScreen extends StatefulWidget {
  final String websiteName;
  final String projectName;

  const ContainerTerminalScreen({
    super.key,
    required this.websiteName,
    required this.projectName,
  });

  @override
  State<ContainerTerminalScreen> createState() => _ContainerTerminalScreenState();
}

class _ContainerTerminalScreenState extends State<ContainerTerminalScreen> {
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_LogLine> _logs = [];
  WebSocketChannel? _channel;
  bool _connected = false;
  bool _reconnecting = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _commandController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _reconnecting = true);
    try {
      final wsUrl = StarlightConstants.apiBaseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');

      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/platform/websites/${widget.websiteName}/terminal'),
      );

      await _channel!.ready;
      setState(() => _connected = true);

      _channel!.stream.listen(
        (data) {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          setState(() {
            _logs.add(_LogLine(
              text: msg['output']?.toString() ?? msg['stdout']?.toString() ?? msg['stderr']?.toString() ?? jsonEncode(msg),
              isError: msg['is_error'] == true || msg['stderr'] != null,
              isSystem: msg['type'] == 'log',
              timestamp: DateTime.now(),
            ));
          });
          Future.delayed(const Duration(milliseconds: 50), () {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
            );
          });
        },
        onDone: () {
          setState(() => _connected = false);
        },
        onError: (e) {
          setState(() {
            _logs.add(_LogLine(text: 'Connection error: $e', isError: true, isSystem: true, timestamp: DateTime.now()));
            _connected = false;
          });
        },
      );

      _logs.add(_LogLine(text: 'Connected to persistent container terminal', isError: false, isSystem: true, timestamp: DateTime.now()));
      _logs.add(_LogLine(text: 'Container stays alive even after you leave this screen', isError: false, isSystem: true, timestamp: DateTime.now()));
      _logs.add(_LogLine(text: 'Run build commands like: npm install && npm run build', isError: false, isSystem: true, timestamp: DateTime.now()));
    } catch (e) {
      setState(() {
        _logs.add(_LogLine(text: 'Failed to connect: $e', isError: true, isSystem: true, timestamp: DateTime.now()));
        _connected = false;
      });
    }
    setState(() => _reconnecting = false);
  }

  void _sendCommand() {
    final cmd = _commandController.text.trim();
    if (cmd.isEmpty) return;

    _channel?.sink.add(jsonEncode({'type': 'command', 'command': cmd}));
    _logs.add(_LogLine(text: '\$ $cmd', isError: false, isSystem: false, timestamp: DateTime.now()));
    _commandController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.projectName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text(
              _connected ? '● Connected' : '○ Disconnected',
              style: TextStyle(
                fontSize: 11,
                color: _connected ? const Color(0xFF2EA043) : const Color(0xFFDA3633),
              ),
            ),
          ],
        ),
        actions: [
          if (!_connected)
            IconButton(
              icon: _reconnecting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 20),
              onPressed: _connect,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _logs.length,
              itemBuilder: (ctx, i) {
                final log = _logs[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    log.text,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: log.isError
                          ? const Color(0xFFDA3633)
                          : log.isSystem
                              ? const Color(0xFF8B949E)
                              : const Color(0xFFC9D1D9),
                      height: 1.4,
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              border: Border(top: BorderSide(color: Color(0xFF30363D))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: _connected ? 'Enter command...' : 'Not connected',
                      hintStyle: const TextStyle(color: Color(0xFF484F58)),
                      filled: true,
                      fillColor: const Color(0xFF21262D),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _connected ? _sendCommand() : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _connected ? _sendCommand : null,
                  icon: const Icon(Icons.send_rounded, size: 20),
                  color: _connected ? const Color(0xFF58A6FF) : const Color(0xFF484F58),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogLine {
  final String text;
  final bool isError;
  final bool isSystem;
  final DateTime timestamp;

  _LogLine({
    required this.text,
    required this.isError,
    required this.isSystem,
    required this.timestamp,
  });
}
