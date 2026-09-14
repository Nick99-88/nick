import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/starlight_http.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/constants.dart';
import '../../../services/institution/dashboard_service.dart';
import '../tabs/database/dashboard_cache_service.dart';
import 'campaign_screen.dart';
import 'create_staff_campaign_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic> _stats = {};
  List<dynamic> _sections = [];
  bool _loadingStats = true;

  // Students tab state
  final _searchCtrl = TextEditingController();
  String? _selectedSection;
  List<dynamic> _searchResults = [];
  List<double> _searchScores = [];
  bool _hasSearched = false;
  bool _searching = false;
  bool _isLocalSearch = false;
  List<dynamic> _allStudents = [];
  bool _loadingAllStudents = false;
  bool _multiSelectMode = false;
  final Set<int> _selectedIndices = {};
  List<dynamic> _absentStudents = [];
  bool _loadingAttendance = false;
  bool _loadingMarksheets = false;
  Map<String, dynamic> _marksheetStats = {};

  // Financial tab state
  List<Map<String, dynamic>> _campaigns = [];
  bool _loadingFinance = false;
  Map<String, dynamic> _financeStats = {};
  List<Map<String, dynamic>> _staffCampaigns = [];
  bool _loadingStaffCampaigns = false;
  Map<String, dynamic> _staffStats = {};
  Map<String, dynamic> _advancedInsights = {};
  bool _loadingAdvanced = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  List<Map<String, dynamic>> get _recentCampaigns {
    final all = <Map<String, dynamic>>[];
    final activeStudents = _campaigns.where((c) {
      final remaining = (c['remaining_amount'] as num?)?.toDouble() ?? 
                        (((c['total_amount'] as num?)?.toDouble() ?? 0) - ((c['paid_amount'] as num?)?.toDouble() ?? 0));
      return c['status'] == 'active' && remaining > 0;
    });
    final activeStaff = _staffCampaigns.where((c) {
      final remaining = (c['remaining_amount'] as num?)?.toDouble() ?? 
                        (((c['total_amount'] as num?)?.toDouble() ?? 0) - ((c['paid_amount'] as num?)?.toDouble() ?? 0));
      return c['status'] == 'active' && remaining > 0;
    });
    
    all.addAll(activeStudents);
    all.addAll(activeStaff);
    all.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });
    return all;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadStats();
    _loadSections();
    _loadAbsentStudents();
    _loadTopPerformers();
    await _loadFinanceData();
    await _loadStaffCampaigns();
    await _loadAdvancedAnalytics();
  }

  Future<void> _loadSections() async {
    try {
      final List<String> sections = await DashboardService().getSections();
      if (mounted) {
        setState(() {
          _sections = sections;
        });
      }
    } catch (_) {}
  }

  // ---------- FUZZY SEARCH ENGINE (Vector-Like Matching) ----------

  String _getStudentField(Map<String, dynamic> student, String key, String altKey) {
    return (student[key]?.toString() ?? student[altKey]?.toString() ?? '');
  }

  List<String> _tokenize(String text) {
    return text.toLowerCase().split(RegExp(r'[\s_\-\.\/]+')).where((t) => t.isNotEmpty).toList();
  }

  double _ngramSimilarity(String a, String b, {int n = 2}) {
    if (a.length < n || b.length < n) return 0;
    final ngrams = <String>{};
    for (int i = 0; i <= a.length - n; i++) {
      ngrams.add(a.substring(i, i + n));
    }
    int overlap = 0;
    for (int i = 0; i <= b.length - n; i++) {
      if (ngrams.contains(b.substring(i, i + n))) overlap++;
    }
    return b.length - n + 1 > 0 ? overlap / (b.length - n + 1) : 0;
  }

  int _damerauLevenshtein(String a, String b) {
    final lenA = a.length;
    final lenB = b.length;
    final matrix = List.generate(lenA + 1, (i) => List.filled(lenB + 1, 0));
    for (int i = 0; i <= lenA; i++) matrix[i][0] = i;
    for (int j = 0; j <= lenB; j++) matrix[0][j] = j;
    for (int i = 1; i <= lenA; i++) {
      for (int j = 1; j <= lenB; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          matrix[i][j] = [matrix[i][j], matrix[i - 2][j - 2] + cost].reduce((a, b) => a < b ? a : b);
        }
      }
    }
    return matrix[lenA][lenB];
  }

  double _computeFuzzyScore(String fieldValue, String queryLower, List<String> queryTokens) {
    final fieldText = fieldValue.toLowerCase().trim();
    if (fieldText.isEmpty) return 0;

    double score = 0;

    if (fieldText == queryLower) return 100;

    if (fieldText.contains(queryLower)) {
      score += 50 + (queryLower.length / fieldText.length) * 20;
    }

    final fieldTokens = _tokenize(fieldText);
    for (final qToken in queryTokens) {
      for (final fToken in fieldTokens) {
        if (fToken == qToken) {
          score += 20;
        } else if (fToken.startsWith(qToken)) {
          score += 15 + (qToken.length / fToken.length) * 5;
        } else if (fToken.contains(qToken)) {
          score += 10;
        } else {
          final dist = _damerauLevenshtein(fToken, qToken);
          final maxLen = fToken.length > qToken.length ? fToken.length : qToken.length;
          if (dist <= maxLen * 0.3 && dist <= 3) {
            score += 8 * (1 - dist / maxLen);
          }
        }
      }
    }

    if (queryLower.length >= 2) {
      score += _ngramSimilarity(fieldText, queryLower) * 15;
    }

    return score;
  }

  List<Map<String, dynamic>> _fuzzySearch(String query, String section) {
    final queryLower = query.toLowerCase().trim();
    final queryTokens = _tokenize(queryLower);

    final scored = <_MapEntry<double>>[];

    for (final student in _allStudents) {
      double score = 0;

      score += _computeFuzzyScore(
        _getStudentField(student, 'name', 'student_name'), queryLower, queryTokens) * 3.0;

      score += _computeFuzzyScore(
        _getStudentField(student, 'father_name', 'fathername'), queryLower, queryTokens) * 2.0;

      score += _computeFuzzyScore(
        _getStudentField(student, 'id', 'student_id'), queryLower, queryTokens) * 1.5;

      score += _computeFuzzyScore(
        _getStudentField(student, 'access_key', ''), queryLower, queryTokens) * 1.0;

      if (section.isNotEmpty) {
        final studentSection = _getStudentField(student, 'section', 'section_name').toLowerCase();
        if (studentSection != section.toLowerCase()) {
          score = 0;
        }
      }

      if (score > 0) {
        scored.add(_MapEntry(student, score));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));

    _searchScores = scored.map((e) => e.value).toList();
    return scored.map((e) => e.key as Map<String, dynamic>).toList();
  }

  Future<void> _fetchAllStudents() async {
    if (_allStudents.isNotEmpty) return;
    if (_loadingAllStudents) return;

    setState(() => _loadingAllStudents = true);
    try {
      print("📦 [Fuzzy Search] Fetching all students for local search...");
      final res = await StarlightHttp.get(
        Uri.parse("${StarlightConstants.apiBaseUrl}/dashboard/my_students"),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        List<dynamic> students = [];
        if (body is List) {
          students = body;
        } else if (body is Map && body['students'] != null) {
          students = body['students'] as List;
        } else if (body is Map && body['data'] != null) {
          students = body['data'] as List;
        }
        print("📦 [Fuzzy Search] Loaded ${students.length} students for local matching.");
        setState(() => _allStudents = students);
      } else {
        throw Exception("Server returned ${res.statusCode}");
      }
    } catch (e) {
      print("❌ [Fuzzy Search] Server fetch failed ($e) — falling back to offline cache.");
      try {
        final cached = await DashboardCacheService.instance.getMyStudents();
        final students = cached['students'] ?? <dynamic>[];
        print("📦 [Fuzzy Search] Loaded ${students.length} students from offline cache.");
        setState(() => _allStudents = students);
      } catch (e2) {
        print("❌ [Fuzzy Search] Offline cache fallback also failed: $e2");
      }
    } finally {
      setState(() => _loadingAllStudents = false);
    }
  }

  Future<void> _searchStudents() async {
    final name = _searchCtrl.text.trim();
    final section = _selectedSection ?? '';
    if (name.isEmpty) {
      setState(() {
        _hasSearched = true;
        _searchResults = [];
        _searchScores = [];
        _isLocalSearch = false;
      });
      return;
    }

    print("🔍 [Owner Analytics Search] Triggered search: query_name='$name', filter_section='$section'");

    setState(() {
      _searching = true;
      _hasSearched = true;
      _isLocalSearch = false;
    });

    // Phase 1: Try server search
    bool serverReturned = false;
    try {
      final url = "${StarlightConstants.apiBaseUrl}/dashboard/students/search?name=${Uri.encodeComponent(name)}${section.isNotEmpty ? '&section=${Uri.encodeComponent(section)}' : ''}";
      print("🔍 [Owner Analytics Search] Requesting URL: $url");

      final res = await StarlightHttp.get(Uri.parse(url));

      print("🔍 [Owner Analytics Search] Server responded with code: ${res.statusCode}");

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        print("🔍 [Owner Analytics Search] Server returned ${data.length} records.");
        if (data.isNotEmpty) {
          _searchScores = List.filled(data.length, 100.0);
          setState(() {
            _searchResults = data;
          });
          serverReturned = true;
        }
      }
    } catch (e) {
      print("⚠️ [Owner Analytics Search] Server search failed: $e");
    }

    // Phase 2: Fallback to local fuzzy search
    if (!serverReturned) {
      print("🔍 [Fuzzy Search] Server returned empty; falling back to local fuzzy search...");
      await _fetchAllStudents();

      if (_allStudents.isNotEmpty) {
        final results = _fuzzySearch(name, section);
        print("🔍 [Fuzzy Search] Found ${results.length} fuzzy matches.");
        for (int i = 0; i < results.length && i < 5; i++) {
          final s = results[i];
          print("   👉 Match #${i + 1}: '${s['name']}' (score: ${_searchScores[i].toStringAsFixed(1)})");
        }
        setState(() {
          _searchResults = results;
          _isLocalSearch = true;
        });
      } else {
        setState(() {
          _searchResults = [];
          _searchScores = [];
        });
      }
    }

    setState(() => _searching = false);
  }

  Future<void> _loadStats() async {
    if (mounted) setState(() => _loadingStats = true);
    try {
      final res = await StarlightHttp.get(
        Uri.parse("${StarlightConstants.apiBaseUrl}/dashboard/stats"),
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) setState(() { _stats = data; });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingStats = false);
  }

  Future<void> _loadAbsentStudents() async {
    if (mounted) setState(() => _loadingAttendance = true);
    try {
      final res = await StarlightHttp.get(
        Uri.parse("${StarlightConstants.apiBaseUrl}/attendance/absent-students?min_days=3"),
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        if (mounted) setState(() => _absentStudents = data);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingAttendance = false);
  }

  Future<void> _loadTopPerformers() async {
    if (mounted) setState(() => _loadingMarksheets = true);
    try {
      final statsRes = await StarlightHttp.get(
        Uri.parse("${StarlightConstants.apiBaseUrl}/marksheet/stats"),
      ).timeout(const Duration(seconds: 12));
      if (statsRes.statusCode == 200) {
        if (mounted) setState(() => _marksheetStats = jsonDecode(statsRes.body));
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingMarksheets = false);
  }

  Future<void> _loadAdvancedAnalytics() async {
    if (mounted) setState(() => _loadingAdvanced = true);
    try {
      final res = await StarlightHttp.get(
        Uri.parse("${StarlightConstants.apiBaseUrl}/dashboard/analytics/owner"),
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _advancedInsights = data;
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingAdvanced = false);
  }

  Future<void> _loadFinanceData() async {
    print("📈 [Owner Analytics] Fetching student fee campaigns from server...");
    if (mounted) setState(() => _loadingFinance = true);
    try {
      final res = await StarlightHttp.get(
        Uri.parse("${StarlightConstants.apiBaseUrl}/finance/campaigns?campaign_type=student"),
      ).timeout(const Duration(seconds: 12));
      print("📈 [Owner Analytics] Student campaigns server response code: ${res.statusCode}");
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['campaigns'] != null) {
          final campaigns = List<Map<String, dynamic>>.from(data['campaigns']);
          print("📈 [Owner Analytics] Successfully loaded ${campaigns.length} student campaigns.");
          final now = DateTime.now();
          for (final c in campaigns) {
            print("📈 [Owner Analytics] Student Campaign: ${c['title']} | status: ${c['status']} | total: ${c['total_amount']} | paid: ${c['paid_amount']} | remaining: ${c['remaining_amount']}");
            if (c['status'] == 'active' && c['created_at'] != null) {
              final createdAt = DateTime.tryParse(c['created_at'].toString());
              if (createdAt != null && now.difference(createdAt).inDays >= 30) {
                c['status'] = 'closed';
                _closeCampaign(c['id']);
              }
            }
          }
          double totalDue = 0;
          double totalPaid = 0;
          final activeCampaigns = campaigns.where((c) {
            final remaining = (c['remaining_amount'] as num?)?.toDouble() ?? 
                              (((c['total_amount'] as num?)?.toDouble() ?? 0) - ((c['paid_amount'] as num?)?.toDouble() ?? 0));
            return c['status'] == 'active' && remaining > 0;
          }).toList();
          for (final c in activeCampaigns) {
            totalDue += (c['total_amount'] as num?)?.toDouble() ?? 0;
            totalPaid += (c['paid_amount'] as num?)?.toDouble() ?? 0;
          }
          if (mounted) setState(() {
            _campaigns = campaigns;
            _financeStats = {
              'total_due': totalDue,
              'total_paid': totalPaid,
              'collection_rate': totalDue > 0 ? ((totalPaid / totalDue) * 100).toStringAsFixed(1) : '0',
              'active_campaigns': activeCampaigns.length,
            };
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingFinance = false);
  }

  Future<void> _closeCampaign(dynamic campaignId) async {
    try {
      await StarlightHttp.put(
        Uri.parse("${StarlightConstants.apiBaseUrl}/finance/campaigns/$campaignId"),
        body: jsonEncode({'status': 'closed'}),
      );
    } catch (_) {}
  }

  Future<void> _createCampaign(String type) async {
    if (type == 'student') {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const CampaignScreen()),
      );
      if (result == true && mounted) {
        await _loadFinanceData();
      }
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateStaffCampaignScreen()),
    );
    if (result == true && mounted) {
      await _loadFinanceData();
      _loadStaffCampaigns();
    }
  }

  Future<void> _loadStaffCampaigns() async {
    print("📈 [Owner Analytics] Fetching staff salary campaigns from server...");
    if (mounted) setState(() => _loadingStaffCampaigns = true);
    try {
      final res = await StarlightHttp.get(
        Uri.parse("${StarlightConstants.apiBaseUrl}/finance/campaigns?campaign_type=staff"),
      ).timeout(const Duration(seconds: 12));
      print("📈 [Owner Analytics] Staff campaigns server response code: ${res.statusCode}");
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['campaigns'] != null) {
          final campaigns = List<Map<String, dynamic>>.from(data['campaigns']);
          print("📈 [Owner Analytics] Successfully loaded ${campaigns.length} staff campaigns.");
          for (final c in campaigns) {
            print("📈 [Owner Analytics] Staff Campaign: ${c['title']} | status: ${c['status']} | total: ${c['total_amount']} | paid: ${c['paid_amount']} | remaining: ${c['remaining_amount']}");
          }
          
          double totalSalary = 0;
          double paidSalary = 0;
          final activeCampaigns = campaigns.where((c) {
            final remaining = (c['remaining_amount'] as num?)?.toDouble() ?? 
                              (((c['total_amount'] as num?)?.toDouble() ?? 0) - ((c['paid_amount'] as num?)?.toDouble() ?? 0));
            return c['status'] == 'active' && remaining > 0;
          }).toList();
          for (final c in activeCampaigns) {
            totalSalary += (c['total_amount'] as num?)?.toDouble() ?? 0;
            paidSalary += (c['paid_amount'] as num?)?.toDouble() ?? 0;
          }
          
          if (mounted) {
            setState(() {
              _staffCampaigns = campaigns;
              _staffStats = {
                'total_salary': totalSalary,
                'paid_salary': paidSalary,
                'remaining_salary': totalSalary - paidSalary,
                'paid_rate': totalSalary > 0 ? ((paidSalary / totalSalary) * 100).toStringAsFixed(1) : '0',
              };
            });
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingStaffCampaigns = false);
  }

  Future<void> _showCampaignHistory() async {
    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch fresh data for both student and staff campaigns in parallel
      await Future.wait([
        _loadFinanceData(),
        _loadStaffCampaigns(),
      ]);
    } catch (_) {}

    // Dismiss loading dialog
    if (mounted) Navigator.pop(context);

    // Now open the history sheet with the freshly fetched data!
    if (mounted) {
      _showCampaignHistorySheet();
    }
  }

  void _showCampaignHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        // Filter student campaigns: closed OR remaining_amount <= 0
        final studentHistory = _campaigns.where((c) {
          final remaining = (c['remaining_amount'] as num?)?.toDouble() ?? 
                            (((c['total_amount'] as num?)?.toDouble() ?? 0) - ((c['paid_amount'] as num?)?.toDouble() ?? 0));
          return c['status'] == 'closed' || remaining <= 0;
        }).toList();

        // Filter staff campaigns: closed OR remaining_amount <= 0
        final staffHistory = _staffCampaigns.where((c) {
          final remaining = (c['remaining_amount'] as num?)?.toDouble() ?? 
                            (((c['total_amount'] as num?)?.toDouble() ?? 0) - ((c['paid_amount'] as num?)?.toDouble() ?? 0));
          return c['status'] == 'closed' || remaining <= 0;
        }).toList();

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollCtrl) => DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                const Text("Campaign History", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                TabBar(
                  labelColor: const Color(0xFF0288D1),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF0288D1),
                  tabs: const [
                    Tab(text: "Student Fees"),
                    Tab(text: "Staff Salary"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildHistoryList(studentHistory, scrollCtrl, loading: false),
                      _buildHistoryList(staffHistory, scrollCtrl, loading: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryList(List<Map<String, dynamic>> list, ScrollController scrollCtrl, {bool loading = false}) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return const Center(child: Text("No campaigns found", style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final c = list[i];
        final total = (c['total_amount'] as num?)?.toDouble() ?? 0;
        final paid = (c['paid_amount'] as num?)?.toDouble() ?? 0;
        final progress = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;
        final section = c['section'] ?? '';
        final memberCount = (c['students'] ?? c['payments'] ?? c['personnel'])?.length ?? 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: InkWell(
            onTap: () {
              Navigator.pop(ctx); // Close sheet
              _showCampaignDetails(c);
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(c['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: c['status'] == 'active' ? const Color(0xFF2E7D32).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          c['status'] == 'active' ? 'Active' : 'Closed',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: c['status'] == 'active' ? const Color(0xFF2E7D32) : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (section.isNotEmpty || memberCount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (section.isNotEmpty) ...[
                          const Icon(Icons.class_, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(section, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(width: 12),
                        ],
                        if (memberCount > 0) ...[
                          const Icon(Icons.people, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            c['campaign_type'] == 'staff' || c['campaign_type'] == 'staff_salary'
                                ? "$memberCount personnel"
                                : "$memberCount students",
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress, backgroundColor: Colors.grey[200], color: const Color(0xFF2E7D32)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Paid: ${paid.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                      Text("Total: ${total.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // The screen uses hardcoded light backgrounds (scaffold + cards), but many
    // texts rely on the theme default color. In dark mode that default is near-white,
    // making text invisible ("blending" into the background). Force a light text
    // theme for this subtree so default-colored text stays dark/readable.
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.light,
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: const Color(0xFF263238),
          displayColor: const Color(0xFF263238),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("ANALYTICS", style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0288D1),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF0288D1),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.people, size: 20), text: "Students"),
            Tab(icon: Icon(Icons.account_balance, size: 20), text: "Institutional"),
            Tab(icon: Icon(Icons.monetization_on, size: 20), text: "Financial"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStudentsTab(),
          _buildInstitutionalTab(),
          _buildFinancialTab(),
        ],
      ),
      ),
    );
  }

  Widget _buildStudentsTab() {
    if (_loadingStats) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: () async {
        await _loadStats();
        _loadSections();
        _loadAbsentStudents();
        _loadTopPerformers();
        _loadFinanceData();
        await _loadAdvancedAnalytics();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statRow([
            _statCard("Students", _stats['student_count'] ?? 0, Icons.people,
                const Color(0xFF0288D1)),
            _statCard("Sections", _stats['total_sections'] ?? 0, Icons.group_work,
                const Color(0xFF2E7D32)),
          ]),
          const SizedBox(height: 16),

          // 🔍 STUDENT SEARCH ENGINE CARD
          Card(
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.search_rounded, color: Color(0xFF1A237E), size: 20),
                      SizedBox(width: 8),
                      Text("STUDENT SEARCH ENGINE",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A237E),
                              letterSpacing: 0.8)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: "Enter student name...",
                            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.withOpacity(0.4)),
                            ),
                          ),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF263238)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedSection,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF263238)),
                        dropdownColor: Colors.white,
                        hint: const Text("Section", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        onChanged: (val) {
                          setState(() {
                            _selectedSection = val;
                          });
                        },
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text("All", style: TextStyle(fontSize: 12, color: Color(0xFF263238))),
                          ),
                          ..._sections.map((sec) => DropdownMenuItem<String>(
                                value: sec.toString(),
                                child: Text(sec.toString(),
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF263238))),
                              )),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1A237E),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _searchStudents,
                    icon: const Icon(Icons.person_search_rounded, size: 18),
                    label: const Text("Run Analytics Lookup",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),

                  // Lookup Results List
                  if (_searching)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_hasSearched) ...[
                    const Divider(height: 24),
                    Row(
                      children: [
                        Text(
                            "LOOKUP RESULTS (${_searchResults.length} Match${_searchResults.length == 1 ? '' : 'es'})",
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF607D8B))),
                        const Spacer(),
                        if (_isLocalSearch && _searchResults.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A237E).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text("LOCAL FUZZY MATCH",
                                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_searchResults.isEmpty && _loadingAllStudents)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: Text("Loading student database for local matching...",
                            style: TextStyle(fontSize: 12, color: Color(0xFF607D8B)))),
                      )
                    else if (_searchResults.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                            child: Text("No matching records found",
                                style: TextStyle(fontSize: 12, color: Color(0xFF607D8B)))),
                      )
                    else ...[
                      // Multi-select controls
                      if (_multiSelectMode)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Text("${_selectedIndices.length} selected",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                              const Spacer(),
                              if (_selectedIndices.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        final selected = _selectedIndices.map((i) => _searchResults[i]).toList();
                                        _exportMultipleStudents(selected, 'txt');
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1A1A2E),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text("TXT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () {
                                        final selected = _selectedIndices.map((i) => _searchResults[i]).toList();
                                        _exportMultipleStudents(selected, 'html');
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(colors: [Color(0xFF64FFDA), Color(0xFF00BCD4)]),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text("HTML", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () async {
                                        final selected = _selectedIndices.map((i) => _searchResults[i]).toList();
                                        for (final s in selected) {
                                          await _exportStudentPdf(s as Map<String, dynamic>);
                                        }
                                        setState(() {
                                          _multiSelectMode = false;
                                          _selectedIndices.clear();
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF7043),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text("PDF", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                    ),
                                  ],
                                ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _multiSelectMode = false;
                                    _selectedIndices.clear();
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(Icons.close, size: 16, color: Colors.grey.shade600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ..._searchResults.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final student = entry.value;
                        final score = idx < _searchScores.length ? _searchScores[idx] : 0.0;
                        final scoreLabel = score >= 80 ? "MATCH" : (score >= 50 ? "GOOD" : (score >= 20 ? "FAIR" : "WEAK"));
                        final scoreColor = score >= 80 ? const Color(0xFF2E7D32) : (score >= 50 ? const Color(0xFF0288D1) : (score >= 20 ? const Color(0xFFE65100) : Colors.grey));
                        final isSelected = _selectedIndices.contains(idx);

                        return Material(
                          color: isSelected ? const Color(0xFF1A237E) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: () {
                              if (_multiSelectMode) {
                                setState(() {
                                  if (isSelected) { _selectedIndices.remove(idx); } else { _selectedIndices.add(idx); }
                                });
                              } else {
                                _showStudentAnalyticsDialog(student);
                              }
                            },
                            onLongPress: () {
                              setState(() {
                                _multiSelectMode = true;
                                _selectedIndices.add(idx);
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  if (_multiSelectMode) ...[
                                    Icon(
                                      isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                      size: 18, color: isSelected ? Colors.white : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(student['name'] ?? 'Unknown Student',
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? Colors.white : const Color(0xFF1A237E)),
                                                  overflow: TextOverflow.ellipsis),
                                            ),
                                            if (_isLocalSearch) ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: scoreColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(scoreLabel,
                                                    style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: scoreColor)),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text("Section: ${student['section_name'] ?? student['section'] ?? 'Unassigned'}",
                                            style: TextStyle(fontSize: 11, color: isSelected ? Colors.white70 : const Color(0xFF1A237E).withOpacity(0.6))),
                                      ],
                                    ),
                                  ),
                                  if (!_multiSelectMode) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.grey),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 🚨 ATTENDANCE ALERT SECTOR
          _sectionHeader(Icons.event_busy, "ATTENDANCE ALERT",
              "Students absent for 3+ consecutive days"),
          if (_loadingAttendance)
            const Center(child: CircularProgressIndicator())
          else if (_absentStudents.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 20),
                  SizedBox(width: 8),
                  Text("No attendance warnings. Perfect engagement!",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32))),
                ],
              ),
            )
          else
            ..._absentStudents.map((stud) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0x33FFCDD2),
                      child: Icon(Icons.warning, color: Colors.redAccent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stud['name'] ?? 'Unknown Student',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A237E))),
                          Text("Section: ${stud['section_name'] ?? 'N/A'}",
                              style: const TextStyle(fontSize: 11, color: Color(0xFF607D8B))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text("${stud['absent_count'] ?? 3} Days Absent",
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 16),

          // 🏆 ACADEMIC INSIGHTS SECTOR
          _sectionHeader(Icons.emoji_events, "ACADEMIC INSIGHTS",
              "Institutional marksheet and grading analysis"),
          if (_loadingMarksheets)
            const Center(child: CircularProgressIndicator())
          else if (_marksheetStats.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child: Text("No academic stats available yet.",
                        style: TextStyle(fontSize: 12, color: Colors.grey))),
              ),
            )
          else ...[
            _statRow([
              _statCard("Pass Rate", "${(_marksheetStats['pass_rate'] as num?)?.toStringAsFixed(1) ?? '0'}%",
                  Icons.pie_chart, const Color(0xFF2E7D32)),
              _statCard("Passed", _marksheetStats['passed_students'] ?? 0,
                  Icons.check_circle_outline, const Color(0xFF0288D1)),
            ]),
            const SizedBox(height: 8),
            _statRow([
              _statCard("Failed", _marksheetStats['failed_students'] ?? 0,
                  Icons.cancel_outlined, Colors.redAccent),
              _statCard("Total Scored", _marksheetStats['total_students'] ?? 0,
                  Icons.assignment_turned_in, Colors.indigo),
            ]),
          ],
          const SizedBox(height: 16),
          _buildAdvancedStudentInsights(),
        ],
      ),
    );
  }

  void _showStudentAnalyticsDialog(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: _StudentDetailCard(
          student: student,
          formatDate: _formatAnalyticsDate,
          onExport: (format) => _exportStudentDetail(student, format),
        ),
      ),
    );
  }

  Future<void> _exportStudentDetail(Map<String, dynamic> student, String format) async {
    if (format == 'pdf') {
      await _exportStudentPdf(student);
      return;
    }
    try {
      final name = student['name']?.toString() ?? 'student';
      final father = student['father_name']?.toString() ?? 'N/A';
      final section = student['section_name']?.toString() ?? student['section']?.toString() ?? 'Unassigned';
      final id = student['id']?.toString() ?? 'N/A';
      final fee = student['fee']?.toString() ?? '0';
      final date = _formatAnalyticsDate(student['created_at']) ?? 'N/A';

      final String content;
      final String fileName;

      if (format == 'txt') {
        content = [
          'STUDENT PROFILE REPORT',
          '===============================================',
          '',
          'Name: $name',
          "Father's Name: $father",
          'Section: $section',
          'ID Number: $id',
          'Monthly Fee: $fee',
          'Admission Date: $date',
          'Status: Active Student',
          '',
          '===============================================',
          'Generated by Starlight Institutional Analytics',
        ].join('\r\n');
        fileName = '${name.replaceAll(' ', '_')}_profile.txt';
      } else {
        content = '<html>\n' +
          '<head><title>Student Profile - $name</title>\n' +
          '<style>\n' +
          '  body{font-family:Arial,sans-serif;background:#f5f5f5;padding:40px;}\n' +
          '  .card{background:#1a1a2e;color:#fff;border-radius:16px;padding:32px;max-width:500px;margin:auto;}\n' +
          '  .header{text-align:center;margin-bottom:24px;}\n' +
          '  .header h1{font-size:22px;margin:8px 0 4px;color:#64ffda;}\n' +
          '  .badge{background:#e8f5e9;color:#2e7d32;padding:4px 12px;border-radius:12px;font-size:12px;font-weight:bold;display:inline-block;}\n' +
          '  .row{display:flex;justify-content:space-between;padding:10px 0;border-bottom:1px solid rgba(255,255,255,0.08);}\n' +
          '  .label{color:#90a4ae;font-size:13px;}\n' +
          '  .value{color:#fff;font-size:14px;font-weight:bold;}\n' +
          '  .footer{text-align:center;margin-top:24px;font-size:11px;color:#546e7a;}\n' +
          '</style></head>\n' +
          '<body>\n' +
          '<div class="card">\n' +
          '  <div class="header">\n' +
          '    <div style="font-size:40px;margin-bottom:8px;">🎓</div>\n' +
          '    <h1>$name</h1>\n' +
          '    <span class="badge">Active Student</span>\n' +
          '  </div>\n' +
          '  <div class="row"><span class="label">Father\'s Name</span><span class="value">$father</span></div>\n' +
          '  <div class="row"><span class="label">Section</span><span class="value">$section</span></div>\n' +
          '  <div class="row"><span class="label">ID Number</span><span class="value">$id</span></div>\n' +
          '  <div class="row"><span class="label">Monthly Fee</span><span class="value">\$$fee</span></div>\n' +
          '  <div class="row"><span class="label">Admission Date</span><span class="value">$date</span></div>\n' +
          '  <div class="footer">Generated by Starlight Institutional Analytics</div>\n' +
          '</div>\n' +
          '</body>\n' +
          '</html>';
        fileName = '${name.replaceAll(' ', '_')}_profile.html';
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(content);

      if (!context.mounted) return;

      final selected = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Export Complete", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text("$fileName saved.\n\nOpen or share the file?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'open'),
              child: const Text("Open File", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0288D1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, 'share'),
              child: const Text("Share", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (selected == 'open') {
        await OpenFile.open(file.path);
      } else if (selected == 'share') {
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], text: "Student Profile - $name"),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e")),
        );
      }
    }
  }

  Future<void> _exportStudentPdf(Map<String, dynamic> student) async {
    try {
      final name = student['name']?.toString() ?? 'Student';
      final father = student['father_name']?.toString() ?? 'N/A';
      final section = student['section_name']?.toString() ?? student['section']?.toString() ?? 'Unassigned';
      final id = student['id']?.toString() ?? 'N/A';
      final fee = student['fee']?.toString() ?? '0';
      final date = _formatAnalyticsDate(student['created_at']) ?? 'N/A';

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF1A1A2E),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(
                      child: pw.Column(
                        children: [
                          pw.Text('Student Profile',
                              style: pw.TextStyle(color: PdfColor.fromInt(0xFF64FFDA), fontSize: 22, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromInt(_blendColor(0xFF2E7D32, 0xFF1A1A2E, 0.15)),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                            ),
                            child: pw.Text('Active Student',
                                style: pw.TextStyle(color: PdfColor.fromInt(0xFF4CAF50), fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    _pdfRow('Name', name),
                    _pdfRow('Father\'s Name', father),
                    _pdfRow('Section', section),
                    _pdfRow('ID Number', id),
                    _pdfRow('Monthly Fee', '\$$fee'),
                    _pdfRow('Admission Date', date),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text('Generated by Starlight Institutional Analytics',
                    style: pw.TextStyle(color: PdfColor.fromInt(0xFF90A4AE), fontSize: 9)),
              ),
            ],
          ),
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: '${name.replaceAll(' ', '_')}_profile.pdf',
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PDF ready — shared via system sheet")),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("PDF export failed: $e")),
        );
      }
    }
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(_blendColor(0xFFFFFF, 0xFF1A1A2E, 0.08)))),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(color: PdfColor.fromInt(0xFF90A4AE), fontSize: 11)),
          pw.Text(value, style: pw.TextStyle(color: PdfColor.fromInt(0xFFFFFFFF), fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _exportMultipleStudents(List<dynamic> students, String format) async {
    if (students.isEmpty) return;
    try {
      final lines = <String>[];
      for (final s in students) {
        final name = s['name']?.toString() ?? 'Unknown';
        final father = s['father_name']?.toString() ?? 'N/A';
        final section = s['section_name']?.toString() ?? s['section']?.toString() ?? 'N/A';
        final id = s['id']?.toString() ?? 'N/A';
        final fee = s['fee']?.toString() ?? '0';
        final date = _formatAnalyticsDate(s['created_at']) ?? 'N/A';
        if (format == 'txt') {
          lines.add('Name: $name | Father: $father | Section: $section | ID: $id | Fee: \$$fee | Date: $date');
        } else {
          lines.add('''<div class="row"><span class="label">$name</span><span class="value">$father | $section | $id</span></div>''');
        }
      }

      final String content;
      final String fileName;
      if (format == 'txt') {
        final now = DateTime.now();
        content = [
          'BATCH STUDENT EXPORT',
          'Generated: ${now.toString().substring(0, 19)}',
          'Total Students: ${students.length}',
          '============================================================',
          '',
          ...lines,
          '',
          '============================================================',
          'Generated by Starlight Institutional Analytics',
        ].join('\r\n');
        fileName = 'batch_students_${now.millisecondsSinceEpoch}.txt';
      } else {
        final now = DateTime.now();
        final meta = '${students.length} students | ${now.toString().substring(0, 10)}';
        content = [
          '<html>',
          '<head><title>Batch Student Export</title>',
          '<style>',
          '  body{font-family:Arial,sans-serif;background:#f5f5f5;padding:40px;}',
          '  .card{background:#1a1a2e;color:#fff;border-radius:16px;padding:32px;max-width:700px;margin:auto;}',
          '  h1{color:#64ffda;font-size:20px;text-align:center;}',
          '  .meta{text-align:center;color:#90a4ae;font-size:12px;margin-bottom:20px;}',
          '  .row{display:flex;justify-content:space-between;padding:10px 0;border-bottom:1px solid rgba(255,255,255,0.08);}',
          '  .label{color:#64ffda;font-weight:bold;font-size:13px;}',
          '  .value{color:#fff;font-size:13px;}',
          '  .footer{text-align:center;margin-top:24px;font-size:11px;color:#546e7a;}',
          '</style></head>',
          '<body>',
          '<div class="card">',
          '  <h1>Batch Student Export</h1>',
          '  <div class="meta">$meta</div>',
          ...lines,
          '  <div class="footer">Generated by Starlight Institutional Analytics</div>',
          '</div>',
          '</body>',
          '</html>',
        ].join('\n');
        fileName = 'batch_students_${now.millisecondsSinceEpoch}.html';
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(content);

      if (!context.mounted) return;
      setState(() {
        _multiSelectMode = false;
        _selectedIndices.clear();
      });

      final selected = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("${students.length} Students Exported", style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text("$fileName saved.\n\nOpen or share the file?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'open'),
              child: const Text("Open File", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0288D1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, 'share'),
              child: const Text("Share", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (selected == 'open') {
        await OpenFile.open(file.path);
      } else if (selected == 'share') {
        await SharePlus.instance.share(
          ShareParams(files: [XFile(file.path)], text: "Batch Student Export (${students.length})"),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Batch export failed: $e")),
        );
      }
    }
  }

  String? _formatAnalyticsDate(dynamic dateStr) {
    if (dateStr == null) return null;
    try {
      final dt = DateTime.parse(dateStr.toString());
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (_) {
      return dateStr.toString();
    }
  }

  Widget _buildInstitutionalTab() {
    if (_loadingStats) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: () async {
        await _loadStats();
        await _loadAdvancedAnalytics();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _insightCard(Icons.people_outline, "Total Enrollment", "${_stats['student_count'] ?? 0}", "Students across ${_stats['total_sections'] ?? 0} sections"),
          const SizedBox(height: 12),
          _insightCard(Icons.school_outlined, "Faculty Strength", "${_stats['teacher_count'] ?? 0}", "Teachers managing academic delivery"),
          const SizedBox(height: 12),
          _insightCard(Icons.support_agent, "Support Staff", "${_stats['staff_count'] ?? 0}", "Administrative & operational personnel"),
          const SizedBox(height: 16),
          _buildInstitutionalAdvancedInsights(),
        ],
      ),
    );
  }

  Widget _buildFinancialTab() {
    if (_loadingFinance) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: () async {
        await _loadFinanceData();
        await _loadStaffCampaigns();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // STUDENT FEE SECTOR
          _sectionHeader(Icons.school, "STUDENT FEES SUMMARY", "Active collection metrics"),
          _statRow([
            _statCard("Fees Paid", _financeStats['total_paid'] ?? 0, Icons.check_circle, const Color(0xFF2E7D32)),
            _statCard("Fees Due", _financeStats['total_due'] ?? 0, Icons.pending, const Color(0xFFE65100)),
          ]),
          const SizedBox(height: 12),
          _insightCard(Icons.pie_chart, "Collection Rate", "${_financeStats['collection_rate'] ?? 0}%", "Fee collection performance"),
          const SizedBox(height: 20),

          // STAFF SALARY SECTOR
          _sectionHeader(Icons.work, "STAFF SALARIES SUMMARY", "Active payroll metrics"),
          _statRow([
            _statCard("Salaries Paid", _staffStats['paid_salary'] ?? 0, Icons.check_circle, const Color(0xFF2E7D32)),
            _statCard("Salaries Due", _staffStats['remaining_salary'] ?? 0, Icons.pending, const Color(0xFFE65100)),
          ]),
          const SizedBox(height: 12),
          _insightCard(Icons.pie_chart, "Disbursal Rate", "${_staffStats['paid_rate'] ?? 0}%", "Salary disbursal performance"),
          const SizedBox(height: 20),

          // CAMPAIGN OVERVIEW
          _sectionHeader(Icons.analytics, "CAMPAIGN METRICS", "Aggregate system counts"),
          _insightCard(Icons.campaign, "Active Campaigns", "${(_financeStats['active_campaigns'] ?? 0) + _staffCampaigns.where((c) {
            final remaining = (c['remaining_amount'] as num?)?.toDouble() ?? 
                              (((c['total_amount'] as num?)?.toDouble() ?? 0) - ((c['paid_amount'] as num?)?.toDouble() ?? 0));
            return c['status'] == 'active' && remaining > 0;
          }).length}", "Ongoing collection & salary drives"),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  "Student Fee",
                  Icons.school,
                  const Color(0xFF0288D1),
                  () => _createCampaign('student'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionButton(
                  "Staff Salary",
                  Icons.work,
                  const Color(0xFF7B1FA2),
                  () => _createCampaign('staff'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showCampaignHistory,
              icon: const Icon(Icons.history, size: 18),
              label: const Text("Campaign History", style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A237E),
                side: const BorderSide(color: Color(0xFF1A237E)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionHeader(Icons.receipt_long, "ACTIVE CAMPAIGNS", "Ongoing collection & salary history"),
          if (_recentCampaigns.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text("No active campaigns found", style: TextStyle(color: Colors.grey))),
            )
          else
            ..._recentCampaigns.take(5).map((c) => _buildCampaignTile(c)),
        ],
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignTile(Map<String, dynamic> c) {
    final total = (c['total_amount'] as num?)?.toDouble() ?? 0;
    final paid = (c['paid_amount'] as num?)?.toDouble() ?? 0;
    final progress = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;
    final status = c['status'] ?? 'active';
    final createdAt = c['created_at'] != null ? DateTime.tryParse(c['created_at'].toString()) : null;
    final title = c['title'] ?? '';
    final type = c['campaign_type'] ?? 'student';
    final isStaff = type == 'staff' || type == 'staff_salary';

    String timerText = '';
    Color timerColor = Colors.grey;
    if (status == 'active' && createdAt != null) {
      final expiresAt = createdAt.add(const Duration(days: 30));
      final remaining = expiresAt.difference(DateTime.now());
      if (remaining.isNegative) {
        timerText = 'Expired';
        timerColor = const Color(0xFFE65100);
      } else {
        final days = remaining.inDays;
        final hours = remaining.inHours % 24;
        if (days > 0) {
          timerText = '${days}d ${hours}h left';
        } else {
          final minutes = remaining.inMinutes % 60;
          timerText = '${hours}h ${minutes}m left';
        }
        timerColor = days <= 3 ? const Color(0xFFE65100) : const Color(0xFF2E7D32);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => _showCampaignDetails(c),
        onLongPress: () => _confirmDeleteCampaign(c),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isStaff ? Icons.work : Icons.school,
                    size: 16,
                    color: isStaff ? const Color(0xFF7B1FA2) : const Color(0xFF0288D1),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: status == 'active' ? const Color(0xFF2E7D32).withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status == 'active' ? 'Active' : 'Closed',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: status == 'active' ? const Color(0xFF2E7D32) : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              if (timerText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 12, color: timerColor),
                    const SizedBox(width: 4),
                    Text(timerText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: timerColor)),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress, backgroundColor: Colors.grey[200], color: const Color(0xFF2E7D32)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Paid: ${paid.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                  Text("Total: ${total.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _authenticate(String reason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _confirmDeleteCampaign(Map<String, dynamic> c) async {
    final title = c['title'] ?? 'Campaign';
    final campaignId = c['id'] ?? '';
    if (campaignId.toString().isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Delete Campaign", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          "Are you sure you want to permanently delete \"$title\"?\nThis will remove all associated payment and budget records.",
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteCampaign(campaignId.toString());
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCampaign(String campaignId) async {
    final authed = await _authenticate("Authenticate to delete this campaign");
    if (!authed) return;

    try {
      final res = await StarlightHttp.delete(
        Uri.parse("${StarlightConstants.apiBaseUrl}/finance/campaigns/$campaignId"),
      );

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Campaign deleted successfully")),
          );
        }
        await _loadFinanceData();
        await _loadStaffCampaigns();
      } else {
        throw Exception("Server returned HTTP ${res.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to delete campaign: $e")),
        );
      }
    }
  }

  void _showCampaignDetails(Map<String, dynamic> c) async {
    final campaignId = c['id'] ?? '';

    // Fetch full campaign data with students
    Map<String, dynamic> fullCampaign = Map.from(c);
    if (campaignId.toString().isNotEmpty) {
      try {
        final res = await StarlightHttp.get(
          Uri.parse("${StarlightConstants.apiBaseUrl}/finance/campaigns/$campaignId"),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map) {
            fullCampaign = Map<String, dynamic>.from(data);
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CampaignScreen(campaign: fullCampaign)),
    );
    if (result == true && mounted) {
      await _loadFinanceData();
      _loadStaffCampaigns();
    }
  }

  Widget _statCard(String title, dynamic val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF607D8B))),
                const SizedBox(height: 2),
                Text(val.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A237E))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightCard(IconData icon, String title, String val, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: const Color(0xFF1A237E).withOpacity(0.1), child: Icon(icon, color: const Color(0xFF1A237E))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF263238))),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF607D8B))),
              ],
            ),
          ),
          Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1A237E))),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10, top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1A237E), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A237E), letterSpacing: 0.5)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF607D8B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(List<Widget> children) {
    return Row(
      children: children.map((c) => Expanded(child: c)).toList(),
    );
  }

  Widget _buildAdvancedStudentInsights() {
    if (_loadingAdvanced) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final studentInsights = _advancedInsights['student_insights'];
    if (studentInsights == null) {
      return const SizedBox.shrink();
    }

    final List toppers = studentInsights['toppers'] ?? [];
    final List improving = studentInsights['improving'] ?? [];
    final List losing = studentInsights['losing'] ?? [];
    final List absentees = studentInsights['absentees'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. TOP PERFORMERS (TROPHY LIST)
        if (toppers.isNotEmpty) ...[
          _sectionHeader(Icons.workspace_premium, "ACADEMIC TOPPERS", "Students with highest exam performance"),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: toppers.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final t = entry.value;
                  final percentage = (t['percentage'] as num?)?.toDouble() ?? 0.0;
                  final isTop1 = idx == 0;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: isTop1 ? const Color(0xFFFFF9C4) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: isTop1 ? const Color(0xFFFFD54F) : const Color(0xFFE0E0E0),
                          child: Text(
                            "${idx + 1}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text("Subject: ${t['subject']} (${t['exam_title']})", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${percentage.toStringAsFixed(1)}%",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF2E7D32)),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 2. RISING STARS & PERFORMANCE DROPS (COMPARISON PROGRESS CLUSTERS)
        if (improving.isNotEmpty || losing.isNotEmpty) ...[
          _sectionHeader(Icons.trending_up, "MARKS PROGRESSION", "Comparing performance deltas of last two exams"),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rising Stars (Improving)
              if (improving.isNotEmpty)
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: const Color(0xFFE8F5E9),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.rocket_launch, color: Color(0xFF2E7D32), size: 16),
                              SizedBox(width: 4),
                              Text("RISING STARS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF2E7D32))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...improving.take(3).map((student) {
                            final delta = (student['improvement'] as num?)?.toDouble() ?? 0.0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(student['name'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                  Text("+${delta.toStringAsFixed(0)}%", style: const TextStyle(fontSize: 10, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              if (improving.isNotEmpty && losing.isNotEmpty) const SizedBox(width: 10),
              // Needs Attention (Losing Marks)
              if (losing.isNotEmpty)
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: const Color(0xFFFFEBEE),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.trending_down, color: Color(0xFFC62828), size: 16),
                              SizedBox(width: 4),
                              Text("NEEDS EFFORT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFC62828))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...losing.take(3).map((student) {
                            final delta = (student['decrease'] as num?)?.toDouble() ?? 0.0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(student['name'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                  Text("-${delta.toStringAsFixed(0)}%", style: const TextStyle(fontSize: 10, color: Color(0xFFC62828), fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // 3. LONG ABSENTEES (ATTENDANCE CHRONICS)
        if (absentees.isNotEmpty) ...[
          _sectionHeader(Icons.warning, "CHRONIC ABSENTEEISM", "Students missing significant number of academic days"),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: absentees.map((stud) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFF3E0),
                        child: Icon(Icons.person_off_rounded, color: Colors.orange, size: 16),
                      ),
                      title: Text(stud['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text("Section: ${stud['section'] ?? 'Unassigned'}", style: const TextStyle(fontSize: 11)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          "${stud['absent_count']} Absences",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.orange.shade800),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildInstitutionalAdvancedInsights() {
    if (_loadingAdvanced) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final instInsights = _advancedInsights['institutional_insights'];
    if (instInsights == null) {
      return const SizedBox.shrink();
    }

    final double attendanceRate = (instInsights['staff_attendance_rate'] as num?)?.toDouble() ?? 100.0;
    final budget = instInsights['budget'] ?? {};
    final double revenue = (budget['potential_revenue'] as num?)?.toDouble() ?? 0.0;
    final double expense = (budget['potential_expense'] as num?)?.toDouble() ?? 0.0;
    final double profitMargin = (budget['profit_margin'] as num?)?.toDouble() ?? 0.0;
    final double profitPercent = (budget['profit_percent'] as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. PROFIT MARGIN & FINANCIAL OUTLOOK
        _sectionHeader(Icons.account_balance_wallet, "INSTITUTION FINANCE EXHIBITION", "Comparison of student potential fees vs operational salaries"),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Potential Profit Margin", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A237E))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (profitMargin >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828)).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      profitMargin >= 0 ? "+${profitPercent.toStringAsFixed(1)}%" : "${profitPercent.toStringAsFixed(1)}%",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: profitMargin >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                profitMargin >= 0 ? "\$${profitMargin.toStringAsFixed(0)}" : "-\$${profitMargin.abs().toStringAsFixed(0)}",
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: (revenue > 0 ? (profitMargin / revenue) : 0.0).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                color: profitMargin >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Monthly Fee Potential", style: TextStyle(fontSize: 10, color: Color(0xFF607D8B))),
                        const SizedBox(height: 4),
                        Text("\$${revenue.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A237E))),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: Colors.grey.withOpacity(0.3)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Monthly Operational Cost", style: TextStyle(fontSize: 10, color: Color(0xFF607D8B))),
                        const SizedBox(height: 4),
                        Text("\$${expense.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. STAFF ATTENDANCE RATE CARD
        _sectionHeader(Icons.badge, "STAFF ENGAGEMENT & ATTENDANCE", "Today's attendance metrics for academic and support personnel"),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 55,
                height: 55,
                child: CircularProgressIndicator(
                  value: attendanceRate / 100,
                  backgroundColor: Colors.grey[200],
                  color: attendanceRate >= 90 ? const Color(0xFF2E7D32) : (attendanceRate >= 75 ? const Color(0xFFE65100) : const Color(0xFFC62828)),
                  strokeWidth: 6,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Overall Staff Attendance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A237E))),
                    const SizedBox(height: 4),
                    Text(
                      "${attendanceRate.toStringAsFixed(0)}% Present Today",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: attendanceRate >= 90 ? const Color(0xFF2E7D32) : (attendanceRate >= 75 ? const Color(0xFFE65100) : const Color(0xFFC62828)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text("Attendance rate across teachers and operational staff members", style: TextStyle(fontSize: 10, color: Color(0xFF607D8B))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _StudentDetailCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final String? Function(dynamic) formatDate;
  final void Function(String format) onExport;

  const _StudentDetailCard({
    required this.student,
    required this.formatDate,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final name = student['name']?.toString() ?? 'Student Profile';
    final father = student['father_name']?.toString() ?? 'N/A';
    final section = student['section_name']?.toString() ?? student['section']?.toString() ?? 'Unassigned';
    final id = student['id']?.toString() ?? 'N/A';
    final fee = student['fee']?.toString() ?? '0';
    final date = formatDate(student['created_at']) ?? 'N/A';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF0F3460)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with gradient accent
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Avatar ring
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF64FFDA), width: 3),
                    color: const Color(0xFF16213E),
                  ),
                  child: Center(
                    child: Text(initials,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF64FFDA))),
                  ),
                ),
                const SizedBox(height: 12),
                Text(name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 12),
                      SizedBox(width: 6),
                      Text("Active Student",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Detail rows
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _darkRow("Father's Name", father, Icons.person_outline),
                _darkRow("Section", section, Icons.class_),
                _darkRow("ID Number", id, Icons.badge_outlined),
                _darkRow("Monthly Fee", "\$$fee", Icons.monetization_on_outlined),
                _darkRow("Admission Date", date, Icons.calendar_today),
              ],
            ),
          ),
          // Divider
          Container(height: 1, color: Colors.white.withOpacity(0.08)),
          // Export actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: _exportBtn("TXT", Icons.description_outlined, const Color(0xFF64FFDA), false, () => onExport('txt')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _exportBtn("HTML", Icons.share_rounded, const Color(0xFF00BCD4), true, () => onExport('html')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _exportBtn("PDF", Icons.picture_as_pdf_rounded, const Color(0xFFFF7043), true, () => onExport('pdf')),
                ),
              ],
            ),
          ),
          // Close button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CLOSE",
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF90A4AE), letterSpacing: 1.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exportBtn(String label, IconData icon, Color accent, bool filled, VoidCallback onTap) {
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: const Color(0xFF1A1A2E),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: accent.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }

  Widget _darkRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64FFDA).withOpacity(0.6)),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF90A4AE))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

int _blendColor(int fg, int bg, double alpha) {
  final fgR = (fg >> 16) & 0xFF;
  final fgG = (fg >> 8) & 0xFF;
  final fgB = fg & 0xFF;
  final bgR = (bg >> 16) & 0xFF;
  final bgG = (bg >> 8) & 0xFF;
  final bgB = bg & 0xFF;
  final r = (fgR * alpha + bgR * (1 - alpha)).round();
  final g = (fgG * alpha + bgG * (1 - alpha)).round();
  final b = (fgB * alpha + bgB * (1 - alpha)).round();
  return (0xFF << 24) | (r << 16) | (g << 8) | b;
}

class _MapEntry<T> {
  final dynamic key;
  final T value;
  _MapEntry(this.key, this.value);
}