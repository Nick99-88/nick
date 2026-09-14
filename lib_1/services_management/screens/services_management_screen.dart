import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/service_connection.dart';
import '../services/service_auth_service.dart';
import 'method_chooser_sheet.dart';
import 'pat_setup_sheet.dart';
import 'oauth_connect_sheet.dart';
import 'master_key_sheet.dart';
import 'github_repos_screen.dart';

/// 🏛️ GitHub — connect to deploy & sync repositories, issues, PRs and more.
class ServicesManagementScreen extends StatefulWidget {
  const ServicesManagementScreen({super.key});

  @override
  State<ServicesManagementScreen> createState() =>
      _ServicesManagementScreenState();
}

class _ServicesManagementScreenState extends State<ServicesManagementScreen> {
  final _auth = ServiceAuthService.instance;
  ServiceConnection? _connection;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    for (final m in AuthMethod.values) {
      final c = await _auth.restore(ServiceProvider.github, m);
      if (c != null) _connection = c;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _connect() async {
    final method = await showModalBottomSheet<AuthMethod>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MethodChooserSheet(provider: ServiceProvider.github),
    );
    if (method == null) return;

    ServiceConnection? result;
    if (method == AuthMethod.pat) {
      result = await showModalBottomSheet<ServiceConnection>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PatSetupSheet(provider: ServiceProvider.github),
      );
    } else if (method == AuthMethod.oauth) {
      result = await showModalBottomSheet<ServiceConnection>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => OAuthConnectSheet(provider: ServiceProvider.github),
      );
    } else {
      result = await showModalBottomSheet<ServiceConnection>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MasterKeySheet(provider: ServiceProvider.github),
      );
    }

    if (result != null) {
      setState(() => _connection = result);
      _toast('GitHub connected via ${result.method.label}');
    }
  }

  Future<void> _disconnect() async {
    if (_connection == null) return;
    await _auth.disconnect(ServiceProvider.github, _connection!.method);
    setState(() => _connection = null);
    _toast('GitHub disconnected');
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: error ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  final Color _gh = const Color(0xFF24292F);

  @override
  Widget build(BuildContext context) {
    final connected = _connection != null;
    final accent = ServiceProvider.github.accent;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF212121)),
        title: Text('GitHub',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF212121),
            )),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A237E)),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Branded GitHub hero ──
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_gh, const Color(0xFF3C4049)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.code_rounded,
                            color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 14),
                      Text('GitHub',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                      const SizedBox(height: 6),
                      Text(
                        connected
                            ? 'Connected${_connection!.accountLabel != null ? ' · ${_connection!.accountLabel}' : ''}'
                            : 'Not connected',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: connected
                              ? const Color(0xFF2E7D32).withOpacity(0.9)
                              : Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          connected ? 'ACTIVE' : 'OFFLINE',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // ── Connect / Reconnect ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _connect,
                    icon: Icon(
                      connected ? Icons.sync_rounded : Icons.add_link_rounded,
                      size: 18,
                    ),
                    label: Text(connected ? 'Reconnect' : 'Connect GitHub'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                if (connected) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _disconnect,
                      icon: const Icon(Icons.link_off_rounded, size: 16),
                      label: const Text('Disconnect'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC62828),
                        side: const BorderSide(
                            color: Color(0xFFC62828), width: 0.8),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const GithubReposScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.folder_special_outlined, size: 16),
                      label: const Text('Manage Repositories'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: accent.withOpacity(0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                // ── What you can do ──
                Text('What you can do',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF212121),
                    )),
                const SizedBox(height: 12),
                _feature(Icons.folder_copy_outlined, 'Manage repositories',
                    'Browse, create and delete repos on your account.'),
                _feature(Icons.description_outlined, 'Issues & Pull Requests',
                    'Open, edit and review code collaboration.'),
                _feature(Icons.bolt_outlined, 'Actions & CI/CD',
                    'Trigger workflows, view runs and secrets.'),
              ],
            ),
    );
  }

  Widget _feature(IconData icon, String title, String subtitle) {
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A237E).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF1A237E), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF212121),
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF8A8F98),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
