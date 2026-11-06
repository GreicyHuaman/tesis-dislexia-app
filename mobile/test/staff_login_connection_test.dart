import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/models/local_evaluation_detail.dart';
import 'package:mobile/core/repositories/auth_session_storage.dart';
import 'package:mobile/core/repositories/local_evaluation_storage.dart';
import 'package:mobile/core/services/auth_service.dart';
import 'package:mobile/core/services/auto_sync_service.dart';
import 'package:mobile/core/services/connection_errors.dart';
import 'package:mobile/features/auth/screens/staff_login_screen.dart';
import 'package:mobile/features/reportes/screens/reportes_screen.dart';

const testEmail = 'prueba@edu.com';
const testPassword = 'clave-ficticia';
const loginFailureMessage = 'No se pudo iniciar sesión. Vuelva a intentarlo.';

http.Response loginResponse({String role = 'MAESTRO', int expires = 60}) {
  return http.Response(
    jsonEncode({
      'access_token': 'test-token',
      'expires_in_minutes': expires,
      'user': {
        'id': 1,
        'nombres': 'Personal',
        'apellidos': 'Prueba',
        'email': testEmail,
        'rol': role,
        'grado_scope': 3,
        'activo': true,
      },
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const service = AuthService(baseUrl: 'https://example.invalid');
  var connections = <String>['wifi'];
  var connectionChecks = 0;

  setUp(() {
    connections = ['wifi'];
    connectionChecks = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'check');
          connectionChecks++;
          return connections;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<AuthLoginResult> loginWith(
    Future<http.Response> Function(http.Request) handler, {
    String email = testEmail,
    String password = testPassword,
  }) {
    return http.runWithClient(
      () => service.login(email: email, password: password),
      () => MockClient(handler),
    );
  }

  void expectFailure(AuthLoginResult result, String message) {
    expect(result.success, isFalse);
    expect(result.user, isNull);
    expect(result.expiresInMinutes, 0);
    expect(result.message, message);
    for (final detail in [
      'ClientException',
      'SocketException',
      'Failed host lookup',
      'https://',
      'Traceback',
      testPassword,
    ]) {
      expect(result.message, isNot(contains(detail)));
    }
  }

  group('Servicio de inicio de sesión', () {
    test('CP047: sin red no envía credenciales ni crea una sesión', () async {
      connections = ['none'];
      var requests = 0;
      final result = await loginWith((_) async {
        requests++;
        return loginResponse();
      });
      expectFailure(result, noInternetMessage);
      expect(requests, 0);
    });

    for (final missingField in ['correo', 'contraseña']) {
      test('Valida $missingField vacío antes de consultar la red', () async {
        connections = ['none'];
        var requests = 0;
        final result = await loginWith(
          (_) async {
            requests++;
            return loginResponse();
          },
          email: missingField == 'correo' ? '   ' : testEmail,
          password: missingField == 'contraseña' ? '' : testPassword,
        );
        expectFailure(result, 'Ingresa correo y contraseña.');
        expect(connectionChecks, 0);
        expect(requests, 0);
      });
    }

    final transportErrors = <Object>[
      const SocketException('Failed host lookup: example.invalid'),
      http.ClientException(
        'SocketException: Failed host lookup',
        Uri.parse('https://example.invalid'),
      ),
      TimeoutException('detalle técnico del servidor'),
    ];
    for (final error in transportErrors) {
      test('CP047: desconexión durante ${error.runtimeType}', () async {
        final result = await loginWith((_) async {
          connections = ['none'];
          throw error;
        });
        expectFailure(result, noInternetMessage);
        expect(connectionChecks, 2);
      });
    }

    for (final error in transportErrors.take(2)) {
      test(
        'DNS con Wi-Fi y ${error.runtimeType} no se confunde con offline',
        () async {
          final result = await loginWith((_) async => throw error);
          expectFailure(result, connectionFailedMessage);
        },
      );
    }

    test('Timeout con red informa indisponibilidad del servicio', () async {
      final result = await loginWith(
        (_) async => throw TimeoutException('detalle técnico'),
      );
      expectFailure(result, serverUnavailableMessage);
    });

    test(
      'Un fallo del comprobador de red se comunica sin enviar HTTP',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (_) async {
              throw PlatformException(
                code: 'unavailable',
                message: 'https://example.invalid/internal',
              );
            });
        var requests = 0;
        final result = await loginWith((_) async {
          requests++;
          return loginResponse();
        });
        expectFailure(result, connectionCheckFailedMessage);
        expect(requests, 0);
      },
    );

    for (final status in [401, 403]) {
      test('HU0001-2: HTTP $status mantiene credenciales genéricas', () async {
        final result = await loginWith(
          (_) async => http.Response(
            'Traceback: https://example.invalid/internal',
            status,
          ),
        );
        expectFailure(result, 'Credenciales inválidas.');
      });
    }

    for (final status in [408, 500, 503]) {
      test('HTTP $status no muestra el estado ni el cuerpo técnico', () async {
        final result = await loginWith(
          (_) async => http.Response(
            'Traceback: https://example.invalid/internal',
            status,
          ),
        );
        expectFailure(result, serverUnavailableMessage);
      });
    }

    test('HTTP 422 solicita revisar datos sin mostrar el cuerpo', () async {
      final result = await loginWith(
        (_) async => http.Response('https://example.invalid/internal', 422),
      );
      expectFailure(
        result,
        'No se pudo completar la solicitud. Verifique los datos enviados.',
      );
    });

    for (final body in [
      'Failed host lookup: https://example.invalid',
      '[]',
      '{}',
      '{"access_token":""}',
    ]) {
      test(
        'Una respuesta de autenticación inválida no crea sesión: $body',
        () async {
          final result = await loginWith((_) async => http.Response(body, 200));
          expectFailure(result, loginFailureMessage);
        },
      );
    }

    test('Un error inesperado no expone detalles internos', () async {
      final result = await loginWith(
        (_) async => throw StateError('https://example.invalid/internal'),
      );
      expectFailure(result, loginFailureMessage);
    });

    for (final role in ['MAESTRO', 'DIRECTORA', 'PSICOLOGA']) {
      test('HU0001-1: conserva el acceso válido del rol $role', () async {
        final result = await loginWith(
          (request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/api/v1/auth/login');
            expect(request.headers['Content-Type'], 'application/json');
            expect(request.headers['Accept'], 'application/json');
            expect(jsonDecode(request.body), {
              'email': testEmail,
              'password': ' $testPassword ',
            });
            return loginResponse(role: role);
          },
          email: '  PRUEBA@EDU.COM  ',
          password: ' $testPassword ',
        );
        expect(result.success, isTrue);
        expect(result.user?.rol, role);
        expect(result.user?.accessToken, 'test-token');
        expect(result.expiresInMinutes, 60);
      });
    }

    test('Conserva la duración predeterminada de la sesión', () async {
      final result = await loginWith((_) async => loginResponse(expires: 0));
      expect(result.success, isTrue);
      expect(result.expiresInMinutes, 480);
    });
  });

  Future<void> showLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('disly-staff-login-test-'),
    );
    if (directory == null) fail('No se pudo preparar Hive para la prueba.');
    addTearDown(() async {
      await AutoSyncService.instance.stop();
      await Hive.close();
      await directory.delete(recursive: true);
    });
    await tester.runAsync(() async {
      Hive.init(directory.path);
      await AuthSessionStorage.init();
      await LocalEvaluationStorage.init();
    });
    await tester.pumpWidget(const MaterialApp(home: StaffLoginScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), testEmail);
    await tester.enterText(find.byType(TextField).at(1), testPassword);
    await tester.ensureVisible(find.text('Ingresar'));
    await tester.pumpAndSettle();
  }

  void expectUnauthenticatedForm(WidgetTester tester, String message) {
    expect(find.text(message), findsOneWidget);
    expect(find.byType(StaffLoginScreen), findsOneWidget);
    expect(find.byType(ReportesScreen), findsNothing);
    expect(AuthSessionStorage.getCurrentUserIfValid(), isNull);
    expect(AuthSessionStorage.getAccessTokenIfValid(), isNull);
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[0].controller?.text, testEmail);
    expect(fields[1].controller?.text, testPassword);
    expect(fields.every((field) => field.enabled == true), isTrue);
    final button = tester.widget<FilledButton>(
      find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    expect(button.onPressed, isNotNull);
    expect(find.text('Ingresando...'), findsNothing);
    for (final detail in [
      'ClientException',
      'SocketException',
      'Failed host lookup',
      'https://',
      'Traceback',
    ]) {
      expect(find.textContaining(detail), findsNothing);
    }
    expect(tester.takeException(), isNull);
  }

  Future<void> waitForWrite(WidgetTester tester, Future<void> write) async {
    var pending = true;
    final pumping = () async {
      while (pending) {
        await tester.pump();
        await Future<void>.delayed(Duration.zero);
      }
    }();
    try {
      await write.timeout(const Duration(seconds: 5));
    } finally {
      pending = false;
      await pumping;
    }
  }

  group('Pantalla de inicio de sesión', () {
    testWidgets(
      'Al ingresar reintenta una evaluación completa con el nuevo token',
      (tester) async {
        late String sessionId;
        Map<String, dynamic>? sent;
        await http.runWithClient(
          () async {
            await showLogin(tester);
            await tester.runAsync(
              () => waitForWrite(tester, () async {
                sessionId = await LocalEvaluationStorage.createSession(
                  estudianteId: 1,
                  tipoPrueba: 'LECTURA',
                  totalItems: 10,
                  nivelDificultadAplicado: 1,
                  totalBaja: 10,
                );
                for (var index = 0; index < 10; index++) {
                  await LocalEvaluationStorage.saveDetail(
                    localSessionId: sessionId,
                    detail: LocalEvaluationDetail(
                      stimulusId: 'test-$index',
                      texto: 'casa',
                      tipoPrueba: 'LECTURA',
                      tiempoRespuestaMs: 2000,
                      duracionDragDropMs: null,
                      tapsErroneos: 0,
                      tipoError: null,
                      complejidadEstimulo: 'BAJA',
                      acierto: true,
                    ),
                  );
                }
                await LocalEvaluationStorage.finishSession(
                  localSessionId: sessionId,
                  totalItems: 10,
                  aciertosPrimerIntento: 10,
                  tapsErroneosTotales: 0,
                  tiempoPromedioMs: 2000,
                );
              }()),
            );
            expect(AuthSessionStorage.hasValidSession(), isFalse);
            expect(
              LocalEvaluationStorage.countCompletedPendingSyncSessions(),
              1,
            );
            await tester.tap(find.text('Ingresar'));
            await tester.runAsync(() async {
              final clock = Stopwatch()..start();
              while (sent == null ||
                  AutoSyncService.instance.status.value.phase !=
                      AutoSyncPhase.synced ||
                  find.byType(ReportesScreen).evaluate().isEmpty ||
                  find
                      .byType(CircularProgressIndicator)
                      .evaluate()
                      .isNotEmpty) {
                if (clock.elapsed > const Duration(seconds: 5)) {
                  fail(
                    'No se confirmó el envío posterior al inicio de sesión.',
                  );
                }
                await tester.pump(const Duration(milliseconds: 16));
                await Future<void>.delayed(Duration.zero);
              }
            });
            await tester.pumpAndSettle();
            expect(
              (sent!['sessions'] as List).single['local_session_id'],
              sessionId,
            );
            expect((sent!['details'] as List).length, 10);
            expect(
              LocalEvaluationStorage.countCompletedPendingSyncSessions(),
              0,
            );
            expect(find.byType(ReportesScreen), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.runAsync(() => waitForWrite(tester, Hive.close()));
          },
          () => MockClient((request) async {
            if (request.url.path == '/api/v1/auth/login') {
              return loginResponse();
            }
            if (request.url.path == '/health') return http.Response('{}', 200);
            expect(request.headers['Authorization'], 'Bearer test-token');
            if (request.url.path.endsWith('/sync')) {
              sent = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response(
                jsonEncode({
                  'status': 'ok',
                  'sessions_received': 1,
                  'details_received': 10,
                  'evaluations_inserted': 1,
                  'details_inserted': 10,
                  'synced': [
                    {
                      'local_session_id': sessionId,
                      'evaluacion_id': 1,
                      'details_inserted': 10,
                      'details_confirmed': 10,
                    },
                  ],
                }),
                200,
              );
            }
            if (request.url.path.endsWith('/resumen-semaforo')) {
              return http.Response(
                '{"total_evaluaciones":0,"semaforos":[]}',
                200,
              );
            }
            expect(request.url.path.endsWith('/evaluaciones'), isTrue);
            return http.Response('[]', 200);
          }),
        );
      },
    );

    testWidgets(
      'CP047: sin sesión ni HTTP, conserva datos y reintenta con red',
      (tester) async {
        connections = ['none'];
        var loginRequests = 0;
        await http.runWithClient(
          () async {
            await showLogin(tester);
            await tester.tap(find.text('Ingresar'));
            await tester.pumpAndSettle();
            expectUnauthenticatedForm(tester, noInternetMessage);
            expect(loginRequests, 0);

            connections = ['wifi'];
            await tester.ensureVisible(find.text('Ingresar'));
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              final saved = Hive.box('staff_auth_session').watch().first;
              await tester.tap(find.text('Ingresar'));
              await saved.timeout(const Duration(seconds: 5));
              await Hive.box('staff_auth_session').flush();
            });
            await tester.pumpAndSettle();
            expect(loginRequests, 1);
            expect(AuthSessionStorage.hasValidSession(), isTrue);
            expect(AuthSessionStorage.getAccessTokenIfValid(), 'test-token');
            expect(AuthSessionStorage.getCurrentUserIfValid()?.rol, 'MAESTRO');
            expect(find.byType(ReportesScreen), findsOneWidget);
            expect(find.byType(StaffLoginScreen), findsNothing);
            expect(find.text(noInternetMessage), findsNothing);
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) async {
            if (request.url.path == '/api/v1/auth/login') {
              loginRequests++;
              return loginResponse();
            }
            expect(request.headers['Authorization'], 'Bearer test-token');
            if (request.url.path.endsWith('/resumen-semaforo')) {
              return http.Response(
                '{"total_evaluaciones":0,"semaforos":[]}',
                200,
              );
            }
            expect(request.url.path.endsWith('/evaluaciones'), isTrue);
            return http.Response('[]', 200);
          }),
        );
      },
    );

    final failures = <String, (String, Future<http.Response> Function())>{
      'desconexión durante el envío': (
        noInternetMessage,
        () async {
          connections = ['none'];
          throw const SocketException('Failed host lookup: example.invalid');
        },
      ),
      'DNS con Wi-Fi': (
        connectionFailedMessage,
        () async => throw http.ClientException(
          'SocketException: Failed host lookup',
          Uri.parse('https://example.invalid'),
        ),
      ),
      'credenciales inválidas': (
        'Credenciales inválidas.',
        () async => http.Response('https://example.invalid/internal', 401),
      ),
      'servidor no disponible': (
        serverUnavailableMessage,
        () async => http.Response('Traceback: https://example.invalid', 503),
      ),
      'respuesta inválida': (
        loginFailureMessage,
        () async => http.Response('https://example.invalid/internal', 200),
      ),
    };
    for (final scenario in failures.entries) {
      testWidgets('${scenario.key}: mensaje seguro y ninguna sesión guardada', (
        tester,
      ) async {
        var requests = 0;
        await http.runWithClient(
          () async {
            await showLogin(tester);
            await tester.tap(find.text('Ingresar'));
            await tester.pumpAndSettle();
            expectUnauthenticatedForm(tester, scenario.value.$1);
            expect(requests, 1);
          },
          () => MockClient((_) async {
            requests++;
            return scenario.value.$2();
          }),
        );
      });
    }
  });
}
