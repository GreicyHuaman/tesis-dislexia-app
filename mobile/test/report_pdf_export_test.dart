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
                return 'reporte_prueba.pdf';
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
        expect(find.text('PDF generado: reporte_prueba.pdf'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

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
      expect(find.textContaining('PDF generado:'), findsNothing);
      expect(tester.widget<IconButton>(pdfButton).onPressed, isNotNull);
      expect(saves, 0);
      builder.completion = Completer<PdfReportResult>();
      await tester.tap(pdfButton);
      await tester.pump();
      builder.completion.complete(testPdf());
      await tester.pumpAndSettle();
      expect(builder.calls, 2);
      expect(saves, 1);
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
      expect(find.textContaining('PDF generado:'), findsNothing);
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
