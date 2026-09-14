import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../models/timetable_models.dart';
import '../services/timetable_service.dart';
import '../widgets/timetable_widgets.dart';

class TimetableAlarmScreen extends StatefulWidget {
  const TimetableAlarmScreen({super.key});

  @override
  State<TimetableAlarmScreen> createState() => _TimetableAlarmScreenState();
}

class _TimetableAlarmScreenState extends State<TimetableAlarmScreen> {
  List<TimetableAlarm> _alarms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlarms();
  }

  Future<void> _loadAlarms() async {
    setState(() => _isLoading = true);
    try {
      final alarms = await TimetableService.getAlarms();
      if (mounted) {
        setState(() {
          _alarms = alarms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAlarm(TimetableAlarm alarm, bool enabled) async {
    final success = await TimetableService.toggleAlarm(alarm.id, enabled);
    if (success && mounted) _loadAlarms();
  }

  Future<void> _deleteAlarm(TimetableAlarm alarm) async {
    final success = await TimetableService.deleteAlarm(alarm.id);
    if (success && mounted) {
      _loadAlarms();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alarm deleted'), backgroundColor: Colors.green),
      );
    }
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
            title: Text('New Alarm', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
                Text(
                  'Time: $timeStr',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
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
                      _loadAlarms();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Alarm Manager',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: StarlightTheme.primaryBlue,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alarms.isEmpty
              ? TimetableWidgets.buildEmptyState(
                  icon: Icons.alarm_off,
                  title: 'No alarms configured',
                  subtitle: 'Tap + to create a new alarm',
                )
              : ListView.builder(
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
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: StarlightTheme.primaryBlue,
        child: const Icon(Icons.add_alarm, color: Colors.white),
        onPressed: _createAlarm,
      ),
    );
  }
}
