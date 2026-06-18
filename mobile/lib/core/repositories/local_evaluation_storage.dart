import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/local_evaluation_detail.dart';

class LocalEvaluationStorage {
  static const String _sessionsBoxName = 'evaluation_sessions';
  static const String _detailsBoxName = 'evaluation_details';

  static const Uuid _uuid = Uuid();

  static Future<void> init() async {
    await Hive.openBox(_sessionsBoxName);
    await Hive.openBox(_detailsBoxName);
  }

  static Box get _sessionsBox => Hive.box(_sessionsBoxName);

  static Box get _detailsBox => Hive.box(_detailsBoxName);

  static String generateId() {
    return _uuid.v4();
  }

  static Future<String> createSession({
    required String tipoPrueba,
    required int totalItems,
    int? estudianteId,
  }) async {
    final sessionId = generateId();
    final now = DateTime.now().toUtc().toIso8601String();

    final session = {
      'local_session_id': sessionId,
      'estudiante_id': estudianteId,
      'tipo_prueba': tipoPrueba,
      'fecha_inicio': now,
      'fecha_fin': null,
      'total_items': totalItems,
      'aciertos_primer_intento': 0,
      'taps_erroneos_totales': 0,
      'tiempo_promedio_ms': 0,
      'sync_status': 'PENDING',
      'created_at': now,
      'updated_at': now,
    };

    await _sessionsBox.put(sessionId, session);

    return sessionId;
  }

  static Future<String> saveDetail({
    required String localSessionId,
    required LocalEvaluationDetail detail,
  }) async {
    final detailId = generateId();
    final now = DateTime.now().toUtc().toIso8601String();

    final payload = {
      'local_detail_id': detailId,
      'local_session_id': localSessionId,
      ...detail.toJson(),
      'sync_status': 'PENDING',
      'created_at': now,
      'updated_at': now,
    };

    await _detailsBox.put(detailId, payload);

    return detailId;
  }

  static Future<void> finishSession({
    required String localSessionId,
    required int totalItems,
    required int aciertosPrimerIntento,
    required int tapsErroneosTotales,
    required int tiempoPromedioMs,
  }) async {
    final currentValue = _sessionsBox.get(localSessionId);
    final currentSession = _asStringMap(currentValue);

    if (currentSession.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();

    final updatedSession = {
      ...currentSession,
      'fecha_fin': now,
      'total_items': totalItems,
      'aciertos_primer_intento': aciertosPrimerIntento,
      'taps_erroneos_totales': tapsErroneosTotales,
      'tiempo_promedio_ms': tiempoPromedioMs,
      'sync_status': 'COMPLETED_PENDING_SYNC',
      'updated_at': now,
    };

    await _sessionsBox.put(localSessionId, updatedSession);
  }

  static List<Map<String, dynamic>> getAllSessions() {
    return _sessionsBox.values
        .map(_asStringMap)
        .where((session) => session.isNotEmpty)
        .toList();
  }

  static List<Map<String, dynamic>> getAllDetails() {
    return _detailsBox.values
        .map(_asStringMap)
        .where((detail) => detail.isNotEmpty)
        .toList();
  }

  static List<Map<String, dynamic>> getDetailsBySession(String localSessionId) {
    return getAllDetails()
        .where((detail) => detail['local_session_id'] == localSessionId)
        .toList();
  }

  static int countPendingSessions() {
    return getAllSessions()
        .where(
          (session) =>
              session['sync_status'] == 'PENDING' ||
              session['sync_status'] == 'COMPLETED_PENDING_SYNC',
        )
        .length;
  }

  static int countCompletedPendingSyncSessions() {
    return getAllSessions()
        .where(
          (session) => session['sync_status'] == 'COMPLETED_PENDING_SYNC',
        )
        .length;
  }

  static Map<String, dynamic> getPendingSyncPayload() {
    final pendingSessions = getAllSessions()
        .where(
          (session) => session['sync_status'] == 'COMPLETED_PENDING_SYNC',
        )
        .toList();

    final pendingSessionIds = pendingSessions
        .map((session) => session['local_session_id']?.toString())
        .whereType<String>()
        .toSet();

    final pendingDetails = getAllDetails()
        .where(
          (detail) =>
              pendingSessionIds.contains(
                detail['local_session_id']?.toString(),
              ) &&
              detail['sync_status'] == 'PENDING',
        )
        .toList();

    return {
      'sessions': pendingSessions,
      'details': pendingDetails,
    };
  }

  static Future<void> markSessionsAsSynced(
    List<String> localSessionIds,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final ids = localSessionIds.toSet();

    for (final sessionId in ids) {
      final currentValue = _sessionsBox.get(sessionId);
      final currentSession = _asStringMap(currentValue);

      if (currentSession.isEmpty) {
        continue;
      }

      await _sessionsBox.put(sessionId, {
        ...currentSession,
        'sync_status': 'SYNCED',
        'synced_at': now,
        'updated_at': now,
      });
    }

    for (final key in _detailsBox.keys) {
      final currentValue = _detailsBox.get(key);
      final currentDetail = _asStringMap(currentValue);

      if (currentDetail.isEmpty) {
        continue;
      }

      final localSessionId = currentDetail['local_session_id']?.toString();

      if (!ids.contains(localSessionId)) {
        continue;
      }

      await _detailsBox.put(key, {
        ...currentDetail,
        'sync_status': 'SYNCED',
        'synced_at': now,
        'updated_at': now,
      });
    }
  }

  static String exportDebugJson() {
    final data = {
      'sessions': getAllSessions(),
      'details': getAllDetails(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static Future<void> clearAllLocalDataForDevelopment() async {
    await _sessionsBox.clear();
    await _detailsBox.clear();
  }

  static Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
      );
    }

    return {};
  }
}
