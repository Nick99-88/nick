class TimetableSchedule {
  final String id;
  final String title;
  final String description;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String subject;
  final String teacher;
  final String room;
  final String type; // 'class', 'exam', 'break', 'event', 'custom'
  final String color;
  final bool isActive;
  final bool hasAlarm;
  final String? alarmId;
  final int alarmMinutesBefore;
  final String recurrence; // 'none', 'daily', 'weekly', 'monthly'
  final String? endDate;
  final String userId;
  final String createdAt;
  final String updatedAt;

  TimetableSchedule({
    required this.id,
    required this.title,
    this.description = '',
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.subject = '',
    this.teacher = '',
    this.room = '',
    this.type = 'class',
    this.color = '#4A90D9',
    this.isActive = true,
    this.hasAlarm = false,
    this.alarmId,
    this.alarmMinutesBefore = 10,
    this.recurrence = 'weekly',
    this.endDate,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TimetableSchedule.fromJson(Map<String, dynamic> json) {
    return TimetableSchedule(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      dayOfWeek: json['day_of_week'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      subject: json['subject'] ?? '',
      teacher: json['teacher'] ?? '',
      room: json['room'] ?? '',
      type: json['type'] ?? 'class',
      color: json['color'] ?? '#4A90D9',
      isActive: json['is_active'] ?? true,
      hasAlarm: json['has_alarm'] ?? false,
      alarmId: json['alarm_id'],
      alarmMinutesBefore: json['alarm_minutes_before'] ?? 10,
      recurrence: json['recurrence'] ?? 'weekly',
      endDate: json['end_date'],
      userId: json['user_id'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'subject': subject,
      'teacher': teacher,
      'room': room,
      'type': type,
      'color': color,
      'is_active': isActive,
      'has_alarm': hasAlarm,
      'alarm_id': alarmId,
      'alarm_minutes_before': alarmMinutesBefore,
      'recurrence': recurrence,
      'end_date': endDate,
      'user_id': userId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  TimetableSchedule copyWith({
    String? title,
    String? description,
    String? dayOfWeek,
    String? startTime,
    String? endTime,
    String? subject,
    String? teacher,
    String? room,
    String? type,
    String? color,
    bool? isActive,
    bool? hasAlarm,
    String? alarmId,
    int? alarmMinutesBefore,
    String? recurrence,
    String? endDate,
  }) {
    return TimetableSchedule(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      subject: subject ?? this.subject,
      teacher: teacher ?? this.teacher,
      room: room ?? this.room,
      type: type ?? this.type,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      hasAlarm: hasAlarm ?? this.hasAlarm,
      alarmId: alarmId ?? this.alarmId,
      alarmMinutesBefore: alarmMinutesBefore ?? this.alarmMinutesBefore,
      recurrence: recurrence ?? this.recurrence,
      endDate: endDate ?? this.endDate,
      userId: userId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class DailyTask {
  final String id;
  String title;
  String description;
  DateTime scheduledTime;
  int durationMinutes;
  bool isCompleted;
  PriorityLevel priority;
  String colorHex;
  DateTime createdAt;
  DateTime updatedAt;

  DailyTask({
    required this.id,
    required this.title,
    this.description = '',
    required this.scheduledTime,
    this.durationMinutes = 30,
    this.isCompleted = false,
    this.priority = PriorityLevel.medium,
    this.colorHex = '#4A90D9',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Duration get remainingTime {
    final now = DateTime.now();
    if (scheduledTime.isBefore(now)) return Duration.zero;
    return scheduledTime.difference(now);
  }

  bool get isOverdue => !isCompleted && scheduledTime.isBefore(DateTime.now());

  bool get isUrgent {
    if (isCompleted || isOverdue) return false;
    return remainingTime.inMinutes < 30;
  }

  factory DailyTask.fromJson(Map<String, dynamic> json) {
    return DailyTask(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      scheduledTime: DateTime.parse(json['scheduled_time']),
      durationMinutes: json['duration_minutes'] ?? 30,
      isCompleted: json['is_completed'] ?? false,
      priority: PriorityLevel.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => PriorityLevel.medium,
      ),
      colorHex: json['color_hex'] ?? '#4A90D9',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'scheduled_time': scheduledTime.toIso8601String(),
        'duration_minutes': durationMinutes,
        'is_completed': isCompleted,
        'priority': priority.name,
        'color_hex': colorHex,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  DailyTask copyWith({
    String? title,
    String? description,
    DateTime? scheduledTime,
    int? durationMinutes,
    bool? isCompleted,
    PriorityLevel? priority,
    String? colorHex,
  }) {
    return DailyTask(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

enum PriorityLevel { low, medium, high, critical }

class TimetableAlarm {
  final String id;
  final String scheduleId;
  final String time;
  final int minutesBefore;
  final bool isEnabled;
  final String? sound;
  final bool vibrate;
  final String label;
  final String alarmType; // 'notification' or 'ringing'

  TimetableAlarm({
    required this.id,
    required this.scheduleId,
    required this.time,
    this.minutesBefore = 10,
    this.isEnabled = true,
    this.sound,
    this.vibrate = true,
    this.label = 'Timetable Reminder',
    this.alarmType = 'notification',
  });

  factory TimetableAlarm.fromJson(Map<String, dynamic> json) {
    return TimetableAlarm(
      id: json['id'] ?? '',
      scheduleId: json['schedule_id'] ?? '',
      time: json['time'] ?? '',
      minutesBefore: json['minutes_before'] ?? 10,
      isEnabled: json['is_enabled'] ?? true,
      sound: json['sound'],
      vibrate: json['vibrate'] ?? true,
      label: json['label'] ?? 'Timetable Reminder',
      alarmType: json['alarm_type'] ?? 'notification',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'schedule_id': scheduleId,
      'time': time,
      'minutes_before': minutesBefore,
      'is_enabled': isEnabled,
      'sound': sound,
      'vibrate': vibrate,
      'label': label,
      'alarm_type': alarmType,
    };
  }
}
