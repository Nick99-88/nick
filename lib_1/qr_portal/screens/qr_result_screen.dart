import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:starlight_flutter/core/theme.dart';
import 'package:starlight_flutter/qr_portal/models/qr_link_model.dart';

class QRResultScreen extends StatefulWidget {
  final QRLinkModel qrLink;
  
  const QRResultScreen({super.key, required this.qrLink});

  @override
  State<QRResultScreen> createState() => _QRResultScreenState();
}

class _QRResultScreenState extends State<QRResultScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'QR Link Details',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: StarlightTheme.primaryBlue,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // QR Code Display
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Scan This QR Code',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: QrImageView(
                          data: widget.qrLink.link,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Link Details
            Text(
              'Link Details',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            
            // Title
            _buildDetailCard('Title', widget.qrLink.title),
            const SizedBox(height: 12),
            
            // Description
            _buildDetailCard('Description', widget.qrLink.description),
            const SizedBox(height: 12),
            
            // Link
            _buildDetailCard('Link', widget.qrLink.link),
            const SizedBox(height: 12),
            
            // Status
            _buildDetailCard('Status', widget.qrLink.isListed ? 'Listed' : 'Unlisted'),
            const SizedBox(height: 12),
            
            // Created At
            _buildDetailCard('Created At', _formatDate(widget.qrLink.createdAt)),
            
            // Expires At
            if (widget.qrLink.expiresAt != null) ...[
              _buildDetailCard('Expires At', _formatDate(widget.qrLink.expiresAt!)),
            ],
            
            // Scan Count
            _buildDetailCard('Scan Count', widget.qrLink.scanCount.toString()),
            
            // Last Scanned
            if (widget.qrLink.lastScanned != null) ...[
              _buildDetailCard('Last Scanned', _formatDate(widget.qrLink.lastScanned!)),
            ],
            
            const SizedBox(height: 32),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Implement share functionality
                      print('🏛️ QR Result: Share link - ${widget.qrLink.link}');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StarlightTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Share Link',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Implement copy functionality
                      print('🏛️ QR Result: Copy link - ${widget.qrLink.link}');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Copy Link',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }
}
