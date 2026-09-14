import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../services/timing_service.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class InstitutionalTimingScreen extends StatefulWidget {
  final VoidCallback onClose;
  const InstitutionalTimingScreen({super.key, required this.onClose});

  @override
  State<InstitutionalTimingScreen> createState() => _InstitutionalTimingScreenState();
}

class _InstitutionalTimingScreenState extends State<InstitutionalTimingScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  
  bool isDaySelected(String day) {
    return _workingDays.contains(day);
  }
  
  // General timing data
  TimeOfDay? _openingTime;
  TimeOfDay? _closingTime;
  List<String> _workingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  List<Map<String, dynamic>> _breakTimes = [];
  
  // Staff timing data
  List<Map<String, dynamic>> _staff = [];
  bool isLoading = false;
  
  // Schedule state
  Map<String, Map<String, dynamic>> _tempSchedules = {};
  Map<String, bool> _wholeDayAvailability = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInstitutionalTiming();
    _loadStaff();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInstitutionalTiming() async {
    setState(() => isLoading = true);
    try {
      final data = await TimingService.getInstitutionalTiming();
      setState(() {
        _openingTime = TimingService.parseTime(data['opening_time']);
        _closingTime = TimingService.parseTime(data['closing_time']);
        _workingDays = List<String>.from(data['working_days'] ?? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']);
        _breakTimes = List<Map<String, dynamic>>.from(data['break_times'] ?? []);
      });
    } catch (e) {
      debugPrint('🏛️ Timing: Error loading institutional timing - $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadStaff() async {
    try {
      debugPrint('🏛️ Timing: Loading staff and teachers...');
      final data = await TimingService.getStaffAndTeachers();
      debugPrint('🏛️ Timing: Loaded data keys: ${data.keys}');
      
      final List staffList = data['staff'] ?? [];
      final List teacherList = data['teachers'] ?? [];
      debugPrint('🏛️ Timing: Staff count: ${staffList.length}, Teachers count: ${teacherList.length}');
      
      final List combinedList = [...staffList, ...teacherList];
      
      setState(() {
        _staff = TimingService.convertStaffList(combinedList);
        
        // Initialize temp schedules and whole day availability from loaded data
        for (final person in _staff) {
          final id = person['id'].toString();
          _tempSchedules[id] = TimingService.convertSchedule(person['schedule']);
          _wholeDayAvailability[id] = person['is_whole_day_admin'] ?? false;
          debugPrint('🏛️ Timing: Loaded person: ${person['name']} (id: $id, type: ${person['type']})');
          debugPrint('🏛️ Timing:   schedule: ${_tempSchedules[id]}');
          debugPrint('🏛️ Timing:   wholeDay: ${_wholeDayAvailability[id]}');
        }
      });
    } catch (e) {
      debugPrint('🏛️ Timing: Error loading staff and teachers - $e');
    }
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: StarlightTheme.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onClose,
        ),
        title: const Text(
          'Institutional Timing',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'General Timing'),
            Tab(text: 'Staff & Teachers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralTimingSection(),
          _buildStaffSchedulesSection(),
        ],
      ),
    );
  }

  Widget _buildGeneralTimingSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('General Institutional Timing'),
          const SizedBox(height: 20),
          
          // Opening and Closing Times
          Row(
            children: [
              Expanded(
                child: _buildTimeCard(
                  'Opening Time',
                  'When institution opens',
                  _openingTime,
                  Icons.access_time,
                  (time) => setState(() => _openingTime = time),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTimeCard(
                  'Closing Time',
                  'When institution closes',
                  _closingTime,
                  Icons.access_time_filled,
                  (time) => setState(() => _closingTime = time),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Working Days
          _buildWorkingDaysCard(),
          
          const SizedBox(height: 24),
          
          // Break Times
          _buildBreakTimesCard(),
          
          const SizedBox(height: 24),
          
          // Save Button
          Container(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : _saveGeneralTiming,
              icon: isLoading 
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save, size: 20),
              label: Text(
                isLoading ? 'Saving...' : 'Save General Timing',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLoading ? Colors.grey : StarlightTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: isLoading ? 0 : 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffSchedulesSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Staff & Teacher Schedules',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                onPressed: isLoading ? null : _saveAllSchedules,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StarlightTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _staff.isEmpty 
              ? _buildEmptyState('No staff or teachers found')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _staff.length,
                  itemBuilder: (context, index) {
                    final staffMember = Map<String, dynamic>.from(_staff[index]);
                    return _buildStaffScheduleCard(staffMember, index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  Widget _buildTimeCard(String title, String subtitle, TimeOfDay? time, IconData icon, Function(TimeOfDay) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: StarlightTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: StarlightTheme.primaryBlue, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _selectTime(time, onChanged),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: StarlightTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: StarlightTheme.primaryBlue.withOpacity(0.3)),
                ),
                child: Text(
                  time != null ? TimingService.formatTime(time) : 'Select Time',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: StarlightTheme.primaryBlue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkingDaysCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: StarlightTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: StarlightTheme.primaryBlue, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Working Days',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: StarlightTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].map((day) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isDaySelected(day)) {
                        _workingDays.remove(day);
                      } else {
                        _workingDays.add(day);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDaySelected(day) ? StarlightTheme.primaryBlue : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDaySelected(day) ? StarlightTheme.primaryBlue.withOpacity(0.3) : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      day.substring(0, 3),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDaySelected(day) ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakTimesCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: StarlightTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, color: StarlightTheme.primaryBlue, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Break Times',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 18,
                            color: StarlightTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: StarlightTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: _addBreakTime,
                        tooltip: 'Add Break Time',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_breakTimes.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.schedule, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No break times configured',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the + button to add your first break time',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                ..._breakTimes.asMap().entries.map((entry) {
                  final index = entry.key;
                  final breakTime = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildBreakTimeItem(breakTime, index),
                  );
                }).toList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakTimeItem(Map<String, dynamic> breakTime, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  breakTime['name'] ?? 'Break Time',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _removeBreakTime(index),
                    tooltip: 'Delete Break Time',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start Time',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _editBreakTime(index, 'start'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: StarlightTheme.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: StarlightTheme.primaryBlue.withOpacity(0.3)),
                            ),
                            child: Text(
                              breakTime['start'] ?? '12:00',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: StarlightTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'End Time',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _editBreakTime(index, 'end'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: StarlightTheme.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: StarlightTheme.primaryBlue.withOpacity(0.3)),
                            ),
                            child: Text(
                              breakTime['end'] ?? '12:30',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: StarlightTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffScheduleCard(Map<String, dynamic> staffMember, int index) {
    final staffId = staffMember['id'].toString();
    final isWholeDay = _wholeDayAvailability[staffId] ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [StarlightTheme.primaryBlue, StarlightTheme.primaryBlue.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16), bottom: Radius.zero),
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'staff_${staffMember['id']}',
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Text(
                      (staffMember['name'] as String)[0].toUpperCase(),
                      style: TextStyle(
                        color: StarlightTheme.primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staffMember['name'] ?? 'Unknown Staff Member',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        staffMember['subject'] ?? 'No Subject Assigned',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Whole Day Admin Section
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.all_inclusive, color: StarlightTheme.primaryBlue),
                const SizedBox(width: 12),
                const Text(
                  'Whole Day Availability',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Checkbox(
                  value: isWholeDay,
                  onChanged: (value) {
                    setState(() {
                      _wholeDayAvailability[staffId] = value ?? false;
                    });
                  },
                  activeColor: StarlightTheme.primaryBlue,
                ),
              ],
            ),
          ),
          
          // Schedule Section
          if (!isWholeDay) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, color: StarlightTheme.primaryBlue, size: 20),
                      const SizedBox(width: 12),
                      const Text(
                        'Weekly Schedule',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: _buildDayBasedSchedule(staffMember),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayBasedSchedule(Map<String, dynamic> staffMember) {
    final staffId = staffMember['id'].toString();
    if (!_tempSchedules.containsKey(staffId)) {
      _tempSchedules[staffId] = {};
    }
    final Map<String, dynamic> schedule = _tempSchedules[staffId]!;
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    return Column(
      children: [
        // Copy schedule section
        if (schedule.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.copy, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Copy schedule from one day to others',
                    style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w500),
                  ),
                ),
                DropdownButton<String>(
                  hint: const Text('From day'),
                  items: days.map((day) => DropdownMenuItem(value: day, child: Text(day))).toList(),
                  onChanged: (sourceDay) {
                    if (sourceDay != null) {
                      _showCopyScheduleDialog(staffMember, sourceDay);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Day-based class management
        ...days.map((day) {
          final dayClasses = schedule[day];
          final hasClasses = dayClasses != null && dayClasses is List && (dayClasses as List).isNotEmpty;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                // Day header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: hasClasses ? StarlightTheme.primaryBlue.withOpacity(0.1) : Colors.grey[50],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasClasses ? Icons.event_available : Icons.event_busy,
                        color: hasClasses ? StarlightTheme.primaryBlue : Colors.grey[600],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: hasClasses ? StarlightTheme.primaryBlue : Colors.grey[700],
                          ),
                        ),
                      ),
                      if (hasClasses)
                        Text(
                          '${(dayClasses as List).length} classes',
                          style: TextStyle(
                            color: StarlightTheme.primaryBlue,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Classes for this day or add button
                if (hasClasses)
                  ...(dayClasses as List).asMap().entries.map((entry) {
                    final index = entry.key;
                    final classData = entry.value;
                    return _buildClassTile(staffMember, day, index, classData);
                  }).toList()
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      onPressed: () => _addClassForDay(staffMember, day),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('Add Classes for $day'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StarlightTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildClassTile(Map<String, dynamic> staffMember, String day, int index, Map<String, dynamic> classData) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                '${classData['start'] ?? '--:--'} - ${classData['end'] ?? '--:--'}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _editClassForDay(staffMember, day, index),
                icon: const Icon(Icons.edit, size: 16),
                color: StarlightTheme.primaryBlue,
              ),
              IconButton(
                onPressed: () => _deleteClassForDay(staffMember, day, index),
                icon: const Icon(Icons.delete, size: 16),
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.class_, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                classData['class'] ?? 'No Class',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 16),
              Icon(Icons.book, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                classData['subject'] ?? 'No Subject',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 16),
              Icon(Icons.room, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                classData['room'] ?? 'No Room',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addClassForDay(Map<String, dynamic> staffMember, String day) {
    _showClassDialog(staffMember, day, null);
  }

  void _editClassForDay(Map<String, dynamic> staffMember, String day, int index) {
    _showClassDialog(staffMember, day, index);
  }

  void _deleteClassForDay(Map<String, dynamic> staffMember, String day, int index) {
    final staffId = staffMember['id'].toString();
    setState(() {
      if (_tempSchedules[staffId]?[day] != null && _tempSchedules[staffId]![day] is List) {
        (_tempSchedules[staffId]![day] as List).removeAt(index);
      }
    });
  }

  void _showClassDialog(Map<String, dynamic> staffMember, String day, int? index) {
    final staffId = staffMember['id'].toString();
    if (!_tempSchedules.containsKey(staffId)) {
      _tempSchedules[staffId] = {};
    }
    
    final TextEditingController classController = TextEditingController();
    final TextEditingController subjectController = TextEditingController();
    final TextEditingController roomController = TextEditingController();
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    // If editing, populate existing data
    if (index != null && _tempSchedules[staffId]![day] != null && _tempSchedules[staffId]![day] is List) {
      final classData = (_tempSchedules[staffId]![day] as List)[index];
      classController.text = classData['class'] ?? '';
      subjectController.text = classData['subject'] ?? '';
      roomController.text = classData['room'] ?? '';
      startTime = TimingService.parseTime(classData['start']);
      endTime = TimingService.parseTime(classData['end']);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [StarlightTheme.primaryBlue, StarlightTheme.primaryBlue.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  index == null ? 'Add Class' : 'Edit Class',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  day,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Form Fields
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          // Class Field
                          TextField(
                            controller: classController,
                            decoration: InputDecoration(
                              labelText: 'Class Name',
                              hintText: 'e.g., Grade 10-A',
                              prefixIcon: Icon(Icons.class_, color: StarlightTheme.primaryBlue),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: StarlightTheme.primaryBlue, width: 2),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Subject Field
                          TextField(
                            controller: subjectController,
                            decoration: InputDecoration(
                              labelText: 'Subject',
                              hintText: 'e.g., Mathematics',
                              prefixIcon: Icon(Icons.book, color: StarlightTheme.primaryBlue),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: StarlightTheme.primaryBlue, width: 2),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Room Field
                          TextField(
                            controller: roomController,
                            decoration: InputDecoration(
                              labelText: 'Room',
                              hintText: 'e.g., Room 101',
                              prefixIcon: Icon(Icons.room, color: StarlightTheme.primaryBlue),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: StarlightTheme.primaryBlue, width: 2),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Time Selection Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.access_time, color: StarlightTheme.primaryBlue),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Lecture Timing',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: StarlightTheme.primaryBlue,
                                      ),
                                    ),
                                    const Spacer(),
                                    // Copy time from previous class
                                    if (_tempSchedules[staffId]?[day] != null && _tempSchedules[staffId]![day] is List && (_tempSchedules[staffId]![day] as List).isNotEmpty)
                                      IconButton(
                                        onPressed: () {
                                          final lastClass = (_tempSchedules[staffId]![day] as List).last;
                                          setDialogState(() {
                                            startTime = TimingService.parseTime(lastClass['start']);
                                            endTime = TimingService.parseTime(lastClass['end']);
                                          });
                                        },
                                        icon: Icon(Icons.content_copy, color: StarlightTheme.primaryBlue),
                                        tooltip: 'Copy time from last class',
                                      ),
                                  ],
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Time Pickers
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () async {
                                          final TimeOfDay? picked = await showTimePicker(
                                            context: context,
                                            initialTime: startTime ?? const TimeOfDay(hour: 9, minute: 0),
                                          );
                                          if (picked != null) {
                                            setDialogState(() => startTime = picked);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: StarlightTheme.primaryBlue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: StarlightTheme.primaryBlue.withOpacity(0.3)),
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(Icons.schedule, color: StarlightTheme.primaryBlue, size: 20),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Start Time',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: StarlightTheme.primaryBlue,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                startTime != null ? TimingService.formatTime(startTime!) : '--:--',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    const SizedBox(width: 16),
                                    
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () async {
                                          final TimeOfDay? picked = await showTimePicker(
                                            context: context,
                                            initialTime: endTime ?? const TimeOfDay(hour: 10, minute: 0),
                                          );
                                          if (picked != null) {
                                            setDialogState(() => endTime = picked);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(Icons.schedule, color: Colors.red, size: 20),
                                              const SizedBox(height: 8),
                                              Text(
                                                'End Time',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                endTime != null ? TimingService.formatTime(endTime!) : '--:--',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      children: [
                        // Copy Day Schedule Button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showCopyDayScheduleDialog(staffMember, day),
                            icon: const Icon(Icons.copy_all),
                            label: const Text('Copy Day Schedule'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: StarlightTheme.primaryBlue),
                              foregroundColor: StarlightTheme.primaryBlue,
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Save Button
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (classController.text.isNotEmpty && startTime != null && endTime != null) {
                                setState(() {
                                  if (_tempSchedules[staffId]![day] == null || !(_tempSchedules[staffId]![day] is List)) {
                                    _tempSchedules[staffId]![day] = [];
                                  }
                                  
                                  final classData = {
                                    'class': classController.text,
                                    'subject': subjectController.text,
                                    'room': roomController.text,
                                    'start': TimingService.formatTime(startTime!),
                                    'end': TimingService.formatTime(endTime!),
                                  };
                                  
                                  if (index != null) {
                                    (_tempSchedules[staffId]![day] as List)[index] = classData;
                                  } else {
                                    (_tempSchedules[staffId]![day] as List).add(classData);
                                  }
                                });
                                Navigator.pop(context);
                              }
                            },
                            icon: const Icon(Icons.save),
                            label: const Text('Save Class'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: StarlightTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCopyDayScheduleDialog(Map<String, dynamic> staffMember, String sourceDay) {
    final staffId = staffMember['id'].toString();
    if (!_tempSchedules.containsKey(staffId)) {
      _tempSchedules[staffId] = {};
    }
    
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final selectedDays = <String, bool>{};
    for (var day in days) {
      selectedDays[day] = false;
    }
    selectedDays[sourceDay] = true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Copy Complete Day Schedule from $sourceDay'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select target days to copy the entire $sourceDay schedule:'),
              const SizedBox(height: 16),
              ...days.map((day) {
                if (day == sourceDay) return const SizedBox.shrink();
                final daySchedule = _tempSchedules[staffId]![day];
                return CheckboxListTile(
                  title: Text(day),
                  subtitle: daySchedule != null && daySchedule is List && daySchedule.isNotEmpty 
                      ? Text('Will replace existing ${daySchedule.length} classes')
                      : null,
                  value: selectedDays[day] ?? false,
                  onChanged: (value) {
                    setDialogState(() => selectedDays[day] = value ?? false);
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final sourceSchedule = _tempSchedules[staffId]![sourceDay];
                if (sourceSchedule != null) {
                  for (final day in days) {
                    if (selectedDays[day] == true) {
                      _tempSchedules[staffId]![day] = List.from(sourceSchedule);
                    }
                  }
                }
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Schedule copied from $sourceDay'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Copy Schedule'),
          ),
        ],
      ),
    );
  }

  void _showCopyScheduleDialog(Map<String, dynamic> staffMember, String sourceDay) {
    final staffId = staffMember['id'].toString();
    if (!_tempSchedules.containsKey(staffId)) {
      _tempSchedules[staffId] = {};
    }
    
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final selectedDays = <String, bool>{};
    for (var day in days) {
      selectedDays[day] = false;
    }
    selectedDays[sourceDay] = true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Copy Schedule from $sourceDay'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select days to copy the schedule to:'),
              const SizedBox(height: 16),
              ...days.map((day) {
                if (day == sourceDay) return const SizedBox.shrink();
                return CheckboxListTile(
                  title: Text(day),
                  value: selectedDays[day] ?? false,
                  onChanged: (value) {
                    setDialogState(() => selectedDays[day] = value ?? false);
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final sourceSchedule = _tempSchedules[staffId]![sourceDay];
                if (sourceSchedule != null) {
                  for (final day in days) {
                    if (selectedDays[day] == true) {
                      _tempSchedules[staffId]![day] = List.from(sourceSchedule);
                    }
                  }
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCell(String text, {int flex = 1, bool isHeader = false, bool isTime = false, VoidCallback? onTap}) {
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isHeader ? StarlightTheme.primaryBlue.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHeader ? Colors.transparent : Colors.grey[200]!,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
              color: isHeader ? StarlightTheme.primaryBlue : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Future<void> _editScheduleTime(Map<String, dynamic> teacher, String day, String type) async {
    final staffId = teacher['id'].toString();
    if (!_tempSchedules.containsKey(staffId)) {
      _tempSchedules[staffId] = {};
    }
    final Map<String, dynamic> schedule = _tempSchedules[staffId]!;
    final currentTime = TimingService.parseTime(schedule[day]?[type] ?? '09:00');
    
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );
    
    if (picked != null) {
      setState(() {
        if (schedule[day] == null) schedule[day] = {};
        schedule[day]![type] = TimingService.formatTime(picked);
      });
    }
  }

  Future<void> _editScheduleSubject(Map<String, dynamic> teacher, String day) async {
    final staffId = teacher['id'].toString();
    if (!_tempSchedules.containsKey(staffId)) {
      _tempSchedules[staffId] = {};
    }
    
    final TextEditingController controller = TextEditingController();
    final Map<String, dynamic> schedule = _tempSchedules[staffId]!;
    controller.text = schedule[day]?['subject'] ?? '';
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Subject - $day'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Subject Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (schedule[day] == null) schedule[day] = {};
              schedule[day]!['subject'] = controller.text;
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _editScheduleRoom(Map<String, dynamic> teacher, String day) async {
    final staffId = teacher['id'].toString();
    if (!_tempSchedules.containsKey(staffId)) {
      _tempSchedules[staffId] = {};
    }
    
    final TextEditingController controller = TextEditingController();
    final Map<String, dynamic> schedule = _tempSchedules[staffId]!;
    controller.text = schedule[day]?['room'] ?? '';
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Room - $day'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Room Number',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (schedule[day] == null) schedule[day] = {};
              schedule[day]!['room'] = controller.text;
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime(TimeOfDay? currentTime, Function(TimeOfDay) onChanged) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: currentTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  void _addBreakTime() {
    setState(() {
      _breakTimes.add({
        'name': 'Break ${_breakTimes.length + 1}',
        'start': '12:00',
        'end': '12:30',
      });
    });
  }

  void _removeBreakTime(int index) {
    setState(() {
      _breakTimes.removeAt(index);
    });
  }

  Future<void> _editBreakTime(int index, String type) async {
    final breakTime = _breakTimes[index];
    final currentTime = TimingService.parseTime(breakTime[type] ?? '12:00');
    
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );
    
    if (picked != null) {
      setState(() {
        _breakTimes[index][type] = TimingService.formatTime(picked);
      });
    }
  }

  
  
  Future<void> _saveSchedule(Map<String, dynamic> staffMember) async {
    try {
      final staffId = staffMember['id'].toString();
      final schedule = _tempSchedules[staffId] ?? {};
      final isWholeDay = _wholeDayAvailability[staffId] ?? false;
      
      debugPrint('🏛️ Timing: Saving schedule for ${staffMember['name']} (id: $staffId)');
      debugPrint('🏛️ Timing:   schedule: $schedule');
      debugPrint('🏛️ Timing:   wholeDay: $isWholeDay');
      
      final success = await TimingService.saveSchedule(
        personnelId: staffId,
        personnelType: staffMember['type'] ?? 'staff',
        schedule: schedule,
        isWholeDayAdmin: isWholeDay,
      );

      debugPrint('🏛️ Timing: Save result for ${staffMember['name']}: $success');

      if (success) {
        setState(() {
          final index = _staff.indexWhere((staff) => staff['id'].toString() == staffId);
          if (index != -1) {
            _staff[index]['schedule'] = schedule;
            _staff[index]['is_whole_day_admin'] = isWholeDay;
          }
        });
      }
    } catch (e) {
      debugPrint('🏛️ Timing: Error saving schedule for ${staffMember['name']}: $e');
    }
  }

  Future<void> _saveAllSchedules() async {
    setState(() => isLoading = true);
    debugPrint('🏛️ Timing: Saving all schedules. Staff count: ${_staff.length}');
    
    try {
      for (final staffMember in _staff) {
        await _saveSchedule(staffMember);
      }
      
      debugPrint('🏛️ Timing: All schedules saved successfully');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All schedules saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('🏛️ Timing: Error saving all schedules: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving schedules: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _editStaffSchedule(Map<String, dynamic> staffMember, int index) {
    // Navigate to edit screen
    print('🏛️ Timing: Editing staff schedule for ${staffMember['name']}');
  }

  void _deleteStaffSchedule(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: const Text('Are you sure you want to delete this staff schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _staff.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveGeneralTiming() async {
    try {
      final success = await TimingService.saveInstitutionalTiming(
        openingTime: TimingService.formatTime(_openingTime ?? const TimeOfDay(hour: 9, minute: 0)),
        closingTime: TimingService.formatTime(_closingTime ?? const TimeOfDay(hour: 15, minute: 0)),
        workingDays: _workingDays,
        breakTimes: _breakTimes,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('General timing saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save timing'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

}
