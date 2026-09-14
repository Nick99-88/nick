import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/service_connection.dart';
import '../services/service_auth_service.dart';
import '../widgets/sheet_scaffold.dart';

/// 🏛️ Personal Access Token entry + live validation.
class PatSetupSheet extends StatefulWidget {
  final ServiceProvider provider;
  const PatSetupSheet({super.key, required this.provider});

  @override
  State<PatSetupSheet> createState() => _PatSetupSheetState();
}

class _PatSetupSheetState extends State<PatSetupSheet> {
  final _auth = ServiceAuthService.instance;
  final _token = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  void _showTokenSteps() {
    const steps = <(String, String)>[
      ('Go to Developer Settings',
          'Log in to GitHub.com. Click your profile picture in the top-right '
              'corner and select Settings. Scroll down to the bottom of the '
              'left sidebar and click Developer settings.'),
      ('Generate the Token',
          'In the left menu, select Personal access tokens → Fine-grained '
              'tokens (Recommended) or Tokens (classic). Click Generate new '
              'token. If prompted, enter your GitHub password or 2FA code.'),
      ('Set Token Details',
          'Note / Name: enter a descriptive name (e.g. Starlight Mobile App). '
              'Expiration: choose a period (30 / 90 days, or No expiration for '
              'classic). Repository Access: All repositories or Only select '
              'repositories.'),
      ('Pick Permissions',
          'For Fine-Grained tokens select exact permissions (e.g. read-only '
              'Issues on a repo). For classic, check repo for full repository '
              'access or the specific Read/Write scopes you need.'),
      ('Copy and Paste',
          'Scroll to the bottom and click Generate token. Copy the token '
              'immediately — it looks like ghp_... or github_pat_... and GitHub '
              'will never show it again. Paste it into the field above.'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.key_rounded,
                      color: Color(0xFF1A237E), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('How to create a Personal Access Token',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF212121),
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < steps.length; i++) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1A237E),
                                shape: BoxShape.circle,
                              ),
                              child: Text('${i + 1}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  )),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(steps[i].$1,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF212121),
                                      )),
                                  const SizedBox(height: 2),
                                  Text(steps[i].$2,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        height: 1.45,
                                        color: const Color(0xFF6B7078),
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (i != steps.length - 1)
                          const SizedBox(height: 14),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F6F8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Most apps use OAuth instead, unless they need '
                          'administrative-level permissions OAuth cannot '
                          'provide (e.g. managing billing or account keys).',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF8A8F98),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Got it',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final conn = await _auth.connectWithPat(
        provider: widget.provider,
        token: _token.text,
      );
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
      title: '${widget.provider.label} · Personal Access Token',
      subtitle:
          'Paste a token with the required scopes. We validate it live and '
          'store it encrypted — it never leaves secure storage.',
      children: [
        TextField(
          controller: _token,
          obscureText: _obscure,
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF212121)),
          decoration: svcInput('Access token').copyWith(
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF8A8F98)),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _showTokenSteps,
            icon: const Icon(Icons.help_outline_rounded,
                size: 16, color: Color(0xFF1A237E)),
            label: Text('Learn how to get your token',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A237E),
                )),
          ),
        ),
        svcError(_error),
      ],
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.provider.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text('Validate & Connect',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
