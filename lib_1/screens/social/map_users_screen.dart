import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/storage.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../services/api_service.dart';
import '../../services/social/explore_service.dart';
import 'full_profile_screen.dart';

class MapUsersScreen extends StatefulWidget {
  const MapUsersScreen({super.key});

  @override
  State<MapUsersScreen> createState() => _MapUsersScreenState();
}

class _MapUsersScreenState extends State<MapUsersScreen> {
  final ExploreService _exploreService = ExploreService();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final FocusNode _cityFocus = FocusNode();
  final FocusNode _countryFocus = FocusNode();
  final MapController _mapController = MapController();

  List<dynamic> _users = [];
  List<dynamic> _institutions = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  LatLng _center = const LatLng(28.6139, 77.2090);
  String _selectedRole = 'all';

  // Autocomplete
  List<Map<String, String>> _citySuggestions = [];
  List<Map<String, String>> _countrySuggestions = [];
  bool _showCitySuggestions = false;
  bool _showCountrySuggestions = false;
  bool _isFetchingSuggestions = false;

  // Local cache
  List<Map<String, String>> _recentSearches = [];
  static const _cacheKey = 'map_recent_searches';
  static const _maxCache = 10;

  static const _roleFilters = [
    {'id': 'all', 'label': 'All', 'icon': Icons.people_alt_rounded, 'color': Color(0xFF38BDF8)},
    {'id': 'teachers', 'label': 'Teachers', 'icon': Icons.school_outlined, 'color': Colors.orange},
    {'id': 'students', 'label': 'Students', 'icon': Icons.person_outline, 'color': Color(0xFF1565C0)},
    {'id': 'owner', 'label': 'Owners', 'icon': Icons.account_balance_rounded, 'color': Color(0xFFBF360C)},
  ];

  @override
  void initState() {
    super.initState();
    _loadCache();
    _loadLastLocation();
    _cityFocus.addListener(() {
      if (_cityFocus.hasFocus) {
        setState(() { _showCitySuggestions = true; _showCountrySuggestions = false; });
      }
    });
    _countryFocus.addListener(() {
      if (_countryFocus.hasFocus) {
        setState(() { _showCountrySuggestions = true; _showCitySuggestions = false; });
      }
    });
  }

  @override
  void dispose() {
    _cityController.dispose();
    _countryController.dispose();
    _cityFocus.dispose();
    _countryFocus.dispose();
    super.dispose();
  }

  // ── Cache ──────────────────────────────────────────────────────────

