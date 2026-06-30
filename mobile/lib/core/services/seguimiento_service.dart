import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/seguimiento_models.dart';

class SeguimientoService {
  final String baseUrl;

  const SeguimientoService({
    this.baseUrl = 'https://tesis-dislexia-app-production.up.railway.app',
  });

  Future<SeguimientoResumen> fetchResumen({required String? authToken}) async {
    final uri = Uri.parse('$baseUrl/api/v1/seguimiento/resumen');

    final response = await http
        .get(uri, headers: _headers(authToken))
        .timeout(const Duration(seconds: 15));

    _ensureSuccess(response);

    return SeguimientoResumen.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<SeguimientoItem>> fetchPriorizados({
    required String? authToken,
    String? prioridad,
    String? estadoSemanal,
  }) async {
    final query = <String, String>{};

    if (prioridad != null && prioridad.trim().isNotEmpty) {
      query['prioridad'] = prioridad.trim().toUpperCase();
    }

    if (estadoSemanal != null && estadoSemanal.trim().isNotEmpty) {
      query['estado_semanal'] = estadoSemanal.trim().toUpperCase();
    }

    final uri = Uri.parse(
      '$baseUrl/api/v1/seguimiento/priorizados',
    ).replace(queryParameters: query.isEmpty ? null : query);

    final response = await http
        .get(uri, headers: _headers(authToken))
        .timeout(const Duration(seconds: 15));

    _ensureSuccess(response);

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      return [];
    }

    return decoded
        .whereType<Map>()
        .map(
          (item) => SeguimientoItem.fromJson(
            item.map((key, dynamic value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  Future<SeguimientoHistorial> fetchHistorial({
    required String? authToken,
    required int estudianteId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/seguimiento/estudiante/$estudianteId',
    );

    final response = await http
        .get(uri, headers: _headers(authToken))
        .timeout(const Duration(seconds: 15));

    _ensureSuccess(response);

    return SeguimientoHistorial.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> createObservacion({
    required String? authToken,
    required int estudianteId,
    int? evaluacionId,
    required String observacionDocente,
    required List<String> categorias,
    String estado = 'ABIERTO',
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/seguimiento/observaciones');

    final body = <String, dynamic>{
      'estudiante_id': estudianteId,
      'evaluacion_id': evaluacionId,
      'observacion_docente': observacionDocente.trim().isEmpty
          ? null
          : observacionDocente.trim(),
      'categorias': categorias,
      'estado': estado.trim().toUpperCase(),
    };

    final response = await http
        .post(
          uri,
          headers: {..._headers(authToken), 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    _ensureSuccess(response);
  }

  Map<String, String> _headers(String? authToken) {
    final token = authToken?.trim();

    if (token == null || token.isEmpty) {
      throw Exception('No existe token de sesion academica.');
    }

    return {'Accept': 'application/json', 'Authorization': 'Bearer $token'};
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = 'Error HTTP ${response.statusCode}.';

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
    } catch (_) {
      // Mantener mensaje generico.
    }

    throw Exception(message);
  }
}
