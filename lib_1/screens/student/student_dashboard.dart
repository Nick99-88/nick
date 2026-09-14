import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/app_routes.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboard> {
    bool _isOnline = false;
  int _unsyncedCount = 0;
  String _studentName = '';
  String _studentGrade = '';
  String _studentSection = '';

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    // Load student profile data
    setState(() {
      _studentName = 'Alice Johnson'; // Mock data
      _studentGrade = 'Grade 10';
      _studentSection = 'Section A';
    });
  }

  Future<void> _updateStatus() async {
    setState(() {
      _isOnline = true; // Default to online for now
      _unsyncedCount = 0; // Default to 0 for now
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _studentName,
              style: const TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '$_studentGrade • $_studentSection',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Academic Overview
            _buildAcademicOverview(),
            const SizedBox(height: 24),

            // Quick Actions
            _buildQuickActions(),
            const SizedBox(height: 24),

            // Recent Assignments
            _buildAssignmentsSection(),
            const SizedBox(height: 24),

            // Attendance Status
            _buildAttendanceSection(),
            const SizedBox(height: 24),

            // Notices & Events
            _buildNoticesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAcademicOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Academic Performance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Current GPA', '3.8', Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Attendance', '92%', Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Rank', '5/30', Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
          children: [
            _buildActionCard(
              'Assignments',
              'View and submit',
              Icons.assignment,
              Colors.blue,
              () => Navigator.pushNamed(context, AppRoutes.assignments),
            ),
            _buildActionCard(
              'Grades',
              'View results',
              Icons.grade,
              Colors.green,
              () => Navigator.pushNamed(context, AppRoutes.grades),
            ),
            _buildActionCard(
              'Timetable',
              'View schedule',
              Icons.schedule,
              Colors.purple,
              () => Navigator.pushNamed(context, AppRoutes.timetable),
            ),
            _buildActionCard(
              'Library',
              'Browse books',
              Icons.menu_book,
              Colors.orange,
              () => Navigator.pushNamed(context, AppRoutes.library),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Assignments',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildAssignmentItem('Mathematics Quiz', 'Due in 2 days', Colors.red),
              _buildAssignmentItem('Science Project', 'Due in 5 days', Colors.orange),
              _buildAssignmentItem('English Essay', 'Due in 1 week', Colors.green),
              _buildAssignmentItem('History Assignment', 'Submitted', Colors.grey),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssignmentItem(String title, String dueDate, Color color) {
    return ListTile(
      leading: Icon(Icons.assignment, color: color),
      title: Text(title),
      subtitle: Text(dueDate),
      trailing: dueDate == 'Submitted' 
          ? const Icon(Icons.check_circle, color: Colors.green)
          : Icon(Icons.arrow_forward_ios, color: color, size: 16),
    );
  }

  Widget _buildAttendanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attendance Overview',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAttendanceStat('Present', 18, Colors.green),
                  _buildAttendanceStat('Absent', 2, Colors.red),
                  _buildAttendanceStat('Late', 3, Colors.orange),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: 0.92,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              const SizedBox(height: 8),
              Text(
                '92% Attendance Rate',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildNoticesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notices & Events',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildNoticeItem('Annual Sports Day', 'Tomorrow', Icons.event, Colors.blue),
              const Divider(),
              _buildNoticeItem('Parent-Teacher Meeting', 'Next Week', Icons.people, Colors.green),
              const Divider(),
              _buildNoticeItem('Science Exhibition', 'In 2 weeks', Icons.science, Colors.purple),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoticeItem(String title, String date, IconData icon, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(date),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }
}
