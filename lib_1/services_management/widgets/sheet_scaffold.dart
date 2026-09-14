import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🏛️ Shared light-themed bottom-sheet scaffold for the service flows.
class SheetScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? footer;

  const SheetScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 8,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFECEEF2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF212121),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF8A8F98),
            ),
          ),
          const SizedBox(height: 18),
          ...children,
          if (footer != null) ...[const SizedBox(height: 18), footer!],
        ],
      ),
    );
  }
}

InputDecoration svcInput(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF5F6F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1A237E), width: 1.5),
      ),
    );

Widget svcError(String? error) {
  if (error == null || error.isEmpty) return const SizedBox.shrink();
  return Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFC62828).withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFC62828).withOpacity(0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded,
            color: Color(0xFFC62828), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            error,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFFC62828),
            ),
          ),
        ),
      ],
    ),
  );
}
