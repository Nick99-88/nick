import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:starlight_flutter/core/theme.dart';
import 'package:starlight_flutter/qr_portal/models/professional_content_model.dart';
import 'package:starlight_flutter/qr_portal/screens/content_detail_screen.dart';
import 'package:starlight_flutter/qr_portal/screens/create_content_screen.dart';
import 'package:starlight_flutter/qr_portal/screens/qr_code_display_screen.dart';
import 'package:starlight_flutter/services/qr/qr_service.dart';
import 'package:gal/gal.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:starlight_flutter/l10n/strings.dart';

class ProfessionalContentListScreen extends StatefulWidget {
  const ProfessionalContentListScreen({super.key});

  @override
  State<ProfessionalContentListScreen> createState() => _ProfessionalContentListScreenState();
}

class _ProfessionalContentListScreenState extends State<ProfessionalContentListScreen> {
  bool _isLoading = false;
  List<ProfessionalContentModel> _contents = [];
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'text', 'image', 'video', 'document', 'link'
  String _sortBy = 'created_at'; // 'created_at', 'title', 'views'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  List<ProfessionalContentModel> get _filteredContents {
    List<ProfessionalContentModel> filtered = _contents.where((content) {
      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        if (!content.title.toLowerCase().contains(searchLower) &&
            !content.description.toLowerCase().contains(searchLower)) {
          return false;
        }
      }
      
      // Apply type filter
      if (_filterType != 'all' && content.contentType != _filterType) {
        return false;
      }
      
      return true;
    }).toList();
    
    // Apply sorting
    switch (_sortBy) {
      case 'title':
        filtered.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'views':
        filtered.sort((a, b) => (b.viewCount ?? 0).compareTo(a.viewCount ?? 0));
        break;
      case 'created_at':
      default:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          tr('qrVaultTitle'),
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
            onPressed: _refreshData,
            tooltip: tr('qrRefreshTooltip'),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: StarlightTheme.primaryBlue),
            onPressed: () => _showSearchDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: StarlightTheme.primaryBlue),
            onPressed: () => _showFilterDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: tr('qrSearchHint'),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.filter_alt, color: StarlightTheme.primaryBlue),
                  onSelected: (String? value) {
                    if (value != null) {
                      setState(() {
                        _filterType = value;
                      });
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'all', child: Text(tr('qrFilterAll'))),
                    PopupMenuItem(value: 'text', child: Text(tr('qrFilterText'))),
                    PopupMenuItem(value: 'image', child: Text(tr('qrFilterImages'))),
                    PopupMenuItem(value: 'video', child: Text(tr('qrFilterVideos'))),
                    PopupMenuItem(value: 'document', child: Text(tr('qrFilterDocuments'))),
                    PopupMenuItem(value: 'link', child: Text(tr('qrFilterLinks'))),
                  ],
                ),
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort, color: StarlightTheme.primaryBlue),
                  onSelected: (String? value) {
                    if (value != null) {
                      setState(() {
                        _sortBy = value;
                      });
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'created_at', child: Text(tr('qrSortCreated'))),
                    PopupMenuItem(value: 'title', child: Text(tr('qrSortTitle'))),
                    PopupMenuItem(value: 'views', child: Text(tr('qrSortMostViewed'))),
                  ],
                ),
              ],
            ),
          ),
          
          // Content List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContents.isEmpty
                    ? _buildEmptyState(tr('qrNoProfessionalContent'), tr('qrCreateFirstContent'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredContents.length,
                        itemBuilder: (context, index) {
                          final content = _filteredContents[index];
                          return _buildContentCard(content);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'content_list_add',
        backgroundColor: StarlightTheme.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateContentScreen()),
        ),
      ),
    );
  }

  Widget _buildContentCard(ProfessionalContentModel content) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content.title,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        content.description,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: content.isListed ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    content.isListed ? tr('qrListed') : tr('qrUnlisted'),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Content Key Section
            if (content.contentKey != null && content.contentKey!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.key, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        content.contentKey!,
                        style: GoogleFonts.robotoMono(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: content.contentKey!));
                        if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr('qrKeyCopied')), backgroundColor: Colors.green),
                        );
                        }
                      },
                      child: const Icon(Icons.copy, color: Colors.blue, size: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // QR Code Section
            if (content.qrCodeData != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Text(
                      tr('qrCodeLabel'),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // QR Code Preview
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildQRCodePreview(content.qrCodeData!),
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // QR Code Actions
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('qrQuickActionsLabel'),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _copyQRCode(content.qrCodeData!),
                                    icon: const Icon(Icons.copy, size: 16),
                                    label: Text(tr('qrCopyQr')),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: StarlightTheme.primaryBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _saveQRToGallery(content.qrCodeData!),
                                    icon: const Icon(Icons.download, size: 16),
                                    label: Text(tr('qrSaveQr')),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Reference Link Section
            if (content.qrCodeUrl != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('qrReferenceLink'),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[100]!),
                            ),
                            child: Text(
                              content.qrCodeUrl!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.blue[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _copyLink(content.qrCodeUrl!),
                          icon: const Icon(Icons.copy, color: Colors.blue),
                          tooltip: tr('qrCopyLink'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Content Info and Actions
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('qrTypeLabel', {'type': content.contentType.toUpperCase()}),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr('qrViewsLabel', {'count': '${content.viewCount ?? 0}'}),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, size: 20),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ContentDetailScreen(content: content)),
                      ),
                      tooltip: tr('qrViewContent'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CreateContentScreen(content: content)),
                      ),
                      tooltip: tr('qrEditContent'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                      onPressed: () => _deleteContent(content),
                      tooltip: tr('qrDeleteContent'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteContent(ProfessionalContentModel content) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('qrDeleteContentTitle')),
        content: Text(tr('qrConfirmDeleteContent', {'title': content.title})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await QRService.deleteProfessionalContent(content.id);
        
        if (response && mounted) {
          setState(() {
            _contents.removeWhere((item) => item.id == content.id);
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('qrContentDeleted')),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('qrContentDeleteFailed', {'error': '$e'})),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('qrSearchContentTitle')),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: tr('qrEnterSearchTerm'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _searchQuery = _searchQuery.trim();
              });
            },
            child: Text(tr('search')),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('qrFilterContentTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('qrFilterByType')),
            RadioListTile(
              title: Text(tr('qrFilterAll')),
              value: _filterType == 'all',
              onChanged: (value) {
                if (value == true) {
                  setState(() {
                    _filterType = 'all';
                  });
                }
              },
            ),
            RadioListTile(
              title: Text(tr('qrFilterText')),
              value: _filterType == 'text',
              onChanged: (value) {
                if (value == true) {
                  setState(() {
                    _filterType = 'text';
                  });
                }
              },
            ),
            RadioListTile(
              title: Text(tr('qrFilterImages')),
              value: _filterType == 'image',
              onChanged: (value) {
                if (value == true) {
                  setState(() {
                    _filterType = 'image';
                  });
                }
              },
            ),
            RadioListTile(
              title: Text(tr('qrFilterVideos')),
              value: _filterType == 'video',
              onChanged: (value) {
                if (value == true) {
                  setState(() {
                    _filterType = 'video';
                  });
                }
              },
            ),
            RadioListTile(
              title: Text(tr('qrFilterDocuments')),
              value: _filterType == 'document',
              onChanged: (value) {
                if (value == true) {
                  setState(() {
                    _filterType = 'document';
                  });
                }
              },
            ),
            RadioListTile(
              title: Text(tr('qrFilterLinks')),
              value: _filterType == 'link',
              onChanged: (value) {
                if (value == true) {
                  setState(() {
                    _filterType = 'link';
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('qrApply')),
          ),
        ],
      ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('qrQrCodeCopied')),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveQRToGallery(String qrCodeData) async {
    try {
      // Extract base64 image data
      final base64String = qrCodeData.split(',').last;
      final bytes = base64Decode(base64String);
      
      // Generate filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'qr_code_$timestamp.png';
      
      // Save to gallery
      await Gal.putImageBytes(bytes, name: fileName);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('qrQrCodeSaved')),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('qrQrCodeSaveFailed', {'error': '$e'})),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      print('🏛️ QR Vault: Starting data load...');
      _contents = await QRService.getProfessionalContents();
      print('🏛️ QR Vault: Loaded ${_contents.length} items');
      for (var content in _contents) {
        print('🏛️ QR Vault: Item - ${content.title} (QR: ${content.qrCodeData != null})');
      }
    } catch (e) {
      print('🏛️ QR Vault: Error loading data - $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('qrFailedToLoadData', {'error': '$e'})),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
      print('🏛️ QR Vault: Loading completed, state updated');
    }
  }

  Future<void> _refreshData() async {
    // Show refresh indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(tr('qrRefreshing')),
          ],
        ),
        backgroundColor: StarlightTheme.primaryBlue,
        duration: const Duration(seconds: 2),
      ),
    );

    // Load fresh data from server
    await _loadData();

    // Show completion message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('qrDataRefreshed', {'count': '${_contents.length}'})),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _copyLink(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('qrRefLinkCopied')),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
