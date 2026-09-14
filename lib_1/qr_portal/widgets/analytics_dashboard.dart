import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:starlight_flutter/core/theme.dart';
import '../models/qr_link_model.dart';
import '../models/professional_content_model.dart';
import '../utils/qr_analytics.dart';

class AnalyticsDashboard extends StatefulWidget {
  final List<QRLinkModel> qrLinks;
  final List<ProfessionalContentModel> contents;

  const AnalyticsDashboard({
    super.key,
    required this.qrLinks,
    required this.contents,
  });

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  @override
  Widget build(BuildContext context) {
    final qrMetrics = QRAnalytics.calculateQRLinkMetrics(widget.qrLinks);
    final contentMetrics = QRAnalytics.calculateContentMetrics(widget.contents);
    final scanTrends = QRAnalytics.getScanTrends(widget.qrLinks);
    final viewTrends = QRAnalytics.getViewTrends(widget.contents);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Analytics Dashboard',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: StarlightTheme.primaryBlue,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: StarlightTheme.primaryBlue),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Cards
            _buildOverviewSection(qrMetrics, contentMetrics),
            
            const SizedBox(height: 24),
            
            // QR Links Analytics
            _buildQRLinksSection(qrMetrics, scanTrends),
            
            const SizedBox(height: 24),
            
            // Professional Content Analytics
            _buildContentSection(contentMetrics, viewTrends),
            
            const SizedBox(height: 24),
            
            // Performance Trends
            _buildTrendsSection(scanTrends, viewTrends),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewSection(Map<String, dynamic> qrMetrics, Map<String, dynamic> contentMetrics) {
    final totalItems = widget.qrLinks.length + widget.contents.length;
    final totalInteractions = (qrMetrics['totalScans'] as int) + (contentMetrics['totalViews'] as int);
    final activeItems = (qrMetrics['activeLinks'] as int) + (contentMetrics['listedContent'] as int);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Items',
                totalItems.toString(),
                Icons.inventory_2,
                StarlightTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Total Interactions',
                totalInteractions.toString(),
                Icons.trending_up,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Active Items',
                activeItems.toString(),
                Icons.check_circle,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQRLinksSection(Map<String, dynamic> qrMetrics, List<Map<String, dynamic>> scanTrends) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QR Links Performance',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Links',
                qrMetrics['totalLinks'].toString(),
                Icons.qr_code,
                StarlightTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Total Scans',
                qrMetrics['totalScans'].toString(),
                Icons.visibility,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Avg Scans',
                qrMetrics['averageScans'].toString(),
                Icons.analytics,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (qrMetrics['mostScanned'] != null)
          _buildTopPerformersCard(
            'Most Scanned QR Link',
            qrMetrics['mostScanned'].title,
            '${qrMetrics['mostScanned'].scanCount} scans',
            Icons.trending_up,
            Colors.green,
          ),
      ],
    );
  }

  Widget _buildContentSection(Map<String, dynamic> contentMetrics, List<Map<String, dynamic>> viewTrends) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Professional Content Performance',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Content',
                contentMetrics['totalContent'].toString(),
                Icons.article,
                StarlightTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Total Views',
                contentMetrics['totalViews'].toString(),
                Icons.visibility,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Avg Views',
                contentMetrics['averageViews'].toString(),
                Icons.analytics,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (contentMetrics['mostViewed'] != null)
          _buildTopPerformersCard(
            'Most Viewed Content',
            contentMetrics['mostViewed'].title,
            '${contentMetrics['mostViewed'].viewCount} views',
            Icons.trending_up,
            Colors.green,
          ),
        const SizedBox(height: 16),
        if (contentMetrics['contentByType'] != null && (contentMetrics['contentByType'] as Map).isNotEmpty)
          _buildContentTypeChart(contentMetrics['contentByType']),
      ],
    );
  }

  Widget _buildTrendsSection(List<Map<String, dynamic>> scanTrends, List<Map<String, dynamic>> viewTrends) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        if (scanTrends.isNotEmpty)
          _buildTrendsList('Recent QR Scans', scanTrends, Icons.qr_code_scanner),
        if (viewTrends.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildTrendsList('Recent Content Views', viewTrends, Icons.visibility),
        ],
        if (scanTrends.isEmpty && viewTrends.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No recent activity',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTopPerformersCard(String title, String itemName, String metric, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  itemName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            metric,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTypeChart(Map<String, int> contentByType) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Content by Type',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          ...contentByType.entries.map((entry) {
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getContentTypeColor(entry.key).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getContentTypeColor(entry.key).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _getContentTypeColor(entry.key),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.key.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _getContentTypeColor(entry.key),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getContentTypeColor(entry.key),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.value.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTrendsList(String title, List<Map<String, dynamic>> trends, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: StarlightTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...trends.take(5).map((trend) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trend['title'],
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[800],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${trend['daysSinceLastScan'] ?? trend['daysSinceLastView']} days ago',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: StarlightTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${trend['scanCount'] ?? trend['viewCount']}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: StarlightTheme.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Color _getContentTypeColor(String type) {
    switch (type.toLowerCase()) {
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
}
