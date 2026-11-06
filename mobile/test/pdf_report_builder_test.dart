import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/auth_user.dart';
import 'package:mobile/core/models/report_models.dart';
import 'package:mobile/core/services/pdf_report_builder.dart';
import 'package:mobile/core/services/student_pdf_report_builder.dart';

const pdfDirector = AuthUser(
  id: 1,
  nombres: 'Director',
  apellidos: 'Prueba',
  email: 'director@edu.com',
  rol: 'DIRECTORA',
  gradoScope: 3,
  activo: true,
);

const pdfTeacher = AuthUser(
  id: 2,
  nombres: 'Docente',
  apellidos: 'Prueba',
  email: 'docente@edu.com',
  rol: 'MAESTRO',
  gradoScope: 3,
  activo: true,
);

List<EvaluationReportItem> pdfEvaluations(int count) => List.generate(
  count,
  (index) => EvaluationReportItem(
    id: index + 1,
    estudianteId: index + 1,
    estudianteNombre: 'Estudiante PDF ${index.toString().padLeft(6, '0')}',
    seccionId: 10,
    fechaEvaluacion: DateTime(2026, 11, 4, 12),
    tipoPrueba: index.isEven ? 'LECTURA' : 'FONOLOGIA',
    totalItems: 10,
    aciertosPrimerIntento: 8,
    tapsErroneosTotales: 3,
    tiempoPromedioMs: 2500,
    porcentajeRiesgo: 20,
    semaforo: 'VERDE',
    fuentePrediccion: 'ML_RANDOM_FOREST',
    modeloNombre: 'random_forest_risk_model',
    modeloVersion: 'test',
    probabilidadVerde: null,
    probabilidadAmarillo: null,
    probabilidadRojo: null,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const builder = PdfReportBuilder();

  for (final entry in {
    'docente': 5,
    'director': 100,
    'institucional': 2500,
  }.entries) {
    test(
      'CP031 genera PDF completo para ${entry.key} con ${entry.value} filas',
      () async {
        final result = await builder.buildEvaluationsReport(
          currentUser: entry.key == 'docente' ? pdfTeacher : pdfDirector,
          summary: ReportSummary(
            totalEvaluaciones: entry.value,
            porcentajePromedioRiesgo: 20,
            semaforos: [
              SemaforoSummaryItem(semaforo: 'VERDE', total: entry.value),
            ],
          ),
          evaluations: pdfEvaluations(entry.value),
        );
        expect(String.fromCharCodes(result.bytes.take(5)), '%PDF-');
        expect(result.bytes.length, greaterThan(500));
        expect(result.filename, endsWith('.pdf'));

        final artifacts = Platform.environment['DISLY_PDF_ARTIFACT_DIR'];
        if (artifacts != null) {
          await File(
            '$artifacts${Platform.pathSeparator}${entry.key}.pdf',
          ).writeAsBytes(result.bytes, flush: true);
        }
      },
    );
  }

  test('El reporte sin evaluaciones se genera sin errores', () async {
    final result = await builder.buildEvaluationsReport(
      currentUser: pdfDirector,
      summary: const ReportSummary(
        totalEvaluaciones: 0,
        porcentajePromedioRiesgo: null,
        semaforos: [],
      ),
      evaluations: [],
    );
    expect(String.fromCharCodes(result.bytes.take(5)), '%PDF-');
  });

  test('Se conserva la generación del PDF individual', () async {
    final result = await const StudentPdfReportBuilder().buildStudentRiskReport(
      profile: StudentRiskProfile.fromJson({
        'estudiante_id': 1,
        'estudiante_nombre': 'María Núñez',
        'seccion_id': 10,
        'total_evaluaciones': 1,
        'pruebas': [],
      }),
    );
    expect(String.fromCharCodes(result.bytes.take(5)), '%PDF-');
    final artifacts = Platform.environment['DISLY_PDF_ARTIFACT_DIR'];
    if (artifacts != null) {
      await File(
        '$artifacts${Platform.pathSeparator}individual.pdf',
      ).writeAsBytes(result.bytes, flush: true);
    }
  });
}
