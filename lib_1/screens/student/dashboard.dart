import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/constants.dart';
import '../../services/timing_service.dart';
import '../../qr_portal/qr_portal_screen.dart';
import '../../video_directory/screens/video_directory.dart';
import '../../timetable_directory/screens/timetable_directory.dart';
import '../../side/screens/side_ide_screen.dart';
import '../hub/wallet_screen.dart';
import '../../widgets/profile_avatar.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  String _studentName = "Student";
  String _studentId = '';
  bool _isLoading = true;

  String _openingTime = "09:00";
  String _closingTime = "17:00";
  List<String> _workingDays = [];
  List<Map<String, dynamic>> _breakTimes = [];

  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _attendanceLoading = false;
  int _presentCount = 0;
  int _absentCount = 0;
  int _totalAttendance = 0;

  double _latestPercentage = 0;
  double _latestObtained = 0;
  double _latestMax = 0;
  String _latestGrade = '-';
  String _latestSessionName = '';
  bool _resultLoading = false;

  static const _dayOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final name = await StarlightStorage.getUserName();
    final id = await StarlightStorage.getUserIdString();
    if (mounted) {
      setState(() {
        _studentName = name ?? "Student";
        _studentId = id ?? '';
      });
    }

    await Future.wait([
      _loadInstitutionTiming(),
      _loadAttendance(),
      _loadLatestResult(),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  List<String> _sortedWorkingDays(List<String> days) {
    days.sort((a, b) {
      final ai = _dayOrder.indexOf(a);
      final bi = _dayOrder.indexOf(b);
      if (ai == -1 && bi == -1) return 0;
      if (ai == -1) return 1;
      if (bi == -1) return -1;
      return ai.compareTo(bi);
    });
    return days;
  }

  Future<void> _loadInstitutionTiming() async {
    try {
      final data = await TimingService.getInstitutionalTiming();
      if (mounted) {
        setState(() {
          _openingTime = data['opening_time'] ?? "09:00";
          _closingTime = data['closing_time'] ?? "17:00";
          _workingDays = _sortedWorkingDays(List<String>.from(data['working_days'] ?? []));
          _breakTimes = List<Map<String, dynamic>>.from(data['break_times'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Error loading institution timing: $e");
    }
  }

  Future<void> _loadAttendance() async {
    setState(() => _attendanceLoading = true);
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/attendance/my-history'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['records'] != null) {
          final records = List<Map<String, dynamic>>.from(data['records']);
          if (mounted) {
            setState(() {
              _attendanceRecords = records;
              _presentCount = records.where((r) => r['status'] == 'present' || r['status'] == 'P').length;
              _absentCount = records.where((r) => r['status'] == 'absent' || r['status'] == 'A').length;
              _totalAttendance = records.length;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading attendance: $e");
    }
    if (mounted) setState(() => _attendanceLoading = false);
  }

  Future<void> _loadLatestResult() async {
    setState(() => _resultLoading = true);
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/marksheet/results'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          final sessionId = data[0]['session_id'];
          final sessionSubjects = data.where((r) => r['session_id'] == sessionId).toList();
          double totalObtained = 0, totalMax = 0;
          for (final s in sessionSubjects) {
            totalObtained += (s['marks_obtained'] ?? 0).toDouble();
            totalMax += (s['max_marks'] ?? 0).toDouble();
          }
          final pct = totalMax > 0 ? (totalObtained / totalMax * 100) : 0.0;
          String grade;
          if (pct >= 90) grade = 'A+';
          else if (pct >= 80) grade = 'A';
          else if (pct >= 70) grade = 'B';
          else if (pct >= 60) grade = 'C';
          else if (pct >= 50) grade = 'D';
          else grade = 'F';
          if (mounted) {
            setState(() {
              _latestObtained = totalObtained;
              _latestMax = totalMax;
              _latestPercentage = pct;
              _latestGrade = grade;
              _latestSessionName = sessionSubjects.first['session_name'] ?? '';
            });
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _resultLoading = false);
  }

  String _getTodayName() {
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[DateTime.now().weekday % 7];
  }

  bool _isTodayWorking() => _workingDays.contains(_getTodayName());

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(),
            const SizedBox(height: 16),
            _buildInstitutionTimingCard(),
            const SizedBox(height: 16),
            _buildAttendanceCard(),
            const SizedBox(height: 16),
            _buildResultCard(),
            const SizedBox(height: 16),
            _buildQuickAccessGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ProfileAvatar(
            userId: _studentId,
            name: _studentName,
            radius: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Welcome, $_studentName", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  _isTodayWorking() ? "Today is a working day" : "Today is off",
                  style: TextStyle(fontSize: 13, color: _isTodayWorking() ? Colors.green.shade200 : Colors.orange.shade200),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionTimingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              const Text("Institution Timing", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _timingBadge(Icons.login, "Open", _openingTime, Colors.green),
              const SizedBox(width: 12),
              _timingBadge(Icons.logout, "Close", _closingTime, Colors.red),
              const SizedBox(width: 12),
              _timingBadge(Icons.calendar_today, "Today", _isTodayWorking() ? "Working" : "Off", _isTodayWorking() ? Colors.green : Colors.orange),
            ],
          ),
          if (_workingDays.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text("Working Days", style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _workingDays.map((day) {
                final isToday = day == _getTodayName();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isToday ? Colors.green.shade700 : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(day.substring(0, 3), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isToday ? Colors.white : Colors.grey[700])),
                );
              }).toList(),
            ),
          ],
          if (_breakTimes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text("Break Times", style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ..._breakTimes.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.free_breakfast, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text("${b['name'] ?? 'Break'}: ${b['start']} - ${b['end']}", style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _timingBadge(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard() {
    final attendanceRate = _totalAttendance > 0
        ? (_presentCount / _totalAttendance * 100).toStringAsFixed(0)
        : '--';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              const Text("My Attendance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              if (_attendanceLoading)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _attStat(Icons.check_circle, "Present", _presentCount.toString(), Colors.green),
              const SizedBox(width: 8),
              _attStat(Icons.cancel, "Absent", _absentCount.toString(), Colors.redAccent),
              const SizedBox(width: 8),
              _attStat(Icons.analytics, "Rate", "$attendanceRate%", Colors.green.shade700),
            ],
          ),
          if (_attendanceRecords.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            SizedBox(
              height: 28,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _attendanceRecords.length > 10 ? 10 : _attendanceRecords.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final r = _attendanceRecords[i];
                  final isPresent = r['status'] == 'present' || r['status'] == 'P';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPresent ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${r['date'] ?? ''}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isPresent ? Colors.green : Colors.redAccent,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _attStat(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    if (_resultLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
        child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (_latestMax == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72, height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _latestPercentage / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(_latestGrade == 'F' ? Colors.red : (_latestGrade == 'A+' || _latestGrade == 'A' ? Colors.green : Colors.orange)),
                ),
                Text("${_latestPercentage.toStringAsFixed(0)}%", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _latestGrade == 'F' ? Colors.red : (_latestGrade == 'A+' || _latestGrade == 'A' ? Colors.green : Colors.orange))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text("Latest Result", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green.shade700)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_latestSessionName, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text("${_latestObtained.toStringAsFixed(0)} / ${_latestMax.toStringAsFixed(0)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _latestGrade == 'F' ? Colors.red.withOpacity(0.1) : (_latestGrade == 'A+' || _latestGrade == 'A' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text("Grade: $_latestGrade", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _latestGrade == 'F' ? Colors.red : (_latestGrade == 'A+' || _latestGrade == 'A' ? Colors.green : Colors.orange))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Quick Access", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
          children: [
            _buildAccessTile(icon: Icons.alarm, title: "Alarms", subtitle: "Universal + Local", color: Colors.red, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TimetableDirectory()))),
            _buildAccessTile(icon: Icons.videocam, title: "Videos", subtitle: "Video Library", color: Colors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VideoDirectory()))),
            _buildAccessTile(icon: Icons.qr_code, title: "QR Portal", subtitle: "Scan & Display", color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QRPortalScreen()))),
            _buildAccessTile(icon: Icons.account_balance_wallet, title: "Wallet", subtitle: "Balance & payments", color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen()))),
            _buildAccessTile(icon: Icons.chat, title: "Chat", subtitle: "Messages", color: Colors.blue, onTap: () {}),
            _buildAccessTile(icon: Icons.code, title: "SIDE IDE", subtitle: "Code & debug", color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SideIdeScreen()))),
          ],
        ),
      ],
    );
  }

  Widget _buildAccessTile({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 22)),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
            const SizedBox(height: 1),
            Text(subtitle, style: TextStyle(fontSize: 8, color: Colors.grey[500]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
