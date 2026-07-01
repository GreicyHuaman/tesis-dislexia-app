import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../repositories/local_evaluation_storage.dart';
import '../repositories/local_student_cache.dart';

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
      final healthOk = await _checkBackendHealth();

      if (!healthOk) {
        return const EvaluationSyncResult(
          success: false,
          message:
              'El backend no está disponible. Verifica Docker y /health en https://tesis-dislexia-app-production.up.railway.app/health.',
          sessionsSynced: 0,
          detailsSynced: 0,
        );
      }

      final uri = Uri.parse('$baseUrl/api/v1/evaluaciones/sync');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return EvaluationSyncResult(
          success: false,
          message:
              'Error del servidor: ${response.statusCode}. ${response.body}',
          sessionsSynced: 0,
          detailsSynced: 0,
        );
      }

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final syncedRaw = decoded['synced'];
      final sessionsByLocalId = <String, Map<String, dynamic>>{
        for (final session in sessions)
          if (session['local_session_id'] != null)
            session['local_session_id'].toString(): session,
      };

      final syncedSessionIds = <String>[];
      Map<dynamic, dynamic>? lastSyncedItem;

      if (syncedRaw is List) {
        for (final item in syncedRaw) {
          if (item is Map) {
            lastSyncedItem = item;

            final localSessionId = item['local_session_id']?.toString();

            if (localSessionId != null && localSessionId.isNotEmpty) {
              syncedSessionIds.add(localSessionId);
            }

            final sourceSession = localSessionId == null
                ? null
                : sessionsByLocalId[localSessionId];

            final studentId = _asNullableInt(sourceSession?['estudiante_id']);

            if (studentId != null) {
              await LocalStudentCache.updateStudentLevelsById(
                studentId: studentId,
                nivelLectura: _asNullableInt(item['nivel_lectura']),
                nivelFonologia: _asNullableInt(item['nivel_fonologia']),
              );
            }
          }
        }
      }

      if (syncedSessionIds.isEmpty) {
        syncedSessionIds.addAll(
          sessions
              .map((session) => session['local_session_id']?.toString())
              .whereType<String>(),
        );
      }

      await LocalEvaluationStorage.markSessionsAsSynced(syncedSessionIds);

      final sessionsInserted = _asInt(decoded['evaluations_inserted']);
      final detailsInserted = _asInt(decoded['details_inserted']);

      final porcentajeRiesgo = _asDouble(lastSyncedItem?['porcentaje_riesgo']);
      final semaforo = lastSyncedItem?['semaforo']?.toString();
      final nivelActualizado = _asNullableInt(
        lastSyncedItem?['nivel_actualizado'],
      );
      final nivelLectura = _asNullableInt(lastSyncedItem?['nivel_lectura']);
      final nivelFonologia = _asNullableInt(lastSyncedItem?['nivel_fonologia']);
      final cambioNivel = lastSyncedItem?['cambio_nivel']?.toString();

      final riskText = porcentajeRiesgo == null || semaforo == null
          ? ''
          : ' Riesgo: ${porcentajeRiesgo.toStringAsFixed(2)}%. Semáforo: $semaforo.';

      return EvaluationSyncResult(
        success: true,
        message:
            'Sincronización exitosa. Sesiones: $sessionsInserted. Detalles: $detailsInserted.$riskText',
        sessionsSynced: sessionsInserted,
        detailsSynced: detailsInserted,
        porcentajeRiesgo: porcentajeRiesgo,
        semaforo: semaforo,
        nivelActualizado: nivelActualizado,
        nivelLectura: nivelLectura,
        nivelFonologia: nivelFonologia,
        cambioNivel: cambioNivel,
      );
    } on TimeoutException {
      return const EvaluationSyncResult(
        success: false,
        message:
            'Tiempo de espera agotado. El backend no respondió dentro del tiempo límite.',
        sessionsSynced: 0,
        detailsSynced: 0,
      );
    } catch (error) {
      return EvaluationSyncResult(
        success: false,
        message: 'Error sincronizando: $error',
        sessionsSynced: 0,
        detailsSynced: 0,
      );
    }
  }

  Future<bool> _checkBackendHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/health');

      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
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
