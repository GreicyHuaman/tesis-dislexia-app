import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/models/auth_user.dart';
import 'package:mobile/core/models/local_evaluation_detail.dart';
import 'package:mobile/core/repositories/auth_session_storage.dart';
import 'package:mobile/core/repositories/local_evaluation_storage.dart';
import 'package:mobile/core/services/auto_sync_service.dart';
import 'package:mobile/core/services/connection_errors.dart';
import 'package:mobile/core/services/evaluation_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const service = EvaluationSyncService(baseUrl: 'https://example.invalid');
  var connections = <String>['wifi'];
  late Directory temporaryDirectory;
  late String localSessionId;

  Future<void> saveStaffSession({
    int minutes = 480,
    String token = 'test-token',
  }) => AuthSessionStorage.saveSession(
    user: AuthUser(
      id: 1,
      nombres: 'Personal',
      apellidos: 'Prueba',
      email: 'ficticio@edu.com',
      rol: 'MAESTRO',
      gradoScope: null,
      activo: true,
      accessToken: token,
    ),
    expiresInMinutes: minutes,
  );

  setUp(() async {
    connections = ['wifi'];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'check');
          return connections;
        });
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'disly-connection-test-',
    );
    Hive.init(temporaryDirectory.path);
    await LocalEvaluationStorage.init();
    await AuthSessionStorage.init();
    await saveStaffSession();
    localSessionId = await LocalEvaluationStorage.createSession(
      tipoPrueba: 'LECTURA',
      totalItems: 1,
      nivelDificultadAplicado: 1,
      totalBaja: 1,
    );
    await LocalEvaluationStorage.saveDetail(
      localSessionId: localSessionId,
      detail: const LocalEvaluationDetail(
        stimulusId: 'test-1',
        texto: 'casa',
        tipoPrueba: 'LECTURA',
        tiempoRespuestaMs: 2000,
        duracionDragDropMs: null,
        tapsErroneos: 1,
        tipoError: 'SELECCION_INCORRECTA',
        complejidadEstimulo: 'BAJA',
        acierto: false,
      ),
    );
    await LocalEvaluationStorage.finishSession(
      localSessionId: localSessionId,
      totalItems: 1,
      aciertosPrimerIntento: 0,
      tapsErroneosTotales: 1,
      tiempoPromedioMs: 2000,
    );
  });

  tearDown(() async {
    await AutoSyncService.instance.stop();
    await Hive.close();
    await temporaryDirectory.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void expectPending() {
    expect(LocalEvaluationStorage.countCompletedPendingSyncSessions(), 1);
    expect(LocalEvaluationStorage.getAllDetails().single['taps_erroneos'], 1);
    expect(
      LocalEvaluationStorage.getAllDetails().single['sync_status'],
      'PENDING',
    );
  }

  test(
    'CP024 sincronización sin red no envía ni pierde evaluaciones',
    () async {
      connections = ['none'];
      var requests = 0;
      await http.runWithClient(
        () async {
          final result = await service.syncPendingEvaluations();
          expect(result.success, isFalse);
          expect(result.message, noInternetMessage);
          expect(result.sessionsSynced, 0);
          expectPending();
        },
        () => MockClient((_) async {
          requests++;
          return http.Response('', 200);
        }),
      );
      expect(requests, 0);
    },
  );

  test(
    'La sincronización automática muestra el mensaje CP024 sin red',
    () async {
      connections = ['none'];
      await AutoSyncService.instance.checkAndSync();
      expect(
        AutoSyncService.instance.status.value.phase,
        AutoSyncPhase.offline,
      );
      expect(AutoSyncService.instance.status.value.message, noInternetMessage);
      expectPending();
    },
  );

  test('Un servidor no disponible conserva los datos pendientes', () async {
    await http.runWithClient(
      () async {
        final result = await service.syncPendingEvaluations();
        expect(result.success, isFalse);
        expect(result.message, serverUnavailableMessage);
        expectPending();
      },
      () => MockClient((request) async {
        expect(request.url.path, '/health');
        return http.Response('https://example.invalid/technical-details', 503);
      }),
    );
  });

  test('Si la conexión cae tras health no se envían evaluaciones', () async {
    var posts = 0;
    await http.runWithClient(
      () async {
        final result = await service.syncPendingEvaluations();
        expect(result.success, isFalse);
        expect(result.message, noInternetMessage);
        expectPending();
      },
      () => MockClient((request) async {
        if (request.method == 'POST') posts++;
        connections = ['none'];
        return http.Response('{}', 200);
      }),
    );
    expect(posts, 0);
  });

  test(
    'HTTP 500 al enviar no se anuncia como sincronización exitosa',
    () async {
      await http.runWithClient(
        () async {
          final result = await service.syncPendingEvaluations();
          expect(result.success, isFalse);
          expect(result.message, serverUnavailableMessage);
          expectPending();
        },
        () => MockClient(
          (request) async => request.url.path == '/health'
              ? http.Response('{}', 200)
              : http.Response('Traceback: https://example.invalid', 500),
        ),
      );
    },
  );

  test(
    'Una respuesta inválida no muestra datos técnicos ni elimina pendientes',
    () async {
      await http.runWithClient(
        () async {
          final result = await service.syncPendingEvaluations();
          expect(result.success, isFalse);
          expect(result.message, contains('No se pudo sincronizar.'));
          expect(result.message, isNot(contains('https://')));
          expectPending();
        },
        () => MockClient(
          (request) async => request.url.path == '/health'
              ? http.Response('{}', 200)
              : http.Response('https://example.invalid/technical-details', 200),
        ),
      );
    },
  );

  test('Al restablecer la conexión se envían los datos conservados', () async {
    connections = ['none'];
    final postedBodies = <Map<String, dynamic>>[];
    await http.runWithClient(
      () async {
        expect((await service.syncPendingEvaluations()).success, isFalse);
        expect(postedBodies, isEmpty);
        expectPending();
        connections = ['wifi'];
        final result = await service.syncPendingEvaluations();
        expect(result.success, isTrue);
        expect(result.sessionsSynced, 1);
        expect(result.detailsSynced, 1);
        expect(LocalEvaluationStorage.countCompletedPendingSyncSessions(), 0);
        expect(postedBodies, hasLength(1));
        expect(
          (postedBodies.single['details'] as List).single['taps_erroneos'],
          1,
        );
      },
      () => MockClient((request) async {
        if (request.url.path == '/health') return http.Response('{}', 200);
        postedBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(
          jsonEncode({
            'status': 'ok',
            'sessions_received': 1,
            'details_received': 1,
            'evaluations_inserted': 1,
            'details_inserted': 1,
            'synced': <Map<String, dynamic>>[
              {
                'local_session_id': localSessionId,
                'evaluacion_id': 1,
                'details_inserted': 1,
                'details_confirmed': 1,
              },
            ],
          }),
          200,
        );
      }),
    );
  });

  Map<String, dynamic> acknowledgement({bool replay = false}) => {
    'status': 'ok',
    'sessions_received': 1,
    'details_received': 1,
    'evaluations_inserted': replay ? 0 : 1,
    'details_inserted': replay ? 0 : 1,
    'synced': <Map<String, dynamic>>[
      {
        'local_session_id': localSessionId,
        'evaluacion_id': 1,
        'details_inserted': replay ? 0 : 1,
        'details_confirmed': 1,
      },
    ],
  };

  Future<EvaluationSyncResult> replyWith(Object body, {int status = 200}) =>
      http.runWithClient(
        () => service.syncPendingEvaluations(),
        () => MockClient(
          (request) async => request.url.path == '/health'
              ? http.Response('{}', 200)
              : http.Response(jsonEncode(body), status),
        ),
      );

  for (final expired in [false, true]) {
    test(
      'Sin sesión válida conserva pendientes y no envía POST: caducada=$expired',
      () async {
        if (expired) {
          await saveStaffSession(minutes: -1);
        } else {
          await AuthSessionStorage.clearSession();
        }
        var posts = 0;
        final result = await http.runWithClient(
          () => service.syncPendingEvaluations(),
          () => MockClient((request) async {
            if (request.method == 'POST') posts++;
            return http.Response('{}', 200);
          }),
        );
        expect(result.success, isFalse);
        expect(result.message, EvaluationSyncService.sessionRequiredMessage);
        expect(posts, 0);
        expectPending();
      },
    );
  }

  test(
    'HTTP 401 conserva evaluaciones y permite enviar tras renovar sesión',
    () async {
      final rejected = await replyWith({}, status: 401);
      expect(rejected.success, isFalse);
      expect(rejected.message, EvaluationSyncService.sessionRequiredMessage);
      expect(AuthSessionStorage.hasValidSession(), isFalse);
      expectPending();
      await saveStaffSession();
      final sent = await replyWith(acknowledgement());
      expect(sent.success, isTrue);
      expect(LocalEvaluationStorage.countCompletedPendingSyncSessions(), 0);
    },
  );

  test(
    'Un 401 tardío no elimina una sesión institucional recién renovada',
    () async {
      final result = await http.runWithClient(
        () => service.syncPendingEvaluations(),
        () => MockClient((request) async {
          if (request.url.path == '/health') return http.Response('{}', 200);
          await saveStaffSession(token: 'renewed-test-token');
          return http.Response('{}', 401);
        }),
      );
      expect(result.success, isFalse);
      expect(AuthSessionStorage.getAccessTokenIfValid(), 'renewed-test-token');
      expectPending();
    },
  );

  for (final error in [
    PlatformException(code: 'connection-test'),
    MissingPluginException('connection-test'),
  ]) {
    test(
      'Fallo ${error.runtimeType} de conectividad se informa y conserva pendientes',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (_) async => throw error);
        await AutoSyncService.instance.checkAndSync(reason: 'test');
        expect(
          AutoSyncService.instance.status.value.phase,
          AutoSyncPhase.error,
        );
        expect(
          AutoSyncService.instance.status.value.message,
          connectionCheckFailedMessage,
        );
        expectPending();
      },
    );
  }

  for (final status in [403, 409, 422]) {
    test(
      'HTTP $status conserva pendientes para revisión sin cerrar la sesión',
      () async {
        final result = await replyWith({
          'detail': 'https://example.invalid/internal',
        }, status: status);
        expect(result.success, isFalse);
        expect(result.message, isNot(contains('https://')));
        expect(AuthSessionStorage.hasValidSession(), isTrue);
        expectPending();
      },
    );
  }

  final invalidReplies = <String, Object>{
    'objeto vacío': {},
    'lista': [],
    'sin confirmaciones': {
      'status': 'ok',
      'sessions_received': 1,
      'details_received': 1,
      'evaluations_inserted': 0,
      'details_inserted': 0,
      'synced': [],
    },
  };
  for (final entry in invalidReplies.entries) {
    test('HTTP 200 con ${entry.key} no marca ninguna sesión', () async {
      final result = await replyWith(entry.value);
      expect(result.success, isFalse);
      expectPending();
    });
  }

  for (final field in [
    'status',
    'sessions_received',
    'details_received',
    'evaluations_inserted',
    'details_inserted',
    'synced',
  ]) {
    test('Acuse sin $field no elimina pendientes', () async {
      final response = acknowledgement()..remove(field);
      expect((await replyWith(response)).success, isFalse);
      expectPending();
    });
  }

  for (final field in ['sessions_received', 'details_received']) {
    test('El contador $field debe ser un entero del protocolo', () async {
      final response = acknowledgement()..[field] = 1.0;
      expect((await replyWith(response)).success, isFalse);
      expectPending();
    });
  }

  for (final entry in <String, Object>{
    'local_session_id': 'unknown',
    'evaluacion_id': 0,
    'details_confirmed': 0,
    'details_inserted': 2,
    'nivel_lectura': 4,
  }.entries) {
    test(
      'Acuse con ${entry.key} inconsistente no cambia el progreso',
      () async {
        final response = acknowledgement();
        (response['synced'] as List<Map<String, dynamic>>).single[entry.key] =
            entry.value;
        expect((await replyWith(response)).success, isFalse);
        expectPending();
      },
    );
  }

  test(
    'Acuses duplicados o ajenos invalidan toda la respuesta antes de modificar Hive',
    () async {
      for (final unknown in [false, true]) {
        final response = acknowledgement();
        final items = response['synced'] as List<Map<String, dynamic>>;
        items.add({
          ...items.single,
          if (unknown) 'local_session_id': 'unknown',
        });
        expect((await replyWith(response)).success, isFalse);
        expectPending();
      }
    },
  );

  test(
    'Un reenvío ya recibido confirma datos sin exigir nuevas inserciones',
    () async {
      final result = await replyWith(acknowledgement(replay: true));
      expect(result.success, isTrue);
      expect(result.sessionsSynced, 1);
      expect(result.detailsSynced, 1);
      await Hive.close();
      await LocalEvaluationStorage.init();
      expect(LocalEvaluationStorage.countCompletedPendingSyncSessions(), 0);
      expect(
        LocalEvaluationStorage.getAllDetails().single['sync_status'],
        'SYNCED',
      );
    },
  );

  test(
    'Solo marca la sesión confirmada cuando falta otra confirmación del lote',
    () async {
      final second = await LocalEvaluationStorage.createSession(
        tipoPrueba: 'LECTURA',
        totalItems: 1,
      );
      final detail = LocalEvaluationStorage.getAllDetails().single;
      await LocalEvaluationStorage.saveDetail(
        localSessionId: second,
        detail: LocalEvaluationDetail.fromJson(detail),
      );
      await LocalEvaluationStorage.finishSession(
        localSessionId: second,
        totalItems: 1,
        aciertosPrimerIntento: 0,
        tapsErroneosTotales: 1,
        tiempoPromedioMs: 2000,
      );
      final response = acknowledgement()
        ..['sessions_received'] = 2
        ..['details_received'] = 2;
      final result = await replyWith(response);
      expect(result.success, isFalse);
      expect(result.sessionsSynced, 1);
      expect(LocalEvaluationStorage.countCompletedPendingSyncSessions(), 1);
      expect(LocalEvaluationStorage.getPendingSyncPayload()['sessions'], [
        isA<Map<String, dynamic>>().having(
          (item) => item['local_session_id'],
          'id',
          second,
        ),
      ]);
      expect(
        LocalEvaluationStorage.getDetailsBySession(
          second,
        ).single['sync_status'],
        'PENDING',
      );
    },
  );
}
