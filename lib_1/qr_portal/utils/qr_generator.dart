import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class QRGenerator {
  /// Generate QR code image widget
  static Widget generateQRCode({
    required String data,
    double size = 200.0,
    Color? foregroundColor,
    Color? backgroundColor,
  }) {
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      backgroundColor: backgroundColor ?? Colors.white,
      foregroundColor: foregroundColor ?? Colors.black,
      gapless: true,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      embeddedImage: null,
      embeddedImageStyle: const QrEmbeddedImageStyle(
        size: Size(40, 40),
      ),
    );
  }

  /// Generate QR code image data for sharing
  static Future<ui.Image?> generateQRImageData({
    required String data,
    double size = 200.0,
    Color? foregroundColor,
    Color? backgroundColor,
  }) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      color: foregroundColor ?? Colors.black,
      emptyColor: backgroundColor ?? Colors.white,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );

    final ui.Image image = await painter.toImage(size);
    return image;
  }

  /// Generate QR code for QR link
  static String generateQRLinkUrl(String linkId) {
    return 'https://hub.institution.site/qr/$linkId';
  }

  /// Generate QR code for professional content
  static String generateProfessionalContentUrl(String contentId) {
    return 'https://hub.institution.site/professional/$contentId';
  }

  /// Validate QR code data format
  static bool isValidQRLink(String qrData) {
    return qrData.startsWith('https://hub.institution.site/qr/') ||
           qrData.startsWith('https://hub.institution.site/professional/');
  }

  /// Extract ID from QR code URL
  static String? extractIdFromQRUrl(String qrData) {
    if (qrData.startsWith('https://hub.institution.site/qr/')) {
      return qrData.replaceFirst('https://hub.institution.site/qr/', '');
    } else if (qrData.startsWith('https://hub.institution.site/professional/')) {
      return qrData.replaceFirst('https://hub.institution.site/professional/', '');
    }
    return null;
  }

  /// Get QR code type from URL
  static String getQRType(String qrData) {
    if (qrData.startsWith('https://hub.institution.site/qr/')) {
      return 'qr_link';
    } else if (qrData.startsWith('https://hub.institution.site/professional/')) {
      return 'professional_content';
    }
    return 'unknown';
  }
}
