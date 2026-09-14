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
import '../../services/social/student_explore_service.dart';
import '../../services/social/student_friend_service.dart';
import '../../widgets/profile_avatar.dart';
import 'full_profile_screen.dart';
import 'chat_screen.dart';

class StudentMapScreen extends StatefulWidget {
  const StudentMapScreen({super.key});

  @override
  State<StudentMapScreen> createState() => _StudentMapScreenState();
}

class _StudentMapScreenState extends State<StudentMapScreen> {
  final StudentExploreService _exploreService = StudentExploreService();
  final StudentFriendService _friendService = StudentFriendService();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final FocusNode _cityFocus = FocusNode();
  final FocusNode _countryFocus = FocusNode();
  final MapController _mapController = MapController();

  List<dynamic> _students = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  LatLng _center = const LatLng(28.6139, 77.2090);

  List<Map<String, String>> _citySuggestions = [];
  List<Map<String, String>> _countrySuggestions = [];
  bool _showCitySuggestions = false;
  bool _showCountrySuggestions = false;
  bool _isFetchingSuggestions = false;

  List<Map<String, String>> _recentSearches = [];
  static const _cacheKey = 'student_map_recent_searches';
  static const _maxCache = 10;

  @override
  void initState() {
    super.initState();
    _loadCache();
    _loadLastLocation();
    _cityFocus.addListener(() {
      if (_cityFocus.hasFocus) {
        setState(() {
          _showCitySuggestions = true;
          _showCountrySuggestions = false;
        });
      }
    });
    _countryFocus.addListener(() {
      if (_countryFocus.hasFocus) {
        setState(() {
          _showCountrySuggestions = true;
          _showCitySuggestions = false;
        });
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
    await prefs.setStringList(_cacheKey, _recentSearches.map((e) => jsonEncode(e)).cast<String>().toList());
  }

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

    setState(() {
      _isLoading = true;
      _showCitySuggestions = false;
      _showCountrySuggestions = false;
    });
    _cityFocus.unfocus();
    _countryFocus.unfocus();

    try {
      final result = await _exploreService.getNearbyStudents(city, country);
      if (mounted) {
        final students = result['students'] ?? [];
        setState(() {
          _students = students;
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
    for (final s in _students) {
      final lat = double.tryParse(s['latitude'].toString());
      final lng = double.tryParse(s['longitude'].toString());
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

  void _onMarkerTap(dynamic student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullProfileScreen(
          item: student,
          isUser: true,
          hasInstitution: false,
        ),
      ),
    );
  }

  void _openChat(dynamic student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          friendId: student['id'].toString(),
          friendName: student['name'] ?? 'Student',
          friendRole: 'student',
          friendPublicId: student['shortId']?.toString(),
          fromInbox: false,
        ),
      ),
    );
  }

  Future<void> _handleAddFriend(dynamic student) async {
    try {
      await _friendService.sendStudentRequest(student['id'].toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Friend request sent to ${student['name']}!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.orange),
        );
      }
    }
  }

  void _selectSuggestion(Map<String, String> s, bool isCity) {
    if (isCity) {
      _cityController.text = s['city'] ?? '';
      if (s['country']?.isNotEmpty == true && _countryController.text.isEmpty) {
        _countryController.text = s['country']!;
      }
      setState(() {
        _showCitySuggestions = false;
        _citySuggestions = [];
      });
      _cityFocus.unfocus();
    } else {
      _countryController.text = s['country'] ?? '';
      if (s['city']?.isNotEmpty == true && _cityController.text.isEmpty) {
        _cityController.text = s['city']!;
      }
      setState(() {
        _showCountrySuggestions = false;
        _countrySuggestions = [];
      });
      _countryFocus.unfocus();
    }
  }

  void _selectRecent(Map<String, String> s) {
    _cityController.text = s['city'] ?? '';
    _countryController.text = s['country'] ?? '';
    setState(() {
      _showCitySuggestions = false;
      _showCountrySuggestions = false;
    });
    _search();
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    for (final student in _students) {
      final lat = double.tryParse(student['latitude'].toString());
      final lng = double.tryParse(student['longitude'].toString());
      if (lat == null || lng == null) continue;

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () => _onMarkerTap(student),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 14),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    (student['name'] ?? '').toString().split(' ').first,
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return markers;
  }

  Widget _buildSuggestionList(List<Map<String, String>> suggestions, bool isCity) {
    final recentToShow = _recentSearches.where((r) {
      final key = isCity ? r['city'] : r['country'];
      return key != null && key.isNotEmpty;
    }).take(5).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
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
            ...suggestions.map((s) => ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: const Icon(Icons.location_on_outlined, color: Color(0xFF38BDF8), size: 16),
              title: Text("${s['city']}, ${s['country']}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
              subtitle: Text(
                (s['display'] ?? '').length > 60 ? '${(s['display'] ?? '').substring(0, 60)}...' : (s['display'] ?? ''),
                style: const TextStyle(color: Colors.white30, fontSize: 9),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
        title: const Text("STUDENT MAP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () {
          _cityFocus.unfocus();
          _countryFocus.unfocus();
          setState(() {
            _showCitySuggestions = false;
            _showCountrySuggestions = false;
          });
        },
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _cityController,
                          focusNode: _cityFocus,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          onChanged: (v) => _fetchSuggestions(v, true),
                          onTap: () => setState(() {
                            _showCitySuggestions = true;
                            _showCountrySuggestions = false;
                          }),
                          decoration: InputDecoration(
                            hintText: "City",
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                            prefixIcon: const Icon(Icons.location_city, color: Colors.white38, size: 18),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _countryController,
                          focusNode: _countryFocus,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          onChanged: (v) => _fetchSuggestions(v, false),
                          onTap: () => setState(() {
                            _showCountrySuggestions = true;
                            _showCitySuggestions = false;
                          }),
                          decoration: InputDecoration(
                            hintText: "Country",
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                            prefixIcon: const Icon(Icons.public, color: Colors.white38, size: 18),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
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
                    ],
                  ),
                ],
              ),
            ),

            if (_showCitySuggestions && (_citySuggestions.isNotEmpty || _isFetchingSuggestions || _cityController.text.isEmpty))
              Padding(padding: const EdgeInsets.only(top: 8), child: _buildSuggestionList(_citySuggestions, true)),

            if (_showCountrySuggestions && (_countrySuggestions.isNotEmpty || _isFetchingSuggestions || _countryController.text.isEmpty))
              Padding(padding: const EdgeInsets.only(top: 8), child: _buildSuggestionList(_countrySuggestions, false)),

            const SizedBox(height: 8),

            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(initialCenter: _center, initialZoom: 12),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.starlight.console',
                        ),
                        MarkerLayer(markers: _buildMarkers()),
                      ],
                    ),
                    if (_students.isNotEmpty)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(color: const Color(0xFF1565C0), shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 5),
                              Text("${_students.length} students", style: const TextStyle(color: Colors.white, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}