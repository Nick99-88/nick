import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:starlight_flutter/core/theme.dart';
import 'package:starlight_flutter/qr_portal/models/professional_content_model.dart';
import 'package:starlight_flutter/qr_portal/screens/create_content_screen.dart';
import 'package:starlight_flutter/services/qr/qr_service_v2.dart';
import 'package:gal/gal.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

class ContentDetailScreen extends StatefulWidget {
  final ProfessionalContentModel content;
  
  const ContentDetailScreen({super.key, required this.content});

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late TabController _tabController;
  late ProfessionalContentModel _currentContent;
  final GlobalKey _qrKey = GlobalKey();
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentContent = widget.content;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Debug logging to check received data
    print('🏛️ ContentDetailScreen: Building with content:');
    print('🏛️ ContentDetailScreen: Title - "${_currentContent.title}"');
    print('🏛️ ContentDetailScreen: Description - "${_currentContent.description}"');
    print('🏛️ ContentDetailScreen: Content Type - "${_currentContent.contentType}"');
    print('🏛️ ContentDetailScreen: Content Data - "${_currentContent.content}"');
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Content Details',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: StarlightTheme.primaryBlue,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: StarlightTheme.primaryBlue),
            onPressed: () => _editContent(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: StarlightTheme.primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: StarlightTheme.primaryBlue,
          tabs: const [
            Tab(text: 'Content', icon: Icon(Icons.article)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildContentTab(),
          _buildAnalyticsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'content_detail_share',
        backgroundColor: StarlightTheme.primaryBlue,
        child: const Icon(Icons.share, color: Colors.white),
        onPressed: () => _shareContent(),
      ),
    );
  }

