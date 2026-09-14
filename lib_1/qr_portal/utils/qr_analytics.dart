import 'package:flutter/material.dart';
import '../models/qr_link_model.dart';
import '../models/professional_content_model.dart';
import '../../services/qr/qr_service.dart';

class QRAnalytics {
  /// Calculate QR link performance metrics
  static Map<String, dynamic> calculateQRLinkMetrics(List<QRLinkModel> links) {
    if (links.isEmpty) {
      return {
        'totalLinks': 0,
        'totalScans': 0,
        'averageScans': 0.0,
        'activeLinks': 0,
        'expiredLinks': 0,
        'mostScanned': null,
        'leastScanned': null,
      };
    }

    final totalLinks = links.length;
    final totalScans = links.fold<int>(0, (sum, link) => sum + (link.scanCount ?? 0));
    final averageScans = totalScans / totalLinks;
    final now = DateTime.now();
    
    final activeLinks = links.where((link) => 
      link.isListed && (link.expiresAt == null || link.expiresAt!.isAfter(now))
    ).length;
    
    final expiredLinks = links.where((link) => 
      link.expiresAt != null && link.expiresAt!.isBefore(now)
    ).length;

    final sortedByScans = List<QRLinkModel>.from(links)
      ..sort((a, b) => (b.scanCount ?? 0).compareTo(a.scanCount ?? 0));

    return {
      'totalLinks': totalLinks,
      'totalScans': totalScans,
      'averageScans': averageScans.toStringAsFixed(1),
      'activeLinks': activeLinks,
      'expiredLinks': expiredLinks,
      'mostScanned': sortedByScans.isNotEmpty ? sortedByScans.first : null,
      'leastScanned': sortedByScans.isNotEmpty ? sortedByScans.last : null,
    };
  }

  /// Calculate professional content performance metrics
  static Map<String, dynamic> calculateContentMetrics(List<ProfessionalContentModel> contents) {
    if (contents.isEmpty) {
      return {
        'totalContent': 0,
        'totalViews': 0,
        'averageViews': 0.0,
        'listedContent': 0,
        'contentByType': {},
        'mostViewed': null,
        'leastViewed': null,
      };
    }

    final totalContent = contents.length;
    final totalViews = contents.fold<int>(0, (sum, content) => sum + (content.viewCount ?? 0));
    final averageViews = totalViews / totalContent;
    
    final listedContent = contents.where((content) => content.isListed).length;
    
    // Group by content type
    final contentByType = <String, int>{};
    for (final content in contents) {
      contentByType[content.contentType] = (contentByType[content.contentType] ?? 0) + 1;
    }

    final sortedByViews = List<ProfessionalContentModel>.from(contents)
      ..sort((a, b) => (b.viewCount ?? 0).compareTo(a.viewCount ?? 0));

    return {
      'totalContent': totalContent,
      'totalViews': totalViews,
      'averageViews': averageViews.toStringAsFixed(1),
      'listedContent': listedContent,
      'contentByType': contentByType,
      'mostViewed': sortedByViews.isNotEmpty ? sortedByViews.first : null,
      'leastViewed': sortedByViews.isNotEmpty ? sortedByViews.last : null,
    };
  }

  /// Get scan trends for QR links
  static List<Map<String, dynamic>> getScanTrends(List<QRLinkModel> links) {
    final trends = <Map<String, dynamic>>[];
    
    for (final link in links) {
      if (link.lastScanned != null) {
        trends.add({
          'id': link.id,
          'title': link.title,
          'lastScanned': link.lastScanned,
          'scanCount': link.scanCount ?? 0,
          'daysSinceLastScan': DateTime.now().difference(link.lastScanned!).inDays,
        });
      }
    }
    
    // Sort by most recent scan
    trends.sort((a, b) => (b['lastScanned'] as DateTime).compareTo(a['lastScanned'] as DateTime));
    
    return trends;
  }

  /// Get view trends for professional content
  static List<Map<String, dynamic>> getViewTrends(List<ProfessionalContentModel> contents) {
    final trends = <Map<String, dynamic>>[];
    
    for (final content in contents) {
      if (content.lastViewed != null) {
        trends.add({
          'id': content.id,
          'title': content.title,
          'contentType': content.contentType,
          'lastViewed': content.lastViewed,
          'viewCount': content.viewCount ?? 0,
          'daysSinceLastView': DateTime.now().difference(content.lastViewed!).inDays,
        });
      }
    }
    
    // Sort by most recent view
    trends.sort((a, b) => (b['lastViewed'] as DateTime).compareTo(a['lastViewed'] as DateTime));
    
    return trends;
  }

  /// Generate performance report
  static Map<String, dynamic> generatePerformanceReport(
    List<QRLinkModel> qrLinks,
    List<ProfessionalContentModel> contents,
  ) {
    final qrMetrics = calculateQRLinkMetrics(qrLinks);
    final contentMetrics = calculateContentMetrics(contents);
    final scanTrends = getScanTrends(qrLinks);
    final viewTrends = getViewTrends(contents);

    return {
      'generatedAt': DateTime.now().toIso8601String(),
      'qrLinks': qrMetrics,
      'professionalContent': contentMetrics,
      'scanTrends': scanTrends,
      'viewTrends': viewTrends,
      'summary': {
        'totalItems': qrLinks.length + contents.length,
        'totalInteractions': (qrMetrics['totalScans'] as int) + (contentMetrics['totalViews'] as int),
        'activeItems': (qrMetrics['activeLinks'] as int) + (contentMetrics['listedContent'] as int),
      },
    };
  }

  /// Track QR scan and content view
  static Future<void> trackInteraction({
    required String type, // 'qr_scan' or 'content_view'
    required String id,
  }) async {
    try {
      if (type == 'qr_scan') {
        await QRService.trackQRScan(id);
      } else if (type == 'content_view') {
        await QRService.trackContentView(id);
      }
    } catch (e) {
      print('🏛️ QR Analytics: Error tracking $type - $e');
    }
  }
}
