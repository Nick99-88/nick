import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:hijri/hijri_calendar.dart';
import '../../core/theme.dart';
import '../models/timetable_models.dart';
import '../services/timetable_service.dart';
import '../screens/timetable_manage_screen.dart';
import '../screens/timetable_alarm_screen.dart';

class TimetableWidgets {
  static Widget buildScheduleCard(
    BuildContext context,
    TimetableSchedule schedule, {
    required VoidCallback onTap,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required VoidCallback onSetAlarm,
  }) {
    final color = Color(int.parse(schedule.color.replaceAll('#', '0xFF')));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schedule.title,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (schedule.subject.isNotEmpty)
                          Text(
                            schedule.subject,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      schedule.type.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit();
                          break;
                        case 'alarm':
                          onSetAlarm();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'alarm', child: Text('Set Alarm')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${schedule.startTime} - ${schedule.endTime}',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    schedule.dayOfWeek,
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                  ),
                  if (schedule.room.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.meeting_room, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      schedule.room,
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                  if (schedule.hasAlarm) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.alarm, size: 16, color: Colors.orange),
                  ],
                ],
              ),
              if (schedule.teacher.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      schedule.teacher,
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Widget buildAlarmCard(
    BuildContext context,
    TimetableAlarm alarm, {
    required Function(bool) onToggle,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: alarm.isEnabled
                ? (alarm.alarmType == 'ringing' ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1))
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            alarm.alarmType == 'ringing' ? Icons.alarm : Icons.notifications,
            color: alarm.isEnabled
                ? (alarm.alarmType == 'ringing' ? Colors.red : Colors.orange)
                : Colors.grey,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                alarm.label,
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: alarm.alarmType == 'ringing' ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                alarm.alarmType == 'ringing' ? 'RING' : 'NOTIF',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: alarm.alarmType == 'ringing' ? Colors.red : Colors.blue,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${alarm.time} • ${alarm.minutesBefore} min before',
          style: GoogleFonts.poppins(color: Colors.grey[600]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: alarm.isEnabled,
              onChanged: onToggle,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildDayFilter({
    required String selectedDay,
    required Function(String) onChanged,
  }) {
    final days = ['all', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = selectedDay == day;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(day == 'all' ? 'All' : day.substring(0, 3)),
              selected: isSelected,
              onSelected: (_) => onChanged(day),
              selectedColor: StarlightTheme.primaryBlue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget buildColorPicker({
    required String selectedColor,
    required Function(String) onChanged,
  }) {
    final colors = {
      'Blue': '#4A90D9',
      'Green': '#4CAF50',
      'Orange': '#FF9800',
      'Red': '#F44336',
      'Purple': '#9C27B0',
      'Teal': '#009688',
      'Pink': '#E91E63',
      'Indigo': '#3F51B5',
    };

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colors.entries.map((entry) {
        final color = Color(int.parse(entry.value.replaceAll('#', '0xFF')));
        final isSelected = selectedColor == entry.value;
        return GestureDetector(
          onTap: () => onChanged(entry.value),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected ? color : Colors.transparent,
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
        );
      }).toList(),
    );
  }

  static Widget buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onRefresh,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          if (onRefresh != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(backgroundColor: StarlightTheme.primaryBlue),
            ),
          ],
        ],
      ),
    );
  }

  static Widget buildTimePicker({
    required String label,
    required String time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.poppins(color: Colors.grey[600])),
            Text(time, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  static Widget buildDropdown({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  static Widget buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  static Widget buildCalendarView({
    required List<TimetableSchedule> schedules,
    bool isIslamic = false,
    Function(Appointment)? onTap,
  }) {
    final appointments = <Appointment>[];

    for (final schedule in schedules) {
      final color = Color(int.parse(schedule.color.replaceAll('#', '0xFF')));
      final startTime = _parseTime(schedule.startTime);
      final endTime = _parseTime(schedule.endTime);

      if (startTime != null && endTime != null) {
        appointments.add(Appointment(
          startTime: startTime,
          endTime: endTime,
          subject: schedule.title,
          color: color,
          recurrenceRule: _getRecurrenceRule(schedule.recurrence),
          location: schedule.room,
          notes: '${schedule.subject}\n${schedule.teacher}',
        ));
      }
    }

    return SfCalendar(
      view: CalendarView.month,
      dataSource: _MeetingDataSource(appointments),
      allowedViews: const [
        CalendarView.day,
        CalendarView.week,
        CalendarView.workWeek,
        CalendarView.month,
      ],
      monthCellBuilder: isIslamic ? (BuildContext context, MonthCellDetails details) {
        final hijriDate = HijriCalendar.fromDate(details.date);
        final eventName = _getIslamicEvent(hijriDate.hMonth, hijriDate.hDay);
        final isToday = details.date.day == DateTime.now().day && details.date.month == DateTime.now().month && details.date.year == DateTime.now().year;

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.2), width: 0.5),
            color: isToday ? StarlightTheme.primaryBlue.withOpacity(0.1) : (eventName != null ? Colors.green.withOpacity(0.05) : null),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${hijriDate.hDay}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                  color: isToday ? StarlightTheme.primaryBlue : (eventName != null ? Colors.green[800] : Colors.grey[800]),
                ),
              ),
              if (eventName != null)
                Text(
                  eventName,
                  style: GoogleFonts.poppins(fontSize: 9, color: Colors.green[800], fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
            ],
          ),
        );
      } : null,
      onTap: (details) {
        if (onTap != null && details.appointments != null && details.appointments!.isNotEmpty) {
          onTap(details.appointments!.first);
        }
      },
    );
  }

  static String? _getIslamicEvent(int month, int day) {
    if (month == 1 && day == 1) return 'Islamic New Year';
    if (month == 1 && day == 10) return 'Ashura';
    if (month == 3 && day == 12) return 'Mawlid al-Nabi';
    if (month == 7 && day == 27) return 'Isra and Mi\'raj';
    if (month == 8 && day == 15) return 'Mid-Sha\'ban';
    if (month == 9 && day == 1) return 'Ramadan Starts';
    if (month == 10 && day == 1) return 'Eid al-Fitr';
    if (month == 12 && day == 9) return 'Day of Arafah';
    if (month == 12 && day == 10) return 'Eid al-Adha';
    return null;
  }

  static DateTime? _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
      }
    } catch (_) {}
    return null;
  }

  static String? _getRecurrenceRule(String recurrence) {
    switch (recurrence) {
      case 'daily':
        return 'FREQ=DAILY';
      case 'weekly':
        return 'FREQ=WEEKLY';
      case 'monthly':
        return 'FREQ=MONTHLY';
      default:
        return null;
    }
  }

  static String formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _MeetingDataSource extends CalendarDataSource {
  _MeetingDataSource(List<Appointment> source) {
    appointments = source;
  }
}
