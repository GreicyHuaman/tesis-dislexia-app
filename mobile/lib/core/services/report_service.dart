import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/report_models.dart';

class ReportFilters {
  final String? tipoPrueba;
  final String? semaforo;
  final int? estudianteId;

  const ReportFilters({
    this.tipoPrueba,
    this.semaforo,
    this.estudianteId,
  });

  bool get hasFilters {
    return tipoPrueba != null ||
        semaforo != null ||
        estudianteId != null;
  }

  Map<String, String> toQueryParameters({
    int? usuarioId,
  }) {
    final params = <String, String>{};

    if (usuarioId != null) {
      params['usuario_id'] = usuarioId.toString();
    }

    if (tipoPrueba != null && tipoPrueba!.trim().isNotEmpty) {
      params['tipo_prueba'] = tipoPrueba!.trim().toUpperCase();
    }

    if (semaforo != null && semaforo!.trim().isNotEmpty) {
      params['semaforo'] = semaforo!.trim().toUpperCase();
    }

    if (estudianteId != null) {
      params['estudiante_id'] = estudianteId.toString();
    }

    return params;
  }
}

class ReportService {
  final String baseUrl;

  const ReportService({
    this.baseUrl = 'http://127.0.0.1:8000',
  });

  Uri buildEvaluacionesCsvUri({
    int? usuarioId,
    ReportFilters filters = const ReportFilters(),
  }) {
    return Uri.parse('$baseUrl/api/v1/reportes/evaluaciones.csv')
        .replace(
      queryParameters: filters.toQueryParameters(
        usuarioId: usuarioId,
      ),
    );
  }

  Future<ReportSummary> fetchResumenSemaforo({
    int? usuarioId,
    ReportFilters filters = const ReportFilters(),
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/reportes/resumen-semaforo')
        .replace(
      queryParameters: filters.toQueryParameters(
        usuarioId: usuarioId,
      ),
    );

    final response = await http.get(uri).timeout(
          const Duration(seconds: 15),
        );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Error cargando resumen: ${response.statusCode}. ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    return ReportSummary.fromJson(decoded);
  }

  Future<StudentRiskProfile> fetchStudentRiskProfile({
    required int estudianteId,
    int? usuarioId,
  }) async {
    final params = <String, String>{};

    if (usuarioId != null) {
      params['usuario_id'] = usuarioId.toString();
    }

    final uri = Uri.parse(
      '$baseUrl/api/v1/reportes/estudiantes/$estudianteId/perfil-riesgo',
    ).replace(
      queryParameters: params,
    );

    final response = await http.get(uri).timeout(
          const Duration(seconds: 15),
        );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Error cargando perfil del estudiante: ${response.statusCode}. ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    return StudentRiskProfile.fromJson(decoded);
  }

  Future<List<EvaluationReportItem>> fetchEvaluaciones({
    int? usuarioId,
    ReportFilters filters = const ReportFilters(),
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/reportes/evaluaciones')
        .replace(
      queryParameters: filters.toQueryParameters(
        usuarioId: usuarioId,
      ),
    );

    final response = await http.get(uri).timeout(
          const Duration(seconds: 15),
        );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Error cargando evaluaciones: ${response.statusCode}. ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      throw Exception('Formato inesperado de evaluaciones.');
    }

    final items = <EvaluationReportItem>[];

    for (final item in decoded) {
      if (item is Map) {
        items.add(
          EvaluationReportItem.fromJson(
            Map<String, dynamic>.from(item),
          ),
        );
      }
    }

    return items;
  }
}

