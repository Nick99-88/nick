import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/storage.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../services/api_service.dart';

class PortfolioCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const PortfolioCategory(this.id, this.label, this.icon, this.color);
}

const List<PortfolioCategory> portfolioCategories = [
  PortfolioCategory('certificate', 'Certificate', Icons.verified_rounded, Color(0xFFFFC107)),
  PortfolioCategory('education', 'Education', Icons.school_outlined, Color(0xFF4CAF50)),
  PortfolioCategory('degree', 'Degree', Icons.menu_book_rounded, Color(0xFF9C27B0)),
  PortfolioCategory('experience', 'Experience', Icons.work_outline_rounded, Color(0xFF2196F3)),
  PortfolioCategory('interest', 'Interest', Icons.interests_rounded, Color(0xFFFF5722)),
  PortfolioCategory('hobby', 'Hobby', Icons.sports_esports_rounded, Color(0xFF00BCD4)),
  PortfolioCategory('card', 'Card', Icons.credit_card_rounded, Color(0xFF607D8B)),
  PortfolioCategory('link', 'Link', Icons.link_rounded, Color(0xFF38BDF8)),
  PortfolioCategory('material', 'Material', Icons.folder_open_rounded, Color(0xFFE91E63)),
];

class PortfolioScreen extends StatefulWidget {
  final VoidCallback onBack;
  const PortfolioScreen({super.key, required this.onBack});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  Map<String, dynamic>? _profile;
  List<dynamic> _items = [];
  bool _isLoading = true;
  String? _error;
  double? _latitude;
  double? _longitude;
  String _city = '';
  String _country = '';
  bool _isRefreshingLocation = false;

