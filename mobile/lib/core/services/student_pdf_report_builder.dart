import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class StudentPdfReportResult {
  final String filename;
  final Uint8List bytes;

  const StudentPdfReportResult({required this.filename, required this.bytes});
}

class StudentPdfReportBuilder {
  const StudentPdfReportBuilder();

  Future<StudentPdfReportResult> buildStudentRiskReport({
    required dynamic profile,
  }) async {
    final now = DateTime.now();

    final estudianteId =
        _readValue(profile, 'estudianteId') ??
        _readValue(profile, 'estudiante_id') ??
        '-';

    final estudianteNombre =
        _readValue(profile, 'estudianteNombre') ??
        _readValue(profile, 'estudiante_nombre') ??
        'Estudiante';

    final document = pw.Document(
      title: 'Reporte individual de riesgo de dislexia',
      author: 'Sistema de tamizaje de riesgo de dislexia',
      subject: 'Perfil individual de riesgo',
      creator: 'Tamizaje de riesgo de dislexia',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Pagina ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          );
        },
        build: (context) {
          return [
            _buildHeader(
              estudianteNombre: estudianteNombre.toString(),
              estudianteId: estudianteId.toString(),
              generatedAt: now,
            ),
            pw.SizedBox(height: 14),
            _buildDisclaimer(),
            pw.SizedBox(height: 16),
            _buildGeneralSummary(profile),
            pw.SizedBox(height: 18),
            _buildTestProfiles(profile),
            pw.SizedBox(height: 18),
            _buildInterpretationNote(),
          ];
        },
      ),
    );

    final bytes = await document.save();

    return StudentPdfReportResult(
      filename: _buildFilename(
        estudianteId: estudianteId.toString(),
        dateTime: now,
      ),
      bytes: bytes,
    );
  }

  pw.Widget _buildHeader({
    required String estudianteNombre,
    required String estudianteId,
    required DateTime generatedAt,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Reporte individual de tamizaje de riesgo de dislexia',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Estudiante: $estudianteNombre',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'ID estudiante: $estudianteId',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Text(
          'Fecha de generacion: ${_formatDateTime(generatedAt)}',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  pw.Widget _buildDisclaimer() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
        color: PdfColors.grey100,
      ),
      child: pw.Text(
        'Nota: Este reporte corresponde a un tamizaje temprano de riesgo. '
        'No constituye diagnostico clinico de dislexia. Los resultados deben '
        'ser interpretados por personal especializado y complementados con '
        'evaluaciones profesionales cuando corresponda.',
        style: const pw.TextStyle(fontSize: 9),
      ),
    );
  }

  pw.Widget _buildGeneralSummary(dynamic profile) {
    final seccionId =
        _readValue(profile, 'seccionId') ??
        _readValue(profile, 'seccion_id') ??
        '-';

    final totalEvaluaciones =
        _readValue(profile, 'totalEvaluaciones') ??
        _readValue(profile, 'total_evaluaciones') ??
        '0';

    final promedioGeneral =
        _readValue(profile, 'porcentajePromedioGeneral') ??
        _readValue(profile, 'porcentaje_promedio_general') ??
        '-';

    final ultimoRiesgo =
        _readValue(profile, 'ultimoPorcentajeRiesgoGeneral') ??
        _readValue(profile, 'ultimo_porcentaje_riesgo_general') ??
        '-';

    final ultimoSemaforo =
        _readValue(profile, 'ultimoSemaforoGeneral') ??
        _readValue(profile, 'ultimo_semaforo_general') ??
        '-';

    final ultimaFecha =
        _readValue(profile, 'ultimaFechaGeneral') ??
        _readValue(profile, 'ultima_fecha_general');

    final rows = [
      ['Indicador', 'Valor'],
      ['Seccion', seccionId.toString()],
      ['Total de evaluaciones', totalEvaluaciones.toString()],
      ['Promedio general de riesgo', _formatPercent(promedioGeneral)],
      ['Ultimo riesgo registrado', _formatPercent(ultimoRiesgo)],
      ['Ultimo semaforo', ultimoSemaforo.toString()],
      ['Ultima fecha de evaluacion', _formatDateValue(ultimaFecha)],
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Resumen general',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: rows.first,
          data: rows.skip(1).toList(),
          border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.4),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(5),
        ),
      ],
    );
  }

  pw.Widget _buildTestProfiles(dynamic profile) {
    final pruebas = _readList(_readValue(profile, 'pruebas'));

    if (pruebas.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Detalle por tipo de prueba',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'No existen evaluaciones registradas para este estudiante.',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      );
    }

    final rows = pruebas.map((item) {
      final tipoPrueba =
          _readValue(item, 'tipoPrueba') ??
          _readValue(item, 'tipo_prueba') ??
          '-';

      final totalEvaluaciones =
          _readValue(item, 'totalEvaluaciones') ??
          _readValue(item, 'total_evaluaciones') ??
          '0';

      final promedioRiesgo =
          _readValue(item, 'porcentajePromedioRiesgo') ??
          _readValue(item, 'porcentaje_promedio_riesgo') ??
          '-';

      final ultimoRiesgo =
          _readValue(item, 'ultimoPorcentajeRiesgo') ??
          _readValue(item, 'ultimo_porcentaje_riesgo') ??
          '-';

      final ultimoSemaforo =
          _readValue(item, 'ultimoSemaforo') ??
          _readValue(item, 'ultimo_semaforo') ??
          '-';

      final ultimaFecha =
          _readValue(item, 'ultimaFecha') ?? _readValue(item, 'ultima_fecha');

      final promedioTiempo =
          _readValue(item, 'promedioTiempoMs') ??
          _readValue(item, 'promedio_tiempo_ms') ??
          '-';

      final promedioErrores =
          _readValue(item, 'promedioErrores') ??
          _readValue(item, 'promedio_errores') ??
          '-';

      final totalVerde =
          _readValue(item, 'totalVerde') ??
          _readValue(item, 'total_verde') ??
          '0';

      final totalAmarillo =
          _readValue(item, 'totalAmarillo') ??
          _readValue(item, 'total_amarillo') ??
          '0';

      final totalRojo =
          _readValue(item, 'totalRojo') ??
          _readValue(item, 'total_rojo') ??
          '0';

      return [
        tipoPrueba.toString(),
        totalEvaluaciones.toString(),
        _formatPercent(promedioRiesgo),
        _formatPercent(ultimoRiesgo),
        ultimoSemaforo.toString(),
        _formatDateValue(ultimaFecha),
        _formatNumberWithSuffix(promedioTiempo, 'ms'),
        _formatNumber(promedioErrores),
        totalVerde.toString(),
        totalAmarillo.toString(),
        totalRojo.toString(),
      ];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Detalle por tipo de prueba',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const [
            'Prueba',
            'Eval.',
            'Prom. riesgo',
            'Ult. riesgo',
            'Semaforo',
            'Ult. fecha',
            'Prom. tiempo',
            'Prom. errores',
            'Verde',
            'Amarillo',
            'Rojo',
          ],
          data: rows,
          border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.35),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 7,
          ),
          cellStyle: const pw.TextStyle(fontSize: 7),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(3),
        ),
      ],
    );
  }

  pw.Widget _buildInterpretationNote() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey500, width: 0.4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Interpretacion sugerida',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'VERDE indica bajo riesgo estimado en la evaluacion registrada. '
            'AMARILLO indica riesgo intermedio que puede requerir seguimiento. '
            'ROJO indica mayor riesgo estimado y sugiere derivacion o revision '
            'por personal especializado. Esta interpretacion es orientativa y '
            'debe complementarse con criterios pedagogicos y psicopedagogicos.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  Object? _readValue(dynamic source, String key) {
    if (source == null) return null;

    if (source is Map) {
      return source[key];
    }

    try {
      switch (key) {
        case 'estudianteId':
          return source.estudianteId;
        case 'estudiante_id':
          return source.estudiante_id;
        case 'estudianteNombre':
          return source.estudianteNombre;
        case 'estudiante_nombre':
          return source.estudiante_nombre;
        case 'seccionId':
          return source.seccionId;
        case 'seccion_id':
          return source.seccion_id;
        case 'totalEvaluaciones':
          return source.totalEvaluaciones;
        case 'total_evaluaciones':
          return source.total_evaluaciones;
        case 'porcentajePromedioGeneral':
          return source.porcentajePromedioGeneral;
        case 'porcentaje_promedio_general':
          return source.porcentaje_promedio_general;
        case 'ultimoPorcentajeRiesgoGeneral':
          return source.ultimoPorcentajeRiesgoGeneral;
        case 'ultimo_porcentaje_riesgo_general':
          return source.ultimo_porcentaje_riesgo_general;
        case 'ultimoSemaforoGeneral':
          return source.ultimoSemaforoGeneral;
        case 'ultimo_semaforo_general':
          return source.ultimo_semaforo_general;
        case 'ultimaFechaGeneral':
          return source.ultimaFechaGeneral;
        case 'ultima_fecha_general':
          return source.ultima_fecha_general;
        case 'pruebas':
          return source.pruebas;
        case 'tipoPrueba':
          return source.tipoPrueba;
        case 'tipo_prueba':
          return source.tipo_prueba;
        case 'porcentajePromedioRiesgo':
          return source.porcentajePromedioRiesgo;
        case 'porcentaje_promedio_riesgo':
          return source.porcentaje_promedio_riesgo;
        case 'ultimoPorcentajeRiesgo':
          return source.ultimoPorcentajeRiesgo;
        case 'ultimo_porcentaje_riesgo':
          return source.ultimo_porcentaje_riesgo;
        case 'ultimoSemaforo':
          return source.ultimoSemaforo;
        case 'ultimo_semaforo':
          return source.ultimo_semaforo;
        case 'ultimaFecha':
          return source.ultimaFecha;
        case 'ultima_fecha':
          return source.ultima_fecha;
        case 'promedioTiempoMs':
          return source.promedioTiempoMs;
        case 'promedio_tiempo_ms':
          return source.promedio_tiempo_ms;
        case 'promedioErrores':
          return source.promedioErrores;
        case 'promedio_errores':
          return source.promedio_errores;
        case 'totalVerde':
          return source.totalVerde;
        case 'total_verde':
          return source.total_verde;
        case 'totalAmarillo':
          return source.totalAmarillo;
        case 'total_amarillo':
          return source.total_amarillo;
        case 'totalRojo':
          return source.totalRojo;
        case 'total_rojo':
          return source.total_rojo;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  List<dynamic> _readList(Object? value) {
    if (value is List) {
      return value;
    }

    return [];
  }

  String _formatPercent(Object? value) {
    if (value == null) return '-';

    final parsed = double.tryParse(value.toString());

    if (parsed == null) {
      return value.toString();
    }

    return '${parsed.toStringAsFixed(2)}%';
  }

  String _formatNumber(Object? value) {
    if (value == null) return '-';

    final parsed = double.tryParse(value.toString());

    if (parsed == null) {
      return value.toString();
    }

    return parsed.toStringAsFixed(2);
  }

  String _formatNumberWithSuffix(Object? value, String suffix) {
    if (value == null) return '-';

    final parsed = double.tryParse(value.toString());

    if (parsed == null) {
      return value.toString();
    }

    return '${parsed.toStringAsFixed(2)} $suffix';
  }

  String _formatDateValue(Object? value) {
    if (value == null) return '-';

    if (value is DateTime) {
      return _formatDateTime(value);
    }

    final parsed = DateTime.tryParse(value.toString());

    if (parsed == null) {
      return value.toString();
    }

    return _formatDateTime(parsed);
  }

  String _formatDateTime(DateTime dateTime) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    final day = twoDigits(dateTime.day);
    final month = twoDigits(dateTime.month);
    final year = dateTime.year.toString();
    final hour = twoDigits(dateTime.hour);
    final minute = twoDigits(dateTime.minute);

    return '$day/$month/$year $hour:$minute';
  }

  String _buildFilename({
    required String estudianteId,
    required DateTime dateTime,
  }) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    final year = dateTime.year.toString();
    final month = twoDigits(dateTime.month);
    final day = twoDigits(dateTime.day);
    final hour = twoDigits(dateTime.hour);
    final minute = twoDigits(dateTime.minute);

    final cleanId = estudianteId.replaceAll(RegExp(r'[^0-9A-Za-z_-]'), '');

    return 'reporte_estudiante_${cleanId}_$year$month${day}_$hour$minute.pdf';
  }
}
