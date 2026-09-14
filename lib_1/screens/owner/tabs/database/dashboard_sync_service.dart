import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../services/institution/dashboard_service.dart';
import '../../../../services/socket/unified_socket_service.dart';
import 'dashboard_local_db.dart';
import 'dashboard_cache_service.dart';

class SyncResult {
  final int total;
  final int synced;
  final int failedPermanent;
  final int retried;
  final List<String> errors;
  SyncResult({required this.total, required this.synced, required this.failedPermanent, required this.retried, required this.errors});
}

class DashboardSyncService {
  final DashboardService _api = DashboardService();
  final DashboardLocalDb _db = DashboardLocalDb.instance;
  final DashboardCacheService _cache = DashboardCacheService.instance;

  static final DashboardSyncService instance = DashboardSyncService._();
  DashboardSyncService._();

  bool _isSyncing = false;
  StreamSubscription? _connectionSub;
  Timer? _periodicSyncTimer;

  Function(SyncResult)? onSyncComplete;
  Function(String message)? onSyncError;

  void init() {
    _listenConnection();
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (UnifiedSocketService.isConnected() && !_isSyncing) {
        syncPendingOps();
      }
    });
    _initialDrain();
  }

  void dispose() {
    _connectionSub?.cancel();
    _periodicSyncTimer?.cancel();
  }

  Future<void> _initialDrain() async {
    await Future.delayed(const Duration(seconds: 5));
    if (!_isSyncing) {
      final count = await _db.getPendingOpCount();
      if (count > 0) {
        debugPrint('🏛️ DashboardSync: startup drain — $count pending ops');
        await syncPendingOps();
      }
    }
  }

  void _listenConnection() {
    UnifiedSocketService.setCallbacks(
      onConnectionStateChanged: (data) {
        final connected = data['connected'] == true;
        if (connected && !_isSyncing) {
          syncPendingOps();
        }
      },
    );
  }

  Future<void> syncPendingOps() async {
    if (_isSyncing) return;
    _isSyncing = true;

    int syncedCount = 0;
    int failedPermCount = 0;
    int retriedCount = 0;
    final errors = <String>[];

    try {
      final ops = await _db.getPendingOps();
      if (ops.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('🏛️ DashboardSync: processing ${ops.length} pending ops (FIFO)');

      for (final op in ops) {
        final id = op['id'] as int;
        final entityType = op['entity_type'] as String;
        final operation = op['operation'] as String;
        final payloadStr = op['payload'] as String;
        final originalValue = op['original_value'] as String? ?? '';
        final retryCount = op['retry_count'] as int? ?? 0;

        if (retryCount >= 5) {
          debugPrint('🏛️ DashboardSync: op $id exceeded max retries — archiving');
          await _db.moveToFailedTable(id);
          errors.add('Op $id ($entityType/$operation): exceeded 5 retries, archived');
          failedPermCount++;
          continue;
        }

        final payload = payloadStr.isNotEmpty
            ? Map<String, dynamic>.from(jsonDecode(payloadStr) as Map)
            : <String, dynamic>{};

        final idempotencyKey = op['idempotency_key'] as String? ?? '';

        try {
          await _executeOp(entityType, operation, payload, originalValue, idempotencyKey);
          await _db.markOpDone(id);
          syncedCount++;
          debugPrint('🏛️ DashboardSync: op $id ($entityType/$operation) synced');
        } on DashboardApiException catch (e) {
          if (_isPermanentError(e.statusCode)) {
            debugPrint('🏛️ DashboardSync: op $id PERMANENT failure (${e.statusCode})');
            await _rollbackOnFailure(op, entityType, operation, payload, e.toString());
            await _db.markOpFailed(id, e.toString(), e.statusCode);
            await _db.moveToFailedTable(id);
            errors.add('Op $id ($entityType/$operation): ${e.statusCode} — ${e.message}');
            failedPermCount++;
          } else {
            debugPrint('🏛️ DashboardSync: op $id retryable failure (${e.statusCode}) — $e');
            await _db.incrementRetryOp(id, e.toString());
            errors.add('Op $id ($entityType/$operation): ${e.statusCode} — will retry');
            retriedCount++;
          }
        } catch (e) {
          debugPrint('🏛️ DashboardSync: op $id network error — $e');
          await _db.incrementRetryOp(id, e.toString());
          errors.add('Op $id ($entityType/$operation): network — will retry');
          retriedCount++;
        }
      }

      if (syncedCount > 0) {
        debugPrint('🏛️ DashboardSync: cache refreshed after sync');
      }
    } catch (e) {
      debugPrint('🏛️ DashboardSync: sync cycle failed — $e');
      errors.add('Sync cycle error: $e');
    } finally {
      _isSyncing = false;
      final result = SyncResult(
        total: syncedCount + failedPermCount + retriedCount,
        synced: syncedCount,
        failedPermanent: failedPermCount,
        retried: retriedCount,
        errors: errors,
      );
      onSyncComplete?.call(result);
      if (errors.isNotEmpty) {
        onSyncError?.call(errors.join('\n'));
      }
    }
  }

  bool _isPermanentError(int statusCode) {
    if (statusCode == 401) return false;
    return statusCode >= 400 && statusCode < 500 && statusCode != 408;
  }

  Future<void> _rollbackOnFailure(
    Map<String, dynamic> op,
    String entityType,
    String operation,
    Map<String, dynamic> payload,
    String error,
  ) async {
    final previousStateStr = op['previous_state'] as String? ?? '';
    if (previousStateStr.isEmpty) return;

    try {
      switch (operation) {
        case 'delete':
          await _rollbackDelete(entityType, previousStateStr, payload);
          break;
        case 'edit':
        case 'update':
          await _rollbackEdit(entityType, previousStateStr);
          break;
        case 'rename':
          await _rollbackRename(entityType, payload);
          break;
      }
      debugPrint('🏛️ DashboardSync: rollback completed for $entityType/$operation');
    } catch (e) {
      debugPrint('🏛️ DashboardSync: rollback failed — $e');
    }
  }

  Future<void> _rollbackDelete(String entityType, String previousState, Map<String, dynamic> payload) async {
    switch (entityType) {
      case 'student':
        final row = jsonDecode(previousState) as Map<String, dynamic>;
        row['sync_status'] = 'done';
        await _db.upsertStudentSection([row], row['section'] ?? '');
        break;
      case 'teacher':
        final row = jsonDecode(previousState) as Map<String, dynamic>;
        row['sync_status'] = 'done';
        final existing = await _db.getTeachers();
        existing.add(row);
        await _db.replaceTeachers(existing);
        break;
      case 'staff':
        final row = jsonDecode(previousState) as Map<String, dynamic>;
        row['sync_status'] = 'done';
        final existing = await _db.getStaff();
        existing.add(row);
        await _db.replaceStaff(existing);
        break;
      case 'section':
        final name = previousState;
        await _db.insertPendingStringItem('sections', name);
        break;
      case 'subject':
        final name = previousState;
        await _db.insertPendingStringItem('subjects', name);
        break;
      case 'role':
        final name = previousState;
        await _db.insertPendingStringItem('roles', name);
        break;
    }
  }

  Future<void> _rollbackEdit(String entityType, String previousState) async {
    switch (entityType) {
      case 'teacher':
        final row = jsonDecode(previousState) as Map<String, dynamic>;
        row['sync_status'] = 'done';
        final existing = await _db.getTeachers();
        final idx = existing.indexWhere((t) => '${t['server_id']}' == '${row['server_id']}' || '${t['local_id']}' == '${row['local_id']}');
        if (idx >= 0) existing[idx] = row;
        await _db.replaceTeachers(existing);
        break;
      case 'staff':
        final row = jsonDecode(previousState) as Map<String, dynamic>;
        row['sync_status'] = 'done';
        final existing = await _db.getStaff();
        final idx = existing.indexWhere((s) => '${s['server_id']}' == '${row['server_id']}' || '${s['local_id']}' == '${row['local_id']}');
        if (idx >= 0) existing[idx] = row;
        await _db.replaceStaff(existing);
        break;
      case 'student':
        final row = jsonDecode(previousState) as Map<String, dynamic>;
        row['sync_status'] = 'done';
        final existing = await _db.getStudents(sectionFilter: row['section']);
        final idx = existing.indexWhere((s) => '${s['server_id']}' == '${row['server_id']}' || '${s['local_id']}' == '${row['local_id']}');
        if (idx >= 0) existing[idx] = row;
        await _db.replaceStudents(existing);
        break;
    }
  }

  Future<void> _rollbackRename(String entityType, Map<String, dynamic> payload) async {
    final oldName = payload['old_name'] as String? ?? '';
    final newName = payload['new_name'] as String? ?? '';
    if (oldName.isEmpty || newName.isEmpty) return;

    final listType = entityType == 'section' ? 'sections' : entityType == 'subject' ? 'subjects' : 'roles';
    await _db.renameStringItem(listType, newName, oldName);
  }

  Future<void> _executeOp(String entityType, String operation, Map<String, dynamic> payload, String originalValue, String idempotencyKey) async {
    final headers = idempotencyKey.isNotEmpty ? {'X-Idempotency-Key': idempotencyKey} : null;
    switch (entityType) {
      case 'student':
        await _executeStudentOp(operation, payload, headers);
      case 'teacher':
        await _executeTeacherOp(operation, payload, headers);
      case 'staff':
        await _executeStaffOp(operation, payload, headers);
      case 'section_teacher':
        await _executeSectionTeacherOp(operation, payload, headers);
      case 'section':
        await _executeStringOp('section', operation, payload, headers);
      case 'subject':
        await _executeStringOp('subject', operation, payload, headers);
      case 'role':
        await _executeStringOp('role', operation, payload, headers);
    }
  }

  Future<void> _executeStudentOp(String operation, Map<String, dynamic> payload, Map<String, String>? headers) async {
    switch (operation) {
      case 'admit':
        final resp = await _api.admitStudent(payload, headers: headers);
        final student = resp['student'];
        if (student is Map<String, dynamic>) {
          await _db.upsertStudentFromServer(student);
          final localId = '${payload['local_id'] ?? ''}';
          if (localId.isNotEmpty) {
            await _db.markStudentDeleted('', localId);
          } else {
            await _db.markStudentDeleted('${student['id'] ?? ''}', '');
          }
        }
      case 'edit':
        await _api.editStudent('${payload['id'] ?? payload['server_id']}', payload, headers: headers);
        await _db.markStudentRowSynced('${payload['id'] ?? payload['server_id']}');
      case 'delete':
        final delId = '${payload['id'] ?? payload['server_id'] ?? ''}';
        try {
          await _api.deleteStudent('${payload['id'] ?? payload['server_id']}', headers: headers);
        } on DashboardApiException catch (e) {
          if (e.statusCode != 404) rethrow;
        }
        if (delId.isNotEmpty) await _db.deleteStudentById(delId);
    }
  }

  Future<void> _executeTeacherOp(String operation, Map<String, dynamic> payload, Map<String, String>? headers) async {
    switch (operation) {
      case 'hire':
        await _api.hireTeacher(payload, headers: headers);
      case 'update':
        await _api.updateTeacher('${payload['id'] ?? payload['server_id']}', payload, headers: headers);
        await _db.markTeacherRowSynced('${payload['id'] ?? payload['server_id']}');
      case 'delete':
        await _api.deleteTeacher('${payload['server_id'] ?? payload['id']}', headers: headers);
    }
  }

  Future<void> _executeStaffOp(String operation, Map<String, dynamic> payload, Map<String, String>? headers) async {
    switch (operation) {
      case 'hire':
        await _api.hireStaff(payload, headers: headers);
      case 'update':
        await _api.updateStaff('${payload['id'] ?? payload['server_id']}', payload, headers: headers);
        await _db.markStaffRowSynced('${payload['id'] ?? payload['server_id']}');
      case 'delete':
        await _api.deleteStaff('${payload['server_id'] ?? payload['id']}', headers: headers);
    }
  }

  Future<void> _executeSectionTeacherOp(String operation, Map<String, dynamic> payload, Map<String, String>? headers) async {
    final teacherId = '${payload['teacher_id'] ?? ''}';
    final section = '${payload['section_name'] ?? ''}';
    final subject = '${payload['subject_name'] ?? ''}';
    switch (operation) {
      case 'assign':
        await _api.assignTeacherToSection(teacherId, section, subject);
        await _db.insertSectionTeacher(section, teacherId, subject, syncStatus: 'done');
      case 'unassign':
        await _api.removeTeacherFromSection(section, teacherId, subject);
        await _db.deleteSectionTeacher(section, teacherId, subject);
    }
  }

  Future<void> _executeStringOp(String entityType, String operation, Map<String, dynamic> payload, Map<String, String>? headers) async {
    final oldName = payload['old_name'] ?? '';
    final newName = payload['new_name'] ?? '';
    final name = payload['name'] ?? '';

    switch (operation) {
      case 'rename':
        if (entityType == 'section') await _api.renameSection(oldName, newName, headers: headers);
        if (entityType == 'subject') await _api.renameSubject(oldName, newName, headers: headers);
        if (entityType == 'role') await _api.renameRole(oldName, newName, headers: headers);
        await _propagateRename(entityType, oldName, newName);
      case 'delete':
        try {
          if (entityType == 'section') await _api.deleteSection(name, headers: headers);
          if (entityType == 'subject') await _api.deleteSubject(name, headers: headers);
          if (entityType == 'role') await _api.deleteRole(name, headers: headers);
        } on DashboardApiException catch (e) {
          if (e.statusCode != 404) rethrow;
        }
    }
  }

  Future<void> _propagateRename(String entityType, String oldName, String newName) async {
    debugPrint('🏛️ DashboardSync: propagating rename $entityType: $oldName → $newName');
    await _db.renamePendingRefs(entityType, oldName, newName);
  }

  bool get isSyncing => _isSyncing;

  Future<void> forceSyncNow() async {
    if (UnifiedSocketService.isConnected()) {
      await syncPendingOps();
    }
  }
}
