import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/service_connection.dart';
import '../services/service_auth_service.dart';
import '../widgets/sheet_scaffold.dart';

/// 🏛️ OAuth 2.0 browser sign-in. Backend exchanges the code for tokens.
class OAuthConnectSheet extends StatefulWidget {
  final ServiceProvider provider;
  const OAuthConnectSheet({super.key, required this.provider});

  @override
  State<OAuthConnectSheet> createState() => _OAuthConnectSheetState();
}

class _OAuthConnectSheetState extends State<OAuthConnectSheet> {
  final _auth = ServiceAuthService.instance;
  bool _loading = false;
  String? _error;

  Future<void> _start() async {
    setState(() => _loading = true);
    try {
      final conn = await _auth.connectWithOAuth(provider: widget.provider);
      if (!mounted) return;
      Navigator.of(context).pop(conn);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: '${widget.provider.label} · OAuth 2.0',
      subtitle: 'You will be redirected to ${widget.provider.label} to '
          'authorize Starlight. The backend securely stores the tokens.',
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFECEEF2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.open_in_browser_rounded,
                  color: Color(0xFF1A237E), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The browser redirects back to the app via '
                  'starlight://oauth/callback. The backend exchanges the '
                  'code for tokens.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF8A8F98),
                  ),
                ),
              ),
            ],
          ),
        ),
        svcError(_error),
      ],
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _start,
          icon: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.login_rounded, size: 18),
          label: Text('Authorize in browser',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.provider.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
