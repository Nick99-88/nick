import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:home_widget/home_widget.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../../core/theme.dart';
import '../../widgets/intro_widgets/intro_check.dart';
import '../../widgets/intro_widgets/timetable_intro.dart';
import '../models/timetable_models.dart';
import '../services/timetable_service.dart';
import '../services/task_service.dart';
import '../widgets/timetable_widgets.dart';
import 'timetable_manage_screen.dart';
import 'timetable_alarm_screen.dart';

class TimetableDirectory extends StatefulWidget {
  const TimetableDirectory({super.key});

  @override
  State<TimetableDirectory> createState() => _TimetableDirectoryState();
}

class _TimetableDirectoryState extends State<TimetableDirectory> with TickerProviderStateMixin {
  late TabController _tabController;
  List<TimetableSchedule> _schedules = [];
  List<TimetableAlarm> _alarms = [];
  List<DailyTask> _tasks = [];
  List<DailyTask> _todayTasks = [];
  bool _isLoading = true;
  String _selectedDayFilter = 'all';
  bool _isIslamicCalendar = false;
  Timer? _timer;
  int _widgetTick = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      setState(() {});
      await _checkDueTasks();
      _widgetTick++;
      if (_widgetTick % 10 == 0 && Platform.isAndroid) {
        TaskService.updateWidgetWithNextTask();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final schedules = await TimetableService.getSchedules();
      final alarms = await TimetableService.getAlarms();
      final tasks = await TaskService.getTasks();
      final now = DateTime.now();
      final todayTasks = tasks.where((t) {
        final diff = t.scheduledTime.difference(now).inDays;
        return diff == 0 && t.scheduledTime.day == now.day;
      }).toList();
      if (mounted) {
        setState(() {
          _schedules = schedules;
          _alarms = alarms;
          _tasks = tasks;
          _todayTasks = todayTasks;
          _isLoading = false;
        });
      }
      TaskService.updateWidgetWithNextTask();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<TimetableSchedule> get _filteredSchedules {
    if (_selectedDayFilter == 'all') return _schedules;
    return _schedules.where((s) => s.dayOfWeek == _selectedDayFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return IntroCheck(
      featureKey: timetableFeatureKey,
      featureIcon: timetableFeatureIcon,
      featureTitle: timetableFeatureTitle,
      featureSubtitle: timetableFeatureSubtitle,
      steps: timetableIntroSteps,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'TimeTable',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: StarlightTheme.primaryBlue,
          ),
        ),
        centerTitle: true,
        actions: [
          if (Platform.isAndroid)
            IconButton(
              icon: const Icon(Icons.widgets_outlined, color: StarlightTheme.primaryBlue),
              tooltip: 'Add home widget',
              onPressed: _addHomeWidget,
            ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: StarlightTheme.primaryBlue),
            onPressed: () => _navigateToCreate(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: StarlightTheme.primaryBlue,
          labelColor: StarlightTheme.primaryBlue,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Schedule', icon: Icon(Icons.schedule)),
            Tab(text: 'Calendar', icon: Icon(Icons.calendar_month)),
            Tab(text: 'Alarms', icon: Icon(Icons.alarm)),
            Tab(text: 'Tasks', icon: Icon(Icons.checklist)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildScheduleTab(),
                _buildCalendarTab(),
                _buildAlarmsTab(),
                _buildTasksTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: StarlightTheme.primaryBlue,
        child: Icon(
          _tabController.index == 2
              ? Icons.add_alarm
              : _tabController.index == 3
                  ? Icons.add_task
                  : Icons.add,
          color: Colors.white,
        ),
        onPressed: () {
          if (_tabController.index == 2) {
            _createAlarm();
          } else if (_tabController.index == 3) {
            _editTask(null);
          } else {
            _navigateToCreate();
          }
        },
      ),
      ),
    );
  }

  Future<void> _addHomeWidget() async {
    try {
      await TaskService.updateWidgetWithNextTask();
      final supported = await HomeWidget.isRequestPinWidgetSupported();
      if (supported == true) {
        await HomeWidget.requestPinWidget(androidName: 'StarlightHomeWidget');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Widget added to home screen'), backgroundColor: Colors.green),
          );
        }
      } else {
        await HomeWidget.updateWidget(androidName: 'StarlightHomeWidget');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Widget updated. Add it manually from your widget list.'), backgroundColor: Colors.blue),
          );
        }
      }
    } catch (e) {
      debugPrint('HomeWidget: error - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildScheduleTab() {
    return Column(
      children: [
        TimetableWidgets.buildDayFilter(
          selectedDay: _selectedDayFilter,
          onChanged: (day) => setState(() => _selectedDayFilter = day),
        ),
        Expanded(child: _buildScheduleList()),
      ],
    );
  }

  Widget _buildScheduleList() {
    final schedules = _filteredSchedules;

    if (schedules.isEmpty) {
      return TimetableWidgets.buildEmptyState(
        icon: Icons.event_busy,
        title: 'No schedules found',
        subtitle: 'Tap + to create a new schedule',
        onRefresh: _loadData,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        final schedule = schedules[index];
        return TimetableWidgets.buildScheduleCard(
          context,
          schedule,
          onTap: () => _navigateToEdit(schedule),
          onEdit: () => _navigateToEdit(schedule),
          onDelete: () => _confirmDelete(schedule),
          onSetAlarm: () => _navigateToAlarms(),
        );
      },
    );
  }

  Widget _buildCalendarTab() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.mosque, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('Islamic Calendar', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Switch(
                value: _isIslamicCalendar,
                onChanged: (v) => setState(() => _isIslamicCalendar = v),
                activeColor: Colors.green,
              ),
            ],
          ),
        ),
        Expanded(
          child: TimetableWidgets.buildCalendarView(
            schedules: _schedules,
            isIslamic: _isIslamicCalendar,
            onTap: (appointment) => _showAppointmentDetails(appointment),
          ),
        ),
      ],
    );
  }

  Widget _buildAlarmsTab() {
    if (_alarms.isEmpty) {
      return TimetableWidgets.buildEmptyState(
        icon: Icons.alarm_off,
        title: 'No alarms configured',
        subtitle: 'Tap + to create a new alarm',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _alarms.length,
      itemBuilder: (context, index) {
        final alarm = _alarms[index];
        return TimetableWidgets.buildAlarmCard(
          context,
          alarm,
          onToggle: (enabled) => _toggleAlarm(alarm, enabled),
          onDelete: () => _deleteAlarm(alarm),
        );
      },
    );
  }

  Widget _buildTasksTab() {
    return Column(
      children: [
        _buildCountdownBanner(),
        Expanded(child: _buildTaskList()),
      ],
    );
  }

  Widget _buildCountdownBanner() {
    final pending = _tasks.where((t) => !t.isCompleted).toList();
    pending.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    final next = pending.isNotEmpty ? pending.first : null;

    if (next == null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [StarlightTheme.primaryBlue.withOpacity(0.8), StarlightTheme.primaryBlue],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'All tasks completed!',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
    }

    final remaining = next.remainingTime;
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);
    final isUrgent = next.isUrgent;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUrgent
              ? [Colors.red.withOpacity(0.7), Colors.red]
              : [StarlightTheme.primaryBlue.withOpacity(0.8), StarlightTheme.primaryBlue],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isUrgent ? Colors.red : StarlightTheme.primaryBlue).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isUrgent ? Icons.alarm : Icons.schedule, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Next: ${next.title}',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${hours}h ${minutes}m ${seconds}s',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                isUrgent ? 'URGENT' : 'Pending',
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${next.scheduledTime.hour.toString().padLeft(2, '0')}:${next.scheduledTime.minute.toString().padLeft(2, '0')} - ${next.durationMinutes} min',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    if (_tasks.isEmpty) {
      return TimetableWidgets.buildEmptyState(
        icon: Icons.checklist_rtl,
        title: 'No tasks',
        subtitle: 'Tap + to create a daily task',
      );
    }

    _tasks.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    final completed = _tasks.where((t) => t.isCompleted).toList();
    final pending = _tasks.where((t) => !t.isCompleted).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (pending.isNotEmpty) ...[
          TimetableWidgets.buildSectionHeader('PENDING (${pending.length})'),
          ...pending.map((task) => _buildTaskCard(task)),
          const SizedBox(height: 16),
        ],
        if (completed.isNotEmpty) ...[
          TimetableWidgets.buildSectionHeader('COMPLETED (${completed.length})'),
          ...completed.map((task) => _buildTaskCard(task)),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildTaskCard(DailyTask task) {
    final color = Color(int.parse(task.colorHex.replaceAll('#', '0xFF')));
    final remaining = task.remainingTime;
    final isOverdue = task.isOverdue;
    final isUrgent = task.isUrgent;

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        await TaskService.deleteTask(task.id);
        _loadData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverdue ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.15),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _editTask(task),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    await TaskService.toggleTask(task.id);
                    _loadData();
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: task.isCompleted ? color : Colors.transparent,
                      border: Border.all(color: task.isCompleted ? color : Colors.grey[400]!, width: 2),
                    ),
                    child: task.isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          color: task.isCompleted ? Colors.grey : Colors.grey[800],
                        ),
                      ),
                      if (task.description.isNotEmpty)
                        Text(
                          task.description,
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (!task.isCompleted) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? Colors.red.withOpacity(0.1)
                          : isUrgent
                              ? Colors.orange.withOpacity(0.1)
                              : color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isOverdue
                          ? 'OVERDUE'
                          : isUrgent
                              ? '${remaining.inMinutes} min'
                              : '${task.scheduledTime.hour.toString().padLeft(2, '0')}:${task.scheduledTime.minute.toString().padLeft(2, '0')}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isOverdue
                            ? Colors.red
                            : isUrgent
                                ? Colors.orange
                                : color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editTask(DailyTask? task) async {
    final result = await _showTaskDialog(task);
    if (result != null && mounted) {
      _loadData();
    }
  }

  Future<DailyTask?> _showTaskDialog(DailyTask? existing) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    TimeOfDay selectedTime = existing != null
        ? TimeOfDay(hour: existing.scheduledTime.hour, minute: existing.scheduledTime.minute)
        : TimeOfDay.now();
    int duration = existing?.durationMinutes ?? 30;
    PriorityLevel priority = existing?.priority ?? PriorityLevel.medium;
    String colorHex = existing?.colorHex ?? '#4A90D9';

    final colors = ['#4A90D9', '#4CAF50', '#FF9800', '#F44336', '#9C27B0', '#009688', '#E91E63', '#3F51B5'];

    return showDialog<DailyTask>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(existing != null ? 'Edit Task' : 'New Task'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Time'),
                    subtitle: Text(selectedTime.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: selectedTime);
                      if (picked != null) setDialogState(() => selectedTime = picked);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('Duration: $duration min'),
                  Slider(
                    value: duration.toDouble(),
                    min: 5,
                    max: 180,
                    divisions: 35,
                    label: '$duration min',
                    onChanged: (v) => setDialogState(() => duration = v.round()),
                  ),
                  const SizedBox(height: 8),
                  const Text('Priority:', style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<PriorityLevel>(
                    value: priority,
                    isExpanded: true,
                    items: PriorityLevel.values.map((p) {
                      return DropdownMenuItem(value: p, child: Text(p.name.toUpperCase()));
                    }).toList(),
                    onChanged: (v) => setDialogState(() => priority = v!),
                  ),
                  const SizedBox(height: 8),
                  const Text('Color:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: colors.map((c) {
                      final clr = Color(int.parse(c.replaceAll('#', '0xFF')));
                      final isSelected = colorHex == c;
                      return GestureDetector(
                        onTap: () => setDialogState(() => colorHex = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: clr,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: clr, blurRadius: 6)]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) return;
                  final now = DateTime.now();
                  final scheduled = DateTime(
                    now.year, now.month, now.day,
                    selectedTime.hour, selectedTime.minute,
                  );
                  if (existing != null) {
                    final updated = existing.copyWith(
                      title: titleController.text.trim(),
                      description: descController.text.trim(),
                      scheduledTime: scheduled,
                      durationMinutes: duration,
                      priority: priority,
                      colorHex: colorHex,
                    );
                    await TaskService.updateTask(updated);
                    Navigator.pop(dialogContext, updated);
                  } else {
                    final created = await TaskService.createTask(DailyTask(
                      id: '',
                      title: titleController.text.trim(),
                      description: descController.text.trim(),
                      scheduledTime: scheduled,
                      durationMinutes: duration,
                      priority: priority,
                      colorHex: colorHex,
                    ));
                    Navigator.pop(dialogContext, created);
                  }
                },
                child: Text(existing != null ? 'Update' : 'Create'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAppointmentDetails(Appointment appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appointment.subject),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time: ${TimetableWidgets.formatTime(appointment.startTime)} - ${TimetableWidgets.formatTime(appointment.endTime)}'),
            if (appointment.location != null) Text('Room: ${appointment.location}'),
            if (appointment.notes != null) Text('Details: ${appointment.notes}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAlarm(TimetableAlarm alarm, bool enabled) async {
    final success = await TimetableService.toggleAlarm(alarm.id, enabled);
    if (success && mounted) {
      _loadData();
    }
  }

  Future<void> _deleteAlarm(TimetableAlarm alarm) async {
    final success = await TimetableService.deleteAlarm(alarm.id);
    if (success && mounted) {
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alarm deleted'), backgroundColor: Colors.green),
      );
    }
  }

  void _navigateToCreate() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TimetableManageScreen()),
    );
    if (result == true && mounted) {
      _loadData();
    }
  }

  void _navigateToEdit(TimetableSchedule schedule) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TimetableManageScreen(schedule: schedule)),
    );
    if (result == true && mounted) {
      _loadData();
    }
  }

  void _navigateToAlarms() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TimetableAlarmScreen()),
    );
  }

  Future<void> _createAlarm() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (context) {
        final labelController = TextEditingController(text: 'Timetable Reminder');
        int minutesBefore = 10;
        String alarmType = 'notification';
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('New Alarm'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Minutes before: '),
                    Expanded(
                      child: Slider(
                        value: minutesBefore.toDouble(),
                        min: 5,
                        max: 60,
                        divisions: 11,
                        label: '$minutesBefore min',
                        onChanged: (v) => setDialogState(() => minutesBefore = v.round()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Time: $timeStr',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text('Alarm Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile(
                        title: const Text('Notification', style: TextStyle(fontSize: 13)),
                        value: 'notification',
                        groupValue: alarmType,
                        onChanged: (v) => setDialogState(() => alarmType = v!),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile(
                        title: const Text('Full Ring', style: TextStyle(fontSize: 13)),
                        value: 'ringing',
                        groupValue: alarmType,
                        onChanged: (v) => setDialogState(() => alarmType = v!),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                Text(
                  alarmType == 'notification'
                      ? 'Shows notification with vibration'
                      : 'Full screen with ringing sound',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  debugPrint('🔔 Creating alarm with type: $alarmType');
                  final alarm = TimetableAlarm(
                    id: '',
                    scheduleId: '',
                    time: timeStr,
                    minutesBefore: minutesBefore,
                    label: labelController.text,
                    alarmType: alarmType,
                  );
                  final created = await TimetableService.createAlarm(alarm);
                  if (mounted) {
                    Navigator.pop(context);
                    if (created != null) {
                      _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Alarm created (${alarmType == 'ringing' ? 'Full Ring' : 'Notification'})'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
         );
       },
     );
   }

  Future<void> _checkDueTasks() async {
    try {
      final due = await TaskService.getDueTasks();
      for (final task in due) {
        HapticFeedback.heavyImpact();
        await TaskService.markNotified(task.id);
        await TaskService.updateWidgetWithNextTask();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${task.title} is due now!'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _confirmDelete(TimetableSchedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: Text('Are you sure you want to delete "${schedule.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await TimetableService.deleteSchedule(schedule.id);
      if (success && mounted) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule deleted'), backgroundColor: Colors.green),
        );
      }
    }
  }
}
