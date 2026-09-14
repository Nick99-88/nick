import '../models/timetable_models.dart';
import '../../core/timetable_storage.dart';
import 'local_alarm_scheduler.dart';

class TimetableService {
  // --- SCHEDULES ---

  static Future<List<TimetableSchedule>> getSchedules() async {
    final localData = await TimetableStorage.getSchedules();
    return localData.map((e) => TimetableSchedule.fromJson(e)).toList();
  }

  static Future<TimetableSchedule?> createSchedule(TimetableSchedule schedule) async {
    final now = DateTime.now().toIso8601String();
    final localSchedule = TimetableSchedule(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      title: schedule.title,
      description: schedule.description,
      dayOfWeek: schedule.dayOfWeek,
      startTime: schedule.startTime,
      endTime: schedule.endTime,
      subject: schedule.subject,
      teacher: schedule.teacher,
      room: schedule.room,
      type: schedule.type,
      color: schedule.color,
      isActive: schedule.isActive,
      hasAlarm: schedule.hasAlarm,
      alarmId: schedule.alarmId,
      alarmMinutesBefore: schedule.alarmMinutesBefore,
      recurrence: schedule.recurrence,
      endDate: schedule.endDate,
      userId: schedule.userId,
      createdAt: now,
      updatedAt: now,
    );
    await TimetableStorage.addSchedule(localSchedule.toJson());
    return localSchedule;
  }

  static Future<bool> updateSchedule(TimetableSchedule schedule) async {
    final updated = TimetableSchedule(
      id: schedule.id,
      title: schedule.title,
      description: schedule.description,
      dayOfWeek: schedule.dayOfWeek,
      startTime: schedule.startTime,
      endTime: schedule.endTime,
      subject: schedule.subject,
      teacher: schedule.teacher,
      room: schedule.room,
      type: schedule.type,
      color: schedule.color,
      isActive: schedule.isActive,
      hasAlarm: schedule.hasAlarm,
      alarmId: schedule.alarmId,
      alarmMinutesBefore: schedule.alarmMinutesBefore,
      recurrence: schedule.recurrence,
      endDate: schedule.endDate,
      userId: schedule.userId,
      createdAt: schedule.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await TimetableStorage.updateSchedule(updated.id, updated.toJson());
    return true;
  }

  static Future<bool> deleteSchedule(String scheduleId) async {
    await TimetableStorage.deleteSchedule(scheduleId);
    return true;
  }

  // --- ALARMS ---

  static Future<List<TimetableAlarm>> getAlarms() async {
    final localData = await TimetableStorage.getAlarms();
    return localData.map((e) => TimetableAlarm.fromJson(e)).toList();
  }

  static Future<TimetableAlarm?> createAlarm(TimetableAlarm alarm) async {
    final localAlarm = TimetableAlarm(
      id: 'alarm_${DateTime.now().millisecondsSinceEpoch}',
      scheduleId: alarm.scheduleId,
      time: alarm.time,
      minutesBefore: alarm.minutesBefore,
      label: alarm.label,
      isEnabled: true,
      alarmType: alarm.alarmType,
      vibrate: alarm.vibrate,
    );
    await TimetableStorage.addAlarm(localAlarm.toJson());
    await LocalAlarmScheduler.scheduleAlarm(localAlarm);
    return localAlarm;
  }

  static Future<bool> updateAlarm(TimetableAlarm alarm) async {
    await TimetableStorage.updateAlarm(alarm.id, alarm.toJson());
    return true;
  }

  static Future<bool> toggleAlarm(String alarmId, bool enabled) async {
    final alarms = await TimetableStorage.getAlarms();
    final index = alarms.indexWhere((a) => a['id'] == alarmId);
    if (index != -1) {
      alarms[index]['is_enabled'] = enabled;
      await TimetableStorage.saveAlarms(alarms);

      final alarm = TimetableAlarm.fromJson(alarms[index]);
      if (enabled) {
        await LocalAlarmScheduler.scheduleAlarm(alarm);
      } else {
        await LocalAlarmScheduler.cancelAlarm(alarm);
      }
    }
    return true;
  }

  static Future<bool> deleteAlarm(String alarmId) async {
    final alarms = await TimetableStorage.getAlarms();
    final index = alarms.indexWhere((a) => a['id'] == alarmId);
    if (index != -1) {
      final alarm = TimetableAlarm.fromJson(alarms[index]);
      await LocalAlarmScheduler.cancelAlarm(alarm);
    }
    await TimetableStorage.deleteAlarm(alarmId);
    return true;
  }

  // --- TODAY'S SCHEDULE ---

  static Future<List<TimetableSchedule>> getTodaySchedule() async {
    final allSchedules = await getSchedules();
    final today = DateTime.now().weekday;
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return allSchedules.where((s) => s.dayOfWeek == dayNames[today - 1]).toList();
  }

  // --- WEEKLY SCHEDULE ---

  static Future<Map<String, List<TimetableSchedule>>> getWeeklySchedule() async {
    final allSchedules = await getSchedules();
    final Map<String, List<TimetableSchedule>> weekMap = {};
    for (final schedule in allSchedules) {
      weekMap.putIfAbsent(schedule.dayOfWeek, () => []).add(schedule);
    }
    return weekMap;
  }
}
