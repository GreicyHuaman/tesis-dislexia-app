import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/models/auth_user.dart';
import 'package:mobile/core/repositories/auth_session_storage.dart';
import 'package:mobile/core/services/connection_errors.dart';
import 'package:mobile/features/reportes/screens/reportes_screen.dart';
import 'package:mobile/features/reportes/screens/student_risk_profile_screen.dart';

const teacher = AuthUser(
  id: 1,
  nombres: 'Docente',
  apellidos: 'Prueba',
  email: 'prueba@edu.com',
  rol: 'MAESTRO',
  gradoScope: 3,
  activo: true,
  accessToken: 'test-token',
);

http.Response successResponse(http.Request request) {
  final Object body;
  if (request.url.path.endsWith('resumen-semaforo')) {
    body = {'total_evaluaciones': 0, 'semaforos': []};
  } else if (request.url.path.endsWith('/evaluaciones')) {
    body = <Object>[];
  } else if (request.url.path.endsWith('/perfil-riesgo')) {
    body = {
      'estudiante_id': 1,
      'estudiante_nombre': 'Estudiante Prueba',
      'seccion_id': 10,
      'total_evaluaciones': 0,
      'pruebas': [],
    };
  } else {
    throw StateError('Solicitud inesperada en prueba: ${request.url.path}');
  }
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  var connections = <String>['wifi'];
  final screens = <String, Widget>{
    'reportes': const ReportesScreen(currentUser: teacher),
    'perfil': const StudentRiskProfileScreen(
      estudianteId: 1,
      authToken: 'test-token',
    ),
  };

  setUp(() {
    connections = ['wifi'];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'check');
          return connections;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void expectNoTechnicalDetails() {
    expect(find.textContaining('ClientException'), findsNothing);
    expect(find.textContaining('SocketException'), findsNothing);
    expect(find.textContaining('Failed host lookup'), findsNothing);
    expect(find.textContaining('https://'), findsNothing);
    expect(find.textContaining('Traceback'), findsNothing);
  }

  for (final screen in screens.entries) {
    testWidgets('CP024 ${screen.key}: mensaje exacto y recuperación', (
      tester,
    ) async {
      connections = ['none'];
      var requests = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(MaterialApp(home: screen.value));
          await tester.pumpAndSettle();
          expect(find.text(noInternetMessage), findsOneWidget);
          expect(find.text('Reintentar'), findsOneWidget);
          expect(requests, 0);
          expectNoTechnicalDetails();

          connections = ['wifi'];
          await tester.tap(find.text('Reintentar'));
          await tester.pumpAndSettle();
          expect(find.text(noInternetMessage), findsNothing);
          expect(find.text('Reintentar'), findsNothing);
          expect(requests, screen.key == 'reportes' ? 2 : 1);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          requests++;
          return successResponse(request);
        }),
      );
    });

    testWidgets('HU0024 ${screen.key}: servidor no disponible y reintentar', (
      tester,
    ) async {
      var serverAvailable = false;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(MaterialApp(home: screen.value));
          await tester.pumpAndSettle();
          expect(find.text(serverUnavailableMessage), findsOneWidget);
          expectNoTechnicalDetails();

          serverAvailable = true;
          await tester.tap(find.text('Reintentar'));
          await tester.pumpAndSettle();
          expect(find.text(serverUnavailableMessage), findsNothing);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          return serverAvailable
              ? successResponse(request)
              : http.Response(
                  'Traceback: https://example.invalid/internal',
                  503,
                );
        }),
      );
    });

    testWidgets('${screen.key}: un error de formato no expone la respuesta', (
      tester,
    ) async {
      await http.runWithClient(
        () async {
          await tester.pumpWidget(MaterialApp(home: screen.value));
          await tester.pumpAndSettle();
          final message = screen.key == 'reportes'
              ? 'No se pudieron cargar los reportes. Vuelva a intentarlo.'
              : 'No se pudo cargar el perfil. Vuelva a intentarlo.';
          expect(find.text(message), findsOneWidget);
          expect(find.text('Reintentar'), findsOneWidget);
          expectNoTechnicalDetails();
          expect(tester.takeException(), isNull);
        },
        () => MockClient(
          (_) async =>
              http.Response('Failed host lookup: https://example.invalid', 200),
        ),
      );
    });
  }

  testWidgets('Un fallo al actualizar conserva el historial ya cargado', (
    tester,
  ) async {
    var requests = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: ReportesScreen(currentUser: teacher)),
        );
        await tester.pumpAndSettle();
        final scrollable = find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.text('Estudiante Prueba'),
          300,
          scrollable: scrollable,
        );
        expect(find.text('Estudiante Prueba'), findsOneWidget);

        connections = ['none'];
        await tester.tap(find.byTooltip('Actualizar'));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, 2000));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(noInternetMessage),
          200,
          scrollable: scrollable,
        );
        expect(find.text(noInternetMessage), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Estudiante Prueba'),
          200,
          scrollable: scrollable,
        );
        expect(find.text('Estudiante Prueba'), findsOneWidget);
        expect(requests, 2);
        expectNoTechnicalDetails();
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        requests++;
        final Object body = request.url.path.endsWith('resumen-semaforo')
            ? {
                'total_evaluaciones': 1,
                'semaforos': [
                  {'semaforo': 'VERDE', 'total': 1},
                ],
              }
            : [
                {
                  'id': 1,
                  'estudiante_id': 1,
                  'estudiante_nombre': 'Estudiante Prueba',
                  'seccion_id': 10,
                  'fecha_evaluacion': '2026-11-04T12:00:00Z',
                  'tipo_prueba': 'LECTURA',
                  'total_items': 10,
                  'aciertos_primer_intento': 8,
                  'taps_erroneos_totales': 11,
                  'semaforo': 'VERDE',
                },
              ];
        return http.Response(jsonEncode(body), 200);
      }),
    );
  });

  testWidgets('La falta de red conserva la sesión y HTTP 401 la elimina', (
    tester,
  ) async {
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('disly-connection-auth-test-'),
    );
    if (directory == null) fail('No se pudo preparar Hive para la prueba.');
    addTearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });
    await tester.runAsync(() async {
      Hive.init(directory.path);
      await AuthSessionStorage.init();
      await AuthSessionStorage.saveSession(user: teacher, expiresInMinutes: 60);
    });

    connections = ['none'];
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          const MaterialApp(home: ReportesScreen(currentUser: teacher)),
        );
        await tester.pumpAndSettle();
        expect(AuthSessionStorage.hasValidSession(), isTrue);
        connections = ['wifi'];
        final button = tester.widget<ElevatedButton>(
          find.ancestor(
            of: find.text('Reintentar'),
            matching: find.byWidgetPredicate(
              (widget) => widget is ElevatedButton,
            ),
          ),
        );
        final callback = button.onPressed;
        if (callback is! Future<void> Function()) {
          fail('Reintentar debe conservar su operación asíncrona.');
        }
        await tester.runAsync(callback);
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Sesión vencida o no autorizada. Cierra sesión e ingresa nuevamente.',
          ),
          findsOneWidget,
        );
        expect(AuthSessionStorage.hasValidSession(), isFalse);
        expect(find.text('Reintentar'), findsOneWidget);
        expectNoTechnicalDetails();
        expect(tester.takeException(), isNull);
      },
      () => MockClient(
        (_) async => http.Response('https://example.invalid/internal', 401),
      ),
    );
  });
}
