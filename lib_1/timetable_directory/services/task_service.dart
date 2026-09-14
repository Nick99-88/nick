import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:alarm/alarm.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/timetable_models.dart';
import 'local_alarm_scheduler.dart';

class TaskService {
  static const String _key = 'daily_tasks';
  static const String _notifiedKey = 'notified_task_ids';

  static Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  static Future<List<DailyTask>> getTasks() async {
    try {
      final p = await _prefs;
      final data = p.getString(_key);
      if (data != null && data.isNotEmpty) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(data));
        return list.map((e) => DailyTask.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('TaskService: Error reading tasks - $e');
    }
    return [];
  }

  static Future<void> saveTasks(List<DailyTask> tasks) async {
    try {
      final p = await _prefs;
      final data = jsonEncode(tasks.map((t) => t.toJson()).toList());
      await p.setString(_key, data);
    } catch (e) {
      debugPrint('TaskService: Error saving tasks - $e');
    }
  }

  static Future<DailyTask> createTask(DailyTask task) async {
    final tasks = await getTasks();
    final newTask = DailyTask(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      title: task.title,
      description: task.description,
      scheduledTime: task.scheduledTime,
      durationMinutes: task.durationMinutes,
      isCompleted: task.isCompleted,
      priority: task.priority,
      colorHex: task.colorHex,
    );
    tasks.add(newTask);
    await saveTasks(tasks);
    await scheduleNativeAlarmForTask(newTask);
    return newTask;
  }

