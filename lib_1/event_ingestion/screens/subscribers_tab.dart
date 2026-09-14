import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ingestion_models.dart';
import '../services/ingestion_service.dart';
import '../widgets/common.dart';
import '../widgets/sheets.dart';

/// 🏛️ Subscribers tab — manage users who receive FCM critical-alert pushes.
class SubscribersTab extends StatefulWidget {
  const SubscribersTab({super.key});

  @override
  State<SubscribersTab> createState() => _SubscribersTabState();
}

class _SubscribersTabState extends State<SubscribersTab> {
  final _svc = IngestionService.instance;
  List<AlertSubscriber> _subs = [];
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
      _subs = await _svc.listSubscribers();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubscriberEditorSheet(
        onSave: (userId) => _svc.addSubscriber(userId),
      ),
    );
    _load();
  }

  Future<void> _delete(AlertSubscriber s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove subscriber?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          '${s.shortId} will no longer receive FCM critical alerts.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove',
                style: GoogleFonts.poppins(color: const Color(0xFFC62828))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteSubscriber(s.userId);
      showIngestionToast(context, 'Subscriber removed');
      _load();
    } catch (e) {
      showIngestionToast(context, 'Remove failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text('Subscriber',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const LoadingPulse(message: 'Loading subscribers…');
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load subscribers',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (_subs.isEmpty) {
      return EmptyState(
        icon: Icons.notifications_active_outlined,
        title: 'No alert subscribers',
        message:
            'Add a Neo4j user id to receive FCM critical-alert push notifications when severity crosses the alert threshold.',
        actionLabel: 'Add subscriber',
        onAction: _add,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF1A237E),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _subs.length,
        itemBuilder: (ctx, i) {
          final s = _subs[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFECEEF2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A1B9A).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      size: 20,
                      color: Color(0xFF6A1B9A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alert Subscriber',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF212121),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.shortId,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8A8F98),
                          fontFamily: 'monospace',
                        ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Color(0xFFC62828)),
                    onPressed: () => _delete(s),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