  Future<void> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_cacheKey) ?? [];
    _recentSearches = raw.map((e) => Map<String, String>.from(jsonDecode(e))).toList();
  }

  Future<void> _saveToCache(String city, String country) async {
    _recentSearches.removeWhere((s) => s['city'] == city && s['country'] == country);
    _recentSearches.insert(0, {'city': city, 'country': country});
    if (_recentSearches.length > _maxCache) _recentSearches = _recentSearches.sublist(0, _maxCache);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_cacheKey, _recentSearches.map((e) => jsonEncode(e)).toList());
  }

  // ── Location ───────────────────────────────────────────────────────

  Future<void> _loadLastLocation() async {
    try {
      final data = await ApiService.get('/auth/portfolio', requireAuth: true);
      final user = data['user'] ?? {};
      final lat = user['latitude'] != null ? double.tryParse(user['latitude'].toString()) : null;
      final lng = user['longitude'] != null ? double.tryParse(user['longitude'].toString()) : null;
      final city = user['city'] ?? '';
      final country = user['country'] ?? '';
      if (lat != null && lng != null) {
        setState(() {
          _center = LatLng(lat, lng);
          _cityController.text = city;
          _countryController.text = country;
        });
        _search();
      }
    } catch (_) {}
  }

  // ── Nominatim Autocomplete ─────────────────────────────────────────

  Future<void> _fetchSuggestions(String query, bool isCity) async {
    if (query.length < 2) {
      setState(() {
        if (isCity) _citySuggestions = [];
        else _countrySuggestions = [];
      });
      return;
    }
    setState(() => _isFetchingSuggestions = true);
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=6&addressdetails=1');
      final resp = await http.get(uri, headers: {'User-Agent': 'StarlightApp/1.0'});
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        final suggestions = data.map<Map<String, String>>((e) {
          final addr = e['address'] ?? {};
          final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['hamlet'] ?? '';
          final country = addr['country'] ?? '';
          return {'city': city, 'country': country, 'display': e['display_name'] ?? ''};
        }).where((s) => isCity ? s['city']!.isNotEmpty : s['country']!.isNotEmpty).toList();
        // Deduplicate
        final seen = <String>{};
        final unique = suggestions.where((s) => seen.add('${s['city']}_${s['country']}')).toList();
        if (mounted) {
          setState(() {
            if (isCity) _citySuggestions = unique;
            else _countrySuggestions = unique;
            _isFetchingSuggestions = false;
          });
        }
      }
    } catch (_) {
      setState(() => _isFetchingSuggestions = false);
    }
  }

  // ── Search ─────────────────────────────────────────────────────────

  Future<void> _search() async {
    final city = _cityController.text.trim();
    final country = _countryController.text.trim();
    if (city.isEmpty || country.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter both city and country"), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    setState(() { _isLoading = true; _showCitySuggestions = false; _showCountrySuggestions = false; });
    _cityFocus.unfocus();
    _countryFocus.unfocus();

    try {
      final result = await _exploreService.getNearbyUsers(city, country, role: _selectedRole);
      if (mounted) {
        final users = result['users'] ?? [];
        final institutions = result['institutions'] ?? [];
        setState(() {
          _users = users;
          _institutions = institutions;
          _isLoading = false;
          _hasSearched = true;
        });
        await _saveToCache(city, country);
        _fitMapToResults();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _fitMapToResults() {
    final allPoints = <LatLng>[];
    for (final u in _users) {
      final lat = double.tryParse(u['latitude'].toString());
      final lng = double.tryParse(u['longitude'].toString());
      if (lat != null && lng != null) allPoints.add(LatLng(lat, lng));
    }
    for (final i in _institutions) {
      final lat = double.tryParse(i['latitude'].toString());
      final lng = double.tryParse(i['longitude'].toString());
      if (lat != null && lng != null) allPoints.add(LatLng(lat, lng));
    }
    if (allPoints.isEmpty) return;
    if (allPoints.length == 1) {
      _mapController.move(allPoints.first, 14);
    } else {
      final bounds = LatLngBounds.fromPoints(allPoints);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)));
    }
  }

  void _onMarkerTap(dynamic item, bool isUser) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => FullProfileScreen(item: item, isUser: isUser)));
  }

  void _selectSuggestion(Map<String, String> s, bool isCity) {
    if (isCity) {
      _cityController.text = s['city'] ?? '';
      if (s['country']?.isNotEmpty == true && _countryController.text.isEmpty) {
        _countryController.text = s['country']!;
      }
      setState(() { _showCitySuggestions = false; _citySuggestions = []; });
      _cityFocus.unfocus();
    } else {
      _countryController.text = s['country'] ?? '';
      if (s['city']?.isNotEmpty == true && _cityController.text.isEmpty) {
        _cityController.text = s['city']!;
      }
      setState(() { _showCountrySuggestions = false; _countrySuggestions = []; });
      _countryFocus.unfocus();
    }
  }

  void _selectRecent(Map<String, String> s) {
    _cityController.text = s['city'] ?? '';
    _countryController.text = s['country'] ?? '';
    setState(() { _showCitySuggestions = false; _showCountrySuggestions = false; });
    _search();
  }

  // ── Markers ────────────────────────────────────────────────────────

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    for (final user in _users) {
      final lat = double.tryParse(user['latitude'].toString());
      final lng = double.tryParse(user['longitude'].toString());
      if (lat == null || lng == null) continue;

      final role = (user['role'] ?? '').toString().toLowerCase();
      Color markerColor;
      IconData markerIcon;
      if (role == 'teacher' || role == 'admin') {
        markerColor = Colors.orange;
        markerIcon = Icons.school_outlined;
      } else if (role == 'student') {
        markerColor = const Color(0xFF1565C0);
        markerIcon = Icons.person_outline;
      } else if (role == 'owner') {
        markerColor = const Color(0xFFBF360C);
        markerIcon = Icons.account_balance_rounded;
      } else {
        markerColor = const Color(0xFF38BDF8);
        markerIcon = Icons.person;
      }

      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 60, height: 56,
        child: GestureDetector(
          onTap: () => _onMarkerTap(user, true),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: markerColor, shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)]),
              child: Icon(markerIcon, color: Colors.white, size: 16),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
              child: Text((user['name'] ?? '').toString().split(' ').first,
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      ));
    }

    for (final inst in _institutions) {
      final lat = double.tryParse(inst['latitude'].toString());
      final lng = double.tryParse(inst['longitude'].toString());
      if (lat == null || lng == null) continue;

      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 60, height: 56,
        child: GestureDetector(
          onTap: () => _onMarkerTap(inst, false),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFFBF360C), shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)]),
              child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
              child: Text(
                (inst['name'] ?? '').toString().length > 12
                    ? '${(inst['name'] ?? '').toString().substring(0, 12)}...'
                    : (inst['name'] ?? '').toString(),
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      ));
    }

    return markers;
  }

  // ── UI ─────────────────────────────────────────────────────────────

  Widget _buildSuggestionList(List<Map<String, String>> suggestions, bool isCity) {
    final recentToShow = _recentSearches.where((r) =>
      (isCity ? r['city'] : r['country']) != null &&
      (isCity ? r['city']! : r['country']!).isNotEmpty
    ).take(5).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recentToShow.isNotEmpty && suggestions.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text("Recent searches", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
            ...recentToShow.map((r) => ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(Icons.history, color: Colors.white38, size: 16),
              title: Text("${r['city']}, ${r['country']}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
              onTap: () => _selectRecent(r),
            )),
          ],
          if (suggestions.isNotEmpty) ...[
            if (recentToShow.isNotEmpty) const Divider(height: 1, color: Color(0xFF334155)),
            if (recentToShow.isNotEmpty) const Padding(
              padding: EdgeInsets.fromLTRB(12, 6, 12, 2),
              child: Text("Suggestions", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
            ...suggestions.map((s) => ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(Icons.location_on_outlined, color: Color(0xFF38BDF8), size: 16),
              title: Text("${s['city']}, ${s['country']}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
              subtitle: Text(
                (s['display'] ?? '').length > 60 ? '${(s['display'] ?? '').substring(0, 60)}...' : (s['display'] ?? ''),
                style: const TextStyle(color: Colors.white30, fontSize: 9),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _selectSuggestion(s, isCity),
            )),
          ],
          if (_isFetchingSuggestions)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)))),
            ),
        ],
      ),
    );
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
        title: const Text("MAP USERS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () { _cityFocus.unfocus(); _countryFocus.unfocus(); setState(() { _showCitySuggestions = false; _showCountrySuggestions = false; }); },
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            // City / Country search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(children: [
                Row(children: [
                  Expanded(flex: 3, child: TextField(
                    controller: _cityController,
                    focusNode: _cityFocus,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onChanged: (v) => _fetchSuggestions(v, true),
                    onTap: () => setState(() { _showCitySuggestions = true; _showCountrySuggestions = false; }),
                    decoration: InputDecoration(
                      hintText: "City", hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      prefixIcon: const Icon(Icons.location_city, color: Colors.white38, size: 18),
                      filled: true, fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  )),
                  const SizedBox(width: 8),
                  Expanded(flex: 3, child: TextField(
                    controller: _countryController,
                    focusNode: _countryFocus,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onChanged: (v) => _fetchSuggestions(v, false),
                    onTap: () => setState(() { _showCountrySuggestions = true; _showCitySuggestions = false; }),
                    decoration: InputDecoration(
                      hintText: "Country", hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      prefixIcon: const Icon(Icons.public, color: Colors.white38, size: 18),
                      filled: true, fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  )),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(color: const Color(0xFF38BDF8), borderRadius: BorderRadius.circular(12)),
                    child: IconButton(
                      icon: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.search, color: Colors.white, size: 20),
                      onPressed: _isLoading ? null : _search,
                    ),
                  ),
                ]),
              ]),
            ),

            // City suggestions
            if (_showCitySuggestions && (_citySuggestions.isNotEmpty || _isFetchingSuggestions || _cityController.text.isEmpty))
              Padding(padding: const EdgeInsets.only(top: 8), child: _buildSuggestionList(_citySuggestions, true)),

            // Country suggestions
            if (_showCountrySuggestions && (_countrySuggestions.isNotEmpty || _isFetchingSuggestions || _countryController.text.isEmpty))
              Padding(padding: const EdgeInsets.only(top: 8), child: _buildSuggestionList(_countrySuggestions, false)),

            const SizedBox(height: 8),

            // Role filter chips
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _roleFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final f = _roleFilters[i];
                  final isSelected = _selectedRole == f['id'];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedRole = f['id'] as String);
                      if (_hasSearched) _search();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? (f['color'] as Color) : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? (f['color'] as Color) : const Color(0xFF334155)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(f['icon'] as IconData, size: 14, color: isSelected ? Colors.white : Colors.white54),
                        const SizedBox(width: 5),
                        Text(f['label'] as String, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Map
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(initialCenter: _center, initialZoom: 12),
                    children: [
                      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.starlight.console'),
                      MarkerLayer(markers: _buildMarkers()),
                    ],
                  ),
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(8)),
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _legendItem(const Color(0xFF1565C0), Icons.person_outline, 'Student'),
                        const SizedBox(height: 4),
                        _legendItem(Colors.orange, Icons.school_outlined, 'Teacher'),
                        const SizedBox(height: 4),
                        _legendItem(const Color(0xFFBF360C), Icons.account_balance_rounded, 'Owner / Institution'),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),

            // Results bar
            if (_hasSearched)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFF1E293B),
                child: Row(children: [
                  if (_selectedRole != 'institutions') ...[
                    Icon(Icons.person, color: const Color(0xFF38BDF8), size: 16),
                    const SizedBox(width: 4),
                    Text("${_users.length}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(width: 12),
                  ],
                  if (_selectedRole != 'teachers' && _selectedRole != 'students') ...[
                    Icon(Icons.account_balance_rounded, color: const Color(0xFFE65100), size: 16),
                    const SizedBox(width: 4),
                    Text("${_institutions.length}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                  const Spacer(),
                  Text("${_cityController.text}, ${_countryController.text}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 14, height: 14,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1)),
        child: Icon(icon, color: Colors.white, size: 8),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500)),
    ]);
  }
}
