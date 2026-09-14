import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ingestion_models.dart';
import '../services/ingestion_service.dart';
import '../widgets/common.dart';
import '../widgets/cards.dart';
import '../widgets/sheets.dart';

/// 🏛️ Events tab — live feed of ingested events with filters & detail view.
class EventsTab extends StatefulWidget {
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  final _svc = IngestionService.instance;
  List<IngestionEvent> _events = [];
  List<IngestionSource> _sources = [];
  bool _loading = true;
  String? _error;
  EventSeverity? _severity;
  String? _sourceId;
  String _query = '';
  bool _autoRefresh = false;
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSources();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadSources() async {
    try {
      _sources = await _svc.listSources();
    } catch (_) {
      _sources = [];
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      _events = await _svc.listEvents(
        sourceId: _sourceId,
        severity: _severity,
        limit: 200,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<IngestionEvent> get _filtered {
    if (_query.trim().isEmpty) return _events;
    final q = _query.toLowerCase();
    return _events
        .where((e) =>
            e.message.toLowerCase().contains(q) ||
            e.sourceName.toLowerCase().contains(q) ||
            e.tags.any((t) => t.toLowerCase().contains(q)))
        .toList();
  }

  void _openEvent(IngestionEvent e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventDetailSheet(event: e),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search message, source or tag…',
                    hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF212121)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sourceId,
                          hint: Text('All sources',
                              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500])),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All sources'),
                            ),
                            ..._sources.map((s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(s.name,
                                      style: GoogleFonts.poppins(fontSize: 13)),
                                )),
                          ],
                          onChanged: (v) {
                            setState(() => _sourceId = v);
                            _load();
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      setState(() => _autoRefresh = !_autoRefresh);
                      if (_autoRefresh) _startAuto();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: _autoRefresh
                            ? const Color(0xFF1A237E)
                            : const Color(0xFFF5F6F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.autorenew_rounded,
                        size: 18,
                        color: _autoRefresh ? Colors.white : const Color(0xFF8A8F98),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SeverityBar(
                counts: _severityCounts,
                selected: _severity,
                onSelected: (s) {
                  setState(() => _severity = s);
                  _load();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _body(),
        ),
      ],
    );
  }

  Map<EventSeverity, int> get _severityCounts {
    final m = <EventSeverity, int>{};
    for (final e in _events) {
      m[e.severity] = (m[e.severity] ?? 0) + 1;
    }
    return m;
  }

  void _startAuto() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 8));
      if (!_autoRefresh || !mounted) return false;
      await _load();
      return _autoRefresh;
    });
  }

  Widget _body() {
    if (_loading) {
      return const LoadingPulse(message: 'Streaming events…');
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Failed to load events',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    final list = _filtered;
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.inbox_rounded,
        title: _query.isNotEmpty ? 'No matching events' : 'No events yet',
        message: _query.isNotEmpty
            ? 'Try a different search term or filter.'
            : 'Events ingested from your sources will appear here in real time.',
        actionLabel: 'Refresh',
        onAction: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF1A237E),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: list.length,
        itemBuilder: (ctx, i) => EventCard(
          event: list[i],
          onTap: () => _openEvent(list[i]),
        ),
      ),
    );
  }
}
