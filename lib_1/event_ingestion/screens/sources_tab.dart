import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ingestion_models.dart';
import '../services/ingestion_service.dart';
import '../widgets/common.dart';
import '../widgets/cards.dart';
import '../widgets/sheets.dart';

/// 🏛️ Sources tab — register, monitor, edit & test ingestion sources.
class SourcesTab extends StatefulWidget {
  const SourcesTab({super.key});

  @override
  State<SourcesTab> createState() => _SourcesTabState();
}

class _SourcesTabState extends State<SourcesTab> {
  final _svc = IngestionService.instance;
  List<IngestionSource> _sources = [];
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
      final results = await Future.wait([
        _svc.listSources(),
        _svc.getStatus(),
      ]);
      final sources = results[0] as List<IngestionSource>;
      final status = results[1] as IngestionStatus;
      final running = {
        for (final w in status.workers) w.sourceId: w.running
      };
      _sources = sources.map((s) {
        if (!s.enabled) return s.copyWith(status: 'disabled');
        if (s.type == SourceType.webhook) {
          return s.copyWith(status: s.webhookSecret == null ? 'no_secret' : 'listening');
        }
        final live = running[s.id] ?? false;
        return s.copyWith(status: live ? 'connected' : 'idle');
      }).toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(IngestionSource s, bool enabled) async {
    final idx = _sources.indexWhere((x) => x.id == s.id);
    if (idx == -1) return;
    setState(() {
      _sources[idx] = _sources[idx]
          .copyWith(enabled: enabled, status: enabled ? 'idle' : 'disabled');
    });
    try {
      await _svc.setSourceEnabled(s.id, enabled);
    } catch (e) {
      showIngestionToast(context, 'Toggle failed: $e', error: true);
      _load();
    }
  }

  Future<void> _delete(IngestionSource s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete source?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'This will stop ingestion from "${s.name}" and remove its config.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.poppins(color: const Color(0xFFC62828))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteSource(s.id);
      showIngestionToast(context, 'Source deleted');
      _load();
    } catch (e) {
      showIngestionToast(context, 'Delete failed: $e', error: true);
    }
  }

  Future<void> _edit(IngestionSource s) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SourceEditorSheet(
        existing: s,
        onSave: (p) => _svc.updateSource(s.id, p),
      ),
    );
    _load();
  }

  Future<void> _create() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SourceEditorSheet(
        onSave: (p) => _svc.createSource(p),
      ),
    );
    _load();
  }

  Future<void> _test(IngestionSource s) async {
    if (s.type != SourceType.webhook) {
      showIngestionToast(context,
          'Only webhook sources accept direct push — use Status tab to push a test event.');
      return;
    }
    if (s.webhookSecret == null) {
      showIngestionToast(context, 'Set a webhook_secret on this source first.',
          error: true);
      return;
    }
    try {
      await _svc.pushTestEvent(
        sourceId: s.id,
        secret: s.webhookSecret!,
        message: 'Test event from Starlight console',
        severity: 'info',
      );
      showIngestionToast(context, 'Test event pushed to /logs');
      _load();
    } catch (e) {
      showIngestionToast(context, 'Push failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text('Source', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const LoadingPulse(message: 'Loading sources…');
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not reach the ingestion API',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (_sources.isEmpty) {
      return EmptyState(
        icon: Icons.add_link_rounded,
        title: 'No ingestion sources yet',
        message:
            'Connect a WebSocket stream, polling endpoint, or incoming webhook to start ingesting external events.',
        actionLabel: 'Add source',
        onAction: _create,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF1A237E),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sources.length,
        itemBuilder: (ctx, i) {
          final s = _sources[i];
          return SourceCard(
            source: s,
            onTap: () => _edit(s),
            onEdit: () => _edit(s),
            onDelete: () => _delete(s),
            onTest: () => _test(s),
            onToggle: (v) => _toggle(s, v),
          );
        },
      ),
    );
  }
}
