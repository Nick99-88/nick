import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../core/theme.dart';
import '../../services/api_service.dart';
import 'qr_content_display_screen.dart';

class LinkContentSearchScreen extends StatefulWidget {
  const LinkContentSearchScreen({super.key});

  @override
  State<LinkContentSearchScreen> createState() => _LinkContentSearchScreenState();
}

class _LinkContentSearchScreenState extends State<LinkContentSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  bool _hasSearched = false;
  Map<String, dynamic>? _searchResult;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchContent() async {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      _showErrorSnackBar('Please enter a search query');
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _searchResult = null;
      _errorMessage = null;
    });

    try {
      print('🔍 Link Search: Searching for query: "$query"');
      
      final response = await ApiService.post('/api/link-search', {
        'query': query,
      });

      print('🔍 Link Search: Response received: $response');

      if (response['success'] == true && response['content'] != null) {
        // Navigate to the specialized content display screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QRContentDisplayScreen(
              link: query,
              data: response,
            ),
          ),
        );
      } else {
        setState(() {
          _searchResult = null;
          _errorMessage = response['message'] ?? 'No content found';
        });
      }
    } catch (e) {
      print('🔍 Link Search: Error - $e');
      setState(() {
        _searchResult = null;
        _errorMessage = 'Error searching content: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      _searchController.text = clipboardData!.text!;
    }
  }

  Widget _buildSearchInput() {
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
            'Search Content',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _searchContent(),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: IconButton(
                      onPressed: _pasteFromClipboard,
                      icon: const Icon(Icons.content_paste, color: Colors.grey),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: StarlightTheme.primaryBlue, width: 2),
                    ),
                    hintText: 'Enter link URL, title, or keywords...',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _searchContent,
        style: ElevatedButton.styleFrom(
          backgroundColor: StarlightTheme.primaryBlue,
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Searching...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Text(
                'Search Content',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildContentDisplay() {
    if (_searchResult == null || _searchResult!['content'] == null) {
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
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'No content found',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching with different keywords or a valid link',
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

    final content = _searchResult!['content'];
    final contentType = content['content_type'] ?? 'text';
    final title = content['title'] ?? 'Untitled Content';
    final description = content['description'] ?? '';
    final contentData = content['content'] ?? '';
    final metadata = content['metadata'] ?? {};
    final viewCount = content['view_count'] ?? 0;
    final createdAt = content['created_at'] ?? '';

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
          // Header with content type indicator
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getContentTypeColor(contentType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getContentTypeIcon(contentType),
                      size: 16,
                      color: _getContentTypeColor(contentType),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      contentType.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getContentTypeColor(contentType),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(
                Icons.visibility,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                '$viewCount views',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Title
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Description
          if (description.isNotEmpty)
            Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Content based on type
          _buildContentByType(contentType, contentData, metadata),
          
          const SizedBox(height: 16),
          
          // Metadata
          if (createdAt.isNotEmpty)
            Text(
              'Created: ${_formatDate(createdAt)}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContentByType(String contentType, String contentData, Map<String, dynamic> metadata) {
    switch (contentType.toLowerCase()) {
      case 'text':
        return _buildTextContent(contentData);
      case 'link':
        return _buildLinkContent(contentData);
      case 'image':
        return _buildImageContent(contentData, metadata);
      case 'video':
        return _buildVideoContent(contentData, metadata);
      case 'document':
        return _buildDocumentContent(contentData, metadata);
      default:
        return _buildTextContent(contentData);
    }
  }

  Widget _buildTextContent(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Text(
        content,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.black87,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildLinkContent(String link) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Link',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            link,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.blue[600],
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(String imageUrl, Map<String, dynamic> metadata) {
    return Container(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[200],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Image not available',
                            style: GoogleFonts.poppins(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          if (metadata['alt_text'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                metadata['alt_text'],
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoContent(String videoUrl, Map<String, dynamic> metadata) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle, color: Colors.red[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Video Content',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (videoUrl.isNotEmpty)
            SelectableText(
              videoUrl,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.red[600],
              ),
            ),
          if (metadata['duration'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Duration: ${metadata['duration']}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentContent(String documentData, Map<String, dynamic> metadata) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: Colors.green[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Document',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (documentData.isNotEmpty)
            Container(
              width: double.infinity,
              height: 200,
              child: SingleChildScrollView(
                child: Text(
                  documentData,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          if (metadata['file_name'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'File: ${metadata['file_name']}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getContentTypeColor(String contentType) {
    switch (contentType.toLowerCase()) {
      case 'text':
        return Colors.blue;
      case 'link':
        return Colors.purple;
      case 'image':
        return Colors.green;
      case 'video':
        return Colors.red;
      case 'document':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getContentTypeIcon(String contentType) {
    switch (contentType.toLowerCase()) {
      case 'text':
        return Icons.text_fields;
      case 'link':
        return Icons.link;
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.play_circle;
      case 'document':
        return Icons.description;
      default:
        return Icons.file_present;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
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
          '🔍 Content Search',
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
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
                    Icon(
                      Icons.search,
                      size: 48,
                      color: StarlightTheme.primaryBlue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Search Content',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Search for content by link URL, title, or keywords',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Search Input
              _buildSearchInput(),
              
              const SizedBox(height: 16),
              
              // Search Button
              _buildSearchButton(),
              
              const SizedBox(height: 24),
              
              // Content Display
              if (_hasSearched) ...[
                Expanded(
                  child: _buildContentDisplay(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
