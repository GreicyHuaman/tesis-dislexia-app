import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobile/core/models/local_evaluation_detail.dart';
import 'package:mobile/core/repositories/local_evaluation_storage.dart';
import 'package:mobile/core/services/assessment_progress_tracker.dart';
import 'package:mobile/features/fonologia/screens/fonologia_assessment_screen.dart';
import 'package:mobile/features/home/screens/student_test_completed_screen.dart';
import 'package:mobile/features/home/screens/test_selection_screen.dart';
import 'package:mobile/features/lectura/screens/lectura_assessment_screen.dart';

List<Map<String, dynamic>> plan(String tipo) => List.generate(
  10,
  (index) => {
    'id': '$tipo-$index',
    'tipo_prueba': tipo,
    'complejidad_estimulo': index < 6 ? 'BAJA' : 'MEDIA',
    if (tipo == 'LECTURA')
      'texto': 'palabra$index'
    else ...{
      'palabra': 'palabra$index',
      'silaba_objetivo': 'sa',
      'opciones': ['ma', 'sa', 'pa'],
      'tipo_estimulo': 'PALABRA_REAL',
    },
  },
);

List<List<String>> options(String tipo) => List.generate(
  10,
  (index) => tipo == 'LECTURA'
      ? ['otra$index', 'palabra$index', 'distinta$index']
      : ['ma', 'sa', 'pa'],
);

LocalEvaluationDetail answer(String tipo, int index, {int errors = 0}) =>
    LocalEvaluationDetail(
      stimulusId: '$tipo-$index',
      texto: tipo == 'LECTURA'
          ? 'palabra$index'
          : 'PALABRA_REAL|palabra$index|sa',
      tipoPrueba: tipo,
      tiempoRespuestaMs: 1200,
      duracionDragDropMs: tipo == 'LECTURA' ? null : 1200,
      tapsErroneos: errors,
      tipoError: errors == 0
          ? null
          : tipo == 'LECTURA'
          ? 'SELECCION_INCORRECTA'
          : 'DRAG_DROP_INCORRECTO',
      complejidadEstimulo: index < 6 ? 'BAJA' : 'MEDIA',
      acierto: errors == 0,
    );

