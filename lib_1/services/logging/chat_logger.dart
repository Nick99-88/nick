import 'dart:developer' as developer;
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// 🏛️ Log Level Enum
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// 🏛️ Log Category Enum
enum LogCategory {
  socket,
  fcm,
  database,
  chat,
  message,
  user,
  system,
  performance,
}

/// 🏛️ Chat System Logger
/// Comprehensive logging system for debugging, monitoring, and analytics
class ChatLogger {
  static final ChatLogger _instance = ChatLogger._internal();
  factory ChatLogger() => _instance;
  ChatLogger._internal();

  // Configuration
  static const bool _enableConsoleLogging = true;
  static const bool _enableFileLogging = true;
  static const int _maxLogFileSize = 10 * 1024 * 1024; // 10MB
  static const int _maxLogFiles = 5;
  static const LogLevel _minLogLevel = LogLevel.debug;

  // File handles
  File? _logFile;
  late final String _logDirectory;

  // Performance tracking
  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, List<int>> _operationDurations = {};

  /// 🏛️ Initialize logger
  Future<void> initialize() async {
    try {
      if (_enableFileLogging) {
        final directory = await getApplicationDocumentsDirectory();
        _logDirectory = '${directory.path}/logs';
        
        // Create logs directory if it doesn't exist
        final logsDir = Directory(_logDirectory);
        if (!await logsDir.exists()) {
          await logsDir.create(recursive: true);
        }
        
        // Set up log file rotation
        await _setupLogFile();
        
        // Clean up old log files
        await _cleanupOldLogs();
      }
      
      info('ChatLogger', 'Chat system logging initialized');
    } catch (e) {
      developer.log('Failed to initialize ChatLogger: $e', name: 'ChatLogger');
    }
  }

  /// 🏛️ Setup log file with rotation
  Future<void> _setupLogFile() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _logFile = File('$_logDirectory/chat_$today.log');
      
