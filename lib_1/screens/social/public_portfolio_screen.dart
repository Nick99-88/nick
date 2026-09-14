import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/api_service.dart';
import '../shared/portfolio_screen.dart';

class PublicPortfolioView extends StatefulWidget {
  final String userId;
  final String userName;
  const PublicPortfolioView({super.key, required this.userId, required this.userName});

  @override
  State<PublicPortfolioView> createState() => _PublicPortfolioViewState();
}

class _PublicPortfolioViewState extends State<PublicPortfolioView> {
  Map<String, dynamic>? _profile;
  List<dynamic> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await ApiService.get('/auth/portfolio/public/${widget.userId}', requireAuth: true);
      if (mounted) {
        setState(() {
          _profile = data['user'];
          _items = data['portfolio_items'] ?? [];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("${widget.userName}'s Portfolio",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white54)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final name = _profile?['name'] ?? 'Unknown';
    final role = _profile?['role'] ?? '';
    final bio = _profile?['bio'] ?? '';
    final city = _profile?['city'] ?? '';
    final country = _profile?['country'] ?? '';
    final lat = _profile?['latitude'] != null ? double.tryParse(_profile!['latitude'].toString()) : null;
    final lng = _profile?['longitude'] != null ? double.tryParse(_profile!['longitude'].toString()) : null;
    final profilePic = _profile?['profile_picture'] ?? '';

    final Map<String, List<dynamic>> grouped = {};
    for (final item in _items) {
      final cat = item['category'] ?? item['type'] ?? 'link';
      grouped.putIfAbsent(cat, () => []).add(item);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
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
                  backgroundImage: profilePic.isNotEmpty ? NetworkImage(profilePic) : null,
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
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(bio, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
                if (lat != null && lng != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(lat, lng),
                          initialZoom: 13,
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                        ),
                        children: [
                          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.starlight.console'),
                          MarkerLayer(markers: [
                            Marker(
                              point: LatLng(lat, lng),
                              width: 30, height: 30,
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
                      "${city.isNotEmpty ? city : ''}${city.isNotEmpty && country.isNotEmpty ? ', ' : ''}${country.isNotEmpty ? country : ''}",
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
              child: const Column(
                children: [
                  Icon(Icons.work_outline_rounded, color: Colors.white24, size: 48),
                  SizedBox(height: 16),
                  Text("No portfolio items", style: TextStyle(color: Colors.white38, fontSize: 14)),
                ],
              ),
            )
          else
            ...grouped.entries.map((entry) {
              final cat = portfolioCategories.firstWhere((c) => c.id == entry.key, orElse: () => portfolioCategories.last);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(cat.icon, color: cat.color, size: 16),
                      const SizedBox(width: 8),
                      Text(cat.label.toUpperCase(), style: TextStyle(color: cat.color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      const Spacer(),
                      Text("${entry.value.length}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...entry.value.map((item) => _buildItemCard(item, cat)),
                  const SizedBox(height: 20),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildItemCard(dynamic item, PortfolioCategory cat) {
    final imageUrl = item['image_url'];
    final hasImage = imageUrl != null && imageUrl.toString().isNotEmpty;
    final tags = item['tags'];
    final List<dynamic> tagList = (tags is List) ? tags : [];

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
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Image.network(
                imageUrl.toString(),
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
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: hasImage ? null : Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: cat.color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(cat.icon, color: cat.color, size: 18),
            ),
            title: Text(item['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            subtitle: _buildSubtitle(item, cat.id),
          ),
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
}