Future<String> createDraft(
  String tipo, {
  int studentId = 1,
  int count = 0,
}) async {
  final id = await LocalEvaluationStorage.createSession(
    tipoPrueba: tipo,
    totalItems: 10,
    estudianteId: studentId,
    nivelDificultadAplicado: 2,
    totalBaja: 6,
    totalMedia: 4,
    assessmentItems: plan(tipo),
    assessmentOptions: options(tipo),
  );
  for (var index = 0; index < count; index++) {
    await LocalEvaluationStorage.saveAssessmentAnswer(
      sessionId: id,
      itemIndex: index,
      detail: answer(tipo, index),
    );
  }
  return id;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('disly-resume-test-');
    Hive.init(directory.path);
    await LocalEvaluationStorage.init();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => ['none']);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final tipo in ['LECTURA', 'FONOLOGIA']) {
    for (final count in [3, 8]) {
      test(
        '$tipo conserva $count/10 y no permite finalizar ni sincronizar',
        () async {
          final id = await createDraft(tipo, count: count);
          final before = LocalEvaluationStorage.getAssessment(id);
          await LocalEvaluationStorage.saveCurrentItemState(
            sessionId: id,
            itemIndex: count,
            errors: 2,
            elapsedMs: 1500,
          );
          await Hive.close();
          await LocalEvaluationStorage.init();
          final restored = LocalEvaluationStorage.getIncompleteAssessment(
            estudianteId: 1,
            tipoPrueba: tipo,
          )!;
          expect(restored.sessionId, id);
          expect(restored.items, before.items);
          expect(restored.options, before.options);
          expect(restored.answeredItems, count);
          expect(restored.remainingItems, 10 - count);
          expect(restored.nivelAplicado, 2);
          expect(restored.currentErrors, 2);
          expect(restored.currentElapsedMs, 1500);
          expect(
            restored.answers.map((item) => item.toJson()).toList(),
            before.answers.map((item) => item.toJson()).toList(),
          );
          for (final total in [count, 10]) {
            await expectLater(
              LocalEvaluationStorage.finishSession(
                localSessionId: id,
                totalItems: total,
                aciertosPrimerIntento: count,
                tapsErroneosTotales: 0,
                tiempoPromedioMs: 1200,
              ),
              throwsStateError,
            );
          }
          final session = LocalEvaluationStorage.getAllSessions().single;
          expect(session['fecha_fin'], isNull);
          expect(session['sync_status'], 'PENDING');
          expect(
            LocalEvaluationStorage.getPendingSyncPayload()['sessions'],
            isEmpty,
          );
          expect(
            LocalEvaluationStorage.getPendingSyncPayload()['details'],
            isEmpty,
          );
          expect(LocalEvaluationStorage.getAllDetails(), hasLength(count));
        },
      );
    }

    test(
      '$tipo guarda diez respuestas sin duplicar y completa una sola sesión',
      () async {
        final id = await createDraft(tipo, count: 8);
        for (var index = 8; index < 10; index++) {
          for (var repetition = 0; repetition < 2; repetition++) {
            await LocalEvaluationStorage.saveAssessmentAnswer(
              sessionId: id,
              itemIndex: index,
              detail: answer(tipo, index),
            );
          }
        }
        expect(LocalEvaluationStorage.getAllDetails(), hasLength(10));
        await LocalEvaluationStorage.finishSession(
          localSessionId: id,
          totalItems: 10,
          aciertosPrimerIntento: 10,
          tapsErroneosTotales: 0,
          tiempoPromedioMs: 1200,
        );
        final finished = LocalEvaluationStorage.getAllSessions().single;
        await LocalEvaluationStorage.finishSession(
          localSessionId: id,
          totalItems: 10,
          aciertosPrimerIntento: 10,
          tapsErroneosTotales: 0,
          tiempoPromedioMs: 1200,
        );
        expect(
          LocalEvaluationStorage.getAllSessions().single['fecha_fin'],
          finished['fecha_fin'],
        );
        expect(LocalEvaluationStorage.countCompletedPendingSyncSessions(), 1);
        expect(
          LocalEvaluationStorage.getIncompleteAssessment(
            estudianteId: 1,
            tipoPrueba: tipo,
          ),
          isNull,
        );
        final payload = LocalEvaluationStorage.getPendingSyncPayload();
        final sessions = payload['sessions'] as List<Map<String, dynamic>>;
        expect(sessions, hasLength(1));
        expect(sessions.single['total_items'], 10);
        for (final field in [
          'assessment_plan',
          'answered_items',
          'current_item_state',
        ]) {
          expect(sessions.single.containsKey(field), isFalse);
        }
        expect(payload['details'], hasLength(10));
        expect(
          LocalEvaluationStorage.getAllSessions().single.containsKey(
            'assessment_plan',
          ),
          isTrue,
        );
        await LocalEvaluationStorage.markSessionsAsSynced([id]);
        expect(
          LocalEvaluationStorage.getPendingSyncPayload()['sessions'],
          isEmpty,
        );
        expect(await createDraft(tipo), isNot(id));
      },
    );
  }

  test(
    'Aísla estudiante y tipo, y reutiliza un borrador ya iniciado',
    () async {
      final lectura = await createDraft('LECTURA', count: 3);
      final fonologia = await createDraft('FONOLOGIA', count: 8);
      final otro = await createDraft('LECTURA', studentId: 2, count: 1);
      expect(await createDraft('LECTURA'), lectura);
      expect(LocalEvaluationStorage.getAllSessions(), hasLength(3));
      expect(
        LocalEvaluationStorage.getIncompleteAssessment(
          estudianteId: 1,
          tipoPrueba: 'FONOLOGIA',
        )?.sessionId,
        fonologia,
      );
      expect(
        LocalEvaluationStorage.getIncompleteAssessment(
          estudianteId: 2,
          tipoPrueba: 'LECTURA',
        )?.sessionId,
        otro,
      );
      expect(
        LocalEvaluationStorage.getIncompleteAssessment(
          estudianteId: 3,
          tipoPrueba: 'LECTURA',
        ),
        isNull,
      );
    },
  );

  test(
    'Repara detalles tras una interrupción entre las dos cajas Hive',
    () async {
      final id = await createDraft('LECTURA', count: 3);
      await Hive.box('evaluation_details').delete('$id:2');
      await Hive.close();
      await LocalEvaluationStorage.init();
      expect(LocalEvaluationStorage.getAssessment(id).answeredItems, 3);
      await LocalEvaluationStorage.restoreAssessmentDetails(id);
      await LocalEvaluationStorage.restoreAssessmentDetails(id);
      expect(LocalEvaluationStorage.getAllDetails(), hasLength(3));
      expect(LocalEvaluationStorage.getAssessment(id).answeredItems, 3);
    },
  );

  test(
    'Un checkpoint atrasado no pierde respuestas ni reduce intentos/tiempo',
    () async {
      final id = await createDraft('LECTURA');
      await LocalEvaluationStorage.saveCurrentItemState(
        sessionId: id,
        itemIndex: 0,
        errors: 3,
        elapsedMs: 2500,
      );
      await LocalEvaluationStorage.saveCurrentItemState(
        sessionId: id,
        itemIndex: 0,
        errors: 1,
        elapsedMs: 500,
      );
      expect(LocalEvaluationStorage.getAssessment(id).currentErrors, 3);
      expect(LocalEvaluationStorage.getAssessment(id).currentElapsedMs, 2500);
      await LocalEvaluationStorage.saveAssessmentAnswer(
        sessionId: id,
        itemIndex: 0,
        detail: answer('LECTURA', 0, errors: 3),
      );
      expect(
        await LocalEvaluationStorage.saveCurrentItemState(
          sessionId: id,
          itemIndex: 0,
          errors: 4,
          elapsedMs: 3000,
        ),
        isFalse,
      );
      expect(LocalEvaluationStorage.getAssessment(id).answeredItems, 1);
      expect(LocalEvaluationStorage.getAssessment(id).currentErrors, 0);
    },
  );

  test(
    'No acepta respuestas de otro ítem ni finaliza una sesión inexistente',
    () async {
      final id = await createDraft('LECTURA');
      await expectLater(
        LocalEvaluationStorage.saveAssessmentAnswer(
          sessionId: id,
          itemIndex: 0,
          detail: answer('LECTURA', 1),
        ),
        throwsStateError,
      );
      await expectLater(
        LocalEvaluationStorage.saveAssessmentAnswer(
          sessionId: id,
          itemIndex: 1,
          detail: answer('LECTURA', 1),
        ),
        throwsStateError,
      );
      await expectLater(
        LocalEvaluationStorage.finishSession(
          localSessionId: 'inexistente',
          totalItems: 10,
          aciertosPrimerIntento: 0,
          tapsErroneosTotales: 0,
          tiempoPromedioMs: 0,
        ),
        throwsStateError,
      );
      expect(LocalEvaluationStorage.getAssessment(id).answeredItems, 0);
    },
  );

  test(
    'El reloj recupera tiempo activo sin contar la pausa de la aplicación',
    () async {
      final id = await createDraft('LECTURA', count: 3);
      var errors = 0;
      final tracker = AssessmentProgressTracker(
        sessionId: id,
        onSaveError: () => errors++,
      );
      tracker.startItem(index: 3, savedErrors: 2, savedElapsedMs: 1400);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      tracker.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Hive.box('evaluation_sessions').flush();
      final pausedTime = tracker.elapsedMs;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(tracker.elapsedMs, pausedTime);
      await tracker.checkpoint();
      expect(
        LocalEvaluationStorage.getAssessment(id).currentElapsedMs,
        pausedTime,
      );
      expect(LocalEvaluationStorage.getAssessment(id).currentErrors, 2);
      expect(pausedTime, greaterThanOrEqualTo(1400));
      tracker.dispose();
      await Hive.box('evaluation_sessions').flush();
      expect(errors, 0);
    },
  );

  Widget selection({int studentId = 1}) => MaterialApp(
    home: TestSelectionScreen(
      estudianteId: studentId,
      studentDisplayName: 'Estudiante de prueba',
      nivelLectura: 3,
      nivelFonologia: 3,
    ),
  );

  Future<void> waitForWrite(WidgetTester tester, Future<dynamic> write) async {
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

  Future<void> waitForUi(WidgetTester tester, bool Function() condition) async {
    final clock = Stopwatch()..start();
    while (!condition()) {
      if (clock.elapsed > const Duration(seconds: 5)) {
        fail('La pantalla no terminó de guardar el avance.');
      }
      await tester.pump();
      await Future<void>.delayed(Duration.zero);
    }
  }

  bool readyForAnswer(WidgetTester tester, String tipo) {
    if (tipo == 'LECTURA') {
      return tester
          .widgetList<ElevatedButton>(find.byType(ElevatedButton))
          .any((button) => button.onPressed != null);
    }
    return tester
        .widgetList<Draggable<String>>(
          find.byWidgetPredicate((widget) => widget is Draggable<String>),
        )
        .any((chip) => chip.maxSimultaneousDrags == 1);
  }

  Future<void> closeScreen(WidgetTester tester, {bool reopen = false}) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await waitForWrite(tester, Hive.box('evaluation_sessions').flush());
      await waitForWrite(tester, Hive.box('evaluation_details').flush());
      if (reopen) {
        await waitForWrite(tester, Hive.close());
        await waitForWrite(tester, LocalEvaluationStorage.init());
      }
    });
    await tester.pump();
  }

  Future<void> gesture(
    WidgetTester tester,
    String tipo,
    int index, {
    bool correct = true,
  }) async {
    if (tipo == 'LECTURA') {
      await tester.tap(
        find.widgetWithText(
          ElevatedButton,
          correct ? 'palabra$index' : 'otra$index',
        ),
      );
    } else {
      final chip = find.byWidgetPredicate(
        (widget) =>
            widget is Draggable<String> &&
            widget.data == (correct ? 'sa' : 'ma'),
      );
      final target = find.byWidgetPredicate(
        (widget) => widget is DragTarget<String>,
      );
      await tester.drag(
        chip,
        tester.getCenter(target) - tester.getCenter(chip),
      );
    }
  }

  Future<void> respond(
    WidgetTester tester,
    String tipo,
    String sessionId,
    int index,
  ) async {
    await tester.runAsync(() async {
      final saved = Hive.box(
        'evaluation_details',
      ).watch().firstWhere((event) => event.key == '$sessionId:$index');
      final finished = index == 9
          ? Hive.box('evaluation_sessions').watch().firstWhere(
              (_) => LocalEvaluationStorage.getAllSessions().any(
                (session) =>
                    session['local_session_id'] == sessionId &&
                    session['sync_status'] == 'COMPLETED_PENDING_SYNC',
              ),
            )
          : null;
      await gesture(tester, tipo, index);
      await waitForWrite(tester, saved);
      if (finished != null) await waitForWrite(tester, finished);
      await waitForWrite(tester, Hive.box('evaluation_sessions').flush());
      await waitForWrite(tester, Hive.box('evaluation_details').flush());
      await waitForUi(
        tester,
        () => index == 9
            ? find.byType(StudentTestCompletedScreen).evaluate().isNotEmpty
            : find.text('Ítem ${index + 2} de 10').evaluate().isNotEmpty &&
                  readyForAnswer(tester, tipo),
      );
    });
    await tester.pumpAndSettle();
  }

  for (final tipo in ['LECTURA', 'FONOLOGIA']) {
    final label = tipo == 'LECTURA' ? 'lectura' : 'fonología';
    for (final count in [3, 8]) {
      testWidgets('$tipo: responde $count, cierra Hive y continúa hasta diez', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final id = await tester.runAsync(() => createDraft(tipo));
        if (id == null) fail('No se pudo preparar la evaluación.');
        await tester.pumpWidget(selection());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continuar $label'));
        await tester.pumpAndSettle();
        for (var index = 0; index < count; index++) {
          await respond(tester, tipo, id, index);
        }
        expect(find.text('Ítem ${count + 1} de 10'), findsOneWidget);
        expect(find.byType(StudentTestCompletedScreen), findsNothing);
        for (var error = 1; error <= 2; error++) {
          await tester.runAsync(() async {
            final saved = Hive.box('evaluation_sessions').watch().firstWhere(
              (_) =>
                  LocalEvaluationStorage.getAssessment(id).currentErrors ==
                  error,
            );
            await gesture(tester, tipo, count, correct: false);
            await waitForWrite(tester, saved);
            await waitForWrite(tester, Hive.box('evaluation_sessions').flush());
            await waitForUi(tester, () => readyForAnswer(tester, tipo));
          });
          await tester.pumpAndSettle();
        }
        final before = LocalEvaluationStorage.getAssessment(id);
        await closeScreen(tester, reopen: true);
        await tester.pumpWidget(selection());
        await tester.pumpAndSettle();
        expect(find.text('Continuar $label'), findsOneWidget);
        expect(
          find.text(
            'Respuestas guardadas: $count de 10. Faltan ${10 - count}.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Continuar $label'));
        await tester.pumpAndSettle();
        expect(find.text('Ítem ${count + 1} de 10'), findsOneWidget);
        final counter = tipo == 'LECTURA'
            ? 'Taps erróneos en este ítem: 2'
            : 'Errores de arrastre en este ítem: 2';
        expect(find.text(counter), findsOneWidget);
        expect(LocalEvaluationStorage.getAllSessions(), hasLength(1));
        final resumed = LocalEvaluationStorage.getAssessment(id);
        expect(resumed.items, before.items);
        expect(resumed.options, before.options);
        expect(resumed.nivelAplicado, 2);
        expect(
          resumed.answers.map((item) => item.toJson()).toList(),
          before.answers.map((item) => item.toJson()).toList(),
        );
        for (var index = count; index < 10; index++) {
          await respond(tester, tipo, id, index);
        }
        expect(find.byType(StudentTestCompletedScreen), findsOneWidget);
        expect(LocalEvaluationStorage.getAllSessions(), hasLength(1));
        expect(LocalEvaluationStorage.getAllDetails(), hasLength(10));
        final completed = LocalEvaluationStorage.getAssessment(id);
        expect(completed.answers[count].tapsErroneos, 2);
        expect(completed.answers[count].acierto, isFalse);
        expect(
          completed.answers[count].tiempoRespuestaMs,
          greaterThanOrEqualTo(before.currentElapsedMs),
        );
        final session = LocalEvaluationStorage.getAllSessions().single;
        expect(session['aciertos_primer_intento'], 9);
        expect(session['taps_erroneos_totales'], 2);
        expect(session['sync_status'], 'COMPLETED_PENDING_SYNC');
        expect(
          LocalEvaluationStorage.getPendingSyncPayload()['details'],
          hasLength(10),
        );
        expect(tester.takeException(), isNull);
        await closeScreen(tester);
      });
    }

    testWidgets(
      '$tipo crea y persiste el plan adaptativo al empezar una prueba nueva',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          final created = Hive.box('evaluation_sessions').watch().first;
          await tester.pumpWidget(
            MaterialApp(
              home: tipo == 'LECTURA'
                  ? const LecturaAssessmentScreen(
                      estudianteId: 1,
                      studentDisplayName: 'Prueba',
                      nivelLectura: 2,
                    )
                  : const FonologiaAssessmentScreen(
                      estudianteId: 1,
                      studentDisplayName: 'Prueba',
                      nivelFonologia: 2,
                    ),
            ),
          );
          await waitForWrite(tester, created);
          await waitForWrite(tester, Hive.box('evaluation_sessions').flush());
          await waitForUi(tester, () => readyForAnswer(tester, tipo));
        });
        await tester.pumpAndSettle();
        expect(find.text('Ítem 1 de 10'), findsOneWidget);
        final progress = LocalEvaluationStorage.getIncompleteAssessment(
          estudianteId: 1,
          tipoPrueba: tipo,
        )!;
        expect(progress.totalItems, 10);
        expect(progress.answeredItems, 0);
        expect(progress.options, hasLength(10));
        final session = LocalEvaluationStorage.getAllSessions().single;
        expect(session['nivel_dificultad_aplicado'], 2);
        expect(session['total_baja'], 6);
        expect(session['total_media'], 4);
        expect(session['total_alta'], 0);
        await closeScreen(tester, reopen: true);
        expect(
          LocalEvaluationStorage.getAssessment(progress.sessionId).items,
          progress.items,
        );
      },
    );

    testWidgets('$tipo recupera el cierre posterior a la última respuesta', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final id = await tester.runAsync(() => createDraft(tipo, count: 10));
      expect(
        LocalEvaluationStorage.getAllSessions().single['sync_status'],
        'PENDING',
      );
      await tester.pumpWidget(selection());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Continuar $label'));
        await waitForUi(
          tester,
          () => find.byType(StudentTestCompletedScreen).evaluate().isNotEmpty,
        );
      });
      await tester.pumpAndSettle();
      expect(LocalEvaluationStorage.getAllSessions(), hasLength(1));
      expect(
        LocalEvaluationStorage.getAllSessions().single['local_session_id'],
        id,
      );
      expect(
        LocalEvaluationStorage.getAllSessions().single['sync_status'],
        'COMPLETED_PENDING_SYNC',
      );
      expect(LocalEvaluationStorage.getAllDetails(), hasLength(10));
      expect(tester.takeException(), isNull);
      await closeScreen(tester);
    });
  }

  testWidgets('No ofrece progreso de otro estudiante', (tester) async {
    await tester.runAsync(() => createDraft('LECTURA', count: 3));
    await tester.pumpWidget(selection(studentId: 2));
    await tester.pumpAndSettle();
    expect(find.text('Continuar lectura'), findsNothing);
    expect(find.text('Empezar lectura'), findsOneWidget);
    expect(find.textContaining('Respuestas guardadas:'), findsNothing);
    expect(tester.takeException(), isNull);
    await closeScreen(tester);
  });

  testWidgets(
    'Una sesión antigua se conserva y no se presenta como recuperable',
    (tester) async {
      final id = await tester.runAsync(() async {
        final id = await LocalEvaluationStorage.createSession(
          tipoPrueba: 'LECTURA',
          totalItems: 10,
          estudianteId: 1,
          nivelDificultadAplicado: 2,
        );
        await LocalEvaluationStorage.saveDetail(
          localSessionId: id,
          detail: answer('LECTURA', 0),
        );
        return id;
      });
      await tester.pumpWidget(selection());
      await tester.pumpAndSettle();
      expect(find.text('Continuar lectura'), findsNothing);
      expect(
        find.textContaining('Hay una prueba anterior guardada'),
        findsOneWidget,
      );
      await tester.tap(find.text('Empezar lectura'));
      await tester.pumpAndSettle();
      expect(find.text('Prueba anterior guardada'), findsOneWidget);
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(
        LocalEvaluationStorage.getAllSessions().single['local_session_id'],
        id,
      );
      expect(LocalEvaluationStorage.getAllDetails(), hasLength(1));
      expect(
        LocalEvaluationStorage.getPendingSyncPayload()['sessions'],
        isEmpty,
      );
      await tester.tap(find.text('Empezar lectura'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Empezar otra'));
        await waitForUi(tester, () => readyForAnswer(tester, 'LECTURA'));
      });
      await tester.pumpAndSettle();
      expect(find.text('Ítem 1 de 10'), findsOneWidget);
      expect(LocalEvaluationStorage.getAllSessions(), hasLength(2));
      expect(
        LocalEvaluationStorage.countLegacyIncomplete(
          estudianteId: 1,
          tipoPrueba: 'LECTURA',
        ),
        1,
      );
      expect(
        LocalEvaluationStorage.getAllDetails().single['local_session_id'],
        id,
      );
      await closeScreen(tester);
    },
  );

  testWidgets('Un plan dañado muestra un aviso sin empezar otra sesión', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final id = await createDraft('LECTURA', count: 3);
      final raw = Map<String, dynamic>.from(
        Hive.box('evaluation_sessions').get(id) as Map,
      );
      raw['assessment_plan'] = {'version': 99};
      await Hive.box('evaluation_sessions').put(id, raw);
    });
    await tester.pumpWidget(selection());
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No se pudo abrir la prueba guardada. Pide ayuda a tu docente.',
      ),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.text('Empezar lectura'));
    await tester.pumpAndSettle();
    expect(find.byType(LecturaAssessmentScreen), findsNothing);
    expect(LocalEvaluationStorage.getAllSessions(), hasLength(1));
    expect(LocalEvaluationStorage.getAllDetails(), hasLength(3));
    expect(tester.takeException(), isNull);
    await closeScreen(tester);
  });
}
