import 'package:starlight_flutter/qr_portal/models/professional_content_model.dart';

/// 🏛️ QR Scan Response Model
/// Handles the response from QR code scanning endpoint
class QRScanResponse {
  final bool success;
  final ProfessionalContentModel? content;
  final String message;

  QRScanResponse({
    required this.success,
    this.content,
    required this.message,
  });

  factory QRScanResponse.fromJson(Map<String, dynamic> json) {
    try {
      print('🏛️ QR Scan Response: Starting response parsing');
      print('🏛️ QR Scan Response: Success field: ${json['success']}');
      print('🏛️ QR Scan Response: Content field exists: ${json['content'] != null}');
      print('🏛️ QR Scan Response: Message: ${json['message']}');
      
      if (json['content'] != null) {
        print('🏛️ QR Scan Response: Content data type: ${json['content'].runtimeType}');
        print('🏛️ QR Scan Response: Content data: ${json['content']}');
      }
      
      final response = QRScanResponse(
        success: json['success'] ?? false,
        content: json['content'] != null 
          ? ProfessionalContentModel.fromJson(json['content'])
          : null,
        message: json['message'] ?? '',
      );
      
      print('🏛️ QR Scan Response: Parsed successfully - content exists: ${response.content != null}');
      if (response.content != null) {
        print('🏛️ QR Scan Response: Content title: "${response.content!.title}"');
        print('🏛️ QR Scan Response: Content type: "${response.content!.contentType}"');
      }
      
      return response;
    } catch (e) {
      print('🏛️ QR Scan Response: Error parsing response - $e');
      print('🏛️ QR Scan Response: JSON data - $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'content': content?.toJson(),
      'message': message,
    };
  }
}
