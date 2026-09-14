import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/service_connection.dart';
import '../services/service_auth_service.dart';
import '../widgets/sheet_scaffold.dart';

/// 🏛️ Managed Cloud Architecture — global master key for multi-tenant routing.
class MasterKeySheet extends StatefulWidget {
  final ServiceProvider provider;
  const MasterKeySheet({super.key, required this.provider});

  @override
  State<MasterKeySheet> createState() => _MasterKeySheetState();
}

class _MasterKeySheetState extends State<MasterKeySheet> {
  final _auth = ServiceAuthService.instance;
  final _key = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await _auth.connectWithMasterKey(
        provider: widget.provider,
        masterKey: _key.text,
      );
      if (!mounted) return;
      // Backend holds the tenanted mapping; surface a synthetic connection.
      Navigator.of(context).pop(ServiceConnection(
        provider: widget.provider,
        method: AuthMethod.masterKey,
        accountLabel: '${widget.provider.label} org',
        isValid: true,
        lastValidated: DateTime.now(),
      ));
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
      title: '${widget.provider.label} · Managed Master Key',
      subtitle: 'Provide the organization master key. The backend routes '
          'your account to its own tenanted resources (multi-tenant).',
      children: [
        TextField(
          controller: _key,
          obscureText: _obscure,
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF212121)),
          decoration: svcInput('Master API key').copyWith(
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF8A8F98)),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
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
              : Text('Connect Organization',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
