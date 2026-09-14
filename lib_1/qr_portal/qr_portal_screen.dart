import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:starlight_flutter/core/theme.dart';
import 'package:starlight_flutter/core/storage.dart';
import 'package:starlight_flutter/services/qr/qr_service.dart';
import 'package:starlight_flutter/qr_portal/models/qr_link_model.dart';
import 'package:starlight_flutter/qr_portal/models/professional_content_model.dart';
import 'package:starlight_flutter/qr_portal/screens/qr_scanner_screen.dart';
import 'package:starlight_flutter/qr_portal/screens/qr_result_screen.dart';
import 'package:starlight_flutter/qr_portal/screens/professional_content_list_screen.dart';
import 'package:starlight_flutter/qr_portal/screens/create_content_screen.dart';
import 'package:starlight_flutter/qr_portal/screens/content_detail_screen.dart';
import 'package:starlight_flutter/qr_portal/screens/qr_link_search_screen.dart';
import 'package:starlight_flutter/qr_portal/screens/link_content_search_screen.dart';
import 'package:starlight_flutter/qr_portal/screens/qr_profile_screen.dart';
import 'package:starlight_flutter/screens/shared/settings_screen.dart';
import 'package:starlight_flutter/l10n/strings.dart';

class QRPortalScreen extends StatefulWidget {
  const QRPortalScreen({super.key});

  @override
  State<QRPortalScreen> createState() => _QRPortalScreenState();
}

class _QRPortalScreenState extends State<QRPortalScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _tabController;
  bool _isLoading = false;
  List<QRLinkModel> _qrLinks = [];
  List<ProfessionalContentModel> _professionalContents = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load QR links and professional content
      _qrLinks = await QRService.getQRLinks();
      _professionalContents = await QRService.getProfessionalContents();
    } catch (e) {
      print('🏛️ QR Portal: Error loading data - $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.person_outline, color: StarlightTheme.primaryBlue),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const QRProfileScreen()),
          ),
        ),
        title: Text(
          tr('qrPortalTitle'),
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: StarlightTheme.primaryBlue,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: StarlightTheme.primaryBlue),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingsScreen(
                  onBack: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: StarlightTheme.primaryBlue),
            onPressed: () => _showActionMenu(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVaultTab(),
                _buildScanTab(),
                _buildLinkSearchTab(),
                _buildAnalysisTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: StarlightTheme.primaryBlue,
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
        onPressed: () => _showQuickActions(),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: StarlightTheme.primaryBlue,
        indicatorWeight: 3,
        labelColor: Colors.grey[600],
        labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelColor: Colors.grey[400],
        tabs: [
          Tab(text: tr('qrTabVault')),
          Tab(text: tr('qrTabScan')),
          Tab(text: tr('qrTabLinkSearch')),
          Tab(text: tr('qrTabAnalysis')),
        ],
      ),
    );
  }

  Widget _buildVaultTab() {
    return const ProfessionalContentListScreen();
  }

  Widget _buildScanTab() {
    return const QRScannerScreen();
  }

  Widget _buildLinkSearchTab() {
    return const LinkContentSearchScreen();
  }

  Widget _buildAnalysisTab() {
    return _buildAnalysisContent();
  }

  Widget _buildAnalysisContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview Cards
          _buildOverviewCards(),
          const SizedBox(height: 24),
          
          // Content Statistics
          _buildContentStatistics(),
          const SizedBox(height: 24),
          
          // Recent Activity
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('qrOverview'),
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                tr('qrTotalContent'),
                '${_professionalContents.length}',
                Icons.article,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                tr('qrTotalQrLinks'),
                '${_qrLinks.length}',
                Icons.link,
                Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                tr('qrTotalViews'),
                '${_getTotalViews()}',
                Icons.visibility,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                tr('qrActiveContent'),
                '${_getActiveContentCount()}',
                Icons.check_circle,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentStatistics() {
    final contentTypeStats = _getContentTypeStatistics();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('qrContentByType'),
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
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
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: contentTypeStats.entries.map((entry) {
              return _buildContentTypeRow(entry.key, entry.value);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildContentTypeRow(String type, int count) {
    final color = _getContentTypeColor(type);
    final total = _professionalContents.length;
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              type.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            '$count ($percentage%)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('qrRecentActivity'),
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
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
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _professionalContents.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        tr('qrNoRecentActivity'),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _professionalContents.length > 5 ? 5 : _professionalContents.length,
                  itemBuilder: (context, index) {
                    final content = _professionalContents[index];
                    return _buildActivityItem(content);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(ProfessionalContentModel content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getContentTypeColor(content.contentType).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getContentTypeIcon(content.contentType),
              color: _getContentTypeColor(content.contentType),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content.title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '${content.viewCount} ${tr('qrViewsSuffix')} • ${_formatDate(content.createdAt.toIso8601String())}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  int _getTotalViews() {
    return _professionalContents.fold<int>(0, (sum, content) => sum + (content.viewCount ?? 0));
  }

  int _getActiveContentCount() {
    return _professionalContents.where((content) => content.isListed).length;
  }

  Map<String, int> _getContentTypeStatistics() {
    final stats = <String, int>{};
    for (final content in _professionalContents) {
      stats[content.contentType] = (stats[content.contentType] ?? 0) + 1;
    }
    return stats;
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
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildEmptyState(String title, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
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

  void _showActionMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('qrCreateNew'),
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.article, color: Colors.blue),
              title: Text('Professional Content', style: GoogleFonts.poppins()),
              subtitle: Text('Production ready content', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateContentScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: Colors.purple),
              title: Text('QR Link Relation', style: GoogleFonts.poppins()),
              subtitle: Text('Link documents, images, PDFs to QR codes', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateContentScreen(isQRLink: true),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showQRReferenceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'QR/Reference Relation',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose action:',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.qr_code, color: Colors.purple),
              title: Text('Generate QR Code', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                _showGenerateQRDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: Colors.blue),
              title: Text('Create Reference Link', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                _showCreateReferenceDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _showGenerateQRDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Generate QR Code',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'QR code generation coming soon!',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Icon(Icons.qr_code_2, size: 64, color: Colors.purple),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _showCreateReferenceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Create Reference Link',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Reference link creation coming soon!',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Icon(Icons.link, size: 64, color: Colors.blue),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Quick Actions',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner, color: Colors.blue),
              title: Text('Scan QR Code', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                _tabController.animateTo(1); // Switch to Scan tab
              },
            ),
            ListTile(
              leading: const Icon(Icons.search, color: Colors.purple),
              title: Text('Search Content', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                _tabController.animateTo(2); // Switch to Link Search tab
              },
            ),
          ],
        ),
      ),
    );
  }
}
