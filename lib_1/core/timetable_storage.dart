import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimetableStorage {
  static const String _keySchedules = "timetable_schedules";
  static const String _keyAlarms = "timetable_alarms";
  static const String _keyLastSync = "timetable_last_sync";
  static const String _keyPreferences = "timetable_preferences";

  static Future<SharedPreferences> get _instance async =>
      await SharedPreferences.getInstance();

  // --- SCHEDULES ---

  static Future<List<Map<String, dynamic>>> getSchedules() async {
    try {
      final p = await _instance;
      final data = p.getString(_keySchedules);
      if (data != null && data.isNotEmpty) {
        return List<Map<String, dynamic>>.from(jsonDecode(data));
      }
    } catch (e) {
      debugPrint("🏛️ Timetable Storage: Error reading schedules - $e");
    }
    return [];
  }

  static Future<void> saveSchedules(List<Map<String, dynamic>> schedules) async {
    try {
      final p = await _instance;
      await p.setString(_keySchedules, jsonEncode(schedules));
      debugPrint("🏛️ Timetable Storage: Saved ${schedules.length} schedules");
    } catch (e) {
      debugPrint("🏛️ Timetable Storage: Error saving schedules - $e");
    }
  }

  static Future<void> addSchedule(Map<String, dynamic> schedule) async {
    final schedules = await getSchedules();
    schedules.add(schedule);
    await saveSchedules(schedules);
  }

  static Future<void> updateSchedule(String id, Map<String, dynamic> schedule) async {
    final schedules = await getSchedules();
    final index = schedules.indexWhere((s) => s['id'] == id);
    if (index != -1) {
      schedules[index] = schedule;
      await saveSchedules(schedules);
    }
  }

  static Future<void> deleteSchedule(String id) async {
    final schedules = await getSchedules();
    schedules.removeWhere((s) => s['id'] == id);
    await saveSchedules(schedules);
  }

  static Future<void> clearSchedules() async {
    final p = await _instance;
    await p.remove(_keySchedules);
  }

  // --- ALARMS ---

  static Future<List<Map<String, dynamic>>> getAlarms() async {
    try {
      final p = await _instance;
      final data = p.getString(_keyAlarms);
      if (data != null && data.isNotEmpty) {
        return List<Map<String, dynamic>>.from(jsonDecode(data));
      }
    } catch (e) {
      debugPrint("🏛️ Timetable Storage: Error reading alarms - $e");
    }
    return [];
  }

  static Future<void> saveAlarms(List<Map<String, dynamic>> alarms) async {
    try {
      final p = await _instance;
      await p.setString(_keyAlarms, jsonEncode(alarms));
      debugPrint("🏛️ Timetable Storage: Saved ${alarms.length} alarms");
    } catch (e) {
      debugPrint("🏛️ Timetable Storage: Error saving alarms - $e");
    }
  }

  static Future<void> addAlarm(Map<String, dynamic> alarm) async {
    final alarms = await getAlarms();
    alarms.add(alarm);
    await saveAlarms(alarms);
  }

  static Future<void> updateAlarm(String id, Map<String, dynamic> alarm) async {
    final alarms = await getAlarms();
    final index = alarms.indexWhere((a) => a['id'] == id);
    if (index != -1) {
      alarms[index] = alarm;
      await saveAlarms(alarms);
    }
  }

  static Future<void> deleteAlarm(String id) async {
    final alarms = await getAlarms();
    alarms.removeWhere((a) => a['id'] == id);
    await saveAlarms(alarms);
  }

  static Future<void> clearAlarms() async {
    final p = await _instance;
    await p.remove(_keyAlarms);
  }

  // --- SYNC TRACKING ---

  static Future<DateTime?> getLastSync() async {
    try {
      final p = await _instance;
      final data = p.getString(_keyLastSync);
      if (data != null) {
        return DateTime.parse(data);
      }
    } catch (e) {
      debugPrint("🏛️ Timetable Storage: Error reading last sync - $e");
    }
    return null;
  }

  static Future<void> setLastSync() async {
    try {
      final p = await _instance;
      await p.setString(_keyLastSync, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint("🏛️ Timetable Storage: Error setting last sync - $e");
    }
  }

  // --- PREFERENCES ---

  static Future<Map<String, dynamic>> getPreferences() async {
    try {
      final p = await _instance;
      final data = p.getString(_keyPreferences);
      if (data != null && data.isNotEmpty) {
        return Map<String, dynamic>.from(jsonDecode(data));
      }
    } catch (e) {
      debugPrint("🏛️ Timetable Storage: Error reading preferences - $e");
    }
    return {
      'default_view': 'week',
      'show_weekends': true,
      'start_hour': 8,
      'end_hour': 18,
      'alarm_enabled': true,
      'alarm_sound': 'default',
      'color_theme': 'blue',
    };
  }

  static Future<void> savePreferences(Map<String, dynamic> prefs) async {
    try {
      final p = await _instance;
      await p.setString(_keyPreferences, jsonEncode(prefs));
    } catch (e) {
      debugPrint("🏛️ Timetable Storage: Error saving preferences - $e");
    }
  }

  static Future<T> getPreference<T>(String key, T defaultValue) async {
    final prefs = await getPreferences();
    return prefs[key] ?? defaultValue;
  }

  static Future<void> setPreference(String key, dynamic value) async {
    final prefs = await getPreferences();
    prefs[key] = value;
    await savePreferences(prefs);
  }

  // --- CLEAR ALL ---

  static Future<void> clearAll() async {
    final p = await _instance;
    await p.remove(_keySchedules);
    await p.remove(_keyAlarms);
    await p.remove(_keyLastSync);
    await p.remove(_keyPreferences);
    debugPrint("🏛️ Timetable Storage: Cleared all data");
  }

  // --- INIT ---

  static Future<void> ensureInitialized() async {
    try {
      await SharedPreferences.getInstance();
      debugPrint("🏛️ Timetable Storage Vault: Online");
    } catch (e) {
      debugPrint("🏛️ Timetable Storage System Failed: $e");
    }
  }
}
