import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:alarm/alarm.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../models/timetable_models.dart';
import '../../core/timetable_storage.dart';
import '../screens/timetable_alarm_ring_screen.dart';

@pragma('vm:entry-point')
void onNotificationTapBackground(NotificationResponse response) {
  debugPrint('🔔 Background notification tap: ${response.payload}');
}

class LocalAlarmScheduler {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static StreamSubscription<AlarmSettings>? _ringSubscription;

  static Future<void> init() async {
    if (_initialized) return;

    await Alarm.init();

    _ringSubscription ??= Alarm.ringStream.stream.listen((alarmSettings) {
      debugPrint('🔔 ALARM RINGING: ${alarmSettings.id}');
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TimetableAlarmRingScreen(alarmSettings: alarmSettings)),
        );
      }
    });

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {},
      onDidReceiveBackgroundNotificationResponse: onNotificationTapBackground,
    );

    await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();

    const channel = AndroidNotificationChannel(
      'timetable_alarms',
      'Timetable Alarms',
      description: 'Alarms for timetable reminders',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

    _initialized = true;
    debugPrint('🔔 LocalAlarmScheduler: Initialized');
  }

  static Future<void> scheduleAlarm(TimetableAlarm alarm) async {
    await init();

    final timeParts = alarm.time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    final now = DateTime.now();
    var alarmTime = DateTime(now.year, now.month, now.day, hour, minute);

    if (alarmTime.isBefore(now)) {
      alarmTime = alarmTime.add(const Duration(days: 1));
    }

    final tzAlarmTime = tz.TZDateTime.from(alarmTime, tz.local);
    final alarmId = alarm.id.hashCode.abs();

    debugPrint('🔔 LocalAlarmScheduler: Scheduling "${alarm.label}" at $alarmTime (type: ${alarm.alarmType}, ID: $alarmId)');

    if (alarm.alarmType == 'ringing') {
      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: tzAlarmTime,
        assetAudioPath: 'assets/audio/alarm_beep.wav',
        loopAudio: true,
        vibrate: alarm.vibrate,
        volume: 0.8,
        fadeDuration: 3.0,
        warningNotificationOnKill: false,
        androidFullScreenIntent: true,
        notificationSettings: NotificationSettings(
          title: 'Timetable Alarm',
          body: alarm.label,
          stopButton: 'Stop',
        ),
      );

      try {
        await Alarm.set(alarmSettings: alarmSettings);
        debugPrint('🔔 LocalAlarmScheduler: Ringing alarm set successfully');
      } catch (e) {
        debugPrint('🔔 LocalAlarmScheduler: Failed to set ringing alarm - $e');
      }
    } else {
      await _scheduleNotificationAlarm(alarmId, 'Timetable Alarm', alarm.label, tzAlarmTime);
    }
  }

  static Future<void> scheduleTaskAlarm(DailyTask task) async {
    await init();

    if (task.scheduledTime.isBefore(DateTime.now())) return;

    final tzAlarmTime = tz.TZDateTime.from(task.scheduledTime, tz.local);
    final alarmId = task.id.hashCode.abs();

    debugPrint('🔔 LocalAlarmScheduler: Scheduling native alarm for task "${task.title}" at ${task.scheduledTime}');

    final alarmSettings = AlarmSettings(
      id: alarmId,
      dateTime: tzAlarmTime,
      assetAudioPath: 'assets/audio/alarm_beep.wav',
      loopAudio: true,
      vibrate: true,
      volume: 0.9,
      fadeDuration: 1.0,
      warningNotificationOnKill: false,
      androidFullScreenIntent: true,
      notificationSettings: NotificationSettings(
        title: 'Task Due!',
        body: task.title,
        stopButton: 'Stop',
      ),
    );

    try {
      await Alarm.set(alarmSettings: alarmSettings);
      debugPrint('🔔 LocalAlarmScheduler: Task ringing alarm set successfully');
    } catch (e) {
      debugPrint('🔔 LocalAlarmScheduler: Failed to set task ringing alarm - $e');
    }
    // Removed the conflicting _scheduleNotificationAlarm call here
  }

  static Future<void> _scheduleNotificationAlarm(int id, String title, String body, tz.TZDateTime scheduledDate) async {
    final androidDetails = AndroidNotificationDetails(
      'timetable_alarms',
      'Timetable Alarms',
      channelDescription: 'Alarms for timetable reminders',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      ongoing: true,
      category: AndroidNotificationCategory.alarm,
      timeoutAfter: 120000,
      autoCancel: false,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    try {
      await _notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint('🔔 LocalAlarmScheduler: Notification alarm set successfully');
    } catch (e) {
      debugPrint('🔔 LocalAlarmScheduler: Failed to set notification alarm - $e');
    }
  }

  static Future<void> cancelAlarm(TimetableAlarm alarm) async {
    final alarmId = alarm.id.hashCode.abs();
    await _notifications.cancel(id: alarmId);
    await Alarm.stop(alarmId);
    debugPrint('🔔 LocalAlarmScheduler: Cancelled alarm ID $alarmId');
  }

  static Future<void> cancelTaskAlarm(String taskId) async {
    final alarmId = taskId.hashCode.abs();
    await _notifications.cancel(id: alarmId);
    await Alarm.stop(alarmId);
    debugPrint('🔔 LocalAlarmScheduler: Cancelled task alarm ID $alarmId');
  }

  static Future<void> rescheduleAll() async {
    await init();
    final alarmsData = await TimetableStorage.getAlarms();
    final alarms = alarmsData.map((e) => TimetableAlarm.fromJson(e)).toList();

    debugPrint('🔔 LocalAlarmScheduler: Rescheduling ${alarms.length} alarms');

    for (final alarm in alarms) {
      if (alarm.isEnabled) {
        await scheduleAlarm(alarm);
      } else {
        debugPrint('🔔 LocalAlarmScheduler: Skipping disabled alarm "${alarm.label}"');
      }
    }
  }
}
