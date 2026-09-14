import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../models/timetable_models.dart';
import '../services/timetable_service.dart';
import '../widgets/timetable_widgets.dart';

class TimetableManageScreen extends StatefulWidget {
  final TimetableSchedule? schedule;

  const TimetableManageScreen({super.key, this.schedule});

  @override
  State<TimetableManageScreen> createState() => _TimetableManageScreenState();
}

class _TimetableManageScreenState extends State<TimetableManageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subjectController = TextEditingController();
  final _teacherController = TextEditingController();
  final _roomController = TextEditingController();

  String _selectedDay = 'Monday';
  String _startTime = '09:00';
  String _endTime = '10:00';
  String _selectedType = 'class';
  String _selectedRecurrence = 'weekly';
  String _selectedColor = '#4A90D9';
  bool _hasAlarm = false;
  int _alarmMinutesBefore = 10;
  bool _isLoading = false;

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final List<String> _types = ['class', 'exam', 'break', 'event', 'custom'];
  final List<String> _recurrences = ['none', 'daily', 'weekly', 'monthly'];

  @override
  void initState() {
    super.initState();
    if (widget.schedule != null) {
      _titleController.text = widget.schedule!.title;
      _descriptionController.text = widget.schedule!.description;
      _subjectController.text = widget.schedule!.subject;
      _teacherController.text = widget.schedule!.teacher;
      _roomController.text = widget.schedule!.room;
      _selectedDay = widget.schedule!.dayOfWeek;
      _startTime = widget.schedule!.startTime;
      _endTime = widget.schedule!.endTime;
      _selectedType = widget.schedule!.type;
      _selectedRecurrence = widget.schedule!.recurrence;
      _selectedColor = widget.schedule!.color;
      _hasAlarm = widget.schedule!.hasAlarm;
      _alarmMinutesBefore = widget.schedule!.alarmMinutesBefore;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    _teacherController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final schedule = TimetableSchedule(
        id: widget.schedule?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dayOfWeek: _selectedDay,
        startTime: _startTime,
        endTime: _endTime,
        subject: _subjectController.text.trim(),
        teacher: _teacherController.text.trim(),
        room: _roomController.text.trim(),
        type: _selectedType,
        color: _selectedColor,
        hasAlarm: _hasAlarm,
        alarmMinutesBefore: _alarmMinutesBefore,
        recurrence: _selectedRecurrence,
        userId: widget.schedule?.userId ?? '',
        createdAt: widget.schedule?.createdAt ?? DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      bool success;
      if (widget.schedule != null) {
        success = await TimetableService.updateSchedule(schedule);
      } else {
        final created = await TimetableService.createSchedule(schedule);
        success = created != null;
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.schedule != null ? 'Schedule updated' : 'Schedule created'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save schedule'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse((isStart ? _startTime : _endTime).split(':')[0]),
        minute: int.parse((isStart ? _startTime : _endTime).split(':')[1]),
      ),
    );
    if (time != null) {
      setState(() {
        final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        if (isStart) {
          _startTime = timeStr;
        } else {
          _endTime = timeStr;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.schedule != null ? 'Edit Schedule' : 'New Schedule',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: StarlightTheme.primaryBlue,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check, color: StarlightTheme.primaryBlue),
            onPressed: _isLoading ? null : _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TimetableWidgets.buildSectionHeader('BASIC INFO'),
            _buildTextField(_titleController, 'Title', Icons.title, required: true),
            const SizedBox(height: 12),
            _buildTextField(_descriptionController, 'Description', Icons.description, maxLines: 2),
            const SizedBox(height: 24),

            TimetableWidgets.buildSectionHeader('SCHEDULE'),
            TimetableWidgets.buildDropdown(
              value: _selectedDay,
              items: _days,
              onChanged: (v) => setState(() => _selectedDay = v!),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TimetableWidgets.buildTimePicker(
                    label: 'Start',
                    time: _startTime,
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TimetableWidgets.buildTimePicker(
                    label: 'End',
                    time: _endTime,
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TimetableWidgets.buildDropdown(
              value: _selectedRecurrence,
              items: _recurrences,
              onChanged: (v) => setState(() => _selectedRecurrence = v!),
            ),
            const SizedBox(height: 24),

            TimetableWidgets.buildSectionHeader('DETAILS'),
            _buildTextField(_subjectController, 'Subject', Icons.book),
            const SizedBox(height: 12),
            _buildTextField(_teacherController, 'Teacher', Icons.person),
            const SizedBox(height: 12),
            _buildTextField(_roomController, 'Room', Icons.meeting_room),
            const SizedBox(height: 12),
            TimetableWidgets.buildDropdown(
              value: _selectedType,
              items: _types,
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            const SizedBox(height: 24),

            TimetableWidgets.buildSectionHeader('COLOR'),
            TimetableWidgets.buildColorPicker(
              selectedColor: _selectedColor,
              onChanged: (color) => setState(() => _selectedColor = color),
            ),
            const SizedBox(height: 24),

            TimetableWidgets.buildSectionHeader('ALARM'),
            SwitchListTile(
              title: Text('Enable Alarm', style: GoogleFonts.poppins()),
              subtitle: Text('$_alarmMinutesBefore minutes before', style: GoogleFonts.poppins(color: Colors.grey[600])),
              value: _hasAlarm,
              onChanged: (v) => setState(() => _hasAlarm = v),
              activeColor: StarlightTheme.primaryBlue,
            ),
            if (_hasAlarm) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Minutes before: '),
                  Expanded(
                    child: Slider(
                      value: _alarmMinutesBefore.toDouble(),
                      min: 5,
                      max: 60,
                      divisions: 11,
                      label: '$_alarmMinutesBefore min',
                      onChanged: (v) => setState(() => _alarmMinutesBefore = v.round()),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {int maxLines = 1, bool required = false}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        prefixIcon: Icon(icon, color: StarlightTheme.primaryBlue, size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: StarlightTheme.primaryBlue),
        ),
      ),
      validator: required ? (v) => v == null || v.isEmpty ? 'Required' : null : null,
    );
  }
}
