import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:starlight_flutter/core/theme.dart';
import '../models/professional_content_model.dart';

class ProfessionalContentCard extends StatefulWidget {
  final ProfessionalContentModel content;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final bool showPreview;

  const ProfessionalContentCard({
    super.key,
    required this.content,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onShare,
    this.showPreview = false,
  });

  @override
  State<ProfessionalContentCard> createState() => _ProfessionalContentCardState();
}

class _ProfessionalContentCardState extends State<ProfessionalContentCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isExpired = widget.content.expiresAt != null && 
        widget.content.expiresAt!.isBefore(DateTime.now());
    
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
                    // Content type icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getContentTypeColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getContentTypeIcon(),
                        color: _getContentTypeColor(),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.content.title,
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
                            widget.content.description,
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
                
                // Content type and metadata
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Content type box - wider for Android
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getContentTypeColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getContentTypeColor().withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getContentTypeIcon(),
                              color: _getContentTypeColor(),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.content.contentType.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: _getContentTypeColor(),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Metadata info (if available)
                      if (widget.content.metadata != null && 
                          widget.content.metadata!.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.content.metadata!.length} metadata fields',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Preview (if enabled and content type supports it)
                if (widget.showPreview && widget.content.contentType == 'text') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      widget.content.content.length > 100 
                          ? '${widget.content.content.substring(0, 100)}...'
                          : widget.content.content,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                
                const SizedBox(height: 12),
                
                // Footer with stats and actions
                Row(
                  children: [
                    // View count
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
                            '${widget.content.viewCount ?? 0}',
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
                if (widget.content.expiresAt != null) ...[
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
                              ? 'Expired ${_formatDate(widget.content.expiresAt!)}'
                              : 'Expires ${_formatDate(widget.content.expiresAt!)}',
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
    } else if (!widget.content.isListed) {
      backgroundColor = Colors.orange;
      textColor = Colors.white;
      text = 'Unlisted';
    } else {
      backgroundColor = Colors.green;
      textColor = Colors.white;
      text = 'Listed';
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

  Color _getContentTypeColor() {
    switch (widget.content.contentType.toLowerCase()) {
      case 'text':
        return Colors.blue;
      case 'image':
        return Colors.green;
      case 'video':
        return Colors.red;
      case 'document':
        return Colors.orange;
      case 'link':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getContentTypeIcon() {
    switch (widget.content.contentType.toLowerCase()) {
      case 'text':
        return Icons.text_fields;
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'document':
        return Icons.description;
      case 'link':
        return Icons.link;
      default:
        return Icons.article;
    }
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
}
