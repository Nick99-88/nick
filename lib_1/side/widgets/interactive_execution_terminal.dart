import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';

class ExecutionLine {
  final String text;
  final bool isError;
  final bool isSystem;
  ExecutionLine({required this.text, this.isError = false, this.isSystem = false});
}

class InteractiveExecutionTerminal extends StatefulWidget {
  final String code;
  final String language;
  final Map<String, String>? files;
  final String? entryFile;

  const InteractiveExecutionTerminal({
    super.key,
    required this.code,
    required this.language,
    this.files,
    this.entryFile,
  });

  @override
  State<InteractiveExecutionTerminal> createState() => _InteractiveExecutionTerminalState();
}

class _InteractiveExecutionTerminalState extends State<InteractiveExecutionTerminal> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<ExecutionLine> _lines = [];
  final List<String> _inputHistory = [];
  int _historyIndex = -1;

  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isRunning = false;
  bool _finished = false;
  int? _exitCode;

  static String _wsBaseUrl() {
    final base = StarlightConstants.apiBaseUrl;
    if (base.startsWith('https://')) return 'wss://${base.substring(8)}';
    if (base.startsWith('http://')) return 'ws://${base.substring(7)}';
    return base;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _run();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _channel = null;
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_isRunning) return;
    setState(() { _isRunning = true; _finished = false; _exitCode = null; _lines.clear(); });

    final token = await StarlightStorage.getUserToken();
    if (token == null || !mounted) {
      _addLine('Authentication failed', isError: true);
      setState(() => _isRunning = false);
      return;
    }

    try {
      final wsUrl = '${_wsBaseUrl()}/side/execute/ws?token=$token';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;

      _channel!.stream.listen(
        _onData,
        onError: (error) {
          _addLine('Connection error: $error', isError: true);
          _setRunning(false);
        },
        onDone: () {
          _setConnected(false);
          if (!_finished) _addLine('Disconnected unexpectedly', isError: true);
        },
        cancelOnError: false,
      );

      _setConnected(true);
      final runPayload = <String, dynamic>{
        'type': 'run',
        'code': widget.code,
        'language': widget.language,
        'files': widget.files ?? {},
      };
      if (widget.entryFile != null && widget.entryFile!.isNotEmpty) {
        runPayload['entry_file'] = widget.entryFile;
      }
      _channel!.sink.add(jsonEncode(runPayload));
      _focusNode.requestFocus();
    } catch (e) {
      _addLine('Connection failed: $e', isError: true);
      _setRunning(false);
    }
  }

  void _disconnectWs() {
    _channel?.sink.close();
    _channel = null;
    _setConnected(false);
  }

  void _setConnected(bool val) {
    if (mounted) {
      try { setState(() => _isConnected = val); } catch (_) {}
    }
  }

  void _setRunning(bool val) {
    if (mounted) {
      try { setState(() => _isRunning = val); } catch (_) {}
    }
  }

  void _onData(dynamic data) {
    try {
      final msg = jsonDecode(data as String);

      if (msg['type'] == 'output') {
        final text = msg['data'] as String?;
        final isError = msg['is_error'] == true;
        if (text != null && text.isNotEmpty) _addLine(text, isError: isError);

      } else if (msg['type'] == 'log') {
        // Server debug logs — dev console only, not shown in the IDE terminal.
        if (kDebugMode) {
          final step = msg['step'] as String? ?? 'LOG';
          final detail = msg['data'] as String? ?? '';
          debugPrint('[SideIDE Run] $step: $detail');
        }

      } else if (msg['type'] == 'started') {
        _focusNode.requestFocus();

      } else if (msg['type'] == 'done') {
        _exitCode = msg['exit_code'] as int?;
        setState(() { _finished = true; _isRunning = false; });
        _disconnectWs();

      } else if (msg['type'] == 'error') {
        _addLine('Error: ${msg['data']}', isError: true);
        setState(() => _isRunning = false);
        _disconnectWs();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SideIDE Run] parse error: $e');
    }
  }

  void _addLine(String text, {bool isError = false, bool isSystem = false}) {
    if (!mounted) return;
    for (final line in text.split('\n')) {
      if (line.isNotEmpty) {
        setState(() => _lines.add(ExecutionLine(text: line, isError: isError, isSystem: isSystem)));
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

  void _sendInput() {
    final text = _inputController.text;
    if (text.isEmpty || !_isConnected || _finished) return;
    _inputHistory.add(text);
    _historyIndex = _inputHistory.length;
    try {
      _channel!.sink.add(jsonEncode({'type': 'input', 'data': text}));
    } catch (_) {
      _addLine('Failed to send input', isError: true);
    }
    _inputController.clear();
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
          if (_isConnected && !_finished) _buildInputBar(),
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
              color: _isRunning ? const Color(0xFF50FA7B) : (_finished ? const Color(0xFF6272A4) : const Color(0xFFFF5555)),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text('OUTPUT', style: const TextStyle(color: Color(0xFF6272A4), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1, fontFamily: 'monospace')),
          if (_isRunning) ...[
            const SizedBox(width: 6),
            const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF50FA7B))),
          ],
          const Spacer(),
          Text(widget.language.toUpperCase(), style: const TextStyle(color: Color(0xFF50FA7B), fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _lines.clear()),
            child: const Icon(Icons.delete_outline, size: 12, color: Color(0xFF6272A4)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _finished ? _run : null,
            child: Icon(Icons.refresh, size: 12, color: _finished ? const Color(0xFF50FA7B) : const Color(0xFF6272A4)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_isRunning && !_finished && _lines.isEmpty) {
      return const Center(
        child: Text('Starting execution...', style: TextStyle(color: Color(0xFF6272A4), fontSize: 11, fontFamily: 'monospace')),
      );
    }
    if (!_isRunning && _finished && _lines.isEmpty) {
      return const Center(
        child: Text('No output', style: TextStyle(color: Color(0xFF6272A4), fontSize: 11, fontFamily: 'monospace')),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _lines.length,
      itemBuilder: (ctx, i) {
        final line = _lines[i];
        final color = line.isError
            ? const Color(0xFFFF5555)
            : line.isSystem
                ? const Color(0xFF6272A4)
                : const Color(0xFFF8F8F2);
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
          const Text('> ', style: TextStyle(color: Color(0xFF50FA7B), fontSize: 12, fontFamily: 'monospace')),
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _focusNode,
              style: const TextStyle(color: Color(0xFFF8F8F2), fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Type input...',
                hintStyle: TextStyle(color: Color(0xFF6272A4), fontSize: 12),
              ),
              onSubmitted: (_) => _sendInput(),
              onChanged: (_) => _historyIndex = _inputHistory.length,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _sendInput,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF50FA7B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.send, size: 12, color: Color(0xFF50FA7B)),
            ),
          ),
        ],
      ),
    );
  }
}
