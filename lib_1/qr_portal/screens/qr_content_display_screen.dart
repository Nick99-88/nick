import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;
import '../../core/theme.dart';
import '../../core/ads_setup.dart';
import '../../core/ad_service.dart';

class QRContentDisplayScreen extends StatefulWidget {
  final String link;
  final Map<String, dynamic> data;

  const QRContentDisplayScreen({
    super.key,
    required this.link,
    required this.data,
  });

  @override
  State<QRContentDisplayScreen> createState() => _QRContentDisplayScreenState();
}

class _QRContentDisplayScreenState extends State<QRContentDisplayScreen> {
  bool _isLoading = false;
  bool _isSaving = false;
  bool _contentUnlocked = false;
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;
  final GlobalKey _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _showAdGate();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadBannerAd() {
    if (!AdConfig.isInitialized) return;
    _bannerAd = BannerAd(
      adUnitId: AdConfig.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('📱 [QRContent] Banner ad loaded.');
          if (mounted) setState(() => _bannerLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('📱 [QRContent] Banner ad failed: ${error.message}');
          ad.dispose();
        },
      ),
    )..load();
  }

  void _showAdGate() {
    if (!AdConfig.isInitialized) {
      setState(() => _contentUnlocked = true);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final reward = await AdService.instance.showRewardedAd(
        onRewarded: () async {
          if (mounted) setState(() => _contentUnlocked = true);
          await AdService.instance.creditRewardedAdUser();
        },
      );
      if (mounted && reward) {
        setState(() => _contentUnlocked = true);
      }
    });
  }

  Future<void> _watchAdToUnlock() async {
    if (!AdConfig.isInitialized) {
      setState(() => _contentUnlocked = true);
      return;
    }

    if (!AdService.instance.isRewardedAdReady) {
      await AdService.instance.loadRewardedAd();
    }

    final reward = await AdService.instance.showRewardedAd(
      onRewarded: () async {
        if (mounted) setState(() => _contentUnlocked = true);
        await AdService.instance.creditRewardedAdUser();
      },
    );
    if (mounted && reward) {
      setState(() => _contentUnlocked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '📄 Content',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: StarlightTheme.primaryBlue,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_contentUnlocked)
            IconButton(
              icon: const Icon(Icons.share, color: Colors.grey),
              onPressed: _shareContent,
            ),
        ],
      ),
      body: Column(
        children: [
          // Banner Ad (if loaded)
          if (_bannerLoaded && _bannerAd != null)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: AdWidget(ad: _bannerAd!),
            ),
          Expanded(
            child: _contentUnlocked
                ? _buildUnlockedContent()
                : _buildLockedContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockedContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContentHeader(),
          const SizedBox(height: 24),
          RepaintBoundary(
            key: _contentKey,
            child: _buildContentBody(),
          ),
          const SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildLockedContent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: StarlightTheme.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 64,
                color: StarlightTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Content Locked',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Watch a short ad to unlock this content and earn rewards!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _watchAdToUnlock,
                icon: const Icon(Icons.play_circle_fill, size: 24),
                label: Text(
                  'Watch Ad to Unlock',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StarlightTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentHeader() {
    // Handle nested data structure from API response
    final contentData = widget.data['content'] ?? widget.data;
    final title = contentData['title'] ?? 'Untitled Content';
    final description = contentData['description'] ?? 'No description available';
    final contentType = contentData['content_type'] ?? 'unknown';
    final createdAt = contentData['created_at'];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
              color: _getContentTypeColor(contentType).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getContentTypeColor(contentType).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getContentTypeIcon(contentType),
                  color: _getContentTypeColor(contentType),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  contentType.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _getContentTypeColor(contentType),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Title
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Description
          Text(
            description,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          
          if (createdAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Created: ${_formatDate(createdAt)}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContentBody() {
    // Handle nested data structure from API response
    final contentData = widget.data['content'] ?? widget.data;
    final content = contentData['content_data'] ?? contentData['content'] ?? '';
    final contentType = contentData['content_type'] ?? 'unknown';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Content',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Render content based on type
          _renderContent(content, contentType),
        ],
      ),
    );
  }

  Widget _renderContent(dynamic content, String contentType) {
    switch (contentType.toLowerCase()) {
      case 'text':
        return _renderTextContent(content);
      case 'image':
        return _renderImageContent(content);
      case 'video':
        return _renderVideoContent(content);
      case 'link':
        return _renderLinkContent(content);
      case 'document':
        return _renderDocumentContent(content);
      default:
        return _renderUnknownContent(content);
    }
  }

  Widget _renderTextContent(dynamic content) {
    return Text(
      content?.toString() ?? 'No text content available',
      style: GoogleFonts.poppins(
        fontSize: 16,
        color: Colors.black87,
        height: 1.6,
      ),
    );
  }

  Widget _renderImageContent(dynamic content) {
    final imageData = content?.toString() ?? '';
    
    if (imageData.isEmpty) {
      return _renderEmptyContent('No image data available');
    }
    
    Widget imageWidget;
    
    if (imageData.startsWith('http')) {
      imageWidget = Image.network(
        imageData,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Failed to load image'),
                ],
              ),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    } else {
      imageWidget = Image.memory(
        base64Decode(imageData),
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Failed to decode image'),
                ],
              ),
            ),
          );
        },
      );
    }
    
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imageWidget,
        ),
      ],
    );
  }

  Widget _renderVideoContent(dynamic content) {
    final videoUrl = content?.toString() ?? '';
    
    if (videoUrl.isEmpty) {
      return _renderEmptyContent('No video URL available');
    }
    
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.play_circle_outline, size: 64, color: Colors.grey[400]),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Text(
              videoUrl,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderLinkContent(dynamic content) {
    final linkUrl = content?.toString() ?? '';
    
    if (linkUrl.isEmpty) {
      return _renderEmptyContent('No link available');
    }
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: StarlightTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: StarlightTheme.primaryBlue.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.link, color: StarlightTheme.primaryBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  linkUrl,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: StarlightTheme.primaryBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new, color: StarlightTheme.primaryBlue),
                onPressed: () => _launchUrl(linkUrl),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _renderDocumentContent(dynamic content) {
    final documentUrl = content?.toString() ?? '';
    
    if (documentUrl.isEmpty) {
      return _renderEmptyContent('No document URL available');
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.description, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Document Available',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            documentUrl,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _launchUrl(documentUrl),
              icon: const Icon(Icons.download),
              label: const Text('Open Document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderUnknownContent(dynamic content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.help_outline, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Unknown Content Type',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content?.toString() ?? 'No content available',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _renderEmptyContent(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveContent,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.download),
            label: Text(
              _isSaving ? 'Saving...' : 'Save to Gallery',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: StarlightTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getContentTypeColor(String contentType) {
    switch (contentType.toLowerCase()) {
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

  IconData _getContentTypeIcon(String contentType) {
    switch (contentType.toLowerCase()) {
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch URL: $url'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _shareContent() async {
    try {
      // Handle nested data structure from API response
      final contentData = widget.data['content'] ?? widget.data;
      final title = contentData['title'] ?? 'Untitled Content';
      final description = contentData['description'] ?? 'No description available';
      final contentType = contentData['content_type'] ?? 'unknown';
      final content = contentData['content_data'] ?? contentData['content'] ?? '';
      
      // Create share text
      String shareText = '📄 $title\n\n';
      shareText += '📝 $description\n\n';
      shareText += '🏷️ Type: $contentType\n\n';
      
      if (contentType == 'text') {
        shareText += '💬 Content: $content\n\n';
      } else if (contentType == 'link') {
        shareText += '🔗 Link: $content\n\n';
      }
      
      shareText += '📱 Shared via Starlight QR Portal';
      
      await Share.share(
        shareText,
        subject: title,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing content: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveContent() async {
    if (_isSaving) return;
    
    setState(() => _isSaving = true);
    
    try {
      // Capture the content as an image
      final RenderRepaintBoundary boundary = _contentKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final Uint8List imageBytes = byteData.buffer.asUint8List();
        
        // Save to gallery using gal plugin
        await Gal.putImageBytes(imageBytes, name: 'qr_content_${DateTime.now().millisecondsSinceEpoch}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Content saved to gallery successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving content: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
