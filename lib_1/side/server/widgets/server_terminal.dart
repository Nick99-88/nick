import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/server_models.dart';
import '../services/server_project_service.dart';

class ServerTerminal extends StatefulWidget {
  final String projectId;
  final bool autoConnect;

  const ServerTerminal({
    super.key,
    required this.projectId,
    this.autoConnect = true,
  });

  @override
  State<ServerTerminal> createState() => _ServerTerminalState();
}

class _ServerTerminalState extends State<ServerTerminal> {
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  Stream<TerminalLog>? _logStream;
  StreamSubscription<TerminalLog>? _logSubscription;
  final List<TerminalLog> _logs = [];
  bool _isConnected = false;
  final List<String> _commandHistory = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    if (widget.autoConnect) {
      _connect();
    }
  }

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _logSubscription?.cancel();
    ServerProjectService.disconnectTerminal();
    super.dispose();
  }

  void _connect() {
    _logStream = ServerProjectService.connectTerminal(widget.projectId);
    _logSubscription = _logStream!.listen((log) {
      setState(() => _logs.add(log));
      _scrollToBottom();
    });
    setState(() => _isConnected = true);
  }

  void _disconnect() {
    _logSubscription?.cancel();
    ServerProjectService.disconnectTerminal();
    setState(() => _isConnected = false);
  }

  void _sendCommand() {
    final command = _commandController.text.trim();
    if (command.isEmpty || !_isConnected) return;

    ServerProjectService.sendTerminalCommand(widget.projectId, command);
    _commandHistory.add(command);
    _historyIndex = _commandHistory.length;
    _commandController.clear();
  }

  void _scrollToBottom() {
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

  void _navigateHistory(int direction) {
    if (_commandHistory.isEmpty) return;
    _historyIndex = (_historyIndex + direction).clamp(0, _commandHistory.length - 1);
    _commandController.text = _commandHistory[_historyIndex];
    _commandController.selection = TextSelection.collapsed(
      offset: _commandController.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildTerminalBody()),
          if (_isConnected) _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _isConnected ? const Color(0xFF3FB950) : const Color(0xFFF85149),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.terminal, size: 14, color: Color(0xFF8B949E)),
          const SizedBox(width: 6),
          const Text(
            'Container Terminal',
            style: TextStyle(
              color: Color(0xFFC9D1D9),
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (!_isConnected)
            _buildTerminalButton(
              icon: Icons.play_arrow,
              label: 'Connect',
              color: const Color(0xFF3FB950),
              onTap: _connect,
            )
          else ...[
            _buildTerminalButton(
              icon: Icons.delete_outline,
              label: 'Clear',
              color: const Color(0xFF8B949E),
              onTap: () => setState(() => _logs.clear()),
            ),
            const SizedBox(width: 6),
            _buildTerminalButton(
              icon: Icons.copy,
              label: 'Copy',
              color: const Color(0xFF8B949E),
              onTap: () {
                final text = _logs.map((l) => l.message).join('\n');
                Clipboard.setData(ClipboardData(text: text));
              },
            ),
            const SizedBox(width: 6),
            _buildTerminalButton(
              icon: Icons.stop,
              label: 'Disconnect',
              color: const Color(0xFFF85149),
              onTap: _disconnect,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTerminalButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminalBody() {
    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isConnected ? Icons.terminal : Icons.cloud_off,
              size: 32,
              color: const Color(0xFF484F58),
            ),
            const SizedBox(height: 8),
            Text(
              _isConnected
                  ? 'Connected. Waiting for logs...'
                  : 'Click "Connect" to start terminal',
              style: const TextStyle(
                color: Color(0xFF484F58),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        return _buildLogLine(log);
      },
    );
  }

  Widget _buildLogLine(TerminalLog log) {
    Color textColor;
    Color? prefixColor;
    String prefix;

    switch (log.stream) {
      case 'stderr':
        textColor = const Color(0xFFF85149);
        prefixColor = const Color(0xFFF85149);
        prefix = 'ERR';
        break;
      case 'system':
        textColor = const Color(0xFF8B949E);
        prefixColor = const Color(0xFF58A6FF);
        prefix = 'SYS';
        break;
      case 'stdin':
        textColor = const Color(0xFF3FB950);
        prefixColor = const Color(0xFF3FB950);
        prefix = '>>>';
        break;
      default:
        textColor = const Color(0xFFC9D1D9);
        prefixColor = const Color(0xFF484F58);
        prefix = 'OUT';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${log.timestamp.hour.toString().padLeft(2, '0')}:'
            '${log.timestamp.minute.toString().padLeft(2, '0')}:'
            '${log.timestamp.second.toString().padLeft(2, '0')} ',
            style: const TextStyle(
              color: Color(0xFF484F58),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: (prefixColor ?? Colors.grey).withOpacity(0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              prefix,
              style: TextStyle(
                color: prefixColor,
                fontSize: 10,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SelectableText(
              log.message,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(top: BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(
        children: [
          const Text(
            '\$ ',
            style: TextStyle(
              color: Color(0xFF3FB950),
              fontSize: 13,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is! KeyDownEvent) return;
                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  _navigateHistory(-1);
                } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  _navigateHistory(1);
                }
              },
              child: TextField(
                controller: _commandController,
                focusNode: _focusNode,
                style: const TextStyle(
                  color: Color(0xFFC9D1D9),
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Type command...',
                  hintStyle: TextStyle(
                    color: Color(0xFF484F58),
                    fontFamily: 'monospace',
                  ),
                ),
                cursorColor: const Color(0xFF3FB950),
                onSubmitted: (_) => _sendCommand(),
              ),
            ),
          ),
          GestureDetector(
            onTap: _sendCommand,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF3FB950).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.send,
                size: 14,
                color: Color(0xFF3FB950),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
