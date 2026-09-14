import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ingestion_models.dart';
import 'common.dart';

const Color _ink = Color(0xFF212121);
const Color _muted = Color(0xFF8A8F98);
const Color _line = Color(0xFFECEEF2);
const Color _brand = Color(0xFF1A237E);

/// Bottom sheet for creating / editing an ingestion source.
///
/// Sends the flat field shape expected by `POST/PUT /api/v1/ingest/sources`:
///   {name, type, enabled, url?, token?, webhook_secret?, poll_interval?, ...}
class SourceEditorSheet extends StatefulWidget {
  final IngestionSource? existing;
  final Future<IngestionSource> Function(Map<String, dynamic>) onSave;
  const SourceEditorSheet({super.key, this.existing, required this.onSave});

  @override
  State<SourceEditorSheet> createState() => _SourceEditorSheetState();
}

class _SourceEditorSheetState extends State<SourceEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late SourceType _type;
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _token = TextEditingController();
  final _secret = TextEditingController();
  final _pollInterval = TextEditingController();
  bool _enabled = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _type = s?.type ?? SourceType.websocket;
    _name.text = s?.name ?? '';
    _url.text = s?.url ?? '';
    _secret.text = s?.webhookSecret ?? '';
    _enabled = s?.enabled ?? true;
    _pollInterval.text = (s?.pollInterval ?? 3).toString();
    if (s != null) {
      _token.text = (s.raw['token'] ?? s.raw['api_key'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _token.dispose();
    _secret.dispose();
    _pollInterval.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildPayload() {
    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'type': _type.value,
      'enabled': _enabled,
    };
    if (_type == SourceType.webhook) {
      if (_secret.text.trim().isNotEmpty) {
        payload['webhook_secret'] = _secret.text.trim();
      }
    } else {
      if (_url.text.trim().isNotEmpty) payload['url'] = _url.text.trim();
      if (_token.text.trim().isNotEmpty) payload['token'] = _token.text.trim();
      if (_type == SourceType.polling) {
        payload['poll_interval'] =
            int.tryParse(_pollInterval.text.trim()) ?? 3;
      }
    }
    return payload;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_buildPayload());
      if (mounted) {
        showIngestionToast(
          context,
          widget.existing == null
              ? 'Source created — supervisor will connect'
              : 'Source updated',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showIngestionToast(context, 'Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              isEdit ? 'Edit Source' : 'New Ingestion Source',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                controller: scroll,
                children: [
                  Text(
                    'Integration type',
                    style: GoogleFonts.poppins(fontSize: 13, color: _muted),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<SourceType>(
                    segments: SourceType.values.map((t) {
                      return ButtonSegment<SourceType>(
                        value: t,
                        label: Text(t.label),
                        icon: Icon(t.icon.icon),
                      );
                    }).toList(),
                    selected: {_type},
                    onSelectionChanged: (s) =>
                        setState(() => _type = s.first),
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) =>
                          states.contains(WidgetState.selected)
                              ? _brand.withOpacity(0.12)
                              : null),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _field(
                          'Display name',
                          _name,
                          hint: 'e.g. Production API Gateway',
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Required' : null,
                        ),
                        if (_type == SourceType.webhook)
                          _field(
                            'Webhook secret (HMAC-SHA256)',
                            _secret,
                            hint: 'shared secret used to verify POST /logs',
                            obscure: true,
                          )
                        else ...[
                          _field(
                            _type == SourceType.websocket
                                ? 'WebSocket URL (wss://...)'
                                : 'Polling endpoint URL (https://...)',
                            _url,
                            hint: _type == SourceType.websocket
                                ? 'wss://logs.example.com/stream'
                                : 'https://api.example.com/events',
                          ),
                          _field(
                            'Bearer token (optional)',
                            _token,
                            hint: 'Authorization: Bearer <token>',
                          ),
                          if (_type == SourceType.polling)
                            _field(
                              'Poll interval (seconds)',
                              _pollInterval,
                              hint: '3',
                            ),
                        ],
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Enabled (connect immediately)',
                            style: GoogleFonts.poppins(fontSize: 13, color: _ink),
                          ),
                          value: _enabled,
                          onChanged: (v) => setState(() => _enabled = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _ink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isEdit ? 'Save Changes' : 'Create Source',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    String? hint,
    bool obscure = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 13, color: _muted),
          ),
          const SizedBox(height: 7),
          TextFormField(
            controller: c,
            obscureText: obscure,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
              filled: true,
              fillColor: const Color(0xFFF5F6F8),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _brand, width: 1.5),
              ),
            ),
            style: GoogleFonts.poppins(fontSize: 13, color: _ink),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet showing full event detail + raw JSON payload.
class EventDetailSheet extends StatelessWidget {
  final IngestionEvent event;
  const EventDetailSheet({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = event.severity.theme;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: _line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(theme.bg),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(event.severity.icon, color: Color(theme.fg)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SeverityBadge(severity: event.severity),
                      const SizedBox(height: 4),
                      Text(
                        event.sourceName.isEmpty
                            ? 'Unknown source'
                            : event.sourceName,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: _muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    showIngestionToast(context, 'Payload copied');
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                controller: scroll,
                children: [
                  _row('Event ID', event.id.isEmpty ? '—' : event.id),
                  _row('Received', event.receivedAt.toLocal().toString()),
                  _row('Source ID',
                      event.sourceId.isEmpty ? '—' : event.sourceId),
                  if (event.tags.isNotEmpty)
                    _row('Tags', event.tags.map((t) => '#$t').join('  ')),
                  const SizedBox(height: 10),
                  Text(
                    'Message',
                    style: GoogleFonts.poppins(fontSize: 13, color: _muted),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      event.message,
                      style: GoogleFonts.poppins(fontSize: 13, color: _ink),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Raw payload',
                    style: GoogleFonts.poppins(fontSize: 13, color: _muted),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6F8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFECEEF2)),
                    ),
                    child: SelectableText(
                      event.prettyPayload,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF212121),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              k,
              style: GoogleFonts.poppins(fontSize: 12, color: _muted),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet to add an alert subscriber (a Neo4j `user_id`).
class SubscriberEditorSheet extends StatefulWidget {
  final Future<void> Function(String) onSave;
  const SubscriberEditorSheet({super.key, required this.onSave});

  @override
  State<SubscriberEditorSheet> createState() => _SubscriberEditorSheetState();
}

class _SubscriberEditorSheetState extends State<SubscriberEditorSheet> {
  final _userId = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _userId.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_userId.text.trim().isEmpty) {
      showIngestionToast(context, 'User ID is required', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(_userId.text.trim());
      if (mounted) {
        showIngestionToast(context, 'Subscriber added');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showIngestionToast(context, 'Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Add Alert Subscriber',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Subscribers are Neo4j user ids; their FCM tokens receive critical alerts.',
              style: GoogleFonts.poppins(fontSize: 12, color: _muted),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: scroll,
                children: [
                  _field('User ID', _userId, hint: 'e.g. user:507f1f77bcf86cd799439011'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _ink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Save Subscriber',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 13, color: _muted),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: c,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]),
            filled: true,
            fillColor: const Color(0xFFF5F6F8),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _brand, width: 1.5),
            ),
          ),
          style: GoogleFonts.poppins(fontSize: 13, color: _ink),
        ),
      ],
    );
  }
}
