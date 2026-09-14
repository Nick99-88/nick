import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/constants.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _children = [];
  String? _selectedChildId;
  bool _isLoadingChildren = true;
  bool _isLoadingData = false;

  // Institutional data
  Map<String, dynamic>? _overview;
  List<dynamic> _marks = [];
  Map<String, dynamic>? _attendance;
  Map<String, dynamic>? _fees;
  List<dynamic> _tests = [];

  // Phone activity data
  Map<String, dynamic>? _phoneActivity;
  bool _isLoadingPhone = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchChildren();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchChildren() async {
    setState(() => _isLoadingChildren = true);
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) throw Exception("Session expired");

      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/parent/my-children'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final children = List<Map<String, dynamic>>.from(data['children'] ?? []);
        if (mounted) {
          setState(() {
            _children = children;
            _isLoadingChildren = false;
          });
          if (children.isNotEmpty) {
            _selectChild(children[0]['id']);
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingChildren = false);
    }
  }

  Future<void> _selectChild(String childId) async {
    setState(() {
      _selectedChildId = childId;
      _isLoadingData = true;
    });

    await Future.wait([
      _fetchOverview(childId),
      _fetchMarks(childId),
      _fetchAttendance(childId),
      _fetchFees(childId),
      _fetchTests(childId),
      _fetchPhoneActivity(childId),
    ]);

    if (mounted) setState(() => _isLoadingData = false);
  }

  Future<String?> _getToken() async => StarlightStorage.getUserToken();

  Future<void> _fetchOverview(String childId) async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final r = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/parent/child/$childId/overview'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (mounted) setState(() => _overview = data['overview']);
      }
    } catch (_) {}
  }

  Future<void> _fetchMarks(String childId) async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final r = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/parent/child/$childId/marks'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (mounted) setState(() => _marks = data['marks'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _fetchAttendance(String childId) async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final r = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/parent/child/$childId/attendance'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (mounted) setState(() => _attendance = data);
      }
    } catch (_) {}
  }

  Future<void> _fetchFees(String childId) async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final r = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/parent/child/$childId/fees'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (mounted) setState(() => _fees = data);
      }
    } catch (_) {}
  }

  Future<void> _fetchTests(String childId) async {
    final token = await _getToken();
    if (token == null) return;
    try {
      final r = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/parent/child/$childId/tests'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (mounted) setState(() => _tests = data['tests'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _fetchPhoneActivity(String childId) async {
    final token = await _getToken();
    if (token == null) return;
    setState(() => _isLoadingPhone = true);
    try {
      final r = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/parent/child/$childId/phone-activity'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (mounted) setState(() {
          _phoneActivity = data['activity'] != null
              ? jsonDecode(data['activity'])
              : null;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingPhone = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Parent Dashboard',
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: StarlightTheme.primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: StarlightTheme.primaryBlue,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.school), text: 'Institutional'),
            Tab(icon: Icon(Icons.phone_android), text: 'Phone Activity'),
          ],
        ),
      ),
      body: _isLoadingChildren
          ? const Center(child: CircularProgressIndicator())
          : _children.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildChildSelector(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildInstitutionalTab(),
                          _buildPhoneActivityTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.family_restroom, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No children linked', style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Ask your child to connect from their profile', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildChildSelector() {
    return Container(
      height: 60,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _children.length,
        itemBuilder: (context, index) {
          final child = _children[index];
          final isSelected = child['id'] == _selectedChildId;
          return GestureDetector(
            onTap: () => _selectChild(child['id']),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? StarlightTheme.primaryBlue : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isSelected ? Colors.white24 : StarlightTheme.primaryBlue.withOpacity(0.1),
                    child: Icon(Icons.person, size: 16, color: isSelected ? Colors.white : StarlightTheme.primaryBlue),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    child['name'] ?? 'Child',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // INSTITUTIONAL TAB
  // ============================================================

  Widget _buildInstitutionalTab() {
    if (_isLoadingData) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: () => _selectChild(_selectedChildId!),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildOverviewCard(),
            const SizedBox(height: 16),
            _buildAttendanceCard(),
            const SizedBox(height: 16),
            _buildMarksCard(),
            const SizedBox(height: 16),
            _buildFeesCard(),
            const SizedBox(height: 16),
            _buildTestsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    if (_overview == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade600, Colors.blue.shade800]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_overview!['student_name'] ?? '', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text('${_overview!['institution_name'] ?? ''} • ${_overview!['section'] ?? ''}',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 16),
          Row(
            children: [
              _overviewStat('Attendance', '${_overview!['attendance_percentage']}%', Colors.white),
              _overviewStat('Exams', '${_overview!['exams_count']}', Colors.white),
              _overviewStat('Fee Paid', '${_overview!['paid_vouchers']}', Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ]),
      ),
    );
  }

  Widget _buildAttendanceCard() {
    if (_attendance == null) return const SizedBox.shrink();
    final present = _attendance!['present'] ?? 0;
    final absent = _attendance!['absent'] ?? 0;
    final late = _attendance!['late'] ?? 0;
    final pct = _attendance!['percentage'] ?? 0.0;
    return _sectionCard('Attendance', Icons.calendar_today, [
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _attStat('Present', '$present', Colors.green),
        _attStat('Absent', '$absent', Colors.red),
        _attStat('Late', '$late', Colors.orange),
      ]),
      const SizedBox(height: 12),
      LinearProgressIndicator(value: pct / 100, backgroundColor: Colors.grey[200], valueColor: AlwaysStoppedAnimation(pct > 80 ? Colors.green : Colors.red)),
      const SizedBox(height: 6),
      Text('$pct% Attendance Rate', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
    ]);
  }

  Widget _attStat(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ]);
  }

  Widget _buildMarksCard() {
    if (_marks.isEmpty) return const SizedBox.shrink();
    return _sectionCard('Marks & Results', Icons.grade, _marks.take(5).map((m) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(flex: 3, child: Text('${m['subject'] ?? m['exam'] ?? ''}', style: GoogleFonts.poppins(fontSize: 13))),
        Expanded(flex: 2, child: Text('${m['obtained']}/${m['max']}', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600))),
        Expanded(flex: 1, child: Text('${m['percentage'] ?? 0}%', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 13, color: (m['percentage'] ?? 0) >= 50 ? Colors.green : Colors.red))),
      ]),
    )).toList());
  }

  Widget _buildFeesCard() {
    if (_fees == null) return const SizedBox.shrink();
    return _sectionCard('Fee Status', Icons.payment, [
      Row(children: [
        Expanded(child: _feeStat('Total Fee', '${_fees!['total_fee'] ?? 0}', Colors.blue)),
        Expanded(child: _feeStat('Paid', '${_fees!['paid'] ?? 0}', Colors.green)),
        Expanded(child: _feeStat('Remaining', '${_fees!['remaining'] ?? 0}', Colors.red)),
      ]),
    ]);
  }

  Widget _feeStat(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ]);
  }

  Widget _buildTestsCard() {
    if (_tests.isEmpty) return const SizedBox.shrink();
    return _sectionCard('Conducted Tests', Icons.quiz, _tests.take(5).map((t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(Icons.article_outlined, size: 18, color: Colors.blue[300]),
        const SizedBox(width: 8),
        Expanded(child: Text('${t['exam'] ?? ''}', style: GoogleFonts.poppins(fontSize: 13))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: t['status'] == 'completed' ? Colors.green[50] : Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('${t['status'] ?? ''}', style: GoogleFonts.poppins(fontSize: 10, color: t['status'] == 'completed' ? Colors.green[700] : Colors.orange[700])),
        ),
      ]),
    )).toList());
  }

  Widget _sectionCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: StarlightTheme.primaryBlue),
            const SizedBox(width: 8),
            Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
  }

  // ============================================================
  // PHONE ACTIVITY TAB
  // ============================================================

  Widget _buildPhoneActivityTab() {
    if (_isLoadingPhone) return const Center(child: CircularProgressIndicator());

    if (_phoneActivity == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_android, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No phone activity data', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Activity will appear when child\'s device syncs', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchPhoneActivity(_selectedChildId!),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildScreenTimeCard(),
            const SizedBox(height: 16),
            _buildAppUsageCard(),
            const SizedBox(height: 16),
            _buildAppInventoryCard(),
            const SizedBox(height: 16),
            _buildBluetoothCard(),
            const SizedBox(height: 16),
            _buildNetworkCard(),
            const SizedBox(height: 16),
            _buildLocationCard(),
            const SizedBox(height: 16),
            _buildSessionLogCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenTimeCard() {
    final screenTime = _phoneActivity!['screen_time'] ?? {};
    final totalMinutes = screenTime['total_minutes'] ?? 0;
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;

    return _sectionCard('Screen Time', Icons.timer, [
      Row(children: [
        Icon(Icons.watch, size: 40, color: StarlightTheme.primaryBlue),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${hours}h ${mins}m', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
          Text('Total active screen time today', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
        ]),
      ]),
    ]);
  }

  Widget _buildAppUsageCard() {
    final apps = List<Map<String, dynamic>>.from(_phoneActivity!['app_usage'] ?? []);
    if (apps.isEmpty) return const SizedBox.shrink();

    return _sectionCard('App Usage (Top 5)', Icons.apps, apps.take(5).map((app) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(app['name'] ?? '', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500))),
          Text('${app['minutes'] ?? 0}m', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
        ]),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: (app['minutes'] ?? 0) / (apps.first['minutes'] ?? 1),
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation(Colors.blue[300]!),
        ),
      ]),
    )).toList());
  }

  Widget _buildAppInventoryCard() {
    final installed = List<String>.from(_phoneActivity!['installed_apps'] ?? []);
    final uninstalled = List<String>.from(_phoneActivity!['uninstalled_apps'] ?? []);
    if (installed.isEmpty && uninstalled.isEmpty) return const SizedBox.shrink();

    return _sectionCard('App Inventory', Icons.inventory_2, [
      if (installed.isNotEmpty) ...[
        Text('Newly Installed', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green[700])),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: installed.map((a) => Chip(
          label: Text(a, style: GoogleFonts.poppins(fontSize: 11)),
          backgroundColor: Colors.green[50],
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        )).toList()),
      ],
      if (uninstalled.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text('Uninstalled', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red[700])),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: uninstalled.map((a) => Chip(
          label: Text(a, style: GoogleFonts.poppins(fontSize: 11)),
          backgroundColor: Colors.red[50],
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        )).toList()),
      ],
    ]);
  }

  Widget _buildBluetoothCard() {
    final devices = List<Map<String, dynamic>>.from(_phoneActivity!['bluetooth_devices'] ?? []);
    return _sectionCard('Connected Devices', Icons.bluetooth, [
      if (devices.isEmpty)
        Text('No Bluetooth devices connected', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]))
      else
        ...devices.map((d) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(d['type'] == 'audio' ? Icons.headphones : Icons.bluetooth, size: 20),
          title: Text(d['name'] ?? '', style: GoogleFonts.poppins(fontSize: 13)),
          subtitle: Text(d['type'] ?? '', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
        )),
    ]);
  }

  Widget _buildNetworkCard() {
    final network = _phoneActivity!['network'] ?? {};
    return _sectionCard('Network', Icons.wifi, [
      _netRow('Type', network['type'] ?? 'Unknown'),
      _netRow('SSID', network['ssid'] ?? 'N/A'),
      _netRow('IP', network['ip'] ?? 'N/A'),
    ]);
  }

  Widget _netRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]))),
        Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildLocationCard() {
    final loc = _phoneActivity!['location'] ?? {};
    return _sectionCard('Location', Icons.location_on, [
      _netRow('Latitude', '${loc['lat'] ?? 'N/A'}'),
      _netRow('Longitude', '${loc['lng'] ?? 'N/A'}'),
      _netRow('Address', loc['address'] ?? 'N/A'),
    ]);
  }

  Widget _buildSessionLogCard() {
    final sessions = List<Map<String, dynamic>>.from(_phoneActivity!['sessions'] ?? []);
    if (sessions.isEmpty) return const SizedBox.shrink();

    return _sectionCard('Session Log (Today)', Icons.history, sessions.take(8).map((s) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(Icons.circle, size: 8, color: s['event'] == 'unlock' ? Colors.green : Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text('${s['time'] ?? ''}', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]))),
        Text(s['event'] ?? '', style: GoogleFonts.poppins(fontSize: 11)),
      ]),
    )).toList());
  }
}