  Widget _buildContentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content Title and Description Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Content Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: StarlightTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _currentContent.contentType.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Content Title
                Text(
                  _currentContent.title,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Content Description
                Text(
                  _currentContent.description,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Content Display
          _buildContentDisplay(),
          
          const SizedBox(height: 24),
          
          // QR Code and Link Section
          _buildQrAndLinkSection(),
          
          const SizedBox(height: 24),
          
          // Metadata
          if (_currentContent.metadata != null && _currentContent.metadata!.isNotEmpty) ...[
            Text(
              'Additional Information',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            ..._currentContent.metadata!.entries.map((entry) => 
              _buildMetadataCard(entry.key, entry.value.toString()),
            ).toList(),
          ],
          
          const SizedBox(height: 24),
          
          // Stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Views', _currentContent.viewCount.toString(), Icons.visibility),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard('Created', _formatDate(_currentContent.createdAt), Icons.calendar_today),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Content Key & QR Section
          _buildContentKeySection(),
          
          if (_currentContent.expiresAt != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This content expires on ${_formatDate(_currentContent.expiresAt!)}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Content Analytics',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 24),
          
          // Overview Cards
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  'Total Views',
                  _currentContent.viewCount.toString(),
                  Icons.visibility,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAnalyticsCard(
                  'Status',
                  _currentContent.isListed ? 'Listed' : 'Unlisted',
                  _currentContent.isListed ? Icons.public : Icons.lock,
                  _currentContent.isListed ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Timeline Information
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Content Timeline',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                _buildTimelineItem('Created', _currentContent.createdAt, Icons.create, Colors.blue),
                if (_currentContent.lastViewed != null)
                  _buildTimelineItem('Last Viewed', _currentContent.lastViewed!, Icons.visibility, Colors.green),
                if (_currentContent.expiresAt != null)
                  _buildTimelineItem('Expires', _currentContent.expiresAt!, Icons.timer, Colors.orange),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Performance Metrics
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Performance Metrics',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                _buildMetricRow('Content Type', _currentContent.contentType.toUpperCase()),
                _buildMetricRow('Content ID', _currentContent.id),
                if (_currentContent.qrCodeUrl != null)
                  _buildMetricRow('QR Code URL', _currentContent.qrCodeUrl!),
                _buildMetricRow('Listed Status', _currentContent.isListed ? 'Yes' : 'No'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String label, DateTime dateTime, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDate(dateTime),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[800],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentDisplay() {
    switch (_currentContent.contentType) {
      case 'text':
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.article, color: StarlightTheme.primaryBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Content',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _currentContent.content,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.6,
                ),
              ),
            ],
          ),
        );
      case 'image':
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.image, color: StarlightTheme.primaryBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Image Content',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _currentContent.content.startsWith('http')
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _currentContent.content,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(_currentContent.content),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                        ),
                      ),
              ),
            ],
          ),
        );
      case 'video':
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.videocam, color: StarlightTheme.primaryBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Video Content',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_currentContent.content.startsWith('http'))
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _currentContent.content,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[900],
                            child: Icon(Icons.videocam, size: 60, color: Colors.grey[600]),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: Colors.grey[900],
                        child: Icon(Icons.videocam, size: 60, color: Colors.grey[600]),
                      ),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow,
                        size: 30,
                        color: StarlightTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentContent.content.startsWith('http')
                            ? 'Video URL: ${_currentContent.content}'
                            : 'Video data: ${_currentContent.content}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case 'link':
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.link, color: StarlightTheme.primaryBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Link Content',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'URL:',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _currentContent.content,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: StarlightTheme.primaryBlue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement URL launch
                    print('🏛️ Launch URL: ${_currentContent.content}');
                  },
                  icon: Icon(Icons.open_in_new, size: 18),
                  label: Text('Open Link'),
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
            ],
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.help_outline, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Unknown Content Type',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Type: ${_currentContent.contentType}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.orange[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Content data: ${_currentContent.content}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildQrAndLinkSection() {
    if (_currentContent.qrCodeData == null && _currentContent.qrCodeUrl == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QR Code & Link',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // QR Code Section
              if (_currentContent.qrCodeData != null) ...[
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildQRCodePreview(_currentContent.qrCodeData!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _saveQRToGallery(_currentContent.qrCodeData!),
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Save QR Code'),
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
                        onPressed: () => _copyQRCode(_currentContent.qrCodeData!),
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy QR'),
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
              ],

              // Divider if both QR and Link exist
              if (_currentContent.qrCodeData != null && _currentContent.qrCodeUrl != null) ...[
                const SizedBox(height: 24),
                Divider(color: Colors.grey[300]),
                const SizedBox(height: 24),
              ],

              // Link Section
              if (_currentContent.qrCodeUrl != null) ...[
                Text(
                  'Reference Link',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _currentContent.qrCodeUrl!,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _copyLink(_currentContent.qrCodeUrl!),
                        icon: const Icon(Icons.copy, color: Colors.blue),
                        tooltip: 'Copy Link',
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQRCodePreview(String qrCodeData) {
    try {
      final base64String = qrCodeData.split(',').last;
      final bytes = base64Decode(base64String);
      return Image.memory(bytes, fit: BoxFit.contain);
    } catch (e) {
      return Container(
        color: Colors.grey[300],
        child: const Icon(Icons.qr_code, color: Colors.grey),
      );
    }
  }

  void _copyQRCode(String qrCodeData) async {
    await Clipboard.setData(ClipboardData(text: qrCodeData));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR Code copied to clipboard!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _saveQRToGallery(String qrCodeData) async {
    try {
      final base64String = qrCodeData.split(',').last;
      final bytes = base64Decode(base64String);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'qr_code_${_currentContent.id}_$timestamp.png';
      await Gal.putImageBytes(bytes, name: fileName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR Code saved to gallery!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save QR Code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildMetadataCard(String key, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$key:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No Image Available',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: StarlightTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: StarlightTheme.primaryBlue, size: 20),
          ),
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
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentKeySection() {
    final key = _currentContent.contentKey;
    if (key == null || key.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Content Access Key',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Key Display with Copy
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: StarlightTheme.primaryBlue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.key, color: StarlightTheme.primaryBlue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        key,
                        style: GoogleFonts.robotoMono(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copyContentKey(key),
                      icon: const Icon(Icons.copy, color: StarlightTheme.primaryBlue),
                      tooltip: 'Copy Key',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // QR Code from Key
              RepaintBoundary(
                key: _qrKey,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: QrImageView(
                    data: key,
                    version: QrVersions.auto,
                    size: 180.0,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isCapturing ? null : _captureQrScreenshot,
                      icon: _isCapturing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.camera_alt, size: 18),
                      label: Text(_isCapturing ? 'Capturing...' : 'Capture QR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StarlightTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _copyContentKey(key),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy Key'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _copyContentKey(String key) async {
    await Clipboard.setData(ClipboardData(text: key));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Content key copied to clipboard!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _captureQrScreenshot() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      final RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        await Gal.putImageBytes(bytes, name: 'qr_${_currentContent.id}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('QR code saved to gallery!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _editContent() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateContentScreen(content: _currentContent),
      ),
    );
    if (mounted) {
      try {
        final response = await QRServiceV2.getProfessionalContent(_currentContent.id);
        if (response.success && response.data != null) {
          setState(() {
            _currentContent = response.data!;
          });
        }
      } catch (e) {
        print('🏛️ ContentDetailScreen: Error re-fetching content - $e');
      }
    }
  }

  void _shareContent() {
    // TODO: Implement share functionality
    print('🏛️ Content Detail: Share content - ${_currentContent.title}');
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }
}
