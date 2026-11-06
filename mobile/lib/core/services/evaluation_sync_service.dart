import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../repositories/auth_session_storage.dart';
import '../repositories/local_evaluation_storage.dart';
import '../repositories/local_student_cache.dart';
import 'connection_errors.dart';

class EvaluationSyncResult {
  final bool success;
  final String message;
  final int sessionsSynced;
  final int detailsSynced;
  final double? porcentajeRiesgo;
  final String? semaforo;
  final int? nivelActualizado;
  final int? nivelLectura;
  final int? nivelFonologia;
  final String? cambioNivel;

  const EvaluationSyncResult({
    required this.success,
    required this.message,
    required this.sessionsSynced,
    required this.detailsSynced,
    this.porcentajeRiesgo,
    this.semaforo,
    this.nivelActualizado,
    this.nivelLectura,
    this.nivelFonologia,
    this.cambioNivel,
  });
}

class EvaluationSyncService {
  static const sessionRequiredMessage =
      'Las evaluaciones siguen guardadas. El docente o director debe '
      'iniciar sesión nuevamente para enviarlas.';
  final String baseUrl;

  const EvaluationSyncService({
    this.baseUrl = 'https://tesis-dislexia-app-production.up.railway.app',
  });

  Future<EvaluationSyncResult> syncPendingEvaluations() async {
    final payload = LocalEvaluationStorage.getPendingSyncPayload();

    final sessions = payload['sessions'] as List<Map<String, dynamic>>;

    if (sessions.isEmpty) {
      return const EvaluationSyncResult(
        success: true,
        message: 'No hay sesiones pendientes para sincronizar.',
        sessionsSynced: 0,
        detailsSynced: 0,
      );
    }

    try {
      await _checkBackendHealth();

      final token = AuthSessionStorage.getAccessTokenIfValid();
      if (token == null || token.trim().isEmpty) {
        throw const RequestFailure(sessionRequiredMessage, statusCode: 401);
      }
      final uri = Uri.parse('$baseUrl/api/v1/evaluaciones/sync');

      final response = await runNetworkRequest(
        () => http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 30)),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401) {
          if (AuthSessionStorage.getAccessTokenIfValid() == token) {
            await AuthSessionStorage.clearSession();
          }
          throw const RequestFailure(sessionRequiredMessage, statusCode: 401);
        }
        if (response.statusCode == 409) {
          throw const RequestFailure(
            'Las evaluaciones siguen guardadas. El docente debe revisar '
            'el estado, consentimiento y posibles conflictos antes de enviarlas.',
            statusCode: 409,
          );
        }
        throw httpRequestFailure(
          response.statusCode,
          fallbackMessage:
              'No se pudieron enviar las evaluaciones. Vuelva a intentarlo.',
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Confirmación de sincronización inválida.');
      }
      final sessionsByLocalId = <String, Map<String, dynamic>>{
        for (final session in sessions)
          if (session['local_session_id'] != null)
            session['local_session_id'].toString(): session,
      };
      final details = payload['details'] as List<Map<String, dynamic>>;
      final confirmed = _validateAcknowledgements(
        decoded,
        sessionsByLocalId,
        details,
      );
      final syncedSessionIds = <String>[];
      var detailsConfirmed = 0;
      for (final item in confirmed) {
        final localSessionId = item['local_session_id'] as String;
        syncedSessionIds.add(localSessionId);
        detailsConfirmed += item['details_confirmed'] as int;
        final sourceSession = sessionsByLocalId[localSessionId];
        final studentId = _asNullableInt(sourceSession?['estudiante_id']);
        if (studentId != null) {
          await LocalStudentCache.updateStudentLevelsById(
            studentId: studentId,
            nivelLectura: _asNullableInt(item['nivel_lectura']),
            nivelFonologia: _asNullableInt(item['nivel_fonologia']),
          );
        }
      }
      await LocalEvaluationStorage.markSessionsAsSynced(syncedSessionIds);
      final lastSyncedItem = confirmed.last;
      final sessionsConfirmed = syncedSessionIds.length;
      final complete = sessionsConfirmed == sessions.length;
      if (!complete) {
        return EvaluationSyncResult(
          success: false,
          message:
              'Se confirmaron $sessionsConfirmed evaluaciones. '
              'Las demás siguen guardadas y pendientes de envío.',
          sessionsSynced: sessionsConfirmed,
          detailsSynced: detailsConfirmed,
        );
      }

