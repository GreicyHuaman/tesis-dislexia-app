import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/models/auth_user.dart';
import 'package:mobile/core/models/seguimiento_models.dart';
import 'package:mobile/core/services/connection_errors.dart';
import 'package:mobile/core/services/seguimiento_service.dart';
import 'package:mobile/features/seguimiento/screens/seguimiento_screen.dart';
import 'package:mobile/features/seguimiento/widgets/observation_dialog.dart';

const categories = [
  'Refuerzo pedagógico',
  'Reevaluación',
  'Coordinación con familia',
  'Seguimiento general',
  'Otro',
];
const teacher = AuthUser(
  id: 1,
  nombres: 'Docente',
  apellidos: 'Prueba',
  email: 'docente@edu.com',
  rol: 'MAESTRO',
  gradoScope: 3,
  activo: true,
  accessToken: 'test-token',
);
const studentData = <String, dynamic>{
  'estudiante_id': 1,
  'estudiante_nombre': 'Estudiante Prueba',
  'seccion_id': 10,
  'evaluacion_id': 15,
  'ultima_fecha_evaluacion': '2026-11-05T10:00:00',
  'estado_semanal': 'AL_DIA',
  'prioridad': 'BAJA',
  'semaforo': 'VERDE',
  'tendencia': 'SIN_HISTORIAL',
  'estado': 'ABIERTO',
  'categorias': <String>[],
};