  String _resolveUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    // Relative path from local storage — prepend backend base URL
    return '${StarlightConstants.apiBaseUrl}$url';
  }

  @override
  void initState() {
    super.initState();
    _fetchPortfolio();
  }

  Future<void> _fetchPortfolio() async {
    try {
      final data = await ApiService.get('/auth/portfolio', requireAuth: true);
      if (mounted) {
        final user = data['user'] ?? {};
        setState(() {
          _profile = user;
          _items = data['portfolio_items'] ?? [];
          _latitude = user['latitude'] != null ? double.tryParse(user['latitude'].toString()) : null;
          _longitude = user['longitude'] != null ? double.tryParse(user['longitude'].toString()) : null;
          _city = user['city'] ?? '';
          _country = user['country'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshLocation() async {
    setState(() => _isRefreshingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await Geolocator.openLocationSettings();
        if (!serviceEnabled) {
          if (mounted) {
            setState(() => _isRefreshingLocation = false);
            StarlightUtils.showErrorBox(context, "Please enable GPS/Location services");
          }
          return;
        }
        await Future.delayed(const Duration(seconds: 1));
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() => _isRefreshingLocation = false);
            StarlightUtils.showErrorBox(context, "Location permission denied");
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _isRefreshingLocation = false);
          StarlightUtils.showErrorBox(context, "Location permission permanently denied. Enable it in app settings.");
        }
        await Geolocator.openAppSettings();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 10)),
      );

      String city = '';
      String country = '';
      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          city = placemarks[0].locality ?? '';
          country = placemarks[0].country ?? '';
        }
      } catch (_) {}

      await ApiService.post('/auth/location', {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'city': city,
        'country': country,
      }, requireAuth: true);

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _city = city;
          _country = country;
          _isRefreshingLocation = false;
        });
        StarlightUtils.showSuccessBox(context, "Location updated");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshingLocation = false);
        StarlightUtils.showErrorBox(context, "Failed to get location: $e");
      }
    }
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Add to Portfolio", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text("Choose a category", style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: portfolioCategories.map((cat) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddMaterialSheet(cat);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cat.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(cat.icon, color: cat.color, size: 22),
                      ),
                      const SizedBox(height: 6),
                      Text(cat.label, style: const TextStyle(color: Colors.white70, fontSize: 10), textAlign: TextAlign.center),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddMaterialSheet(PortfolioCategory category) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddMaterialSheet(category: category),
    );

    if (result == null) return;

    try {
      final List<File> localFiles = List<File>.from(result.remove('_local_files') ?? []);
      final resp = await ApiService.post('/auth/portfolio', result, requireAuth: true);
      final itemId = resp['item']?['id'] ?? resp['id'];

      // Upload any local files
      if (itemId != null) {
        for (final file in localFiles) {
          await _uploadFile(itemId, file);
        }
      }

      _fetchPortfolio();
    } catch (e) {
      if (mounted) {
        StarlightUtils.showErrorBox(context, "Failed to add: $e");
      }
    }
  }

  Future<void> _uploadFile(String itemId, File file) async {
    try {
      final token = await StarlightStorage.getUserToken();
      final uri = Uri.parse('${StarlightConstants.apiBaseUrl}/auth/portfolio/$itemId/file');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final resp = await request.send();
      if (resp.statusCode != 200) {
        debugPrint("File upload failed: ${resp.statusCode}");
      }
    } catch (e) {
      debugPrint("File upload error: $e");
    }
  }

  Future<void> _deleteItem(String itemId) async {
    try {
      await ApiService.delete('/auth/portfolio/$itemId', requireAuth: true);
      _fetchPortfolio();
    } catch (e) {
      if (mounted) {
        StarlightUtils.showErrorBox(context, "Failed to delete: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70),
          onPressed: widget.onBack,
        ),
        title: const Text("PORTFOLIO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFF38BDF8)),
            onPressed: _showCategoryPicker,
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'refresh_location',
            backgroundColor: _isRefreshingLocation ? Colors.white24 : const Color(0xFF38BDF8),
            onPressed: _isRefreshingLocation ? null : _refreshLocation,
            child: _isRefreshingLocation
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.my_location, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'add_portfolio',
            backgroundColor: const Color(0xFF38BDF8),
            onPressed: _showCategoryPicker,
            child: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () { setState(() { _isLoading = true; _error = null; }); _fetchPortfolio(); },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text("Retry"),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final name = _profile?['name'] ?? 'Unknown';
    final role = _profile?['role'] ?? '';
    final publicId = _profile?['public_id'] ?? '';
    final bio = _profile?['bio'] ?? '';
    final profilePic = _profile?['profile_picture'] ?? '';

    final Map<String, List<dynamic>> grouped = {};
    for (final item in _items) {
      final cat = item['category'] ?? item['type'] ?? 'material';
      grouped.putIfAbsent(cat, () => []).add(item);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildProfileHeader(name, role, publicId, bio, profilePic),
          const SizedBox(height: 24),

          if (_items.isEmpty)
            _buildEmptyState()
          else
            ...grouped.entries.map((entry) {
              final cat = portfolioCategories.firstWhere(
                (c) => c.id == entry.key,
                orElse: () => portfolioCategories.last,
              );
              return _buildCategorySection(cat, entry.value);
            }),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(String name, String role, String publicId, String bio, String profilePic) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFF38BDF8).withOpacity(0.2),
            backgroundImage: profilePic.isNotEmpty ? NetworkImage(_resolveUrl(profilePic)) : null,
            child: profilePic.isEmpty ? const Icon(Icons.person, size: 40, color: Color(0xFF38BDF8)) : null,
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          if (role.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF38BDF8).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Text(role.toUpperCase(), style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ),
          ],
          if (publicId.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('@$publicId', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(bio, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
          if (_latitude != null && _longitude != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 120,
                width: double.infinity,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(_latitude!, _longitude!),
                    initialZoom: 13,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.starlight.console',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(_latitude!, _longitude!),
                        width: 30,
                        height: 30,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 14),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.location_on_outlined, color: Colors.white38, size: 14),
              const SizedBox(width: 4),
              Text(
                "${_city.isNotEmpty ? _city : ''}${_city.isNotEmpty && _country.isNotEmpty ? ', ' : ''}${_country.isNotEmpty ? _country : ''}",
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          const Icon(Icons.work_outline_rounded, color: Colors.white24, size: 48),
          const SizedBox(height: 16),
          const Text("No portfolio items yet", style: TextStyle(color: Colors.white38, fontSize: 14)),
          const SizedBox(height: 8),
          const Text("Tap + to add certificates, materials,\nand more", textAlign: TextAlign.center, style: TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCategorySection(PortfolioCategory cat, List<dynamic> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(cat.icon, color: cat.color, size: 16),
            const SizedBox(width: 8),
            Text(cat.label.toUpperCase(), style: TextStyle(color: cat.color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const Spacer(),
            Text("${items.length}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => _buildItemCard(item, cat)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildItemCard(dynamic item, PortfolioCategory cat) {
    final attachments = item['attachments'];
    final List<dynamic> attachmentList = (attachments is List) ? attachments : [];
    final hasAttachments = attachmentList.isNotEmpty;
    final imageUrl = item['image_url'];
    final hasImage = imageUrl != null && imageUrl.toString().isNotEmpty;
    final tags = item['tags'];
    final List<dynamic> tagList = (tags is List) ? tags : [];
    final customFields = item['custom_fields'];
    Map<String, dynamic> cf = {};
    if (customFields is Map) {
      cf = Map<String, dynamic>.from(customFields);
    } else if (customFields is String && customFields.isNotEmpty) {
      try {
        cf = Map<String, dynamic>.from(jsonDecode(customFields));
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            GestureDetector(
              onTap: () => _openAttachment(imageUrl.toString()),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: Image.network(
                  _resolveUrl(imageUrl.toString()),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    color: cat.color.withOpacity(0.1),
                    child: Center(child: Icon(cat.icon, color: cat.color.withOpacity(0.3), size: 32)),
                  ),
                ),
              ),
            ),
          if (!hasImage && hasAttachments)
            GestureDetector(
              onTap: () => _openAttachment(attachmentList.first.toString()),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: _buildAttachmentPreview(attachmentList.first.toString(), cat),
              ),
            ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: (hasImage || hasAttachments) ? null : Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: cat.color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(cat.icon, color: cat.color, size: 18),
            ),
            title: Text(item['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            subtitle: _buildSubtitle(item, cat.id),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white24, size: 16),
              onSelected: (v) { if (v == 'delete') _deleteItem(item['id']); },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'delete', child: Text("Delete", style: TextStyle(color: Colors.redAccent, fontSize: 13))),
              ],
            ),
          ),
          // Custom fields display
          if (cf.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: cf.entries.where((e) => e.value.toString().isNotEmpty).map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(text: "${e.key}: ", style: TextStyle(color: cat.color, fontSize: 10, fontWeight: FontWeight.w600)),
                          TextSpan(text: e.value.toString(), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          // Additional attachments
          if (attachmentList.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: attachmentList.skip(1).map((url) {
                  final urlStr = url.toString();
                  return GestureDetector(
                    onTap: () => _openAttachment(urlStr),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cat.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cat.color.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getFileIcon(urlStr), size: 12, color: cat.color),
                          const SizedBox(width: 4),
                          Text(_getFileName(urlStr), style: TextStyle(color: cat.color, fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          // Tags
          if (tagList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tagList.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(t.toString(), style: TextStyle(color: cat.color, fontSize: 10, fontWeight: FontWeight.w500)),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview(String url, PortfolioCategory cat) {
    final resolved = _resolveUrl(url);
    final lower = resolved.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp')) {
      return Image.network(resolved, height: 160, width: double.infinity, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackAttachmentThumb(cat));
    }
    return _fallbackAttachmentThumb(cat);
  }

  Widget _fallbackAttachmentThumb(PortfolioCategory cat) {
    return Container(
      height: 100,
      width: double.infinity,
      color: cat.color.withOpacity(0.1),
      child: Center(child: Icon(cat.icon, color: cat.color.withOpacity(0.3), size: 32)),
    );
  }

  Widget? _buildSubtitle(dynamic item, String category) {
    final parts = <String>[];
    switch (category) {
      case 'certificate':
        if (item['issuer']?.isNotEmpty == true) parts.add(item['issuer']);
        if (item['issue_date']?.isNotEmpty == true) parts.add(item['issue_date']);
        break;
      case 'education':
        if (item['institution']?.isNotEmpty == true) parts.add(item['institution']);
        if (item['grade']?.isNotEmpty == true) parts.add(item['grade']);
        break;
      case 'degree':
        if (item['degree_type']?.isNotEmpty == true) parts.add(item['degree_type']);
        if (item['institution']?.isNotEmpty == true) parts.add(item['institution']);
        if (item['grade']?.isNotEmpty == true) parts.add(item['grade']);
        break;
      case 'experience':
        if (item['company']?.isNotEmpty == true) parts.add(item['company']);
        if (item['position']?.isNotEmpty == true) parts.add(item['position']);
        break;
      case 'interest':
        if (item['field']?.isNotEmpty == true) parts.add(item['field']);
        break;
      case 'card':
        if (item['issuer']?.isNotEmpty == true) parts.add(item['issuer']);
        if (item['card_number']?.isNotEmpty == true) parts.add(item['card_number']);
        break;
      case 'link':
        if (item['url']?.isNotEmpty == true) parts.add(item['url']);
        break;
    }
    if (item['description']?.isNotEmpty == true && parts.isEmpty) {
      parts.add(item['description']);
    }
    if (parts.isEmpty) return null;
    return Text(parts.join(' · '), style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis);
  }

  void _openAttachment(String url) {
    final resolved = _resolveUrl(url);
    final lower = resolved.toLowerCase();

    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp') || lower.endsWith('.gif')) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(url: resolved),
      ));
    } else if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.webm')) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => _FullScreenVideoPlayer(url: resolved),
      ));
    } else if (lower.endsWith('.pdf')) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => _FullScreenPdfViewer(url: resolved),
      ));
    } else {
      OpenFile.open(resolved);
    }
  }

  IconData _getFileIcon(String url) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return Icons.description_rounded;
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) return Icons.table_chart_rounded;
    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) return Icons.slideshow_rounded;
    if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.webm')) return Icons.videocam_rounded;
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp')) return Icons.image_rounded;
    return Icons.insert_drive_file_rounded;
  }

  String _getFileName(String url) {
    final segments = url.split('/');
    final last = segments.last;
    return last.length > 20 ? '${last.substring(0, 17)}...' : last;
  }
}

// ---------------------------------------------------------------------------
// Full-Screen Image Viewer
// ---------------------------------------------------------------------------

class _FullScreenImageViewer extends StatelessWidget {
  final String url;
  const _FullScreenImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white24, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-Screen Video Player
// ---------------------------------------------------------------------------

class _FullScreenVideoPlayer extends StatefulWidget {
  final String url;
  const _FullScreenVideoPlayer({required this.url});

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _videoController.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        allowFullScreen: false,
        allowMuting: true,
        showControls: true,
      );
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white54)))
              : Center(
                  child: Chewie(controller: _chewieController!),
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-Screen PDF Viewer
// ---------------------------------------------------------------------------

class _FullScreenPdfViewer extends StatelessWidget {
  final String url;
  const _FullScreenPdfViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("PDF", style: TextStyle(color: Colors.white, fontSize: 14)),
      ),
      body: SfPdfViewer.network(url),
    );
  }
}