      final porcentajeRiesgo = _asDouble(lastSyncedItem['porcentaje_riesgo']);
      final semaforo = lastSyncedItem['semaforo']?.toString();
      final nivelActualizado = _asNullableInt(
        lastSyncedItem['nivel_actualizado'],
      );
      final nivelLectura = _asNullableInt(lastSyncedItem['nivel_lectura']);
      final nivelFonologia = _asNullableInt(lastSyncedItem['nivel_fonologia']);
      final cambioNivel = lastSyncedItem['cambio_nivel']?.toString();

      final riskText = porcentajeRiesgo == null || semaforo == null
          ? ''
          : ' Riesgo: ${porcentajeRiesgo.toStringAsFixed(2)}%. Semáforo: $semaforo.';

      return EvaluationSyncResult(
        success: true,
        message:
            'Sincronización exitosa. Sesiones: $sessionsConfirmed. Detalles: $detailsConfirmed.$riskText',
        sessionsSynced: sessionsConfirmed,
        detailsSynced: detailsConfirmed,
        porcentajeRiesgo: porcentajeRiesgo,
        semaforo: semaforo,
        nivelActualizado: nivelActualizado,
        nivelLectura: nivelLectura,
        nivelFonologia: nivelFonologia,
        cambioNivel: cambioNivel,
      );
    } catch (error, stackTrace) {
      logRequestFailure('Sincronizar evaluaciones', error, stackTrace);
      return EvaluationSyncResult(
        success: false,
        message: requestErrorMessage(
          error,
          fallbackMessage:
              'No se pudo sincronizar. Las evaluaciones permanecen guardadas '
              'en el dispositivo. Vuelva a intentarlo.',
        ),
        sessionsSynced: 0,
        detailsSynced: 0,
      );
    }
  }

  List<Map<String, dynamic>> _validateAcknowledgements(
    Map<String, dynamic> response,
    Map<String, Map<String, dynamic>> sessions,
    List<Map<String, dynamic>> details,
  ) {
    final raw = response['synced'];
    if (response['status'] != 'ok' ||
        response['sessions_received'] is! int ||
        response['details_received'] is! int ||
        response['sessions_received'] != sessions.length ||
        response['details_received'] != details.length ||
        raw is! List ||
        raw.isEmpty) {
      throw const FormatException(
        'Falta una confirmación válida del servidor.',
      );
    }
    final confirmed = <Map<String, dynamic>>[];
    final ids = <String>{};
    final evaluationIds = <int>{};
    var insertedDetails = 0;
    for (final item in raw) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Confirmación inválida.');
      }
      final id = item['local_session_id'];
      final evaluationId = item['evaluacion_id'];
      final count = item['details_confirmed'];
      final inserted = item['details_inserted'];
      if (id is! String ||
          !sessions.containsKey(id) ||
          !ids.add(id) ||
          evaluationId is! int ||
          evaluationId <= 0 ||
          !evaluationIds.add(evaluationId) ||
          count is! int ||
          count <= 0 ||
          count != sessions[id]?['total_items'] ||
          count !=
              details
                  .where((detail) => detail['local_session_id'] == id)
                  .length ||
          inserted is! int ||
          inserted < 0 ||
          inserted > count) {
        throw const FormatException('La confirmación no corresponde al envío.');
      }
      for (final key in [
        'nivel_lectura',
        'nivel_fonologia',
        'nivel_actualizado',
      ]) {
        final value = item[key];
        if (value != null && (value is! int || value < 1 || value > 3)) {
          throw const FormatException('Nivel confirmado inválido.');
        }
      }
      insertedDetails += inserted;
      confirmed.add(item);
    }
    final insertedSessions = response['evaluations_inserted'];
    if (insertedSessions is! int ||
        insertedSessions < 0 ||
        insertedSessions > confirmed.length ||
        response['details_inserted'] is! int ||
        response['details_inserted'] != insertedDetails) {
      throw const FormatException(
        'Los totales confirmados son inconsistentes.',
      );
    }
    return confirmed;
  }

  Future<void> _checkBackendHealth() async {
    final uri = Uri.parse('$baseUrl/health');
    final response = await runNetworkRequest(
      () => http.get(uri).timeout(const Duration(seconds: 5)),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RequestFailure(
        serverUnavailableMessage,
        statusCode: response.statusCode,
      );
    }
  }

  int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value.toString());
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString());
  }
}
