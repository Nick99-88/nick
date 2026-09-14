import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:starlight_flutter/core/storage.dart';
import 'package:starlight_flutter/core/constants.dart';
import 'package:starlight_flutter/qr_portal/models/qr_link_model.dart';
import 'package:starlight_flutter/qr_portal/models/professional_content_model.dart';
import 'package:starlight_flutter/qr_portal/models/qr_scan_response_model.dart';

class QRService {
  static const String _baseUrl = StarlightConstants.apiBaseUrl;

  static Future<List<QRLinkModel>> getQRLinks() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/api/qr-links'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => QRLinkModel.fromJson(item)).toList();
      } else {
        print('🏛️ QR Service: Failed to load QR links - ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('🏛️ QR Service: Error loading QR links - $e');
      return [];
    }
  }

  static Future<List<ProfessionalContentModel>> getProfessionalContents() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        print('🏛️ QR Service: No token found');
        return [];
      }

      print('🏛️ QR Service: Fetching from $_baseUrl/api/professional-content');
      print('🏛️ QR Service: Token: $token');

      final response = await http.get(
        Uri.parse('$_baseUrl/api/professional-content'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🏛️ QR Service: Response status: ${response.statusCode}');
      print('🏛️ QR Service: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('🏛️ QR Service: Parsed ${data.length} items');
        return data.map((item) => ProfessionalContentModel.fromJson(item)).toList();
      } else {
        print('🏛️ QR Service: Failed to load professional content - ${response.statusCode}');
        print('🏛️ QR Service: Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('🏛️ QR Service: Error loading professional content - $e');
      return [];
    }
  }

  static Future<QRLinkModel?> createQRLink({
    required String title,
    required String description,
    required String link,
    bool isListed = true,
    DateTime? expiresAt,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return null;

      final userData = await StarlightStorage.getUserData();
      final userId = userData?['id'] ?? '';

      final qrLink = QRLinkModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        link: link,
        userId: userId,
        isListed: isListed,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
      );

      final response = await http.post(
        Uri.parse('$_baseUrl/api/qr-links'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(qrLink.toJson()),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return QRLinkModel.fromJson(data);
      } else {
        print('🏛️ QR Service: Failed to create QR link - ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('🏛️ QR Service: Error creating QR link - $e');
      return null;
    }
  }

  static Future<ProfessionalContentModel?> createProfessionalContent({
    required String title,
    required String description,
    required String contentType,
    required String content,
    bool isListed = true,
    DateTime? expiresAt,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return null;

      final userData = await StarlightStorage.getUserData();
      final userId = userData?['id'] ?? '';

      final professionalContent = ProfessionalContentModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        contentType: contentType,
        content: content,
        userId: userId,
        isListed: isListed,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        metadata: metadata,
      );

      final response = await http.post(
        Uri.parse('$_baseUrl/api/professional-content'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(professionalContent.toJson()),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return ProfessionalContentModel.fromJson(data);
      } else {
        print('🏛️ QR Service: Failed to create professional content - ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('🏛️ QR Service: Error creating professional content - $e');
      return null;
    }
  }

  static Future<bool> updateQRLink({
    required String id,
    String? title,
    String? description,
    bool? isListed,
    DateTime? expiresAt,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return false;

      final updateData = <String, dynamic>{};
      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (isListed != null) updateData['is_listed'] = isListed;
      if (expiresAt != null) updateData['expires_at'] = expiresAt.toIso8601String();

      final response = await http.put(
        Uri.parse('$_baseUrl/api/qr-links/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('🏛️ QR Service: Failed to update QR link - ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('🏛️ QR Service: Error updating QR link - $e');
      return false;
    }
  }

  static Future<bool> updateProfessionalContent({
    required String id,
    String? title,
    String? description,
    String? contentType,
    String? content,
    bool? isListed,
    DateTime? expiresAt,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return false;

      final updateData = <String, dynamic>{};
      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (contentType != null) updateData['content_type'] = contentType;
      if (content != null) updateData['content'] = content;
      if (isListed != null) updateData['is_listed'] = isListed;
      if (expiresAt != null) updateData['expires_at'] = expiresAt.toIso8601String();
      if (metadata != null) updateData['metadata'] = metadata;

      final response = await http.put(
        Uri.parse('$_baseUrl/api/professional-content/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('🏛️ QR Service: Failed to update professional content - ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('🏛️ QR Service: Error updating professional content - $e');
      return false;
    }
  }

  static Future<bool> deleteQRLink(String id) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$_baseUrl/api/qr-links/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('🏛️ QR Service: Failed to delete QR link - ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('🏛️ QR Service: Error deleting QR link - $e');
      return false;
    }
  }

  static Future<bool> deleteProfessionalContent(String id) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$_baseUrl/api/professional-content/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('🏛️ QR Service: Failed to delete professional content - ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('🏛️ QR Service: Error deleting professional content - $e');
      return false;
    }
  }

  static Future<void> trackQRScan(String qrLinkId) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/qr-links/$qrLinkId/scan'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print('🏛️ QR Service: QR scan tracked successfully');
      } else {
        print('🏛️ QR Service: Failed to track QR scan - ${response.statusCode}');
      }
    } catch (e) {
      print('🏛️ QR Service: Error tracking QR scan - $e');
    }
  }

  static Future<void> trackContentView(String contentId) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/professional-content/$contentId/view'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        print('🏛️ QR Service: Content view tracked successfully');
      } else {
        print('🏛️ QR Service: Failed to track content view - ${response.statusCode}');
      }
    } catch (e) {
      print('🏛️ QR Service: Error tracking content view - $e');
    }
  }

  // QR Code Scanning
  static Future<Map<String, dynamic>?> scanQRCode(String contentId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/qr-scan'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'content_id': contentId,
        }),
      );

      print('🏛️ QR Service: Response status: ${response.statusCode}');
      print('🏛️ QR Service: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        print('🏛️ QR Service: Failed to scan QR code - ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('🏛️ QR Service: Error scanning QR code - $e');
      return null;
    }
  }

  // Alias for createProfessionalContent to match the method name used in CreateContentScreen
  static Future<bool> saveProfessionalContent({
    required String title,
    required String description,
    required String contentType,
    required String content,
    bool isListed = true,
    DateTime? expiresAt,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final result = await createProfessionalContent(
        title: title,
        description: description,
        contentType: contentType,
        content: content,
        isListed: isListed,
        expiresAt: expiresAt,
        metadata: metadata,
      );
      return result != null;
    } catch (e) {
      print('🏛️ QR Service: Error saving professional content - $e');
      return false;
    }
  }

  // Fetch data from QR link
  static Future<Map<String, dynamic>?> fetchQRLinkData(String link) async {
    try {
      print('🏛️ QR Service: Starting fetchQRLinkData with link: $link');
      
      // Extract content ID from URL
      String contentId = link;
      print('🏛️ QR Service: Original link: "$link"');
      print('🏛️ QR Service: Link contains /scan/: ${link.contains('/scan/')}');
      
      if (link.contains('/scan/')) {
        contentId = link.split('/scan/').last;
        print('🏛️ QR Service: Split result: ${link.split('/scan/')}');
        print('🏛️ QR Service: Extracted content ID: "$contentId"');
        print('🏛️ QR Service: Content ID length: ${contentId.length}');
        print('🏛️ QR Service: Content ID ends with: "${contentId.substring(contentId.length - 5)}"');
      } else {
        print('🏛️ QR Service: Using full link as content ID');
      }
      
      final token = await StarlightStorage.getUserToken();
      
      final url = '$_baseUrl/api/qr-scan';
      print('🏛️ QR Service: Making request to URL: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'content_id': contentId, // Use extracted content ID
        }),
      );

      print('🏛️ QR Service: Request URL was: ${response.request?.url}');
      print('🏛️ QR Service: Fetch response status: ${response.statusCode}');
      print('🏛️ QR Service: Fetch response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🏛️ QR Service: Parsed response data: $data');
        
        try {
          final qrScanResponse = QRScanResponse.fromJson(data);
          print('🏛️ QR Service: Response success: ${qrScanResponse.success}');
          print('🏛️ QR Service: Response content exists: ${qrScanResponse.content != null}');
          if (qrScanResponse.content != null) {
            print('🏛️ QR Service: Content ID: ${qrScanResponse.content!.id}');
            print('🏛️ QR Service: Content title: ${qrScanResponse.content!.title}');
          }
          print('🏛️ QR Service: Response message: ${qrScanResponse.message}');
          return qrScanResponse.toJson();
        } catch (e) {
          print('🏛️ QR Service: Error parsing QRScanResponse - $e');
          print('🏛️ QR Service: Falling back to raw data');
          return data;
        }
      } else if (response.statusCode == 404) {
        print('🏛️ QR Service: Link not found - $link');
        return null;
      } else {
        print('🏛️ QR Service: Failed to fetch QR link data - ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('🏛️ QR Service: Error fetching QR link data - $e');
      return null;
    }
  }
}