// ---------------------------------------------------------------------------
// Add Material Bottom Sheet
// ---------------------------------------------------------------------------

class _AddMaterialSheet extends StatefulWidget {
  final PortfolioCategory category;
  const _AddMaterialSheet({required this.category});

  @override
  State<_AddMaterialSheet> createState() => _AddMaterialSheetState();
}

class _AddMaterialSheetState extends State<_AddMaterialSheet> {
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final List<String> _tags = [];
  final List<_CustomFieldEntry> _customFields = [];
  final List<File> _localFiles = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _urlCtrl.dispose();
    _tagCtrl.dispose();
    for (final f in _customFields) {
      f.nameCtrl.dispose();
      f.valueCtrl.dispose();
    }
    super.dispose();
  }

  void _addCustomField() {
    setState(() {
      _customFields.add(_CustomFieldEntry());
    });
  }

  void _removeCustomField(int index) {
    setState(() {
      _customFields[index].nameCtrl.dispose();
      _customFields[index].valueCtrl.dispose();
      _customFields.removeAt(index);
    });
  }

  Future<void> _pickFiles() async {
    final picker = ImagePicker();

    // Show choice dialog
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Attach file", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF38BDF8)),
                title: const Text("Image", style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text("Pick from gallery or camera", style: TextStyle(color: Colors.white38, fontSize: 11)),
                onTap: () => Navigator.pop(ctx, 'image'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              ListTile(
                leading: const Icon(Icons.videocam_rounded, color: Color(0xFFFF5722)),
                title: const Text("Video", style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text("Max 1 minute clip", style: TextStyle(color: Colors.white38, fontSize: 11)),
                onTap: () => Navigator.pop(ctx, 'video'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF4CAF50)),
                title: const Text("Document", style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text("PDF, Word, Excel, etc.", style: TextStyle(color: Colors.white38, fontSize: 11)),
                onTap: () => Navigator.pop(ctx, 'document'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      if (source == 'image') {
        final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
        if (img != null) {
          setState(() => _localFiles.add(File(img.path)));
        }
      } else if (source == 'video') {
        final vid = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 1));
        if (vid != null) {
          setState(() => _localFiles.add(File(vid.path)));
        }
      } else if (source == 'document') {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'],
        );
        if (result != null && result.files.isNotEmpty) {
          final path = result.files.first.path;
          if (path != null) {
            setState(() => _localFiles.add(File(path)));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to pick file: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Title is required"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Build custom_fields dict
    final Map<String, String> customFields = {};
    for (final f in _customFields) {
      final name = f.nameCtrl.text.trim();
      final value = f.valueCtrl.text.trim();
      if (name.isNotEmpty) {
        customFields[name] = value;
      }
    }

    final data = <String, dynamic>{
      'title': _titleCtrl.text.trim(),
      'category': widget.category.id,
      'description': _descriptionCtrl.text.trim(),
      'url': _urlCtrl.text.trim(),
      'custom_fields': customFields,
      'tags': _tags,
      '_local_files': _localFiles,
    };

    Navigator.pop(context, data);
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 20),
                ),
                const SizedBox(width: 12),
                Text("Add ${cat.label}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),

            // Title
            _input("Title *", _titleCtrl),
            const SizedBox(height: 12),

            // Description
            _input("Description", _descriptionCtrl, maxLines: 2),
            const SizedBox(height: 12),

            // URL (optional)
            _input("URL (optional)", _urlCtrl),
            const SizedBox(height: 16),

            // File Attachments
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.attach_file_rounded, color: Colors.white38, size: 16),
                      const SizedBox(width: 6),
                      const Text("Attachments", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _pickFiles,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: cat.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, color: cat.color, size: 14),
                              const SizedBox(width: 4),
                              Text("Add", style: TextStyle(color: cat.color, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_localFiles.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _localFiles.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final file = _localFiles[i];
                          final isImage = file.path.toLowerCase().endsWith('.jpg') ||
                              file.path.toLowerCase().endsWith('.jpeg') ||
                              file.path.toLowerCase().endsWith('.png');
                          final isVideo = file.path.toLowerCase().endsWith('.mp4') ||
                              file.path.toLowerCase().endsWith('.mov') ||
                              file.path.toLowerCase().endsWith('.webm');
                          return Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF334155)),
                                ),
                                child: isImage
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(file, fit: BoxFit.cover),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            isVideo ? Icons.videocam_rounded : Icons.insert_drive_file_rounded,
                                            color: isVideo ? Colors.orangeAccent : Colors.greenAccent,
                                            size: 24,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            file.path.split('/').last.length > 12
                                                ? '${file.path.split('/').last.substring(0, 9)}...'
                                                : file.path.split('/').last,
                                            style: const TextStyle(color: Colors.white38, fontSize: 8),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => setState(() => _localFiles.removeAt(i)),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 12),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    const Text("No files attached", style: TextStyle(color: Colors.white24, fontSize: 11)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Custom Fields
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.dynamic_form_rounded, color: Colors.white38, size: 16),
                      const SizedBox(width: 6),
                      const Text("Custom Fields", style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _addCustomField,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: cat.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, color: cat.color, size: 14),
                              const SizedBox(width: 4),
                              Text("Add", style: TextStyle(color: cat.color, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_customFields.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...List.generate(_customFields.length, (i) {
                      final f = _customFields[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: f.nameCtrl,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: "Field name",
                                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
                                  filled: true,
                                  fillColor: const Color(0xFF1E293B),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: f.valueCtrl,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: "Value",
                                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
                                  filled: true,
                                  fillColor: const Color(0xFF1E293B),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _removeCustomField(i),
                              child: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else ...[
                    const SizedBox(height: 8),
                    const Text("Add your own fields (e.g. Institution, Score, etc.)", style: TextStyle(color: Colors.white24, fontSize: 11)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tags
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Tags", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 8),
                  if (_tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _tags.map((t) => Chip(
                        label: Text(t, style: const TextStyle(color: Colors.white, fontSize: 11)),
                        backgroundColor: cat.color.withOpacity(0.2),
                        deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white54),
                        onDeleted: () => setState(() => _tags.remove(t)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )).toList(),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: const InputDecoration(
                            hintText: "Add a tag and press Enter",
                            hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (v) {
                            final tag = v.trim();
                            if (tag.isNotEmpty && !_tags.contains(tag)) {
                              setState(() => _tags.add(tag));
                              _tagCtrl.clear();
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add_circle, color: cat.color, size: 20),
                        onPressed: () {
                          final tag = _tagCtrl.text.trim();
                          if (tag.isNotEmpty && !_tags.contains(tag)) {
                            setState(() => _tags.add(tag));
                            _tagCtrl.clear();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cat.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Save to Portfolio"),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _input(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF334155))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _CustomFieldEntry {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController valueCtrl = TextEditingController();
}