      // Check file size and rotate if needed
      if (await _logFile!.exists()) {
        final fileSize = await _logFile!.length();
        if (fileSize > _maxLogFileSize) {
          await _rotateLogFile();
        }
      }
    } catch (e) {
      developer.log('Failed to setup log file: $e', name: 'ChatLogger');
    }
  }

  /// 🏛️ Rotate log file
  Future<void> _rotateLogFile() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final timestamp = DateFormat('HH-mm-ss').format(DateTime.now());
      
      // Rename current log file
      await _logFile!.rename('$_logDirectory/chat_$today-$timestamp.log');
      
      // Create new log file
      _logFile = File('$_logDirectory/chat_$today.log');
    } catch (e) {
      developer.log('Failed to rotate log file: $e', name: 'ChatLogger');
    }
  }

  /// 🏛️ Clean up old log files
  Future<void> _cleanupOldLogs() async {
    try {
      final logsDir = Directory(_logDirectory);
      final files = await logsDir.list().toList();
      
      // Sort by creation time (oldest first)
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return aStat.modified.compareTo(bStat.modified);
      });
      
      // Keep only the most recent files
      if (files.length > _maxLogFiles) {
        for (int i = 0; i < files.length - _maxLogFiles; i++) {
          try {
            await files[i].delete();
          } catch (e) {
            developer.log('Failed to delete old log file: $e', name: 'ChatLogger');
          }
        }
      }
    } catch (e) {
      developer.log('Failed to cleanup old logs: $e', name: 'ChatLogger');
    }
  }

  /// 🏛️ Log debug message
  void debug(String category, String message, {Map<String, dynamic>? data, String? operationId}) {
    _log(LogLevel.debug, category, message, data: data, operationId: operationId);
  }

  /// 🏛️ Log info message
  void info(String category, String message, {Map<String, dynamic>? data, String? operationId}) {
    _log(LogLevel.info, category, message, data: data, operationId: operationId);
  }

  /// 🏛️ Log warning message
  void warning(String category, String message, {Map<String, dynamic>? data, String? operationId}) {
    _log(LogLevel.warning, category, message, data: data, operationId: operationId);
  }

  /// 🏛️ Log error message
  void error(String category, String message, {Map<String, dynamic>? data, String? operationId, dynamic error, StackTrace? stackTrace}) {
    _log(LogLevel.error, category, message, data: data, operationId: operationId, error: error, stackTrace: stackTrace);
  }

  /// 🏛️ Log critical message
  void critical(String category, String message, {Map<String, dynamic>? data, String? operationId, dynamic error, StackTrace? stackTrace}) {
    _log(LogLevel.critical, category, message, data: data, operationId: operationId, error: error, stackTrace: stackTrace);
  }

  /// 🏛️ Core logging method
  void _log(LogLevel level, String category, String message, {
    Map<String, dynamic>? data,
    String? operationId,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    // Check if we should log this level
    if (level.index < _minLogLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase();
    
    // Create log entry
    final logEntry = {
      'timestamp': timestamp,
      'level': levelStr,
      'category': category,
      'message': message,
      'operation_id': operationId,
      'data': data,
      'error': error?.toString(),
      'stack_trace': stackTrace?.toString(),
    };

    // Console logging
    if (_enableConsoleLogging) {
      _logToConsole(level, category, message, logEntry);
    }

    // File logging
    if (_enableFileLogging) {
      _logToFile(logEntry);
    }
  }

  /// 🏛️ Log to console
  void _logToConsole(LogLevel level, String category, String message, Map<String, dynamic> logEntry) {
    final emoji = _getLevelEmoji(level);
    final formattedMessage = '$emoji $category: $message';
    
    switch (level) {
      case LogLevel.debug:
        developer.log(formattedMessage, name: 'ChatLogger');
        break;
      case LogLevel.info:
        print(formattedMessage);
        break;
      case LogLevel.warning:
        print('⚠️ $formattedMessage');
        break;
      case LogLevel.error:
        print('❌ $formattedMessage');
        if (logEntry['error'] != null) {
          print('   Error: ${logEntry['error']}');
        }
        break;
      case LogLevel.critical:
        print('🚨 CRITICAL: $formattedMessage');
        if (logEntry['error'] != null) {
          print('   Error: ${logEntry['error']}');
        }
        if (logEntry['stack_trace'] != null) {
          print('   Stack: ${logEntry['stack_trace']}');
        }
        break;
    }
  }

  /// 🏛️ Log to file
  Future<void> _logToFile(Map<String, dynamic> logEntry) async {
    try {
      if (_logFile == null) return;
      
      final logLine = jsonEncode(logEntry) + '\n';
      await _logFile!.writeAsString(logLine, mode: FileMode.append);
    } catch (e) {
      developer.log('Failed to write to log file: $e', name: 'ChatLogger');
    }
  }

  /// 🏛️ Get emoji for log level
  String _getLevelEmoji(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.critical:
        return '🚨';
    }
  }

  /// 🏛️ Start performance tracking
  String startPerformanceTracking(String operation) {
    final operationId = '${operation}_${DateTime.now().millisecondsSinceEpoch}';
    _operationStartTimes[operationId] = DateTime.now();
    debug('Performance', 'Started tracking: $operation', operationId: operationId);
    return operationId;
  }

  /// 🏛️ End performance tracking
  void endPerformanceTracking(String operationId) {
    final startTime = _operationStartTimes[operationId];
    if (startTime == null) {
      warning('Performance', 'No start time found for operation: $operationId');
      return;
    }

    final duration = DateTime.now().difference(startTime).inMilliseconds;
    final operation = operationId.split('_').sublist(0, -1).join('_');
    
    // Store duration for analytics
    if (!_operationDurations.containsKey(operation)) {
      _operationDurations[operation] = [];
    }
    _operationDurations[operation]!.add(duration);
    
    // Log performance
    final level = duration > 5000 ? LogLevel.warning : LogLevel.info;
    _log(level, 'Performance', 'Completed: $operation in ${duration}ms', 
         operationId: operationId, data: {'duration_ms': duration});
    
    // Clean up
    _operationStartTimes.remove(operationId);
  }

  /// 🏛️ Get performance statistics
  Map<String, Map<String, int>> getPerformanceStats() {
    final stats = <String, Map<String, int>>{};
    
    for (final entry in _operationDurations.entries) {
      final durations = entry.value;
      if (durations.isEmpty) continue;
      
      durations.sort();
      final avg = durations.reduce((a, b) => a + b) ~/ durations.length;
      final min = durations.first;
      final max = durations.last;
      final median = durations[durations.length ~/ 2];
      
      stats[entry.key] = {
        'avg_ms': avg,
        'min_ms': min,
        'max_ms': max,
        'median_ms': median,
        'count': durations.length,
      };
    }
    
    return stats;
  }

  /// 🏛️ Log user action
  void logUserAction(String action, {Map<String, dynamic>? data}) {
    info('User', 'Action: $action', data: data);
  }

  /// 🏛️ Log socket event
  void logSocketEvent(String event, {Map<String, dynamic>? data}) {
    debug('Socket', 'Event: $event', data: data);
  }

  /// 🏛️ Log FCM event
  void logFcmEvent(String event, {Map<String, dynamic>? data}) {
    info('FCM', 'Event: $event', data: data);
  }

  /// 🏛️ Log database operation
  void logDatabaseOperation(String operation, {Map<String, dynamic>? data, String? operationId}) {
    debug('Database', 'Operation: $operation', data: data, operationId: operationId);
  }

  /// 🏛️ Log chat operation
  void logChatOperation(String operation, {Map<String, dynamic>? data, String? operationId}) {
    info('Chat', 'Operation: $operation', data: data, operationId: operationId);
  }

  /// 🏛️ Log message operation
  void logMessageOperation(String operation, {Map<String, dynamic>? data, String? operationId}) {
    info('Message', 'Operation: $operation', data: data, operationId: operationId);
  }

  /// 🏛️ Log system event
  void logSystemEvent(String event, {Map<String, dynamic>? data}) {
    info('System', 'Event: $event', data: data);
  }

  /// 🏛️ Get recent logs
  Future<List<String>> getRecentLogs({int count = 100}) async {
    try {
      if (_logFile == null) return [];
      
      final content = await _logFile!.readAsString();
      final lines = content.split('\n').where((line) => line.isNotEmpty).toList();
      
      // Return the most recent lines
      return lines.reversed.take(count).toList().reversed.toList();
    } catch (e) {
      developer.log('Failed to get recent logs: $e', name: 'ChatLogger');
      return [];
    }
  }

  /// 🏛️ Export logs to file
  Future<File?> exportLogs({DateTime? startDate, DateTime? endDate}) async {
    try {
      final logsDir = Directory(_logDirectory);
      final files = await logsDir.list().toList();
      
      final buffer = StringBuffer();
      
      for (final file in files) {
        if (file is File && file.path.endsWith('.log')) {
          final content = await file.readAsString();
          final lines = content.split('\n');
          
          for (final line in lines) {
            if (line.isEmpty) continue;
            
            try {
              final logEntry = jsonDecode(line);
              final timestamp = DateTime.parse(logEntry['timestamp']);
              
              // Filter by date range if provided
              if (startDate != null && timestamp.isBefore(startDate)) continue;
              if (endDate != null && timestamp.isAfter(endDate)) continue;
              
              buffer.writeln(line);
            } catch (e) {
              // Skip invalid JSON lines
              continue;
            }
          }
        }
      }
      
      final exportFile = File('$_logDirectory/chat_export_${DateTime.now().millisecondsSinceEpoch}.log');
      await exportFile.writeAsString(buffer.toString());
      
      return exportFile;
    } catch (e) {
      developer.log('Failed to export logs: $e', name: 'ChatLogger');
      return null;
    }
  }

  /// 🏛️ Clear all logs
  Future<void> clearLogs() async {
    try {
      final logsDir = Directory(_logDirectory);
      final files = await logsDir.list().toList();
      
      for (final file in files) {
        try {
          await file.delete();
        } catch (e) {
          developer.log('Failed to delete log file: $e', name: 'ChatLogger');
        }
      }
      
      info('ChatLogger', 'All logs cleared');
    } catch (e) {
      developer.log('Failed to clear logs: $e', name: 'ChatLogger');
    }
  }

  /// 🏛️ Dispose logger
  void dispose() {
    _operationStartTimes.clear();
    _operationDurations.clear();
    info('ChatLogger', 'Chat system logging disposed');
  }
}

/// 🏛️ Global logger instance
final chatLogger = ChatLogger();
