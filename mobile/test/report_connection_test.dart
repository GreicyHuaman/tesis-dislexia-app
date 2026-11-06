import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/services/connection_errors.dart';
import 'package:mobile/core/services/report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  var connections = <String>['wifi'];
  const service = ReportService(baseUrl: 'https://example.invalid');
  final operations = <String, Future<Object> Function()>{
    'resumen': () => service.fetchResumenSemaforo(),
    'evaluaciones': () => service.fetchEvaluaciones(),
    'perfil': () => service.fetchStudentRiskProfile(estudianteId: 1),
    'CSV': () => service.downloadEvaluacionesCsv(authToken: 'test-token'),
  };

  TypeMatcher<RequestFailure> failure(String message) => isA<RequestFailure>()
      .having((error) => error.message, 'mensaje', message);

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

  for (final operation in operations.entries) {
    test('CP024 ${operation.key}: sin red no envía solicitudes', () async {
      connections = ['none'];
      var requests = 0;
      await http.runWithClient(
        () =>
            expectLater(operation.value(), throwsA(failure(noInternetMessage))),
        () => MockClient((_) async {
          requests++;
          return http.Response('', 200);
        }),
      );
      expect(requests, 0);
    });

    test('HU0024 ${operation.key}: HTTP 503 no expone el cuerpo', () async {
      await http.runWithClient(
        () => expectLater(
          operation.value(),
          throwsA(
            failure(
              serverUnavailableMessage,
            ).having((error) => error.statusCode, 'estado', 503),
          ),
        ),
        () => MockClient(
          (_) async =>
              http.Response('Traceback: https://example.invalid/internal', 503),
        ),
      );
    });
  }

  test('Timeout con red disponible indica servicio no disponible', () async {
    await http.runWithClient(
      () => expectLater(
        service.fetchEvaluaciones(),
        throwsA(failure(serverUnavailableMessage)),
      ),
      () => MockClient((_) async => throw TimeoutException('timeout técnico')),
    );
  });

  test(
    'Una desconexión durante la solicitud muestra el mensaje CP024',
    () async {
      await http.runWithClient(
        () => expectLater(
          service.fetchEvaluaciones(),
          throwsA(failure(noInternetMessage)),
        ),
        () => MockClient((_) async {
          connections = ['none'];
          throw const SocketException('Failed host lookup: example.invalid');
        }),
      );
    },
  );

  test(
    'Una desconexión durante un timeout no se confunde con servidor',
    () async {
      await http.runWithClient(
        () => expectLater(
          service.fetchEvaluaciones(),
          throwsA(failure(noInternetMessage)),
        ),
        () => MockClient((_) async {
          connections = ['none'];
          throw TimeoutException('timeout técnico');
        }),
      );
    },
  );

  test('Un fallo DNS con Wi-Fi no diagnostica falta de Internet', () async {
    await http.runWithClient(
      () => expectLater(
        service.fetchStudentRiskProfile(estudianteId: 1),
        throwsA(failure(connectionFailedMessage)),
      ),
      () => MockClient(
        (_) async => throw http.ClientException(
          'SocketException: Failed host lookup',
          Uri.parse('https://example.invalid'),
        ),
      ),
    );
  });

  for (final status in [401, 403, 404, 422]) {
    test(
      'HTTP $status conserva la causa sin mostrar detalles técnicos',
      () async {
        await http.runWithClient(
          () => expectLater(
            service.fetchEvaluaciones(),
            throwsA(
              isA<RequestFailure>()
                  .having((error) => error.statusCode, 'estado', status)
                  .having(
                    (error) => error.toString().contains('example.invalid'),
                    'sin URL',
                    isFalse,
                  ),
            ),
          ),
          () => MockClient(
            (_) async =>
                http.Response('https://example.invalid/internal', status),
          ),
        );
      },
    );
  }

  test(
    'Un fallo de la comprobación de red se comunica explícitamente',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(
              code: 'unavailable',
              message: 'detalle interno',
            );
          });
      var requests = 0;
      await http.runWithClient(
        () => expectLater(
          service.fetchEvaluaciones(),
          throwsA(failure(connectionCheckFailedMessage)),
        ),
        () => MockClient((_) async {
          requests++;
          return http.Response('', 200);
        }),
      );
      expect(requests, 0);
    },
  );

  test(
    'La descarga CSV conserva los filtros y el contenido recibido',
    () async {
      await http.runWithClient(
        () async {
          final result = await service.downloadEvaluacionesCsv(
            authToken: 'test-token',
            filters: const ReportFilters(
              tipoPrueba: 'LECTURA',
              estudianteId: 1,
            ),
          );
          expect(String.fromCharCodes(result.bytes), 'id,total_items\n1,10\n');
          expect(
            result.filename,
            startsWith('reporte_evaluaciones_lectura_estudiante_1_'),
          );
        },
        () => MockClient((request) async {
          expect(request.url.queryParameters['tipo_prueba'], 'LECTURA');
          expect(request.url.queryParameters['estudiante_id'], '1');
          expect(request.headers['Accept'], 'text/csv');
          return http.Response('id,total_items\n1,10\n', 200);
        }),
      );
    },
  );
}