  static Future<void> updateTask(DailyTask task) async {
    final tasks = await getTasks();
    final index = tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      tasks[index] = task;
      await saveTasks(tasks);
      await clearNotified(task.id);
      if (task.isCompleted) {
        await cancelNativeAlarmForTask(task);
      } else {
        await scheduleNativeAlarmForTask(task);
      }
    }
  }

  static Future<void> toggleTask(String id) async {
    final tasks = await getTasks();
    final index = tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      tasks[index].isCompleted = !tasks[index].isCompleted;
      tasks[index].updatedAt = DateTime.now();
    await saveTasks(tasks);
    await clearAllNotified();
  }
  }

  static Future<void> deleteTask(String id) async {
    final tasks = await getTasks();
    tasks.removeWhere((t) => t.id == id);
    await saveTasks(tasks);
    await clearNotified(id);
  }

  static Future<void> clearCompleted() async {
    final tasks = await getTasks();
    tasks.removeWhere((t) => t.isCompleted);
    await saveTasks(tasks);
    await updateWidgetWithNextTask();
  }

  static Future<List<DailyTask>> getTodayTasks() async {
    final all = await getTasks();
    final today = DateTime.now();
    return all.where((t) {
      final diff = t.scheduledTime.difference(today).inDays;
      return diff == 0 && t.scheduledTime.day == today.day;
    }).toList();
  }

  static Future<List<DailyTask>> getPendingTasks() async {
    final all = await getTasks();
    return all.where((t) => !t.isCompleted).toList();
  }

  static Future<DailyTask?> getNextPendingTask() async {
    final pending = await getPendingTasks();
    pending.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    if (pending.isEmpty) return null;
    final now = DateTime.now();
    final upcoming = pending.where((t) => !t.scheduledTime.isBefore(now)).toList();
    if (upcoming.isNotEmpty) return upcoming.first;
    return pending.first;
  }

  static Future<List<DailyTask>> getDueTasks() async {
    final now = DateTime.now();
    final pending = await getPendingTasks();
    final notified = await _getNotifiedIds();
    return pending
        .where((t) => t.scheduledTime.isBefore(now) && !notified.contains(t.id))
        .toList();
  }

  static Future<Set<String>> _getNotifiedIds() async {
    try {
      final p = await _prefs;
      final data = p.getStringList(_notifiedKey);
      return data?.toSet() ?? {};
    } catch (_) {
      return {};
    }
  }

  static Future<void> markNotified(String id) async {
    try {
      final p = await _prefs;
      final ids = p.getStringList(_notifiedKey) ?? [];
      ids.add(id);
      await p.setStringList(_notifiedKey, ids);
    } catch (_) {}
  }

  static Future<void> clearNotified(String id) async {
    try {
      final p = await _prefs;
      final ids = p.getStringList(_notifiedKey) ?? [];
      ids.remove(id);
      await p.setStringList(_notifiedKey, ids);
    } catch (_) {}
  }

  static Future<void> clearAllNotified() async {
    try {
      final p = await _prefs;
      await p.remove(_notifiedKey);
    } catch (_) {}
  }

  static Future<void> ringForTask(DailyTask task) async {
    try {
      final ringTime = DateTime.now().add(const Duration(seconds: 3));
      final tzRingTime = tz.TZDateTime.from(ringTime, tz.local);
      final alarmSettings = AlarmSettings(
        id: task.id.hashCode.abs(),
        dateTime: tzRingTime,
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
      await Alarm.set(alarmSettings: alarmSettings);
      debugPrint('🔔 TaskService: Ringing alarm for "${task.title}"');
    } catch (e) {
      debugPrint('🔔 TaskService: ringForTask error - $e');
    }
  }

  static Future<void> scheduleNativeAlarmForTask(DailyTask task) async {
    try {
      if (task.isCompleted || task.scheduledTime.isBefore(DateTime.now())) return;
      await LocalAlarmScheduler.scheduleTaskAlarm(task);
      debugPrint('🔔 TaskService: Native alarm scheduled for "${task.title}" at ${task.scheduledTime}');
    } catch (e) {
      debugPrint('🔔 TaskService: scheduleNativeAlarmForTask error - $e');
    }
  }

  static Future<void> cancelNativeAlarmForTask(DailyTask task) async {
    try {
      final alarmId = task.id.hashCode.abs();
      await Alarm.stop(alarmId);
      debugPrint('🔔 TaskService: Native alarm cancelled for "${task.title}"');
    } catch (e) {
      debugPrint('🔔 TaskService: cancelNativeAlarmForTask error - $e');
    }
  }

  static Future<void> updateWidgetWithNextTask() async {
    try {
      final tasks = await getTasks();
      final pending = tasks.where((t) => !t.isCompleted).toList();
      pending.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      final pendingCount = pending.length;
      final completedCount = tasks.where((t) => t.isCompleted).length;
      final totalCount = tasks.length;
      final now = DateTime.now();
      // Only show upcoming tasks (not overdue) for the timer
      final upcoming = pending.where((t) => !t.scheduledTime.isBefore(now)).toList();
      final next = upcoming.isNotEmpty ? upcoming.first : null;

      if (next != null) {
        final targetEpochMs = next.scheduledTime.millisecondsSinceEpoch;
        String icon;
        if (next.priority == PriorityLevel.critical || next.priority == PriorityLevel.high) {
          icon = '🔥';
        } else {
          icon = '📌';
        }

        final remaining = next.scheduledTime.difference(now);
        final hours = remaining.inHours;
        final minutes = remaining.inMinutes.remainder(60);
        final status = hours > 0 ? '$hours hours $minutes min • $pendingCount pending' : '$minutes min left • $pendingCount pending';

        await HomeWidget.saveWidgetData<String>('widgetTitle', next.title);
        await HomeWidget.saveWidgetData<int>('targetEpochMs', targetEpochMs);
        await HomeWidget.saveWidgetData<String>('widgetMessage', next.description);
        await HomeWidget.saveWidgetData<String>('widgetStatus', status);
        await HomeWidget.saveWidgetData<String>('widgetIcon', icon);
        await HomeWidget.saveWidgetData<String>('widgetTaskId', next.id);
        await HomeWidget.saveWidgetData<bool>('widgetHasTask', true);
      } else {
        // No upcoming tasks - check if there are overdue tasks
        final overdue = pending.where((t) => t.scheduledTime.isBefore(now)).toList();
        if (overdue.isNotEmpty) {
          final firstOverdue = overdue.first;
          final overdueMin = now.difference(firstOverdue.scheduledTime).inMinutes;
          await HomeWidget.saveWidgetData<String>('widgetTitle', firstOverdue.title);
          await HomeWidget.saveWidgetData<int>('targetEpochMs', 0); // No timer for overdue
          await HomeWidget.saveWidgetData<String>('widgetMessage', firstOverdue.description);
          await HomeWidget.saveWidgetData<String>('widgetStatus', 'OVERDUE by ${overdueMin}m • $pendingCount pending');
          await HomeWidget.saveWidgetData<String>('widgetIcon', '⚠️');
          await HomeWidget.saveWidgetData<String>('widgetTaskId', firstOverdue.id);
          await HomeWidget.saveWidgetData<bool>('widgetHasTask', true);
        } else {
          await HomeWidget.saveWidgetData<String>('widgetTitle', totalCount > 0 ? 'All $completedCount tasks done!' : 'No tasks yet');
          await HomeWidget.saveWidgetData<int>('targetEpochMs', 0);
          await HomeWidget.saveWidgetData<String>('widgetMessage', totalCount > 0 ? 'Completed $completedCount of $totalCount' : 'Tap + to create one');
          await HomeWidget.saveWidgetData<String>('widgetStatus', '');
          await HomeWidget.saveWidgetData<String>('widgetIcon', totalCount > 0 ? '✅' : '📋');
          await HomeWidget.saveWidgetData<String>('widgetTaskId', '');
          await HomeWidget.saveWidgetData<bool>('widgetHasTask', false);
        }
      }
      await HomeWidget.updateWidget(androidName: 'StarlightHomeWidget');
    } catch (e) {
      debugPrint('TaskService: updateWidgetWithNextTask error - $e');
    }
  }
}
