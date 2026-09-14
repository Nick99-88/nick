import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:starlight_flutter/core/theme.dart';
import '../models/ingestion_models.dart';

/// 🏛️ Shared, reusable widgets for the ingestion UI. All follow the
/// Starlight convention: white cards, soft shadows, rounded corners, Poppins,
/// and the institutional brand palette from [StarlightTheme].

const Color _ink = StarlightTheme.secondaryBlack;
const Color _muted = Color(0xFF8A8F98);
const Color _line = Color(0xFFECEEF2);
const Color _brand = StarlightTheme.primaryBlue;
const Color _success = StarlightTheme.accentGreen;
const Color _danger = StarlightTheme.errorRed;

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const SectionTitle({super.key, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: GoogleFonts.poppins(fontSize: 12, color: _muted),
                  ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class SeverityBadge extends StatelessWidget {
  final EventSeverity severity;
  final double scale;
  const SeverityBadge({super.key, required this.severity, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final t = severity.theme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 4 * scale,
      ),
      decoration: BoxDecoration(
        color: Color(t.bg),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(t.fg).withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(severity.icon, size: 13 * scale, color: Color(t.fg)),
          SizedBox(width: 4 * scale),
          Text(
            severity.label,
            style: GoogleFonts.poppins(
              fontSize: 11 * scale,
              fontWeight: FontWeight.w600,
              color: Color(t.fg),
            ),
          ),
        ],
      ),
    );
  }
}

class TypeChip extends StatelessWidget {
  final SourceType type;
  const TypeChip({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final spec = type.icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Color(spec.color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon, size: 13, color: Color(spec.color)),
          const SizedBox(width: 5),
          Text(
            type.label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(spec.color),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool pulse;
  const StatusDot({
    super.key,
    required this.color,
    required this.label,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: pulse
            ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8, spreadRadius: 1)]
            : null,
      ),
    );
    final animated = pulse
        ? dot.animate(onPlay: (c) => c.repeat()).scale(
              duration: 900.ms,
              begin: const Offset(1, 1),
              end: const Offset(1.5, 1.5),
              curve: Curves.easeInOut,
            )
        : dot;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        animated,
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: _muted, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? hint;
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, color: _muted),
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                hint!,
                style: GoogleFonts.poppins(fontSize: 10.5, color: _muted.withOpacity(0.7)),
              ),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _brand.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 42, color: _brand.withOpacity(0.7)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: _muted),
            ),
            if (actionLabel != null && onAction != null)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: ElevatedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(actionLabel!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LoadingPulse extends StatelessWidget {
  final String? message;
  const LoadingPulse({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3, color: _brand),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                message!,
                style: GoogleFonts.poppins(fontSize: 13, color: _muted),
              ),
            ),
        ],
      ),
    );
  }
}

void showIngestionToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: error ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ),
  );
}

class SeverityBar extends StatelessWidget {
  final Map<EventSeverity, int> counts;
  final EventSeverity? selected;
  final ValueChanged<EventSeverity?> onSelected;
  const SeverityBar({
    super.key,
    required this.counts,
    this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = EventSeverity.values.where((s) => s != EventSeverity.unknown);
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final sev = items.elementAt(i);
          final active = selected == sev;
          final color = Color(sev.theme.fg);
          return FilterChip(
            selected: active,
            onSelected: (_) => onSelected(active ? null : sev),
            label: Text(
              '${sev.label} ${counts[sev] ?? 0}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : color,
              ),
            ),
            backgroundColor: color.withOpacity(0.1),
            selectedColor: color,
            showCheckmark: false,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 6),
          );
        },
      ),
    );
  }
}
