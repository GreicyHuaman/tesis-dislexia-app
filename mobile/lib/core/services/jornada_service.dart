import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/jornada_evaluacion.dart';

class JornadaService {
  final String baseUrl;

  const JornadaService({
    this.baseUrl = 'https://tesis-dislexia-app-production.up.railway.app',
  });

  Future<JornadaEvaluacion> activarJornada({
    required String? authToken,
    required int seccionId,
    bool pruebaLecturaActiva = true,
    bool pruebaFonologiaActiva = true,
    int duracionHoras = 8,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/jornadas-evaluacion/activar');

    final response = await http
        .post(
          uri,
          headers: _headers(authToken),
          body: jsonEncode({
            'seccion_id': seccionId,
            'prueba_lectura_activa': pruebaLecturaActiva,
            'prueba_fonologia_activa': pruebaFonologiaActiva,
            'duracion_horas': duracionHoras,
          }),
        )
        .timeout(const Duration(seconds: 15));

    _ensureSuccess(response);

    return JornadaEvaluacion.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<JornadaEvaluacion> obtenerJornadaActiva({
    required String? authToken,
    required int seccionId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/jornadas-evaluacion/activa/$seccionId',
    );

    final response = await http
        .get(uri, headers: _headers(authToken))
        .timeout(const Duration(seconds: 15));

    _ensureSuccess(response);

    return JornadaEvaluacion.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<JornadaEvaluacion> cerrarJornada({
    required String? authToken,
    required int jornadaId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/jornadas-evaluacion/$jornadaId/cerrar',
    );

    final response = await http
        .patch(uri, headers: _headers(authToken))
        .timeout(const Duration(seconds: 15));

    _ensureSuccess(response);

    return JornadaEvaluacion.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Map<String, String> _headers(String? authToken) {
    final token = authToken?.trim();

    if (token == null || token.isEmpty) {
      throw Exception('No existe token de sesion academica.');
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = 'Error HTTP ${response.statusCode}.';

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is Map && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
    } catch (_) {
      // Mantener mensaje generico.
    }

    throw Exception(message);
  }
}
