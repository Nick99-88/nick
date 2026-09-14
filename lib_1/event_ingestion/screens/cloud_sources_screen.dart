import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/constants.dart';

/// 🏛️ Connect cloud providers (Render / DigitalOcean / Railway) as live log
/// sources for the Event Ingestion console. The backend proxies the native
/// stream to one unified WebSocket.
class CloudSourcesScreen extends StatefulWidget {
  const CloudSourcesScreen({super.key});

  @override
  State<CloudSourcesScreen> createState() => _CloudSourcesScreenState();
}

class _CloudSourcesScreenState extends State<CloudSourcesScreen> {
  List<_Conn> _conns = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
          Uri.parse('${StarlightConstants.apiBaseUrl}/ingestion/connections'));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = body['connections'] as List? ?? [];
        _conns = list.map((e) => _Conn.fromJson(e)).toList();
      } else {
        _error = 'Failed to load (${res.statusCode})';
      }
    } catch (e) {
      debugPrint('[CloudSources] load error: $e');
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final provider = ValueNotifier<String>('render');
    final token = TextEditingController();
    final label = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16),
        child: Material(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connect a cloud source',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF212121))),
                const SizedBox(height: 14),
                Text('Provider',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: const Color(0xFF8A8F98))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFECEEF2)),
                  ),
                  child: ValueListenableBuilder<String>(
                    valueListenable: provider,
                    builder: (_, val, __) => DropdownButton<String>(
                      isExpanded: true,
                      value: val,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                            value: 'render', child: Text('Render')),
                        DropdownMenuItem(
                            value: 'digitalocean',
                            child: Text('DigitalOcean')),
                        DropdownMenuItem(
                            value: 'railway', child: Text('Railway')),
                      ],
                      onChanged: (v) => provider.value = v!,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: token,
                  decoration: _input('API token'),
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: label,
                  decoration: _input('Label (optional)'),
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final prov = provider.value;
                      debugPrint('[CloudSources] connect -> provider=$prov '
                          'tokenLen=${token.text.trim().length}');
                      try {
                        final res = await http
                            .post(
                              Uri.parse('${StarlightConstants.apiBaseUrl}'
                                  '/ingestion/connections'),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                'provider': prov,
                                'token': token.text.trim(),
                                'label': label.text.trim(),
                              }),
                            )
                            .timeout(const Duration(seconds: 20));
                        if (res.statusCode == 200) {
                          if (mounted) Navigator.of(context).pop(true);
                        } else {
                          throw Exception(res.body);
                        }
                      } catch (e) {
                        debugPrint('[CloudSources] connect error: $e');
                        if (mounted) {
                          final nav = Navigator.of(context);
                          if (nav.canPop()) nav.pop();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                'Connect failed ($prov): ${e.toString().replaceFirst('Exception: ', '')}'),
                            backgroundColor: const Color(0xFFC62828),
                          ));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Connect & verify',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _delete(String id) async {
    await http.delete(Uri.parse(
        '${StarlightConstants.apiBaseUrl}/ingestion/connections/$id'));
    _load();
  }

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: const Color(0xFF8A8F98)),
        filled: true,
        fillColor: const Color(0xFFF5F6F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF212121)),
        title: Text('Cloud Log Sources',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: const Color(0xFF212121))),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFF1A237E)),
            onPressed: _add,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1A237E)),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A237E)))
          : _error != null
              ? Center(child: Text(_error!))
              : _conns.isEmpty
                  ? Center(
                      child: Text('No cloud sources yet. Tap + to connect.',
                          style: GoogleFonts.poppins(
                              color: const Color(0xFF8A8F98))))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _conns.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) => _connCard(_conns[i]),
                    ),
    );
  }

  Widget _connCard(_Conn c) {
    final icon = c.provider == 'render'
        ? Icons.cloud_rounded
        : c.provider == 'digitalocean'
            ? Icons.waves_rounded
            : Icons.train_rounded;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECEEF2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF1A237E)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(c.label,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF212121))),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFC62828), size: 18),
                  onPressed: () => _delete(c.id),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${c.provider} · ${c.count} services',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: const Color(0xFF8A8F98))),
            const SizedBox(height: 10),
            ...c.services.map((s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined,
                      color: Color(0xFF8A8F98), size: 18),
                  title: Text(s['name'] ?? s['id'],
                      style: GoogleFonts.poppins(fontSize: 13)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF8A8F98)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CloudLogViewerScreen(
                        connectionId: c.id,
                        serviceId: s['id'],
                        title: s['name'] ?? s['id'],
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _Conn {
  final String id;
  final String provider;
  final String label;
  final int count;
  final List<dynamic> services;
  _Conn({
    required this.id,
    required this.provider,
    required this.label,
    required this.count,
    required this.services,
  });
  factory _Conn.fromJson(Map<String, dynamic> j) => _Conn(
        id: j['id'],
        provider: j['provider'],
        label: j['label'] ?? j['provider'],
        count: j['count'] ?? (j['services'] as List? ?? []).length,
        services: j['services'] as List? ?? [],
      );
}

/// 🏛️ Live log viewer — connects to the backend's unified WebSocket proxy.
class CloudLogViewerScreen extends StatefulWidget {
  final String connectionId;
  final String serviceId;
  final String title;
  const CloudLogViewerScreen({
    super.key,
    required this.connectionId,
    required this.serviceId,
    required this.title,
  });

  @override
  State<CloudLogViewerScreen> createState() => _CloudLogViewerScreenState();
}

class _CloudLogViewerScreenState extends State<CloudLogViewerScreen> {
  final List<String> _lines = [];
  bool _connected = false;
  String? _error;

  late final WebSocketChannel _channel;

  @override
  void initState() {
    super.initState();
    final wsBase = StarlightConstants.apiBaseUrl
        .replaceFirst(RegExp(r'^https://'), 'wss://')
        .replaceFirst(RegExp(r'^http://'), 'ws://');
    final uri = Uri.parse(
        '$wsBase/ingestion/stream?connection_id=${widget.connectionId}'
        '&service_id=${widget.serviceId}');
    _channel = WebSocketChannel.connect(uri);
    _channel.stream.listen(_onMessage, onError: (e) {
      debugPrint('[CloudLogViewer] stream error: $e');
      if (mounted) setState(() => _error = e.toString());
    }, onDone: () {
      if (mounted) setState(() => _connected = false);
    });
    setState(() => _connected = true);
  }

  void _onMessage(dynamic msg) {
    try {
      final m = jsonDecode(msg as String) as Map<String, dynamic>;
      final line = m['line']?.toString() ?? msg.toString();
      if (m['kind'] == 'error') {
        debugPrint('[CloudLogViewer] backend error: $line');
        setState(() => _error = line);
        return;
      }
      setState(() => _lines.add(line));
    } catch (_) {
      setState(() => _lines.add(msg.toString()));
    }
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.title,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 15)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _connected
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFC62828),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_connected ? 'LIVE' : 'OFFLINE',
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1)),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(_error!,
                    style: GoogleFonts.poppins(color: const Color(0xFFFF8A80))),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _lines.length,
              itemBuilder: (_, i) => Text(
                _lines[i],
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFC9D1D9),
                  fontFamily: 'monospace',
                ),
              ),
            ),
    );
  }
}
