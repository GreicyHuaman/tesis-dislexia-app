import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/models/auth_user.dart';
import 'package:mobile/core/models/report_models.dart';
import 'package:mobile/core/services/connection_errors.dart';
import 'package:mobile/core/services/report_service.dart';
import 'package:mobile/features/reportes/screens/reportes_screen.dart';
import 'package:mobile/features/reportes/widgets/institutional_summary_card.dart';

import 'pdf_report_builder_test.dart' show pdfDirector, pdfTeacher;

const institutionalJson = <String, dynamic>{
  'total_secciones': 3,
  'secciones_activas': 2,
  'secciones_inactivas': 1,
  'total_estudiantes': 5,
  'estudiantes_activos': 3,
  'estudiantes_inactivos': 2,
  'total_evaluaciones': 4,
  'estudiantes_con_evaluaciones': 3,
  'estudiantes_sin_evaluaciones': 2,
};

http.Response jsonResponse(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response historyResponse(http.Request request) {
  final filtered = request.url.queryParameters.containsKey('estudiante_id');
  if (request.url.path.endsWith('resumen-semaforo')) {
    return jsonResponse({
      'total_evaluaciones': filtered ? 0 : 1,
      'semaforos': [],
    });
  }
  if (request.url.path.endsWith('/evaluaciones')) {
    return jsonResponse(
      filtered
          ? <Object>[]
          : [
              {
                'id': 1,
                'estudiante_id': 1,
                'estudiante_nombre': 'Estudiante Prueba',
                'fecha_evaluacion': '2026-11-01T12:00:00',
              },
            ],
    );
  }
  throw StateError('Solicitud inesperada en prueba.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const service = ReportService(baseUrl: 'https://example.invalid');
  var connections = <String>['wifi'];

  setUp(() {
    connections = ['wifi'];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => connections);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void expectCounts(
    WidgetTester tester, {
    int sections = 3,
    int students = 5,
    int evaluations = 4,
  }) {
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('institutional-sections-total')),
          )
          .data,
      '$sections',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('institutional-students-total')),
          )
          .data,
      '$students',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('institutional-evaluations-total')),
          )
          .data,
      '$evaluations',
    );
  }

  Finder inSummary(Finder matching) => find.descendant(
    of: find.byType(InstitutionalSummaryCard),
    matching: matching,
  );

  void expectNoTechnicalDetails() {
    for (final text in [
      'ClientException',
      'SocketException',
      'Traceback',
      'https://',
      'Failed host lookup',
    ]) {
      expect(find.textContaining(text), findsNothing);
    }
  }

  test(
    'El modelo conserva los conteos y calcula cobertura por estudiantes únicos',
    () {
      final data = InstitutionalSummary.fromJson(institutionalJson);
      expect(data.totalSecciones, 3);
      expect(data.seccionesActivas, 2);
      expect(data.seccionesInactivas, 1);
      expect(data.totalEstudiantes, 5);
      expect(data.estudiantesActivos, 3);
      expect(data.estudiantesInactivos, 2);
      expect(data.totalEvaluaciones, 4);
      expect(data.estudiantesConEvaluaciones, 3);
      expect(data.estudiantesSinEvaluaciones, 2);
      expect(data.porcentajeCobertura, 60);
    },
  );

  test('Cero estudiantes no produce un porcentaje de cobertura ficticio', () {
    final data = InstitutionalSummary.fromJson(
      institutionalJson.map((key, value) => MapEntry(key, 0)),
    );
    expect(data.porcentajeCobertura, isNull);
  });

  for (final invalid in <Object?>[null, -1, 1.5, '3', true]) {
    test(
      'Rechaza indicadores inválidos ($invalid), sin sustituirlos por cero',
      () {
        expect(
          () => InstitutionalSummary.fromJson({
            ...institutionalJson,
            'total_secciones': invalid,
          }),
          throwsFormatException,
        );
      },
    );
  }
  test('Rechaza una respuesta sin indicadores obligatorios', () {
    expect(() => InstitutionalSummary.fromJson({}), throwsFormatException);
  });
  for (final values in [
    {'total_secciones': 4},
    {'total_estudiantes': 6},
    {'estudiantes_con_evaluaciones': 5, 'estudiantes_sin_evaluaciones': 0},
  ]) {
    test('Rechaza conteos inconsistentes: $values', () {
      expect(
        () => InstitutionalSummary.fromJson({...institutionalJson, ...values}),
        throwsFormatException,
      );
    });
  }

  test(
    'El servicio consulta agregados autenticados, sin filtros del historial',
    () async {
      await http.runWithClient(
        () async {
          final data = await service.fetchResumenInstitucional(
            authToken: 'test-token',
          );
          expect(data.totalEstudiantes, 5);
        },
        () => MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/reportes/resumen-institucional');
          expect(request.url.query, isEmpty);
          expect(request.headers['Authorization'], 'Bearer test-token');
          return jsonResponse(institutionalJson);
        }),
      );
    },
  );
  for (final status in [401, 403, 404, 503]) {
    test(
      'El resumen conserva HTTP $status y no expone el cuerpo técnico',
      () async {
        await http.runWithClient(
          () async {
            await expectLater(
              service.fetchResumenInstitucional(authToken: 'test-token'),
              throwsA(
                isA<RequestFailure>()
                    .having((error) => error.statusCode, 'estado', status)
                    .having(
                      (error) => error.message.contains('https://'),
                      'sin URL',
                      false,
                    )
                    .having(
                      (error) => error.message.contains('Traceback'),
                      'sin cuerpo',
                      false,
                    ),
              ),
            );
          },
          () => MockClient(
            (_) async => http.Response(
              'Traceback https://example.invalid/private',
              status,
            ),
          ),
        );
      },
    );
  }
  test('Sin red no solicita el resumen y muestra el mensaje CP024', () async {
    connections = ['none'];
    var requests = 0;
    await http.runWithClient(
      () async {
        await expectLater(
          service.fetchResumenInstitucional(),
          throwsA(
            isA<RequestFailure>().having(
              (error) => error.message,
              'mensaje',
              noInternetMessage,
            ),
          ),
        );
        expect(requests, 0);
      },
      () => MockClient((_) async {
        requests++;
        return jsonResponse(institutionalJson);
      }),
    );
  });
  test('Timeout con red se informa como servicio no disponible', () async {
    await http.runWithClient(
      () async {
        await expectLater(
          service.fetchResumenInstitucional(),
          throwsA(
            isA<RequestFailure>().having(
              (error) => error.message,
              'mensaje',
              serverUnavailableMessage,
            ),
          ),
        );
      },
      () => MockClient((_) async => throw TimeoutException('Detalle privado')),
    );
  });
  for (final body in <Object>[
    <Object>[],
    {'total_secciones': 3},
  ]) {
    test(
      'Una respuesta HTTP 200 incompleta no equivale a una institución vacía: $body',
      () async {
        await http.runWithClient(() async {
          await expectLater(
            service.fetchResumenInstitucional(),
            throwsFormatException,
          );
        }, () => MockClient((_) async => jsonResponse(body)));
      },
    );
  }

  testWidgets('CP032: director ve totales, estados y avance desde el inicio', (
    tester,
  ) async {
    var institutionalRequests = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: ReportesScreen(currentUser: pdfDirector)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(InstitutionalSummaryCard), findsOneWidget);
        expectCounts(tester);
        expect(find.text('Activas: 2 | Inactivas: 1'), findsOneWidget);
        expect(find.text('Activos: 3 | Inactivos: 2'), findsOneWidget);
        expect(find.text('Con al menos una evaluación: 3'), findsOneWidget);
        expect(find.text('Sin evaluaciones: 2'), findsOneWidget);
        expect(
          find.text('Cobertura: 60.0% de estudiantes registrados'),
          findsOneWidget,
        );
        expect(institutionalRequests, 1);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        if (request.url.path.endsWith('resumen-institucional')) {
          institutionalRequests++;
          return jsonResponse(institutionalJson);
        }
        return historyResponse(request);
      }),
    );
  });

  testWidgets(
    'El docente conserva su panel y no consulta agregados institucionales',
    (tester) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: ReportesScreen(currentUser: pdfTeacher)),
          );
          await tester.pumpAndSettle();
          expect(find.byType(InstitutionalSummaryCard), findsNothing);
          expect(find.text('Reporte docente'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          expect(request.url.path.endsWith('resumen-institucional'), isFalse);
          return historyResponse(request);
        }),
      );
    },
  );

  testWidgets(
    'Aplicar filtros del historial no modifica los totales institucionales',
    (tester) async {
      final requests = <Uri>[];
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: ReportesScreen(currentUser: pdfDirector)),
          );
          await tester.pumpAndSettle();
          final scrollable = find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first;
          final input = find.widgetWithText(
            TextField,
            'Estudiante ID opcional',
          );
          await tester.scrollUntilVisible(input, 300, scrollable: scrollable);
          await tester.enterText(input, '7');
          await tester.scrollUntilVisible(
            find.text('Aplicar filtros'),
            200,
            scrollable: scrollable,
          );
          await tester.tap(find.text('Aplicar filtros'));
          await tester.pumpAndSettle();
          expect(
            requests
                .where((uri) => uri.path.endsWith('resumen-institucional'))
                .length,
            1,
          );
          expect(
            requests
                .where((uri) => uri.queryParameters['estudiante_id'] == '7')
                .length,
            2,
          );
          await tester.drag(find.byType(ListView), const Offset(0, 3000));
          await tester.pumpAndSettle();
          expectCounts(tester);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          requests.add(request.url);
          return request.url.path.endsWith('resumen-institucional')
              ? jsonResponse(institutionalJson)
              : historyResponse(request);
        }),
      );
    },
  );

  testWidgets('El resumen carga aunque el historial no esté disponible', (
    tester,
  ) async {
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: ReportesScreen(currentUser: pdfDirector)),
        );
        await tester.pumpAndSettle();
        expectCounts(tester);
        expect(tester.takeException(), isNull);
      },
      () => MockClient(
        (request) async => request.url.path.endsWith('resumen-institucional')
            ? jsonResponse(institutionalJson)
            : http.Response('Traceback https://example.invalid', 503),
      ),
    );
  });

  testWidgets(
    'Sin conexión no muestra ceros ficticios y permite recuperar el resumen',
    (tester) async {
      connections = ['none'];
      var requests = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: ReportesScreen(currentUser: pdfDirector)),
          );
          await tester.pumpAndSettle();
          expect(inSummary(find.text(noInternetMessage)), findsOneWidget);
          expect(
            find.byKey(const ValueKey('institutional-sections-total')),
            findsNothing,
          );
          expect(requests, 0);
          expectNoTechnicalDetails();
          connections = ['wifi'];
          await tester.tap(find.text('Reintentar resumen institucional'));
          await tester.pumpAndSettle();
          expectCounts(tester);
          expect(requests, 1);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          requests++;
          return request.url.path.endsWith('resumen-institucional')
              ? jsonResponse(institutionalJson)
              : historyResponse(request);
        }),
      );
    },
  );

  testWidgets(
    'Un fallo al actualizar conserva los totales y avisa que pueden estar desactualizados',
    (tester) async {
      var available = true;
      var responseData = institutionalJson;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: ReportesScreen(currentUser: pdfDirector)),
          );
          await tester.pumpAndSettle();
          available = false;
          await tester.tap(find.byTooltip('Actualizar'));
          await tester.pumpAndSettle();
          expectCounts(tester);
          expect(
            inSummary(find.text(serverUnavailableMessage)),
            findsOneWidget,
          );
          expect(
            find.textContaining('podría no estar actualizado'),
            findsOneWidget,
          );
          expectNoTechnicalDetails();
          available = true;
          responseData = {
            ...institutionalJson,
            'total_estudiantes': 6,
            'estudiantes_activos': 4,
            'estudiantes_sin_evaluaciones': 3,
          };
          await tester.tap(find.text('Reintentar resumen institucional'));
          await tester.pumpAndSettle();
          expectCounts(tester, students: 6);
          expect(inSummary(find.text(serverUnavailableMessage)), findsNothing);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('resumen-institucional')) {
            return available
                ? jsonResponse(responseData)
                : http.Response('Traceback https://example.invalid', 503);
          }
          return historyResponse(request);
        }),
      );
    },
  );

  testWidgets(
    'Una institución realmente vacía muestra cero y no inventa cobertura',
    (tester) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: ReportesScreen(currentUser: pdfDirector)),
          );
          await tester.pumpAndSettle();
          expectCounts(tester, sections: 0, students: 0, evaluations: 0);
          expect(find.text('No hay estudiantes registrados.'), findsOneWidget);
          expect(find.textContaining('Cobertura:'), findsNothing);
          expect(tester.takeException(), isNull);
        },
        () => MockClient(
          (request) async => request.url.path.endsWith('resumen-institucional')
              ? jsonResponse(
                  institutionalJson.map((key, value) => MapEntry(key, 0)),
                )
              : historyResponse(request),
        ),
      );
    },
  );

  testWidgets(
    'Una respuesta de una cuenta anterior no sobrescribe el resumen nuevo',
    (tester) async {
      final oldResponse = Completer<http.Response>();
      var institutionalRequests = 0;
      const nextDirector = AuthUser(
        id: 99,
        nombres: 'Director',
        apellidos: 'Nuevo',
        email: 'nuevo@edu.com',
        rol: 'DIRECTORA',
        gradoScope: 3,
        activo: true,
        accessToken: 'next-test-token',
      );
      final nextJson = {
        ...institutionalJson,
        'total_estudiantes': 6,
        'estudiantes_activos': 4,
        'estudiantes_sin_evaluaciones': 3,
      };
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: ReportesScreen(currentUser: pdfDirector)),
          );
          await tester.pump();
          expect(institutionalRequests, 1);
          await tester.pumpWidget(
            const MaterialApp(home: ReportesScreen(currentUser: nextDirector)),
          );
          await tester.pumpAndSettle();
          expectCounts(tester, students: 6);
          oldResponse.complete(jsonResponse(institutionalJson));
          await tester.pumpAndSettle();
          expectCounts(tester, students: 6);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('resumen-institucional')) {
            institutionalRequests++;
            return institutionalRequests == 1
                ? oldResponse.future
                : jsonResponse(nextJson);
          }
          return historyResponse(request);
        }),
      );
    },
  );

  testWidgets('Si se revoca el permiso, no se conserva el resumen anterior', (
    tester,
  ) async {
    var authorized = true;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: ReportesScreen(currentUser: pdfDirector)),
        );
        await tester.pumpAndSettle();
        expectCounts(tester);
        authorized = false;
        await tester.tap(find.byTooltip('Actualizar'));
        await tester.pumpAndSettle();
        expect(
          inSummary(
            find.text('No tiene permiso para consultar esta información.'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('institutional-sections-total')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        if (request.url.path.endsWith('resumen-institucional')) {
          return authorized
              ? jsonResponse(institutionalJson)
              : http.Response('Traceback privado', 403);
        }
        return historyResponse(request);
      }),
    );
  });

  testWidgets('Recargar descarta una consulta anterior aunque siga pendiente', (
    tester,
  ) async {
    final oldResponse = Completer<http.Response>();
    var requests = 0;
    final latestJson = {
      ...institutionalJson,
      'total_estudiantes': 6,
      'estudiantes_activos': 4,
      'estudiantes_sin_evaluaciones': 3,
    };
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: ReportesScreen(currentUser: pdfDirector)),
        );
        await tester.pump();
        expect(requests, 1);
        await tester.drag(find.byType(ListView), const Offset(0, 500));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(requests, 2);
        await tester.pumpAndSettle();
        expectCounts(tester, students: 6);
        oldResponse.complete(jsonResponse(institutionalJson));
        await tester.pumpAndSettle();
        expectCounts(tester, students: 6);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        if (request.url.path.endsWith('resumen-institucional')) {
          requests++;
          return requests == 1 ? oldResponse.future : jsonResponse(latestJson);
        }
        return historyResponse(request);
      }),
    );
  });

  testWidgets(
    'Una respuesta incompleta se informa sin mostrar indicadores inventados',
    (tester) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: ReportesScreen(currentUser: pdfDirector)),
          );
          await tester.pumpAndSettle();
          expect(
            inSummary(
              find.text(
                'No se pudo cargar el resumen institucional. Vuelva a intentarlo.',
              ),
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('institutional-students-total')),
            findsNothing,
          );
          expectNoTechnicalDetails();
          expect(tester.takeException(), isNull);
        },
        () => MockClient(
          (request) async => request.url.path.endsWith('resumen-institucional')
              ? jsonResponse({
                  'total_secciones': 3,
                  'detalle': 'Traceback https://example.invalid',
                })
              : historyResponse(request),
        ),
      );
    },
  );

  testWidgets(
    'Salir con una consulta pendiente no modifica una pantalla desmontada',
    (tester) async {
      final pending = Completer<http.Response>();
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: ReportesScreen(currentUser: pdfDirector)),
          );
          await tester.pump();
          await tester.pumpWidget(const MaterialApp(home: SizedBox()));
          pending.complete(jsonResponse(institutionalJson));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
        () => MockClient(
          (request) async => request.url.path.endsWith('resumen-institucional')
              ? pending.future
              : historyResponse(request),
        ),
      );
    },
  );

  testWidgets(
    'El resumen cabe sin desbordamientos en una pantalla móvil estrecha',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                InstitutionalSummaryCard(
                  summary: InstitutionalSummary.fromJson(institutionalJson),
                  isLoading: false,
                  errorMessage: null,
                  onRetry: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectCounts(tester);
      expect(tester.takeException(), isNull);
    },
  );
}
