import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/report_models.dart';

class ReportFilters {
  final String? tipoPrueba;
  final String? semaforo;
  final int? estudianteId;

  const ReportFilters({this.tipoPrueba, this.semaforo, this.estudianteId});

  bool get hasFilters {
    return tipoPrueba != null || semaforo != null || estudianteId != null;
  }

  Map<String, String> toQueryParameters() {
    final params = <String, String>{};

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

class ReportCsvDownloadResult {
  final String filename;
  final List<int> bytes;

  const ReportCsvDownloadResult({required this.filename, required this.bytes});
}

class ReportService {
  final String baseUrl;

  const ReportService({
    this.baseUrl = 'https://tesis-dislexia-app-production.up.railway.app',
  });

  Future<ReportSummary> fetchResumenSemaforo({
    String? authToken,
    ReportFilters filters = const ReportFilters(),
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/reportes/resumen-semaforo',
    ).replace(queryParameters: filters.toQueryParameters());

    final response = await http
        .get(
          uri,
          headers: _headers(authToken: authToken, accept: 'application/json'),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Error cargando resumen: ${response.statusCode}. ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    return ReportSummary.fromJson(decoded);
  }

  Future<List<EvaluationReportItem>> fetchEvaluaciones({
    String? authToken,
    ReportFilters filters = const ReportFilters(),
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/reportes/evaluaciones',
    ).replace(queryParameters: filters.toQueryParameters());

    final response = await http
        .get(
          uri,
          headers: _headers(authToken: authToken, accept: 'application/json'),
        )
        .timeout(const Duration(seconds: 15));

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
          EvaluationReportItem.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }

    return items;
  }

  Future<StudentRiskProfile> fetchStudentRiskProfile({
    required int estudianteId,
    String? authToken,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/v1/reportes/estudiantes/$estudianteId/perfil-riesgo',
    );

    final response = await http
        .get(
          uri,
          headers: _headers(authToken: authToken, accept: 'application/json'),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Error cargando perfil del estudiante: ${response.statusCode}. ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    return StudentRiskProfile.fromJson(decoded);
  }

  Future<ReportCsvDownloadResult> downloadEvaluacionesCsv({
    String? authToken,
    ReportFilters filters = const ReportFilters(),
  }) async {
    final cleanToken = authToken?.trim();

    if (cleanToken == null || cleanToken.isEmpty) {
      throw Exception('No hay token de autenticación para exportar CSV.');
    }

    final uri = Uri.parse(
      '$baseUrl/api/v1/reportes/evaluaciones.csv',
    ).replace(queryParameters: filters.toQueryParameters());

    final response = await http
        .get(
          uri,
          headers: _headers(authToken: cleanToken, accept: 'text/csv'),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Error exportando CSV: ${response.statusCode}. ${response.body}',
      );
    }

    final filename = _buildCsvFilename(filters);

    return ReportCsvDownloadResult(
      filename: filename,
      bytes: response.bodyBytes,
    );
  }

  Map<String, String> _headers({
    required String? authToken,
    required String accept,
  }) {
    final headers = <String, String>{'Accept': accept};

    final cleanToken = authToken?.trim();

    if (cleanToken != null && cleanToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $cleanToken';
    }

    return headers;
  }

  String _buildCsvFilename(ReportFilters filters) {
    final now = DateTime.now();
    final timestamp =
        '${now.year}'
        '${_two(now.month)}'
        '${_two(now.day)}_'
        '${_two(now.hour)}'
        '${_two(now.minute)}'
        '${_two(now.second)}';

    final parts = <String>['reporte_evaluaciones'];

    if (filters.tipoPrueba != null) {
      parts.add(filters.tipoPrueba!.toLowerCase());
    }

    if (filters.semaforo != null) {
      parts.add(filters.semaforo!.toLowerCase());
    }

    if (filters.estudianteId != null) {
      parts.add('estudiante_${filters.estudianteId}');
    }

    parts.add(timestamp);

    return '${parts.join('_')}.csv';
  }

  String _two(int value) {
    return value.toString().padLeft(2, '0');
  }
}
