import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ingestion_models.dart';
import '../services/ingestion_service.dart';
import '../widgets/common.dart';

/// 🏛️ Status tab — ingestion engine health, worker state, config & test push.
class StatusTab extends StatefulWidget {
  const StatusTab({super.key});

  @override
  State<StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<StatusTab> {
  final _svc = IngestionService.instance;
  IngestionStatus? _status;
  List<IngestionSource> _sources = [];
  bool _loading = true;
  bool _toggling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _svc.getStatus(),
        _svc.listSources(),
      ]);
      _status = results[0] as IngestionStatus;
      _sources = results[1] as List<IngestionSource>;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pushTest() async {
    final webhookSources =
        _sources.where((s) => s.type == SourceType.webhook).toList();
    final target = webhookSources.isNotEmpty ? webhookSources.first : null;

    final sev = ValueNotifier<EventSeverity>(EventSeverity.info);
    final msg = TextEditingController(
      text: 'Manual test event from Starlight console',
    );
    final src = ValueNotifier<IngestionSource?>(target);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Push test event',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Source',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF8A8F98))),
              const SizedBox(height: 6),
              ValueListenableBuilder<IngestionSource?>(
                valueListenable: src,
                builder: (_, v, __) => DropdownButtonFormField<IngestionSource?>(
                  value: v,
                  isExpanded: true,
                  items: [
                    if (webhookSources.isEmpty)
                      const DropdownMenuItem(
                        value: null,
                        child: Text('No webhook sources'),
                      ),
                    ...webhookSources.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.name),
                        )),
                  ],
                  onChanged: (val) => src.value = val,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF5F6F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Severity',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF8A8F98))),
              const SizedBox(height: 6),
              ValueListenableBuilder<EventSeverity>(
                valueListenable: sev,
                builder: (_, v, __) => Wrap(
                  spacing: 8,
                  children: EventSeverity.values
                      .where((s) => s != EventSeverity.unknown)
                      .map((s) {
                    final active = sev.value == s;
                    final c = Color(s.theme.fg);
                    return ChoiceChip(
                      selected: active,
                      onSelected: (_) => sev.value = s,
                      label: Text(s.label),
                      backgroundColor: c.withOpacity(0.1),
                      selectedColor: c,
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : c,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Text('Message',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF8A8F98))),
              const SizedBox(height: 6),
              TextField(
                controller: msg,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF5F6F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: GoogleFonts.poppins(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () async {
              final s = src.value;
              if (s == null) {
                showIngestionToast(context, 'Create a webhook source first',
                    error: true);
                return;
              }
              if (s.webhookSecret == null) {
                showIngestionToast(context, 'Set a webhook_secret on the source',
                    error: true);
                return;
              }
              Navigator.pop(ctx);
              try {
                await _svc.pushTestEvent(
                  sourceId: s.id,
                  secret: s.webhookSecret!,
                  message: msg.text,
                  severity: sev.value.name,
                );
                showIngestionToast(context, 'Test event pushed to /logs');
                _load();
              } catch (e) {
                showIngestionToast(context, 'Push failed: $e', error: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E)),
            child: Text('Push',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    msg.dispose();
  }

  String _sourceName(String id) {
    final s = _sources.where((x) => x.id == id).firstOrNull;
    return s?.name ?? id;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingPulse(message: 'Reading system status…');
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Status unavailable',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    final st = _status!;
    final running = st.activeWorkers;
    final total = st.workers.length;
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF1A237E),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _engineCard(st),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: [
              StatTile(
                label: 'Stored events',
                value: '${st.storedEvents}',
                icon: Icons.storage_rounded,
                color: const Color(0xFF1A237E),
              ),
              StatTile(
                label: 'Active workers',
                value: '$running / $total',
                icon: Icons.cable_rounded,
                color: const Color(0xFF00897B),
              ),
              StatTile(
                label: 'Auto-expire (TTL)',
                value: '${IngestionStatus.ttlDays}d',
                icon: Icons.timer_rounded,
                color: const Color(0xFF6A1B9A),
                hint: 'server default',
              ),
              StatTile(
                label: 'Alert cooldown',
                value: '${IngestionStatus.cooldownSeconds}s',
                icon: Icons.notifications_paused_rounded,
                color: const Color(0xFFE65100),
                hint: 'debounce window',
              ),
            ],
          ),
          const SizedBox(height: 14),
          SectionTitle(
            title: 'Workers',
            subtitle: 'Reconciled against enabled WebSocket / Polling sources',
          ),
          const SizedBox(height: 8),
          if (st.workers.isEmpty)
            _placeholder('No outbound workers running')
          else
            ...st.workers.map(_workerTile),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _pushTest,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Push test event'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _engineCard(IngestionStatus st) {
    final enabled = st.enabled;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: enabled
              ? [const Color(0xFF1A237E), const Color(0xFF283593)]
              : [const Color(0xFF424242), const Color(0xFF616161)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (enabled ? const Color(0xFF1A237E) : Colors.grey)
                .withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              enabled ? Icons.bolt_rounded : Icons.pause_circle_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled ? 'Ingestion Engine Online' : 'Ingestion Engine Paused',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled
                      ? 'Workers auto-reconnect to enabled sources'
                      : 'No active ingestion while paused',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: enabled
                  ? Colors.greenAccent.withOpacity(0.2)
                  : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              enabled ? 'ENABLED' : 'DISABLED',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workerTile(WorkerStatus w) {
    final color = w.running
        ? const Color(0xFF2E7D32)
        : const Color(0xFF9E9E9E);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECEEF2)),
      ),
      child: Row(
        children: [
          Icon(Icons.cable_rounded, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sourceName(w.sourceId),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212121),
                  ),
                ),
                Text(
                  w.sourceId,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A8F98),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          StatusDot(
            color: color,
            label: w.running ? 'Running' : 'Stopped',
            pulse: w.running,
          ),
        ],
      ),
    );
  }

  Widget _placeholder(String text) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF8A8F98)),
      ),
    );
  }
}
