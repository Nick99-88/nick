import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../qr_portal/models/qr_link_model.dart';
import '../../qr_portal/models/professional_content_model.dart';

/// 🏛️ Enhanced QR Service V2
/// Provides comprehensive QR and Professional Content management
/// with improved error handling, validation, and type safety

// 🏛️ Response Models
class QRServiceResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int? statusCode;

  QRServiceResponse({
    required this.success,
    this.data,
    this.error,
    this.statusCode,
  });
}

class QRServiceV2 {
  static const String _baseUrl = 'https://api.institution.site';
  static const Duration _timeout = Duration(seconds: 30);
  static const String _keyChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String _generateKey() {
    final rand = Random.secure();
    return List.generate(16, (_) => _keyChars[rand.nextInt(_keyChars.length)]).join();
  }

  // 🏛️ HTTP Helper Methods
  static Future<http.Response> _makeRequest({
    required String method,
    required String endpoint,
    Map<String, String>? headers,
    dynamic body,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final requestHeaders = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        ...?headers,
      };

      final url = '$_baseUrl$endpoint';
      print('🏛️ QR Service: Making $method request to $url');
      print('🏛️ QR Service: Token: ${token.isNotEmpty ? 'Present' : 'Missing'}');
      
      if (body != null) {
        print('🏛️ QR Service: Request body: $body');
      }

      late http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(
            Uri.parse(url),
            headers: requestHeaders,
          ).timeout(_timeout);
          break;
        case 'POST':
          response = await http.post(
            Uri.parse(url),
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(_timeout);
          break;
        case 'PUT':
          response = await http.put(
            Uri.parse(url),
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(_timeout);
          break;
        case 'DELETE':
          response = await http.delete(
            Uri.parse(url),
            headers: requestHeaders,
          ).timeout(_timeout);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      print('🏛️ QR Service: Response status: ${response.statusCode}');
      print('🏛️ QR Service: Response body: ${response.body}');

      return response;
    } catch (e) {
      print('🏛️ QR Service: Network error - $e');
      throw Exception('Network error: $e');
    }
  }

  static QRServiceResponse<T> _handleResponse<T>({
    required http.Response response,
    required T Function(Map<String, dynamic>) fromJson,
  }) {
    try {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isNotEmpty) {
          final data = jsonDecode(response.body);
          
          if (data is Map<String, dynamic>) {
            if (data.containsKey('status') && data.containsKey('message') && !data.containsKey('id')) {
              return QRServiceResponse<T>(
                success: true,
                statusCode: response.statusCode,
              );
            }
            return QRServiceResponse<T>(
              success: true,
              data: fromJson(data),
              statusCode: response.statusCode,
            );
          }
        }
        return QRServiceResponse<T>(
          success: true,
          statusCode: response.statusCode,
        );
      } else {
        return QRServiceResponse<T>(
          success: false,
          error: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return QRServiceResponse<T>(
        success: false,
        error: 'Response parsing error: $e',
        statusCode: response.statusCode,
      );
    }
  }

  // 🏛️ QR Links Management

  /// Get all QR links for the current user
  static Future<QRServiceResponse<List<QRLinkModel>>> getQRLinks() async {
    try {
      final response = await _makeRequest(
        method: 'GET',
        endpoint: '/api/qr-links',
      );

      return _handleResponse<List<QRLinkModel>>(
        response: response,
        fromJson: (data) {
          if (data is List) {
            return (data as List)
                .map((item) => QRLinkModel.fromJson(item))
                .toList();
          }
          return [];
        },
      );
    } catch (e) {
      print('🏛️ QR Service: Error loading QR links - $e');
      return QRServiceResponse<List<QRLinkModel>>(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Create a new QR link
  static Future<QRServiceResponse<QRLinkModel>> createQRLink({
    required String title,
    required String description,
    required String link,
    bool isListed = true,
    DateTime? expiresAt,
  }) async {
    try {
      // Validate input
      if (title.trim().isEmpty) {
        return QRServiceResponse<QRLinkModel>(
          success: false,
          error: 'Title is required',
        );
      }
      if (description.trim().isEmpty) {
        return QRServiceResponse<QRLinkModel>(
          success: false,
          error: 'Description is required',
        );
      }
      if (link.trim().isEmpty) {
        return QRServiceResponse<QRLinkModel>(
          success: false,
          error: 'Link is required',
        );
      }

      final userData = await StarlightStorage.getUserData();
      final userId = userData?['id'] ?? '';

      final qrLinkData = {
        'title': title.trim(),
        'description': description.trim(),
        'link': link.trim(),
        'content_key': _generateKey(),
        'is_listed': isListed,
        'expires_at': expiresAt?.toUtc().toIso8601String(),
      };

      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/api/qr-links',
        body: qrLinkData,
      );

      return _handleResponse<QRLinkModel>(
        response: response,
        fromJson: (data) => QRLinkModel.fromJson(data),
      );
    } catch (e) {
      print('🏛️ QR Service: Error creating QR link - $e');
      return QRServiceResponse<QRLinkModel>(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Update an existing QR link
  static Future<QRServiceResponse<QRLinkModel>> updateQRLink({
    required String id,
    String? title,
    String? description,
    String? link,
    bool? isListed,
    DateTime? expiresAt,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      
      if (title != null && title.trim().isNotEmpty) {
        updateData['title'] = title.trim();
      }
      if (description != null && description.trim().isNotEmpty) {
        updateData['description'] = description.trim();
      }
      if (link != null && link.trim().isNotEmpty) {
        updateData['link'] = link.trim();
      }
      if (isListed != null) {
        updateData['is_listed'] = isListed;
      }
      if (expiresAt != null) {
        updateData['expires_at'] = expiresAt!.toUtc().toIso8601String();
      }

      final response = await _makeRequest(
        method: 'PUT',
        endpoint: '/api/qr-links/$id',
        body: updateData,
      );

      return _handleResponse<QRLinkModel>(
        response: response,
        fromJson: (data) => QRLinkModel.fromJson(data),
      );
    } catch (e) {
      print('🏛️ QR Service: Error updating QR link - $e');
      return QRServiceResponse<QRLinkModel>(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Delete a QR link
  static Future<QRServiceResponse<bool>> deleteQRLink(String id) async {
    try {
      if (id.trim().isEmpty) {
        return QRServiceResponse<bool>(
          success: false,
          error: 'QR Link ID is required',
        );
      }

      final response = await _makeRequest(
        method: 'DELETE',
        endpoint: '/api/qr-links/$id',
      );

      if (response.statusCode == 200) {
        return QRServiceResponse<bool>(
          success: true,
          data: true,
        );
      } else {
        return QRServiceResponse<bool>(
          success: false,
          error: 'Failed to delete QR link',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('🏛️ QR Service: Error deleting QR link - $e');
      return QRServiceResponse<bool>(
        success: false,
        error: e.toString(),
      );
    }
  }

  // 🏛️ Professional Content Management

  /// Get all professional content for the current user
  static Future<QRServiceResponse<List<ProfessionalContentModel>>> getProfessionalContents() async {
    try {
      final response = await _makeRequest(
        method: 'GET',
        endpoint: '/api/professional-content',
      );

      return _handleResponse<List<ProfessionalContentModel>>(
        response: response,
        fromJson: (data) {
          if (data is List) {
            return (data as List)
                .map((item) => ProfessionalContentModel.fromJson(item))
                .toList();
          }
          return [];
        },
      );
    } catch (e) {
      print('🏛️ QR Service: Error loading professional content - $e');
      return QRServiceResponse<List<ProfessionalContentModel>>(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Get a single professional content by ID
  static Future<QRServiceResponse<ProfessionalContentModel>> getProfessionalContent(String id) async {
    try {
      final response = await _makeRequest(
        method: 'GET',
        endpoint: '/api/professional-content/$id',
      );

      return _handleResponse<ProfessionalContentModel>(
        response: response,
        fromJson: (data) => ProfessionalContentModel.fromJson(data),
      );
    } catch (e) {
      print('🏛️ QR Service: Error fetching professional content - $e');
      return QRServiceResponse<ProfessionalContentModel>(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Create new professional content
  static Future<QRServiceResponse<ProfessionalContentModel>> createProfessionalContent({
    required String title,
    required String description,
    required String contentType,
    required String content,
    bool isListed = true,
    DateTime? expiresAt,
    DateTime? publishAt,
    Map<String, dynamic>? metadata,
  }) async {
    print('🏛️ QR Service: createProfessionalContent called');
    try {
      // Validate input
      if (title.trim().isEmpty) {
        print('🏛️ QR Service: Title validation failed');
        return QRServiceResponse<ProfessionalContentModel>(
          success: false,
          error: 'Title is required',
        );
      }
      if (description.trim().isEmpty) {
        print('🏛️ QR Service: Description validation failed');
        return QRServiceResponse<ProfessionalContentModel>(
          success: false,
          error: 'Description is required',
        );
      }
      if (content.trim().isEmpty) {
        print('🏛️ QR Service: Content validation failed');
        return QRServiceResponse<ProfessionalContentModel>(
          success: false,
          error: 'Content is required',
        );
      }
      if (!['text', 'image', 'video', 'document', 'link'].contains(contentType)) {
        print('🏛️ QR Service: Content type validation failed: $contentType');
        return QRServiceResponse<ProfessionalContentModel>(
          success: false,
          error: 'Invalid content type. Must be: text, image, video, document, or link',
        );
      }

      final contentData = {
        'title': title.trim(),
        'description': description.trim(),
        'content_type': contentType,
        'content': content.trim(),
        'content_key': _generateKey(),
        'is_listed': isListed,
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        'publish_at': publishAt?.toUtc().toIso8601String(),
        'metadata': metadata ?? {},
      };

      print('🏛️ QR Service: About to make HTTP request');
      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/api/professional-content',
        body: contentData,
      );
      print('🏛️ QR Service: HTTP request completed');

      return _handleResponse<ProfessionalContentModel>(
        response: response,
        fromJson: (data) => ProfessionalContentModel.fromJson(data),
      );
    } catch (e) {
      print('🏛️ QR Service: Error creating professional content - $e');
      return QRServiceResponse<ProfessionalContentModel>(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Update existing professional content
  static Future<QRServiceResponse<ProfessionalContentModel>> updateProfessionalContent({
    required String id,
    String? title,
    String? description,
    String? contentType,
    String? content,
    bool? isListed,
    DateTime? expiresAt,
    DateTime? publishAt,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (id.trim().isEmpty) {
        return QRServiceResponse<ProfessionalContentModel>(
          success: false,
          error: 'Content ID is required',
        );
      }

      final updateData = <String, dynamic>{};
      
      if (title != null && title.trim().isNotEmpty) {
        updateData['title'] = title.trim();
      }
      if (description != null && description.trim().isNotEmpty) {
        updateData['description'] = description.trim();
      }
      if (contentType != null && ['text', 'image', 'video', 'document', 'link'].contains(contentType!)) {
        updateData['content_type'] = contentType;
      }
      if (content != null && content.trim().isNotEmpty) {
        updateData['content'] = content.trim();
      }
      if (isListed != null) {
        updateData['is_listed'] = isListed;
      }
      if (expiresAt != null) {
        updateData['expires_at'] = expiresAt!.toUtc().toIso8601String();
      }
      if (publishAt != null) {
        updateData['publish_at'] = publishAt!.toUtc().toIso8601String();
      }
      if (metadata != null) {
        updateData['metadata'] = metadata;
      }

      final response = await _makeRequest(
        method: 'PUT',
        endpoint: '/api/professional-content/$id',
        body: updateData,
      );

      return _handleResponse<ProfessionalContentModel>(
        response: response,
        fromJson: (data) => ProfessionalContentModel.fromJson(data),
      );
    } catch (e) {
      print('🏛️ QR Service: Error updating professional content - $e');
      return QRServiceResponse<ProfessionalContentModel>(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Delete professional content
  static Future<QRServiceResponse<bool>> deleteProfessionalContent(String id) async {
    try {
      if (id.trim().isEmpty) {
        return QRServiceResponse<bool>(
          success: false,
          error: 'Content ID is required',
        );
      }

      final response = await _makeRequest(
        method: 'DELETE',
        endpoint: '/api/professional-content/$id',
      );

      if (response.statusCode == 200) {
        return QRServiceResponse<bool>(
          success: true,
          data: true,
        );
      } else {
        return QRServiceResponse<bool>(
          success: false,
          error: 'Failed to delete professional content',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('🏛️ QR Service: Error deleting professional content - $e');
      return QRServiceResponse<bool>(
        success: false,
        error: e.toString(),
      );
    }
  }

  // 🏛️ Analytics and Tracking

  /// Track when a QR link is scanned
  static Future<QRServiceResponse<bool>> trackQRScan(String qrLinkId) async {
    try {
      if (qrLinkId.trim().isEmpty) {
        return QRServiceResponse<bool>(
          success: false,
          error: 'QR Link ID is required',
        );
      }

      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/api/qr-links/$qrLinkId/scan',
      );

      if (response.statusCode == 200) {
        return QRServiceResponse<bool>(
          success: true,
          data: true,
        );
      } else {
        return QRServiceResponse<bool>(
          success: false,
          error: 'Failed to track QR scan',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('🏛️ QR Service: Error tracking QR scan - $e');
      return QRServiceResponse<bool>(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Track when professional content is viewed
  static Future<QRServiceResponse<bool>> trackContentView(String contentId) async {
    try {
      if (contentId.trim().isEmpty) {
        return QRServiceResponse<bool>(
          success: false,
          error: 'Content ID is required',
        );
      }

      final response = await _makeRequest(
        method: 'POST',
        endpoint: '/api/professional-content/$contentId/view',
      );

      if (response.statusCode == 200) {
        return QRServiceResponse<bool>(
          success: true,
          data: true,
        );
      } else {
        return QRServiceResponse<bool>(
          success: false,
          error: 'Failed to track content view',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('🏛️ QR Service: Error tracking content view - $e');
      return QRServiceResponse<bool>(
        success: false,
        error: e.toString(),
      );
    }
  }

  // 🏛️ Legacy Compatibility Methods
  
  /// Backward compatibility with existing code
  static Future<QRLinkModel?> createQRLinkLegacy({
    required String title,
    required String description,
    required String link,
    bool isListed = true,
    DateTime? expiresAt,
  }) async {
    final response = await createQRLink(
      title: title,
      description: description,
      link: link,
      isListed: isListed,
      expiresAt: expiresAt,
    );
    return response.success ? response.data : null;
  }

  static Future<ProfessionalContentModel?> createProfessionalContentLegacy({
    required String title,
    required String description,
    required String contentType,
    required String content,
    bool isListed = true,
    DateTime? expiresAt,
    DateTime? publishAt,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await createProfessionalContent(
      title: title,
      description: description,
      contentType: contentType,
      content: content,
      isListed: isListed,
      expiresAt: expiresAt,
      publishAt: publishAt,
      metadata: metadata,
    );
    return response.success ? response.data : null;
  }

  static Future<bool> saveProfessionalContentLegacy({
    required String title,
    required String description,
    required String contentType,
    required String content,
    bool isListed = true,
    DateTime? expiresAt,
    DateTime? publishAt,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await createProfessionalContent(
      title: title,
      description: description,
      contentType: contentType,
      content: content,
      isListed: isListed,
      expiresAt: expiresAt,
      publishAt: publishAt,
      metadata: metadata,
    );
    return response.success;
  }

  static Future<bool> updateProfessionalContentLegacy({
    required String id,
    String? title,
    String? description,
    String? contentType,
    String? content,
    bool? isListed,
    DateTime? expiresAt,
    DateTime? publishAt,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await updateProfessionalContent(
      id: id,
      title: title,
      description: description,
      contentType: contentType,
      content: content,
      isListed: isListed,
      expiresAt: expiresAt,
      publishAt: publishAt,
      metadata: metadata,
    );
    return response.success;
  }

  static Future<List<QRLinkModel>> getQRLinksLegacy() async {
    final response = await getQRLinks();
    return response.success ? response.data ?? [] : [];
  }

  static Future<List<ProfessionalContentModel>> getProfessionalContentsLegacy() async {
    final response = await getProfessionalContents();
    return response.success ? response.data ?? [] : [];
  }

  static Future<bool> deleteQRLinkLegacy(String id) async {
    final response = await deleteQRLink(id);
    return response.success;
  }

  static Future<bool> deleteProfessionalContentLegacy(String id) async {
    final response = await deleteProfessionalContent(id);
    return response.success;
  }
}
