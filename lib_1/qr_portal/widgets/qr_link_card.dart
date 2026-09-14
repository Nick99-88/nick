import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:starlight_flutter/core/theme.dart';
import '../models/qr_link_model.dart';
import '../utils/qr_generator.dart';

class QRLinkCard extends StatefulWidget {
  final QRLinkModel qrLink;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final bool showQRCode;

  const QRLinkCard({
    super.key,
    required this.qrLink,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onShare,
    this.showQRCode = false,
  });

  @override
  State<QRLinkCard> createState() => _QRLinkCardState();
}

class _QRLinkCardState extends State<QRLinkCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isExpired = widget.qrLink.expiresAt != null && 
        widget.qrLink.expiresAt!.isBefore(DateTime.now());
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: _isHovered ? StarlightTheme.primaryBlue.withOpacity(0.3) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          onHover: (hovered) => setState(() => _isHovered = hovered),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title and status
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.qrLink.title,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isExpired ? Colors.grey : Colors.grey[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.qrLink.description,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status badge
                    _buildStatusBadge(isExpired),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Link URL with copy button
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.qrLink.link,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: StarlightTheme.primaryBlue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () => _copyToClipboard(widget.qrLink.link),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // QR Code display (if enabled)
                if (widget.showQRCode) ...[
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: QRGenerator.generateQRCode(
                        data: QRGenerator.generateQRLinkUrl(widget.qrLink.id),
                        size: 120,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Footer with stats and actions
                Row(
                  children: [
                    // Scan count
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: StarlightTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 14,
                            color: StarlightTheme.primaryBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.qrLink.scanCount ?? 0}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: StarlightTheme.primaryBlue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Action buttons
                    if (widget.onShare != null)
                      IconButton(
                        icon: const Icon(Icons.share, size: 20),
                        onPressed: widget.onShare,
                        visualDensity: VisualDensity.compact,
                      ),
                    
                    if (widget.onEdit != null)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: widget.onEdit,
                        visualDensity: VisualDensity.compact,
                      ),
                    
                    if (widget.onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: widget.onDelete,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                
                // Expiry info
                if (widget.qrLink.expiresAt != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isExpired ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: isExpired ? Colors.red : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isExpired 
                              ? 'Expired ${_formatDate(widget.qrLink.expiresAt!)}'
                              : 'Expires ${_formatDate(widget.qrLink.expiresAt!)}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: isExpired ? Colors.red : Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isExpired) {
    Color backgroundColor;
    Color textColor;
    String text;
    
    if (isExpired) {
      backgroundColor = Colors.red;
      textColor = Colors.white;
      text = 'Expired';
    } else if (!widget.qrLink.isListed) {
      backgroundColor = Colors.orange;
      textColor = Colors.white;
      text = 'Unlisted';
    } else {
      backgroundColor = Colors.green;
      textColor = Colors.white;
      text = 'Active';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes';
    } else {
      return 'Just now';
    }
  }

  void _copyToClipboard(String text) {
    // TODO: Implement clipboard functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link copied to clipboard'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
