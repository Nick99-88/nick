import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:starlight_flutter/core/theme.dart';
import 'package:starlight_flutter/qr_portal/models/professional_content_model.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

class QRCodeDisplayScreen extends StatefulWidget {
  final ProfessionalContentModel content;

  const QRCodeDisplayScreen({super.key, required this.content});

  @override
  State<QRCodeDisplayScreen> createState() => _QRCodeDisplayScreenState();
}

class _QRCodeDisplayScreenState extends State<QRCodeDisplayScreen> {
  final GlobalKey _qrKey = GlobalKey();
  bool _isCapturing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'QR Code - ${widget.content.title}',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: StarlightTheme.primaryBlue,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: StarlightTheme.primaryBlue),
            onPressed: _shareQRCode,
            tooltip: 'Share QR Code',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Content Information Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.content.title,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.content.description,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: StarlightTheme.primaryBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.content.contentType.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.content.isListed)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Listed',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // QR Code Display
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.grey[50]!,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Scan to View Content',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // QR Code
                    RepaintBoundary(
                      key: _qrKey,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: widget.content.qrCodeData != null
                            ? _buildBase64QRCode()
                            : _buildGeneratedQRCode(),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    if (widget.content.contentKey != null && widget.content.contentKey!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: StarlightTheme.primaryBlue.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.key, color: StarlightTheme.primaryBlue, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              widget.content.contentKey!,
                              style: GoogleFonts.robotoMono(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () async {
                                await Clipboard.setData(ClipboardData(text: widget.content.contentKey!));
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Key copied!'), backgroundColor: Colors.green),
                                  );
                                }
                              },
                              child: const Icon(Icons.copy, color: StarlightTheme.primaryBlue, size: 18),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    Text(
                      'Content ID: ${widget.content.id}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Action Buttons
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Actions',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _captureScreenshot,
                            icon: _isCapturing 
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt),
                            label: Text(_isCapturing ? 'Capturing...' : 'Screenshot'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: StarlightTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _copyReferenceLink,
                            icon: const Icon(Icons.link),
                            label: const Text('Copy Link'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _downloadQRCode,
                        icon: const Icon(Icons.download),
                        label: const Text('Download QR Code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBase64QRCode() {
    try {
      final base64String = widget.content.qrCodeData!.split(',').last;
      final bytes = base64Decode(base64String);
      return Image.memory(bytes);
    } catch (e) {
      return _buildGeneratedQRCode();
    }
  }

  Widget _buildGeneratedQRCode() {
    final qrData = widget.content.contentKey ?? widget.content.qrCodeUrl ?? 'https://yourapp.com/scan/${widget.content.id}';
    return QrImageView(
      data: qrData,
      version: QrVersions.auto,
      size: 200.0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
    );
  }

  Future<void> _captureScreenshot() async {
    if (_isCapturing) return;
    
    setState(() => _isCapturing = true);
    
    try {
      final RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        // In a real app, you would save this to device storage
        // For now, we'll just show a success message
        await Clipboard.setData(ClipboardData(text: 'QR Code screenshot captured!'));
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('QR Code screenshot captured!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to capture screenshot: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  Future<void> _copyReferenceLink() async {
    final link = widget.content.qrCodeUrl ?? 'https://yourapp.com/scan/${widget.content.id}';
    await Clipboard.setData(ClipboardData(text: link));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Reference link copied to clipboard!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _downloadQRCode() async {
    // In a real app, you would implement actual download functionality
    // For now, we'll just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Download functionality coming soon!'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareQRCode() async {
    // In a real app, you would implement share functionality
    // For now, we'll copy the link to clipboard
    await _copyReferenceLink();
  }
}
