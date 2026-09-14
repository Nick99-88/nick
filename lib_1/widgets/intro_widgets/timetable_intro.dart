import 'package:flutter/material.dart';

const String timetableFeatureKey = 'timetable';
const IconData timetableFeatureIcon = Icons.schedule;
const String timetableFeatureTitle = 'Timetable';
const String timetableFeatureSubtitle = 'Manage your class schedules, set alarms, and never miss a session.';

List<Map<String, dynamic>> get timetableIntroSteps => [
  {
    'icon': Icons.calendar_today_rounded,
    'title': 'Smart Schedule',
    'description': 'Visualize your weekly timetable with color-coded classes, deadlines, and events at a glance.',
    'color': const Color(0xFF1A237E),
  },
  {
    'icon': Icons.alarm_add_rounded,
    'title': 'Custom Reminders',
    'description': 'Set smart alarms and reminders for upcoming classes, exams, and important events.',
    'color': const Color(0xFF283593),
  },
  {
    'icon': Icons.sync_rounded,
    'title': 'Always Updated',
    'description': 'Your timetable syncs across all devices, so you stay organized wherever you are.',
    'color': const Color(0xFF3F51B5),
  },
  {
    'icon': Icons.dashboard_rounded,
    'title': 'Dashboard View',
    'description': 'Get an overview of your daily and weekly schedule with the interactive dashboard.',
    'color': const Color(0xFF5C6BC0),
  },
];