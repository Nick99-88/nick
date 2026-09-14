import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../models/video_models.dart';
import '../services/video_download_service.dart';

Future<void> showDownloadDialog(BuildContext context, {
  required VideoPost video,
  required Map<String, String> availableQualities,
}) async {
  String selectedType = 'video';
  String? selectedQuality;
  String? selectedQualityLabel;

  final qualities = availableQualities.entries.toList();

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isTablet = screenWidth > 600;

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.download, color: StarlightTheme.primaryBlue, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Download',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 22 : 18,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: isTablet ? 500 : null,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Video title: ${video.title}',
                        style: GoogleFonts.poppins(color: Colors.grey[300], fontSize: 13),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 20),
                    Text('Type', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _typeChip('Video', Icons.videocam, selectedType == 'video', () {
                          setDialogState(() {
                            selectedType = 'video';
                            selectedQuality = null;
                            selectedQualityLabel = null;
                          });
                        }),
                        const SizedBox(width: 12),
                        _typeChip('Audio', Icons.audiotrack, selectedType == 'audio', () {
                          setDialogState(() {
                            selectedType = 'audio';
                            selectedQuality = null;
                            selectedQualityLabel = null;
                          });
                        }),
                      ],
                    ),
                    if (selectedType == 'video' && qualities.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text('Quality', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 8),
                      ...qualities.map((q) => RadioListTile<String>(
                            value: q.key,
                            groupValue: selectedQuality,
                            title: Text(q.value,
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
                            activeColor: StarlightTheme.primaryBlue,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            onChanged: (v) {
                              setDialogState(() {
                                selectedQuality = v;
                                selectedQualityLabel = q.value;
                              });
                            },
                          )),
                    ],
                    if (selectedType == 'video' && qualities.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Default quality will be used',
                            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                      ),
                    if (selectedType == 'audio')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Audio-only download (MP3 format)',
                            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        VideoDownloadService.instance.startDownload(
                          video: video,
                          type: selectedType,
                          quality: selectedQuality,
                          qualityLabel: selectedQualityLabel,
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${selectedType == 'video' ? 'Video' : 'Audio'} download started'),
                            backgroundColor: StarlightTheme.primaryBlue,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StarlightTheme.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Download', style: GoogleFonts.poppins()),
                    ),
                  ],
          );
        },
      );
    },
  );
}

Widget _typeChip(String label, IconData icon, bool selected, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? StarlightTheme.primaryBlue.withOpacity(0.2) : Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: selected ? Border.all(color: StarlightTheme.primaryBlue, width: 2) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: selected ? StarlightTheme.primaryBlue : Colors.grey),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.poppins(
            color: selected ? Colors.white : Colors.grey,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          )),
        ],
      ),
    ),
  );
}
