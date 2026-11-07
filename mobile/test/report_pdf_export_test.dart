import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/models/auth_user.dart';
import 'package:mobile/core/models/report_models.dart';
import 'package:mobile/core/services/pdf_report_builder.dart';
import 'package:mobile/features/reportes/screens/reportes_screen.dart';
import 'package:mobile/features/reportes/screens/student_risk_profile_screen.dart';

import 'pdf_report_builder_test.dart' show pdfDirector, pdfTeacher;

class ControlledPdfBuilder extends PdfReportBuilder {
  Completer<PdfReportResult> completion = Completer<PdfReportResult>();
  int calls = 0;
  AuthUser? receivedUser;

  @override
  Future<PdfReportResult> buildEvaluationsReport({
    required AuthUser currentUser,
    required ReportSummary summary,
    required List<EvaluationReportItem> evaluations,
  }) {
    calls++;
    receivedUser = currentUser;
    return completion.future;
  }
}

PdfReportResult testPdf() => PdfReportResult(
  filename: 'reporte_prueba.pdf',
  bytes: Uint8List.fromList('%PDF-test'.codeUnits),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  final pdfButton = find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.tooltip == 'Exportar PDF',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => ['wifi']);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<T> withReportResponses<T>(
    Future<T> Function() action,
  ) => http.runWithClient(
    action,
    () => MockClient((request) async {
      if (request.url.path.endsWith('resumen-institucional')) {
        return http.Response(
          '{"total_secciones":0,"secciones_activas":0,"secciones_inactivas":0,'
          '"total_estudiantes":0,"estudiantes_activos":0,"estudiantes_inactivos":0,'
          '"total_evaluaciones":0,"estudiantes_con_evaluaciones":0,'
          '"estudiantes_sin_evaluaciones":0}',
          200,
        );
      }
      if (request.url.path.endsWith('resumen-semaforo')) {
        return http.Response('{"total_evaluaciones":0,"semaforos":[]}', 200);
      }
      if (request.url.path.endsWith('/evaluaciones')) {
        return http.Response('[]', 200);
      }
      if (request.url.path.endsWith('/perfil-riesgo')) {
        return http.Response(
          '{"estudiante_id":1,"estudiante_nombre":"Estudiante Prueba",'
          '"seccion_id":10,"total_evaluaciones":0,"pruebas":[]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      throw StateError('Solicitud inesperada en prueba.');
    }),
  );

  for (final user in [pdfDirector, pdfTeacher]) {
    testWidgets('CP031 ${user.rol}: progreso, una exportación y apertura', (
      tester,
    ) async {
      final builder = ControlledPdfBuilder();
      var saves = 0;
      await withReportResponses(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ReportesScreen(
              currentUser: user,
              pdfReportBuilder: builder,
              savePdf: ({required bytes, required filename}) async {
                saves++;
                expect(filename, 'reporte_prueba.pdf');
                expect(String.fromCharCodes(bytes), '%PDF-test');
                return r'C:\ruta_privada\reporte_prueba.pdf';
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(pdfButton);
        await tester.pump();
        expect(builder.calls, 1);
        expect(builder.receivedUser?.rol, user.rol);
        expect(tester.widget<IconButton>(pdfButton).onPressed, isNull);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.tap(pdfButton);
        await tester.pump(const Duration(milliseconds: 100));
        expect(builder.calls, 1);

        builder.completion.complete(testPdf());
        await tester.pumpAndSettle();
        expect(saves, 1);
        expect(tester.widget<IconButton>(pdfButton).onPressed, isNotNull);
        expect(find.text('El PDF se descargó con éxito.'), findsOneWidget);
        expect(find.textContaining('PDF generado:'), findsNothing);
        expect(find.textContaining('ruta_privada'), findsNothing);
        expect(find.textContaining('reporte_prueba.pdf'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('PDF individual: confirmación breve solo después de guardar', (
    tester,
  ) async {
    final saveStarted = Completer<void>();
    final saved = Completer<String>();
    await withReportResponses(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: StudentRiskProfileScreen(
            estudianteId: 1,
            authToken: 'test-token',
            savePdf: ({required bytes, required filename}) {
              expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
              expect(filename.endsWith('.pdf'), isTrue);
              saveStarted.complete();
              return saved.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Exportar PDF individual'));
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (!saveStarted.isCompleted) {
          if (DateTime.now().isAfter(deadline)) {
            throw StateError('No se inició el guardado del PDF individual.');
          }
          await tester.pump(const Duration(milliseconds: 10));
          await Future<void>.delayed(Duration.zero);
        }
      });
      await tester.pump();
      expect(find.text('El PDF se descargó con éxito.'), findsNothing);
      saved.complete(r'C:\ruta_privada\perfil_prueba.pdf');
      await tester.pumpAndSettle();
      expect(find.text('El PDF se descargó con éxito.'), findsOneWidget);
      expect(find.textContaining('PDF generado:'), findsNothing);
      expect(find.textContaining('ruta_privada'), findsNothing);
      expect(find.textContaining('perfil_prueba.pdf'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Un error de generación se informa y permite reintentar', (
    tester,
  ) async {
    final builder = ControlledPdfBuilder();
    var saves = 0;
    await withReportResponses(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReportesScreen(
            currentUser: pdfDirector,
            pdfReportBuilder: builder,
            savePdf: ({required bytes, required filename}) async {
              saves++;
              return filename;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(pdfButton);
      await tester.pump();
      builder.completion.completeError(StateError('Detalle técnico privado'));
      await tester.pumpAndSettle();
      expect(
        find.text('No se pudo exportar el PDF. Vuelva a intentarlo.'),
        findsOneWidget,
      );
      expect(find.textContaining('Detalle técnico'), findsNothing);
      expect(find.text('El PDF se descargó con éxito.'), findsNothing);
      expect(tester.widget<IconButton>(pdfButton).onPressed, isNotNull);
      expect(saves, 0);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      builder.completion = Completer<PdfReportResult>();
      await tester.tap(pdfButton);
      await tester.pump();
      builder.completion.complete(testPdf());
      await tester.pumpAndSettle();
      expect(builder.calls, 2);
      expect(saves, 1);
      expect(find.text('El PDF se descargó con éxito.'), findsOneWidget);
      expect(tester.widget<IconButton>(pdfButton).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Un error de guardado no se anuncia como PDF exportado', (
    tester,
  ) async {
    final builder = ControlledPdfBuilder();
    await withReportResponses(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReportesScreen(
            currentUser: pdfDirector,
            pdfReportBuilder: builder,
            savePdf: ({required bytes, required filename}) async {
              throw const FileSystemException('Sin espacio', 'ruta privada');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(pdfButton);
      await tester.pump();
      builder.completion.complete(testPdf());
      await tester.pumpAndSettle();
      expect(
        find.text('No se pudo exportar el PDF. Vuelva a intentarlo.'),
        findsOneWidget,
      );
      expect(find.textContaining('ruta privada'), findsNothing);
      expect(find.text('El PDF se descargó con éxito.'), findsNothing);
      expect(tester.widget<IconButton>(pdfButton).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Salir durante la generación no abre un archivo después', (
    tester,
  ) async {
    final builder = ControlledPdfBuilder();
    var saves = 0;
    await withReportResponses(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReportesScreen(
            currentUser: pdfDirector,
            pdfReportBuilder: builder,
            savePdf: ({required bytes, required filename}) async {
              saves++;
              return filename;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(pdfButton);
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      builder.completion.complete(testPdf());
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'Cambiar de cuenta durante la generación no abre el PDF anterior',
    (tester) async {
      final builder = ControlledPdfBuilder();
      var saves = 0;
      Future<String> save({
        required List<int> bytes,
        required String filename,
      }) async {
        saves++;
        return filename;
      }

      await withReportResponses(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ReportesScreen(
              currentUser: pdfDirector,
              pdfReportBuilder: builder,
              savePdf: save,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final initialState = tester.state(find.byType(ReportesScreen));
        await tester.tap(pdfButton);
        await tester.pump();
        await tester.pumpWidget(
          MaterialApp(
            home: ReportesScreen(
              currentUser: pdfTeacher,
              pdfReportBuilder: builder,
              savePdf: save,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          identical(initialState, tester.state(find.byType(ReportesScreen))),
          isTrue,
        );
        builder.completion.complete(testPdf());
        await tester.pumpAndSettle();
        expect(saves, 0);
        expect(tester.takeException(), isNull);
      });
    },
  );
}