http.Response jsonResponse(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
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

  Future<void> openForm(
    WidgetTester tester, {
    Map<String, dynamic> overrides = const {},
    ValueChanged<bool?>? onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => ObservationDialog(
                    item: SeguimientoItem.fromJson({
                      ...studentData,
                      ...overrides,
                    }),
                    authToken: 'test-token',
                  ),
                );
                onResult?.call(result);
              },
              child: const Text('Abrir formulario'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir formulario'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseCategory(WidgetTester tester, String category) async {
    final chip = find.widgetWithText(FilterChip, category);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  Future<void> enterObservation(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(TextFormField));
    await tester.enterText(
      find.byType(TextFormField),
      'Reforzar lectura de sílabas.',
    );
    tester.testTextInput.hide();
    await tester.pump();
  }

  test('El catálogo móvil coincide exactamente con HU0035', () {
    expect(seguimientoObservationCategories, categories);
  });

  testWidgets(
    'El formulario ofrece las cinco categorías, no el catálogo anterior',
    (tester) async {
      await openForm(tester);
      expect(find.byType(FilterChip), findsNWidgets(5));
      for (final category in categories) {
        expect(find.widgetWithText(FilterChip, category), findsOneWidget);
      }
      expect(find.text('Lectura lenta'), findsNothing);
      expect(find.text('Confusión visual de letras'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('HU0035-2: no envía ni cierra el formulario sin categoría', (
    tester,
  ) async {
    var requests = 0;
    await http.runWithClient(
      () async {
        await openForm(tester);
        await enterObservation(tester);
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();
        expect(
          find.text('Selecciona al menos una categoría válida.'),
          findsOneWidget,
        );
        expect(find.byType(ObservationDialog), findsOneWidget);
        expect(find.text('Reforzar lectura de sílabas.'), findsOneWidget);
        expect(requests, 0);
      },
      () => MockClient((_) async {
        requests++;
        return jsonResponse({});
      }),
    );
  });

  for (final category in categories) {
    testWidgets('Guarda una observación con $category', (tester) async {
      Map<String, dynamic>? sent;
      bool? result;
      await http.runWithClient(
        () async {
          await openForm(tester, onResult: (value) => result = value);
          await enterObservation(tester);
          await chooseCategory(tester, category);
          await tester.tap(find.text('Guardar'));
          await tester.pumpAndSettle();
          expect(sent?['categorias'], [category]);
          expect(sent?['evaluacion_id'], 15);
          expect(sent?['observacion_docente'], 'Reforzar lectura de sílabas.');
          expect(sent?['estado'], 'ABIERTO');
          expect(result, isTrue);
          expect(find.byType(ObservationDialog), findsNothing);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/seguimiento/observaciones');
          expect(request.headers['Authorization'], 'Bearer test-token');
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          expect(sent!.containsKey('responsable_id'), isFalse);
          expect(sent!.containsKey('fecha_seguimiento'), isFalse);
          return jsonResponse({});
        }),
      );
    });
  }

  testWidgets(
    'Permite varias categorías válidas y elimina una selección previa',
    (tester) async {
      Map<String, dynamic>? sent;
      await http.runWithClient(
        () async {
          await openForm(tester);
          await chooseCategory(tester, 'Refuerzo pedagógico');
          await chooseCategory(tester, 'Reevaluación');
          await chooseCategory(tester, 'Otro');
          await chooseCategory(tester, 'Otro');
          await tester.tap(find.text('Guardar'));
          await tester.pumpAndSettle();
          expect(sent?['categorias'], ['Refuerzo pedagógico', 'Reevaluación']);
          expect(sent?['observacion_docente'], isNull);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return jsonResponse({});
        }),
      );
    },
  );

  testWidgets(
    'Una categoría histórica no se envía ni se convierte automáticamente',
    (tester) async {
      Map<String, dynamic>? sent;
      await http.runWithClient(
        () async {
          await openForm(
            tester,
            overrides: {
              'categorias': ['Lectura lenta'],
              'observacion_docente': 'Nota anterior',
            },
          );
          expect(
            find.textContaining('Elige una categoría vigente'),
            findsOneWidget,
          );
          expect(
            tester
                .widgetList<FilterChip>(find.byType(FilterChip))
                .every((chip) => !chip.selected),
            isTrue,
          );
          await tester.tap(find.text('Guardar'));
          await tester.pumpAndSettle();
          expect(sent, isNull);
          expect(
            find.text('Selecciona al menos una categoría válida.'),
            findsOneWidget,
          );
          await chooseCategory(tester, 'Seguimiento general');
          await tester.tap(find.text('Guardar'));
          await tester.pumpAndSettle();
          expect(sent?['categorias'], ['Seguimiento general']);
          expect(sent?['observacion_docente'], 'Nota anterior');
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return jsonResponse({});
        }),
      );
    },
  );

  for (final overrides in [
    {'semaforo': 'ROJO'},
    {'estado_semanal': 'VENCIDA'},
    {'estado': 'DERIVACION_SUGERIDA'},
    {'estado': 'CERRADO'},
  ]) {
    testWidgets('Conserva observación obligatoria para $overrides', (
      tester,
    ) async {
      var requests = 0;
      await http.runWithClient(
        () async {
          await openForm(tester, overrides: overrides);
          await chooseCategory(tester, 'Refuerzo pedagógico');
          await tester.tap(find.text('Guardar'));
          await tester.pumpAndSettle();
          expect(
            find.text('La observación es obligatoria para este caso.'),
            findsOneWidget,
          );
          expect(requests, 0);
          expect(find.byType(ObservationDialog), findsOneWidget);
        },
        () => MockClient((_) async {
          requests++;
          return jsonResponse({});
        }),
      );
    });
  }

  testWidgets('No pierde texto ni selección ante error y permite reintentar', (
    tester,
  ) async {
    var available = false;
    var requests = 0;
    await http.runWithClient(
      () async {
        await openForm(tester);
        await enterObservation(tester);
        await chooseCategory(tester, 'Refuerzo pedagógico');
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();
        expect(find.text(serverUnavailableMessage), findsOneWidget);
        expect(find.textContaining('Traceback'), findsNothing);
        expect(find.textContaining('https://'), findsNothing);
        expect(find.text('Reforzar lectura de sílabas.'), findsOneWidget);
        expect(
          tester
              .widget<FilterChip>(
                find.widgetWithText(FilterChip, 'Refuerzo pedagógico'),
              )
              .selected,
          isTrue,
        );
        available = true;
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();
        expect(requests, 2);
        expect(find.byType(ObservationDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((_) async {
        requests++;
        return available
            ? jsonResponse({})
            : http.Response('Traceback https://example.invalid', 503);
      }),
    );
  });

  testWidgets('Una validación de API se muestra sin estructuras técnicas', (
    tester,
  ) async {
    await http.runWithClient(
      () async {
        await openForm(tester);
        await chooseCategory(tester, 'Otro');
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Selecciona al menos una categoría del catálogo y revisa los datos de la observación.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('literal_error'), findsNothing);
        expect(find.byType(ObservationDialog), findsOneWidget);
      },
      () => MockClient(
        (_) async => http.Response(
          '{"detail":[{"type":"literal_error","input":"privado"}]}',
          422,
        ),
      ),
    );
  });

  testWidgets('Sin Internet conserva el formulario y no envía el POST', (
    tester,
  ) async {
    connections = ['none'];
    var requests = 0;
    await http.runWithClient(
      () async {
        await openForm(tester);
        await chooseCategory(tester, 'Refuerzo pedagógico');
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();
        expect(find.text(noInternetMessage), findsOneWidget);
        expect(requests, 0);
        expect(find.byType(ObservationDialog), findsOneWidget);
      },
      () => MockClient((_) async {
        requests++;
        return jsonResponse({});
      }),
    );
  });

  testWidgets(
    'Guardar deshabilita controles y evita envíos o cierres simultáneos',
    (tester) async {
      final response = Completer<http.Response>();
      var requests = 0;
      await http.runWithClient(
        () async {
          await openForm(tester);
          await chooseCategory(tester, 'Otro');
          await tester.tap(find.text('Guardar'));
          await tester.pump();
          expect(
            tester
                .widget<FilledButton>(
                  find.byWidgetPredicate((widget) => widget is FilledButton),
                )
                .onPressed,
            isNull,
          );
          expect(
            tester
                .widget<TextButton>(find.widgetWithText(TextButton, 'Cancelar'))
                .onPressed,
            isNull,
          );
          expect(
            tester
                .widgetList<FilterChip>(find.byType(FilterChip))
                .every((chip) => chip.onSelected == null),
            isTrue,
          );
          await tester.tap(find.text('Guardando...'));
          await tester.binding.handlePopRoute();
          await tester.pump();
          expect(requests, 1);
          expect(find.byType(ObservationDialog), findsOneWidget);
          response.complete(jsonResponse({}));
          await tester.pumpAndSettle();
          expect(find.byType(ObservationDialog), findsNothing);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((_) async {
          requests++;
          return response.future;
        }),
      );
    },
  );

  testWidgets('Cancelar no guarda ni muestra éxito', (tester) async {
    bool? result;
    await openForm(tester, onResult: (value) => result = value);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'CP035: registrar desde tarjeta y consultar el historial tras volver a entrar',
    (tester) async {
      Map<String, dynamic>? saved;
      Map<String, dynamic>? posted;
      var historyReads = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: SeguimientoScreen(currentUser: teacher)),
          );
          await tester.pumpAndSettle();
          final scrollable = find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(
            find.text('Ver historial'),
            300,
            scrollable: scrollable,
          );
          await tester.tap(find.text('Ver historial'));
          await tester.pumpAndSettle();
          expect(find.text('Historial longitudinal'), findsOneWidget);
          expect(
            find.text('Todavía no hay observaciones docentes registradas.'),
            findsOneWidget,
          );
          await tester.tap(find.text('Cerrar'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Registrar observación'));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(DropdownButtonFormField<String>).last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Reforzamiento').last);
          await tester.pumpAndSettle();
          await enterObservation(tester);
          await chooseCategory(tester, 'Refuerzo pedagógico');
          await tester.tap(find.text('Guardar'));
          await tester.pumpAndSettle();
          expect(
            find.text('Observación guardada correctamente.'),
            findsOneWidget,
          );
          expect(posted?['estado'], 'REFORZAMIENTO');
          expect(posted?['categorias'], ['Refuerzo pedagógico']);
          expect(posted?['evaluacion_id'], 15);
          await tester.pumpWidget(const MaterialApp(home: SizedBox()));
          await tester.pumpAndSettle();
          await tester.pumpWidget(
            const MaterialApp(home: SeguimientoScreen(currentUser: teacher)),
          );
          await tester.pumpAndSettle();
          final reloadedScroll = find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(
            find.text('Ver historial'),
            300,
            scrollable: reloadedScroll,
          );
          await tester.tap(find.text('Ver historial'));
          await tester.pumpAndSettle();
          expect(find.text('Reforzar lectura de sílabas.'), findsOneWidget);
          expect(
            find.widgetWithText(Chip, 'Refuerzo pedagógico'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Responsable: Docente Prueba'),
            findsOneWidget,
          );
          expect(
            find.textContaining('2026-11-05 | REFORZAMIENTO'),
            findsOneWidget,
          );
          expect(historyReads, 2);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          if (request.method == 'POST') {
            posted = jsonDecode(request.body) as Map<String, dynamic>;
            saved = {
              'id': 30,
              ...posted!,
              'categorias_json': jsonEncode(posted!['categorias']),
              'fecha_seguimiento': '2026-11-05T12:00:00',
              'responsable_id': 1,
              'responsable_nombre': 'Docente Prueba',
            };
            return jsonResponse(saved!);
          }
          final actual = {
            ...studentData,
            if (saved != null) ...{
              'categorias': posted!['categorias'],
              'observacion_docente': posted!['observacion_docente'],
              'estado': posted!['estado'],
            },
          };
          if (request.url.path.endsWith('/resumen')) {
            return jsonResponse({
              'total_estudiantes': 1,
              'al_dia': 1,
              'prioridad_baja': 1,
            });
          }
          if (request.url.path.endsWith('/priorizados')) {
            return jsonResponse([actual]);
          }
          if (request.url.path.endsWith('/estudiante/1')) {
            historyReads++;
            return jsonResponse({
              'estudiante_id': 1,
              'estudiante_nombre': 'Estudiante Prueba',
              'actual': actual,
              'observaciones': [if (saved != null) saved!],
            });
          }
          throw StateError('Solicitud inesperada en prueba.');
        }),
      );
    },
  );

  test(
    'El servicio informa un formato de listado inválido, no simula un listado vacío',
    () async {
      await http.runWithClient(() async {
        await expectLater(
          const SeguimientoService().fetchPriorizados(authToken: 'test-token'),
          throwsFormatException,
        );
      }, () => MockClient((_) async => jsonResponse({})));
    },
  );

  testWidgets(
    'El formulario cabe y permite acceder a todas las categorías en móvil estrecho',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await openForm(tester);
      for (final category in categories) {
        await chooseCategory(tester, category);
      }
      expect(
        tester
            .widgetList<FilterChip>(find.byType(FilterChip))
            .every((chip) => chip.selected),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
