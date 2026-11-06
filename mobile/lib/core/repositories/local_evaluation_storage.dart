import 'dart:convert';
import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/local_evaluation_detail.dart';
import '../models/local_assessment_progress.dart';

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
    int? nivelDificultadAplicado,
    int totalBaja = 0,
    int totalMedia = 0,
    int totalAlta = 0,
    String? versionBancoPalabras,
    List<Map<String, dynamic>>? assessmentItems,
    List<List<String>>? assessmentOptions,
  }) async {
    if (assessmentItems != null) {
      if (estudianteId == null ||
          assessmentItems.length != totalItems ||
          totalItems <= 0 ||
          assessmentOptions == null ||
          assessmentOptions.length != totalItems) {
        throw ArgumentError('El plan de evaluación está incompleto.');
      }
      final existing = getIncompleteAssessment(
        estudianteId: estudianteId,
        tipoPrueba: tipoPrueba,
      );
      if (existing != null) return existing.sessionId;
    }
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
      'nivel_dificultad_aplicado': nivelDificultadAplicado,
      'total_baja': totalBaja,
      'total_media': totalMedia,
      'total_alta': totalAlta,
      'version_banco_palabras': versionBancoPalabras,
      'sync_status': 'PENDING',
      'created_at': now,
      'updated_at': now,
      if (assessmentItems != null) ...{
        'assessment_plan': {
          'version': 1,
          'items': assessmentItems,
          'options': assessmentOptions,
        },
        'answered_items': <Map<String, dynamic>>[],
        'current_item_state': {'index': 0, 'errors': 0, 'elapsed_ms': 0},
      },
    };

    if (assessmentItems != null) _readAssessment(session);
    await _sessionsBox.put(sessionId, session);
    await _sessionsBox.flush();

    return sessionId;
  }

  static Future<String> saveDetail({
    required String localSessionId,
    required LocalEvaluationDetail detail,
    int? itemIndex,
  }) async {
    final detailId = itemIndex == null
        ? generateId()
        : '$localSessionId:$itemIndex';
    if (itemIndex != null && _detailsBox.containsKey(detailId)) return detailId;
    final now = DateTime.now().toUtc().toIso8601String();

    final payload = {
      'local_detail_id': detailId,
      'local_session_id': localSessionId,
      ...detail.toJson(),
      'sync_status': 'PENDING',
      'created_at': now,
      'updated_at': now,
      'item_index': ?itemIndex,
    };

    await _detailsBox.put(detailId, payload);
    await _detailsBox.flush();

    return detailId;
  }

  static LocalAssessmentProgress? getIncompleteAssessment({
    required int estudianteId,
    required String tipoPrueba,
  }) {
    final candidates =
        getAllSessions()
            .where(
              (session) =>
                  session['estudiante_id'] == estudianteId &&
                  session['tipo_prueba'] == tipoPrueba &&
                  session['sync_status'] == 'PENDING' &&
                  session.containsKey('assessment_plan'),
            )
            .toList()
          ..sort(
            (a, b) => a['created_at'].toString().compareTo(
              b['created_at'].toString(),
            ),
          );
    return candidates.isEmpty ? null : _readAssessment(candidates.first);
  }

  static int countLegacyIncomplete({
    required int estudianteId,
    required String tipoPrueba,
  }) => getAllSessions()
      .where(
        (session) =>
            session['estudiante_id'] == estudianteId &&
            session['tipo_prueba'] == tipoPrueba &&
            session['sync_status'] == 'PENDING' &&
            !session.containsKey('assessment_plan'),
      )
      .length;

  static LocalAssessmentProgress getAssessment(String sessionId) {
    return _readAssessment(_asStringMap(_sessionsBox.get(sessionId)));
  }

  static Future<void> restoreAssessmentDetails(String sessionId) async {
    final progress = getAssessment(sessionId);
    for (var index = 0; index < progress.answers.length; index++) {
      await saveDetail(
        localSessionId: sessionId,
        detail: progress.answers[index],
        itemIndex: index,
      );
    }
  }

  static Future<LocalAssessmentProgress> saveAssessmentAnswer({
    required String sessionId,
    required int itemIndex,
    required LocalEvaluationDetail detail,
  }) async {
    final session = _asStringMap(_sessionsBox.get(sessionId));
    final progress = _readAssessment(session);
    if (session['sync_status'] != 'PENDING' ||
        itemIndex < 0 ||
        itemIndex >= progress.totalItems ||
        itemIndex > progress.answeredItems ||
        detail.stimulusId != progress.items[itemIndex]['id'] ||
        detail.tipoPrueba != progress.tipoPrueba) {
      throw StateError('La respuesta no corresponde al ítem pendiente.');
    }
    if (itemIndex == progress.answeredItems) {
      final answers = [...progress.answers, detail];
      await _sessionsBox.put(sessionId, {
        ...session,
        'answered_items': answers.map((answer) => answer.toJson()).toList(),
        'current_item_state': {
          'index': answers.length,
          'errors': 0,
          'elapsed_ms': 0,
        },
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _sessionsBox.flush();
    }
    final saved = getAssessment(sessionId);
    await saveDetail(
      localSessionId: sessionId,
      detail: saved.answers[itemIndex],
      itemIndex: itemIndex,
    );
    return saved;
  }

  static Future<bool> saveCurrentItemState({
    required String sessionId,
    required int itemIndex,
    required int errors,
    required int elapsedMs,
  }) async {
    if (errors < 0 || elapsedMs < 0) {
      throw ArgumentError('Los intentos y el tiempo no pueden ser negativos.');
    }
    final session = _asStringMap(_sessionsBox.get(sessionId));
    final progress = _readAssessment(session);
    // Una escritura del ítem anterior no debe sobrescribir una respuesta guardada.
    if (session['sync_status'] != 'PENDING' ||
        itemIndex != progress.answeredItems ||
        progress.remainingItems == 0) {
      return false;
    }
    await _sessionsBox.put(sessionId, {
      ...session,
      'current_item_state': {
        'index': itemIndex,
        'errors': max(errors, progress.currentErrors),
        'elapsed_ms': max(elapsedMs, progress.currentElapsedMs),
      },
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _sessionsBox.flush();
    return true;
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
      throw StateError('No se encontró la sesión local.');
    }
    if (currentSession['sync_status'] == 'COMPLETED_PENDING_SYNC' ||
        currentSession['sync_status'] == 'SYNCED') {
      return;
    }
    final expected = currentSession['total_items'];
    final hasPlan = currentSession.containsKey('assessment_plan');
    final count = hasPlan
        ? _readAssessment(currentSession).answeredItems
        : getDetailsBySession(localSessionId).length;
    if (expected is! int ||
        expected <= 0 ||
        totalItems != expected ||
        count != expected) {
      throw StateError('La evaluación tiene respuestas pendientes.');
    }
    if (hasPlan) {
      await restoreAssessmentDetails(localSessionId);
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
    await _sessionsBox.flush();
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
        .where((session) => session['sync_status'] == 'COMPLETED_PENDING_SYNC')
        .length;
  }

  static Map<String, dynamic> getPendingSyncPayload() {
    final pendingSessions = getAllSessions()
        .where((session) => session['sync_status'] == 'COMPLETED_PENDING_SYNC')
        .map(
          (session) => Map<String, dynamic>.from(session)
            ..remove('assessment_plan')
            ..remove('answered_items')
            ..remove('current_item_state'),
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
        .map(
          (detail) => Map<String, dynamic>.from(detail)..remove('item_index'),
        )
        .toList();

    return {'sessions': pendingSessions, 'details': pendingDetails};
  }

  static Future<void> markSessionsAsSynced(List<String> localSessionIds) async {
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
    await _sessionsBox.flush();
    await _detailsBox.flush();
  }

  static String exportDebugJson() {
    final data = {'sessions': getAllSessions(), 'details': getAllDetails()};

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

  static LocalAssessmentProgress _readAssessment(Map<String, dynamic> session) {
    final plan = _asStringMap(session['assessment_plan']);
    final rawItems = plan['items'];
    final rawOptions = plan['options'];
    final rawAnswers = session['answered_items'];
    final sessionId = session['local_session_id'];
    final studentId = session['estudiante_id'];
    final tipo = session['tipo_prueba'];
    final level = session['nivel_dificultad_aplicado'];
    if (plan['version'] != 1 ||
        rawItems is! List ||
        rawOptions is! List ||
        rawAnswers is! List ||
        sessionId is! String ||
        studentId is! int ||
        studentId <= 0 ||
        tipo is! String ||
        !{'LECTURA', 'FONOLOGIA'}.contains(tipo) ||
        level is! int ||
        level < 1 ||
        level > 3 ||
        rawItems.isEmpty ||
        rawItems.length != session['total_items'] ||
        rawOptions.length != rawItems.length ||
        rawAnswers.length > rawItems.length) {
      throw const FormatException('El progreso local no se puede recuperar.');
    }
    final items = <Map<String, dynamic>>[];
    final options = <List<String>>[];
    final ids = <String>{};
    for (var index = 0; index < rawItems.length; index++) {
      final item = _asStringMap(rawItems[index]);
      final id = item['id'];
      final choices = rawOptions[index];
      final target = tipo == 'LECTURA'
          ? item['texto']
          : item['silaba_objetivo'];
      if (id is! String ||
          id.isEmpty ||
          !ids.add(id) ||
          item['tipo_prueba'] != tipo ||
          choices is! List ||
          choices.length < 3 ||
          choices.toSet().length != choices.length ||
          target is! String ||
          target.trim().isEmpty ||
          !choices.contains(target) ||
          (tipo == 'FONOLOGIA' &&
              (item['palabra'] is! String ||
                  item['palabra'].toString().trim().isEmpty)) ||
          choices.any((choice) => choice is! String || choice.trim().isEmpty)) {
        throw const FormatException('El plan local contiene ítems inválidos.');
      }
      items.add(item);
      options.add(choices.cast<String>().toList());
    }
    final answers = rawAnswers
        .map((answer) => LocalEvaluationDetail.fromJson(_asStringMap(answer)))
        .toList();
    for (var index = 0; index < answers.length; index++) {
      if (answers[index].stimulusId != items[index]['id'] ||
          answers[index].tipoPrueba != tipo) {
        throw const FormatException('Las respuestas no coinciden con el plan.');
      }
    }
    final state = _asStringMap(session['current_item_state']);
    final errors = state['errors'];
    final elapsed = state['elapsed_ms'];
    if (state['index'] != answers.length ||
        errors is! int ||
        errors < 0 ||
        elapsed is! int ||
        elapsed < 0) {
      throw const FormatException('El estado del ítem pendiente es inválido.');
    }
    return LocalAssessmentProgress(
      sessionId: sessionId,
      estudianteId: studentId,
      tipoPrueba: tipo,
      nivelAplicado: level,
      items: items,
      options: options,
      answers: answers,
      currentErrors: errors,
      currentElapsedMs: elapsed,
    );
  }
}
