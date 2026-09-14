import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';

class TerminalLine {
  final String text;
  final bool isError;
  final bool isSystem;
  TerminalLine({required this.text, this.isError = false, this.isSystem = false});
}

class InteractiveTerminal extends StatefulWidget {
  final String projectId;
  final VoidCallback? onClose;

  const InteractiveTerminal({
    super.key,
    required this.projectId,
    this.onClose,
  });

  @override
  State<InteractiveTerminal> createState() => _InteractiveTerminalState();
}

class _InteractiveTerminalState extends State<InteractiveTerminal> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<TerminalLine> _lines = [];
  final List<String> _commandHistory = [];
  int _historyIndex = -1;

  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _fatalError = false;
  bool _commandRunning = false;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _disconnectWs();
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_isConnected || _isConnecting) return;
    setState(() => _isConnecting = true);
    _addLine('Connecting to server...', isSystem: true);

    final token = await StarlightStorage.getUserToken();
    if (token == null || !mounted) {
      _addLine('Authentication failed', isError: true, isSystem: true);
      setState(() => _isConnecting = false);
      return;
    }

    try {
      final base = StarlightConstants.apiBaseUrl;
      final wsBase = base.startsWith('https://')
          ? 'wss://${base.substring(8)}'
          : base.startsWith('http://')
              ? 'ws://${base.substring(7)}'
              : base;
      final wsUrl = '$wsBase/side/server/projects/${widget.projectId}/terminal/ws?token=$token';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;

      _channel!.stream.listen(
        _onData,
        onError: (error) {
          _addLine('Connection error: $error', isError: true, isSystem: true);
          _scheduleReconnect();
        },
        onDone: () {
          _addLine('Disconnected from server', isSystem: true);
          _setConnected(false);
          if (!_fatalError) _scheduleReconnect();
        },
        cancelOnError: false,
      );

      _setConnected(true);
      _startHeartbeat();
    } catch (e) {
      _addLine('Connection failed: $e', isError: true, isSystem: true);
      _setConnected(false);
    }

    if (mounted) setState(() => _isConnecting = false);
  }

  void _disconnectWs() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setConnected(false);
  }

  void _manualReconnect() {
    _fatalError = false;
    _reconnectAttempts = 0;
    _connect();
  }

  void _setConnected(bool val) {
    if (mounted) setState(() => _isConnected = val);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {
          _scheduleReconnect();
        }
      }
    });
  }

  void _scheduleReconnect() {
    if (_fatalError || _reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectAttempts++;
    Future.delayed(Duration(seconds: 2 * _reconnectAttempts), () {
      if (mounted && !_isConnected) _connect();
    });
  }

  void _onData(dynamic data) {
    try {
      final msg = jsonDecode(data as String);
      if (msg['type'] == 'output') {
        final stdout = msg['stdout'] as String?;
        final stderr = msg['stderr'] as String?;
        if (stdout != null && stdout.isNotEmpty) _addLine(stdout);
        if (stderr != null && stderr.isNotEmpty) _addLine(stderr, isError: true);
      } else if (msg['type'] == 'done') {
        setState(() => _commandRunning = false);
      } else if (msg['type'] == 'log') {
        final output = msg['output'] as String?;
        final isError = msg['is_error'] == true;
        if (output != null && output.isNotEmpty) {
          _addLine(output, isError: isError);
        }
        if (isError && output != null && (output.contains('Failed to start container') || output.contains('not installed'))) {
          _fatalError = true;
        }
      }
    } catch (_) {}
  }

  void _addLine(String text, {bool isError = false, bool isSystem = false}) {
    if (!mounted) return;
    for (final line in text.split('\n')) {
      if (line.isNotEmpty) {
        setState(() => _lines.add(TerminalLine(text: line, isError: isError, isSystem: isSystem)));
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendCommand() {
    final cmd = _inputController.text.trim();
    if (cmd.isEmpty || !_isConnected) return;

    if (_commandRunning) {
      // Send as input to running process
      try {
        _channel!.sink.add(jsonEncode({'type': 'input', 'data': cmd}));
      } catch (_) {
        _addLine('Failed to send input', isError: true, isSystem: true);
      }
    } else {
      // Send as new command
      _addLine('\$ $cmd');
      _commandHistory.add(cmd);
      _historyIndex = _commandHistory.length;
      try {
        _channel!.sink.add(jsonEncode({'type': 'command', 'command': cmd}));
        setState(() => _commandRunning = true);
      } catch (_) {
        _addLine('Failed to send command', isError: true, isSystem: true);
      }
    }
    _inputController.clear();
  }

  void _navigateHistory(int direction) {
    if (_commandHistory.isEmpty) return;
    _historyIndex = (_historyIndex + direction).clamp(0, _commandHistory.length - 1);
    _inputController.text = _commandHistory[_historyIndex];
    _inputController.selection = TextSelection.collapsed(offset: _inputController.text.length);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        border: Border(top: BorderSide(color: const Color(0xFF44475A).withOpacity(0.3))),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
          if (_isConnected) _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF282A36),
        border: Border(bottom: BorderSide(color: Color(0xFF44475A), width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: _isConnected ? const Color(0xFF50FA7B) : const Color(0xFFFF5555),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text('TERMINAL', style: TextStyle(color: Color(0xFF6272A4), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1, fontFamily: 'monospace')),
          if (_isConnecting) ...[
            const SizedBox(width: 6),
            const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF50FA7B))),
          ],
          const Spacer(),
          if (_fatalError)
            GestureDetector(
              onTap: _manualReconnect,
              child: const Icon(Icons.refresh, size: 12, color: Color(0xFF50FA7B)),
            ),
          if (!_fatalError && _isConnected)
            GestureDetector(
              onTap: () => setState(() => _lines.clear()),
              child: const Icon(Icons.delete_outline, size: 12, color: Color(0xFF6272A4)),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _fatalError ? _manualReconnect : (_isConnected ? _disconnectWs : _connect),
            child: Icon(
              _fatalError ? Icons.refresh : (_isConnected ? Icons.link_off : Icons.link),
              size: 12, color: const Color(0xFF6272A4),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onClose,
            child: const Icon(Icons.close, size: 10, color: Color(0xFF6272A4)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_lines.isEmpty && !_isConnecting) {
      return const Center(
        child: Text(
          'Connecting to container...',
          style: TextStyle(color: Color(0xFF6272A4), fontSize: 11, fontFamily: 'monospace'),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _lines.length,
      itemBuilder: (ctx, i) {
        final line = _lines[i];
        Color color;
        if (line.isSystem) {
          color = const Color(0xFF6272A4);
        } else if (line.isError) {
          color = const Color(0xFFFF5555);
        } else {
          color = const Color(0xFFF8F8F2);
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 0.5),
          child: Text(
            line.text,
            style: TextStyle(color: color, fontSize: 12, fontFamily: 'monospace', height: 1.3),
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF282A36),
        border: Border(top: BorderSide(color: Color(0xFF44475A), width: 0.5)),
      ),
      child: Row(
        children: [
          const Text('\$ ', style: TextStyle(color: Color(0xFF50FA7B), fontSize: 12, fontFamily: 'monospace')),
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _focusNode,
              style: const TextStyle(color: Color(0xFFF8F8F2), fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Type command...',
                hintStyle: TextStyle(color: Color(0xFF6272A4), fontSize: 12),
              ),
              onSubmitted: (_) => _sendCommand(),
              onChanged: (_) => _historyIndex = _commandHistory.length,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _sendCommand,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF50FA7B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(_commandRunning ? Icons.keyboard_return : Icons.send,
                  size: 12, color: const Color(0xFF50FA7B)),
            ),
          ),
        ],
      ),
    );
  }
}
