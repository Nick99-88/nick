import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/service_connection.dart';
import '../widgets/sheet_scaffold.dart';

/// 🏛️ Lets the user pick which authentication method to use for a provider.
class MethodChooserSheet extends StatelessWidget {
  final ServiceProvider provider;
  const MethodChooserSheet({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final methods = provider.supportedMethods;
    return SheetScaffold(
      title: 'Connect ${provider.label}',
      subtitle: 'Choose how Starlight should authenticate with this provider.',
      children: methods
          .map((m) => _methodTile(context, m))
          .toList(),
    );
  }

  Widget _methodTile(BuildContext context, AuthMethod m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECEEF2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).pop(m),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: provider.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(m.icon, color: provider.accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.label,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.description,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: const Color(0xFF8A8F98),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF8A8F98)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
