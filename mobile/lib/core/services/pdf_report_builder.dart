import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/auth_user.dart';

class PdfReportResult {
  final String filename;
  final Uint8List bytes;

  const PdfReportResult({
    required this.filename,
    required this.bytes,
  });
}

class PdfReportBuilder {
  const PdfReportBuilder();

  Future<PdfReportResult> buildEvaluationsReport({
    required AuthUser currentUser,
    required dynamic summary,
    required List<dynamic> evaluations,
  }) async {
    final now = DateTime.now();
    final document = pw.Document(
      title: 'Reporte de tamizaje de riesgo de dislexia',
      author: currentUser.nombreCompleto,
      subject: 'Reporte academico de evaluaciones',
      creator: 'Tamizaje de riesgo de dislexia',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
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
              currentUser: currentUser,
              generatedAt: now,
            ),
            pw.SizedBox(height: 14),
            _buildDisclaimer(),
            pw.SizedBox(height: 14),
            _buildSummary(summary),
            pw.SizedBox(height: 18),
            _buildEvaluationsTable(evaluations),
          ];
        },
      ),
    );

    final bytes = await document.save();

    return PdfReportResult(
      filename: _buildFilename(now),
      bytes: bytes,
    );
  }

  pw.Widget _buildHeader({
    required AuthUser currentUser,
    required DateTime generatedAt,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Reporte de tamizaje de riesgo de dislexia',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Generado por: ${currentUser.nombreCompleto} (${currentUser.rolTexto})',
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
        border: pw.Border.all(
          color: PdfColors.grey600,
          width: 0.5,
        ),
        color: PdfColors.grey100,
      ),
      child: pw.Text(
        'Nota: Este reporte corresponde a un tamizaje temprano de riesgo. '
        'No constituye diagnostico clinico de dislexia. Los resultados deben '
        'ser interpretados por personal especializado y complementados con '
        'evaluaciones profesionales.',
        style: const pw.TextStyle(fontSize: 9),
      ),
    );
  }

  pw.Widget _buildSummary(dynamic summary) {
    final total = _readValue(summary, 'totalEvaluaciones') ??
        _readValue(summary, 'total_evaluaciones') ??
        '0';

    final promedio = _readValue(summary, 'porcentajePromedioRiesgo') ??
        _readValue(summary, 'porcentaje_promedio_riesgo') ??
        '-';

    final semaforos = _readValue(summary, 'semaforos');

    final rows = <List<String>>[
      ['Indicador', 'Valor'],
      ['Total de evaluaciones', total.toString()],
      ['Promedio de riesgo', _formatPercent(promedio)],
    ];

    if (semaforos is List) {
      for (final item in semaforos) {
        final semaforo = _readValue(item, 'semaforo')?.toString() ?? '-';
        final itemTotal = _readValue(item, 'total')?.toString() ?? '0';

        rows.add([
          'Total $semaforo',
          itemTotal,
        ]);
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Resumen general',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: rows.first,
          data: rows.skip(1).toList(),
          border: pw.TableBorder.all(
            color: PdfColors.grey600,
            width: 0.4,
          ),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColors.grey300,
          ),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(5),
        ),
      ],
    );
  }

  pw.Widget _buildEvaluationsTable(List<dynamic> evaluations) {
    final rows = evaluations.map((item) {
      final id = _readValue(item, 'id')?.toString() ?? '-';

      final estudiante = _readValue(item, 'estudianteNombre') ??
          _readValue(item, 'estudiante_nombre') ??
          'Sin nombre';

      final tipoPrueba = _readValue(item, 'tipoPrueba') ??
          _readValue(item, 'tipo_prueba') ??
          '-';

      final fechaRaw = _readValue(item, 'fechaEvaluacion') ??
          _readValue(item, 'fecha_evaluacion');

      final riesgo = _readValue(item, 'porcentajeRiesgo') ??
          _readValue(item, 'porcentaje_riesgo') ??
          '-';

      final semaforo = _readValue(item, 'semaforo')?.toString() ?? '-';

      final totalItems = _readValue(item, 'totalItems') ??
          _readValue(item, 'total_items') ??
          '-';

      final aciertos = _readValue(item, 'aciertosPrimerIntento') ??
          _readValue(item, 'aciertos_primer_intento') ??
          '-';

      final errores = _readValue(item, 'tapsErroneosTotales') ??
          _readValue(item, 'taps_erroneos_totales') ??
          '-';

      final tiempo = _readValue(item, 'tiempoPromedioMs') ??
          _readValue(item, 'tiempo_promedio_ms') ??
          '-';

      final modelo = _readValue(item, 'modeloNombre') ??
          _readValue(item, 'modelo_nombre') ??
          _readValue(item, 'fuentePrediccion') ??
          _readValue(item, 'fuente_prediccion') ??
          '-';

      return [
        id,
        estudiante.toString(),
        _formatDateValue(fechaRaw),
        tipoPrueba.toString(),
        totalItems.toString(),
        aciertos.toString(),
        errores.toString(),
        '$tiempo ms',
        _formatPercent(riesgo),
        semaforo,
        modelo.toString(),
      ];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Detalle de evaluaciones',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        if (rows.isEmpty)
          pw.Text(
            'No hay evaluaciones para los filtros seleccionados.',
            style: const pw.TextStyle(fontSize: 10),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const [
              'ID',
              'Estudiante',
              'Fecha',
              'Prueba',
              'Items',
              'Aciertos',
              'Errores',
              'Tiempo',
              'Riesgo',
              'Semaforo',
              'Modelo',
            ],
            data: rows,
            border: pw.TableBorder.all(
              color: PdfColors.grey600,
              width: 0.35,
            ),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 7,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey300,
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.all(3),
            columnWidths: const {
              0: pw.FixedColumnWidth(24),
              1: pw.FlexColumnWidth(2.2),
              2: pw.FixedColumnWidth(62),
              3: pw.FixedColumnWidth(58),
              4: pw.FixedColumnWidth(34),
              5: pw.FixedColumnWidth(42),
              6: pw.FixedColumnWidth(40),
              7: pw.FixedColumnWidth(52),
              8: pw.FixedColumnWidth(46),
              9: pw.FixedColumnWidth(52),
              10: pw.FlexColumnWidth(1.2),
            },
          ),
      ],
    );
  }

  Object? _readValue(dynamic source, String key) {
    if (source == null) return null;

    if (source is Map) {
      return source[key];
    }

    try {
      switch (key) {
        case 'id':
          return source.id;
        case 'totalEvaluaciones':
          return source.totalEvaluaciones;
        case 'total_evaluaciones':
          return source.total_evaluaciones;
        case 'porcentajePromedioRiesgo':
          return source.porcentajePromedioRiesgo;
        case 'porcentaje_promedio_riesgo':
          return source.porcentaje_promedio_riesgo;
        case 'semaforos':
          return source.semaforos;
        case 'estudianteNombre':
          return source.estudianteNombre;
        case 'estudiante_nombre':
          return source.estudiante_nombre;
        case 'fechaEvaluacion':
          return source.fechaEvaluacion;
        case 'fecha_evaluacion':
          return source.fecha_evaluacion;
        case 'tipoPrueba':
          return source.tipoPrueba;
        case 'tipo_prueba':
          return source.tipo_prueba;
        case 'totalItems':
          return source.totalItems;
        case 'total_items':
          return source.total_items;
        case 'aciertosPrimerIntento':
          return source.aciertosPrimerIntento;
        case 'aciertos_primer_intento':
          return source.aciertos_primer_intento;
        case 'tapsErroneosTotales':
          return source.tapsErroneosTotales;
        case 'taps_erroneos_totales':
          return source.taps_erroneos_totales;
        case 'tiempoPromedioMs':
          return source.tiempoPromedioMs;
        case 'tiempo_promedio_ms':
          return source.tiempo_promedio_ms;
        case 'porcentajeRiesgo':
          return source.porcentajeRiesgo;
        case 'porcentaje_riesgo':
          return source.porcentaje_riesgo;
        case 'semaforo':
          return source.semaforo;
        case 'modeloNombre':
          return source.modeloNombre;
        case 'modelo_nombre':
          return source.modelo_nombre;
        case 'fuentePrediccion':
          return source.fuentePrediccion;
        case 'fuente_prediccion':
          return source.fuente_prediccion;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String _formatPercent(Object? value) {
    if (value == null) return '-';

    final parsed = double.tryParse(value.toString());

    if (parsed == null) {
      return value.toString();
    }

    return '${parsed.toStringAsFixed(2)}%';
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

  String _buildFilename(DateTime dateTime) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    final year = dateTime.year.toString();
    final month = twoDigits(dateTime.month);
    final day = twoDigits(dateTime.day);
    final hour = twoDigits(dateTime.hour);
    final minute = twoDigits(dateTime.minute);

    return 'reporte_evaluaciones_$year$month${day}_$hour$minute.pdf';
  }
}

