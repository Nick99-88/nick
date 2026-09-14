import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ingestion_models.dart';
import 'common.dart';

const Color _ink = Color(0xFF212121);

class SourceCard extends StatelessWidget {
  final IngestionSource source;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTest;
  final ValueChanged<bool> onToggle;

  const SourceCard({
    super.key,
    required this.source,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onTest,
    required this.onToggle,
  });

  Color get _statusColor {
    if (!source.enabled) return const Color(0xFF9E9E9E);
    switch (source.status) {
      case 'no_secret':
        return const Color(0xFFF9A825);
      case 'listening':
      case 'connected':
        return const Color(0xFF2E7D32);
      case 'idle':
        return const Color(0xFF1565C0);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String get _statusLabel {
    if (!source.enabled) return 'Disabled';
    switch (source.status) {
      case 'no_secret':
        return 'Needs secret';
      case 'listening':
        return 'Listening';
      case 'connected':
        return 'Live';
      case 'idle':
        return 'Idle';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = source.type.icon;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECEEF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Color(spec.color).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(spec.icon, size: 20, color: Color(spec.color)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source.name,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            source.displayUrl,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: const Color(0xFF8A8F98),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: source.enabled,
                      onChanged: onToggle,
                      activeColor: const Color(0xFF2E7D32),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TypeChip(type: source.type),
                    const SizedBox(width: 8),
                    StatusDot(
                      color: _statusColor,
                      label: _statusLabel,
                      pulse: source.isLive,
                    ),
                    const Spacer(),
                    if (source.lastEventAt != null)
                      Text(
                        'last ${source.lastEventAt!.hour}:${source.lastEventAt!.minute.toString().padLeft(2, '0')}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF8A8F98),
                        ),
                      ),
                ],
              ),
              if (source.status == 'no_secret') ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 14, color: Color(0xFFC62828)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No webhook secret configured — incoming pushes will be rejected.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: Color(0xFFC62828),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
                Row(
                  children: [
                    _ActionChip(
                      icon: Icons.flash_on_rounded,
                      label: 'Test',
                      onTap: onTest,
                    ),
                    const SizedBox(width: 8),
                    _ActionChip(
                      icon: Icons.edit_outlined,
                      label: 'Edit',
                      onTap: onEdit,
                    ),
                    const SizedBox(width: 8),
                    _ActionChip(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      danger: true,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06, end: 0);
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFC62828) : const Color(0xFF1A237E);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final IngestionEvent event;
  final VoidCallback onTap;
  const EventCard({super.key, required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = event.severity.theme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 84,
                decoration: BoxDecoration(
                  color: Color(theme.fg),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SeverityBadge(severity: event.severity),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              event.sourceName.isEmpty
                                  ? 'Unknown source'
                                  : event.sourceName,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF8A8F98),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            event.relativeTime,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF8A8F98),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.message,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          color: _ink,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (event.tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: event.tags.take(4).map((t) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F6F8),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#$t',
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
