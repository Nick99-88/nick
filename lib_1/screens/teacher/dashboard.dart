import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/constants.dart';
import '../../services/timing_service.dart';
import '../owner/document_vault_screen.dart';
import '../../qr_portal/qr_portal_screen.dart';
import '../../video_directory/screens/video_directory.dart';
import '../../timetable_directory/screens/timetable_directory.dart';
import '../../side/screens/side_ide_screen.dart';
import '../../side/screens/challenges_screen.dart';
import '../../excel/main_screen.dart';
import '../../widgets/profile_avatar.dart';

class TeacherConsole extends StatefulWidget {
  const TeacherConsole({super.key});

  @override
  State<TeacherConsole> createState() => _TeacherConsoleState();
}

class _TeacherConsoleState extends State<TeacherConsole> {
  String _teacherName = "Teacher";
  String _teacherId = '';
  bool _isLoading = true;

  // Institution timing
  String _openingTime = "09:00";
  String _closingTime = "17:00";
  List<String> _workingDays = [];
  List<Map<String, dynamic>> _breakTimes = [];
  bool _hasPersonalSchedule = false;

  // Teacher schedule
  Map<String, dynamic> _mySchedule = {};
  bool _isWholeDayAdmin = false;

  // Attendance
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _attendanceLoading = false;
  int _presentCount = 0;
  int _absentCount = 0;
  int _totalAttendance = 0;

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
        _teacherName = name ?? "Teacher";
        _teacherId = id ?? '';
      });
    }

    await Future.wait([
      _loadInstitutionTiming(),
      _loadMySchedule(),
      _loadAttendance(),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadInstitutionTiming() async {
    try {
      final data = await TimingService.getInstitutionalTiming();
      if (mounted) {
        setState(() {
          _openingTime = data['opening_time'] ?? "09:00";
          _closingTime = data['closing_time'] ?? "17:00";
          _workingDays = List<String>.from(data['working_days'] ?? []);
          _breakTimes = List<Map<String, dynamic>>.from(data['break_times'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Error loading institution timing: $e");
    }
  }

  Future<void> _loadMySchedule() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/institution/directory/my-permissions'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          final schedule = data['schedule'] as Map<String, dynamic>? ?? {};
          final isWholeDay = data['is_whole_day_admin'] == true;

          setState(() {
            _mySchedule = schedule;
            _isWholeDayAdmin = isWholeDay;
            _hasPersonalSchedule = schedule.isNotEmpty;
            if (schedule.isNotEmpty) {
              _openingTime = schedule['opening_time'] ?? _openingTime;
              _closingTime = schedule['closing_time'] ?? _closingTime;
              _workingDays = List<String>.from(schedule['working_days'] ?? _workingDays);
              _breakTimes = List<Map<String, dynamic>>.from(schedule['break_times'] ?? _breakTimes);
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading schedule: $e");
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

  String _getTodayName() {
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[DateTime.now().weekday % 7];
  }

  bool _isTodayWorking() {
    return _workingDays.contains(_getTodayName());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

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
            _buildTodayScheduleCard(),
            const SizedBox(height: 16),
            _buildAttendanceCard(),
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
          colors: [StarlightTheme.primaryBlue, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ProfileAvatar(
            userId: _teacherId,
            name: _teacherName,
            radius: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome, $_teacherName",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isTodayWorking() ? "Today is a working day" : "Today is off",
                  style: TextStyle(
                    fontSize: 13,
                    color: _isTodayWorking() ? Colors.green.shade200 : Colors.orange.shade200,
                  ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: StarlightTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              const Text(
                "My Timing",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              if (!_hasPersonalSchedule)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Not set yet",
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _timingBadge(Icons.login, "Open", _openingTime, Colors.green),
              const SizedBox(width: 12),
              _timingBadge(Icons.logout, "Close", _closingTime, Colors.red),
              const SizedBox(width: 12),
              _timingBadge(
                Icons.calendar_today,
                "Today",
                _isTodayWorking() ? "Working" : "Off",
                _isTodayWorking() ? Colors.green : Colors.orange,
              ),
            ],
          ),
          if (_workingDays.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              "Working Days",
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _workingDays.map((day) {
                final short = day.substring(0, 3);
                final isToday = day == _getTodayName();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isToday ? StarlightTheme.primaryBlue : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    short,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isToday ? Colors.white : Colors.grey[700],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (_breakTimes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              "Break Times",
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ..._breakTimes.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.free_breakfast, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    "${b['name'] ?? 'Break'}: ${b['start']} - ${b['end']}",
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
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
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
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

  Widget _buildTodayScheduleCard() {
    final today = _getTodayName();
    final todaySchedule = _mySchedule[today];
    final hasSchedule = todaySchedule != null && todaySchedule is List && (todaySchedule as List).isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: StarlightTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                "Today's Lectures ($today)",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              if (_isWholeDayAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "ALL DAY",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasSchedule && !_isWholeDayAdmin)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_busy, size: 40, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      "No lectures scheduled for today",
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else if (_isWholeDayAdmin)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.all_inclusive, color: Colors.green, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Whole Day Available",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "You are available for the entire day",
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate((todaySchedule as List).length, (index) {
              final lecture = todaySchedule[index];
              return _buildLectureItem(lecture, index);
            }),
        ],
      ),
    );
  }

  Widget _buildLectureItem(Map<String, dynamic> lecture, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: index < (lecture['start'] != null ? 1 : 0) ? 8 : 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: StarlightTheme.primaryBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lecture['class'] ?? lecture['subject'] ?? 'Lecture',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  "${lecture['start'] ?? ''} - ${lecture['end'] ?? ''}",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (lecture['room'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                lecture['room'],
                style: TextStyle(fontSize: 10, color: Colors.blue[700], fontWeight: FontWeight.w600),
              ),
            ),
        ],
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note, color: StarlightTheme.primaryBlue, size: 20),
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
              _attStat(Icons.analytics, "Rate", "$attendanceRate%", StarlightTheme.primaryBlue),
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

  Widget _buildQuickAccessGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Access",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.75,
          children: [
            _buildAccessTile(
              icon: Icons.alarm,
              title: "Alarms",
              subtitle: "Universal + Local",
              color: Colors.red,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TimetableDirectory()),
              ),
            ),
            _buildAccessTile(
              icon: Icons.videocam,
              title: "Videos",
              subtitle: "Video Library",
              color: Colors.purple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VideoDirectory()),
              ),
            ),
            _buildAccessTile(
              icon: Icons.qr_code,
              title: "QR Portal",
              subtitle: "Scan & Display",
              color: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QRPortalScreen()),
              ),
            ),
            _buildAccessTile(
              icon: Icons.folder_open,
              title: "Documents",
              subtitle: "Files & Docs",
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DocumentVaultScreen()),
              ),
            ),
            _buildAccessTile(
              icon: Icons.local_library,
              title: "Library",
              subtitle: "Books & resources",
              color: Colors.orange,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Library coming soon!")),
                );
              },
            ),
            _buildAccessTile(
              icon: Icons.code,
              title: "SIDE IDE",
              subtitle: "Code & debug",
              color: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SideIdeScreen()),
              ),
            ),
            _buildAccessTile(
              icon: Icons.table_chart_outlined,
              title: "Excel",
              subtitle: "Export reports",
              color: Colors.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SpreadsheetEditorScreen()),
              ),
            ),
            _buildAccessTile(
              icon: Icons.emoji_events,
              title: "Challenges",
              subtitle: "Earn Dev-Points",
              color: Colors.amber,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SideChallengesScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccessTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: TextStyle(fontSize: 8, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
