import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/models/jornada_evaluacion.dart';
import 'package:mobile/core/models/student.dart';
import 'package:mobile/core/repositories/local_classroom_mode_storage.dart';
import 'package:mobile/core/repositories/local_pin_attempt_guard.dart';
import 'package:mobile/core/repositories/local_student_cache.dart';
import 'package:mobile/core/services/student_service.dart';
import 'package:mobile/features/auth/screens/pin_login_screen.dart';

const cachedStudent = Student(
  id: 1,
  nombres: 'Estudiante',
  apellidos: 'Prueba',
  fechaNacimiento: null,
  seccionId: 10,
  consentimientoFirmado: true,
  nivelLectura: 2,
  nivelFonologia: 3,
  activo: true,
);
const pinContext = 'student_pin_login_section_10';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'disly-offline-test-',
    );
    Hive.init(temporaryDirectory.path);
    await LocalStudentCache.init();
    await Hive.openBox('classroom_mode');
    await LocalPinAttemptGuard.getState(pinContext);
  });

  tearDown(() async {
    await Hive.close();
    await temporaryDirectory.delete(recursive: true);
  });

  Future<StudentLookupResult> offlineLookup(String pin, {int sectionId = 10}) {
    return http.runWithClient(
      () =>
          StudentService().findByPinForModoAula(seccionId: sectionId, pin: pin),
      () => MockClient((_) async => http.Response('', 503)),
    );
  }

  Future<void> storeMode() => LocalClassroomModeStorage.saveFromJornada(
    jornada: JornadaEvaluacion(
      id: 100,
      seccionId: 10,
      responsableId: 2,
      fechaInicio: DateTime.now(),
      fechaCierre: null,
      fechaExpiracion: DateTime.now().add(const Duration(hours: 8)),
      estado: 'ACTIVA',
      pruebaLecturaActiva: true,
      pruebaFonologiaActiva: true,
    ),
    sectionDisplayName: '3 X',
  );

  test(
    'CP013 permite identificar el PIN offline y conservar sus niveles',
    () async {
      await LocalStudentCache.replaceStudentsForSection(
        seccionId: 10,
        studentsByPin: {'4826': cachedStudent},
      );
      await storeMode();
      final result = await offlineLookup('4826');
      expect(result.success, isTrue);
      expect(result.fromCache, isTrue);
      expect(result.requiresOfflinePreparation, isFalse);
      expect(result.student?.nivelLectura, 2);
      expect(result.student?.nivelFonologia, 3);
      expect((await LocalClassroomModeStorage.getCurrent())?.seccionId, 10);
    },
  );

  test(
    'El padrón y la jornada descargados persisten al reabrir Hive',
    () async {
      await LocalStudentCache.replaceStudentsForSection(
        seccionId: 10,
        studentsByPin: {'4826': cachedStudent},
      );
      await storeMode();
      await Hive.close();
      Hive.init(temporaryDirectory.path);
      await LocalStudentCache.init();
      expect((await offlineLookup('4826')).success, isTrue);
      expect((await LocalClassroomModeStorage.getCurrent())?.jornadaId, 100);
    },
  );

  test(
    'HU0013-2 diferencia una sección no preparada de un PIN incorrecto',
    () async {
      final result = await offlineLookup('4826');
      expect(result.success, isFalse);
      expect(result.requiresOfflinePreparation, isTrue);
      expect(result.message, contains('Descargar sección'));
    },
  );

  test('Un PIN ajeno no habilita otra sección offline', () async {
    await LocalStudentCache.replaceStudentsForSection(
      seccionId: 10,
      studentsByPin: {'4826': cachedStudent},
    );
    final result = await offlineLookup('4826', sectionId: 20);
    expect(result.success, isFalse);
    expect(result.student, isNull);
    expect(result.requiresOfflinePreparation, isTrue);
  });

  test(
    'Un PIN incorrecto en una sección preparada conserva el rechazo normal',
    () async {
      await LocalStudentCache.replaceStudentsForSection(
        seccionId: 10,
        studentsByPin: {'4826': cachedStudent},
      );
      final result = await offlineLookup('5837');
      expect(result.success, isFalse);
      expect(result.requiresOfflinePreparation, isFalse);
    },
  );

  test('No guarda parcialmente un padrón con un PIN inválido', () async {
    await expectLater(
      LocalStudentCache.replaceStudentsForSection(
        seccionId: 10,
        studentsByPin: {'4826': cachedStudent, '123': cachedStudent},
      ),
      throwsArgumentError,
    );
    expect(LocalStudentCache.countStudentsForSection(10), 0);
  });

  test('No guarda estudiantes ajenos ni sin habilitación', () async {
    for (final student in [
      const Student(
        id: 2,
        nombres: 'Otro',
        apellidos: 'Prueba',
        fechaNacimiento: null,
        seccionId: 20,
        consentimientoFirmado: true,
        activo: true,
      ),
      const Student(
        id: 2,
        nombres: 'Otro',
        apellidos: 'Prueba',
        fechaNacimiento: null,
        seccionId: 10,
        consentimientoFirmado: false,
        activo: true,
      ),
      const Student(
        id: 2,
        nombres: 'Otro',
        apellidos: 'Prueba',
        fechaNacimiento: null,
        seccionId: 10,
        consentimientoFirmado: true,
        activo: false,
      ),
    ]) {
      await expectLater(
        LocalStudentCache.replaceStudentsForSection(
          seccionId: 10,
          studentsByPin: {'4826': student},
        ),
        throwsArgumentError,
      );
    }
    expect(LocalStudentCache.countStudentsForSection(10), 0);
  });

  Future<void> submitPin(WidgetTester tester, String pin) async {
    await tester.runAsync(() async {
      await storeMode();
      await tester.pumpWidget(const MaterialApp(home: PinLoginScreen()));
    });
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), pin);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Empezar'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
    );
    final callback = button.onPressed;
    if (callback is! Future<void> Function()) {
      throw StateError('El ingreso por PIN debe estar habilitado.');
    }
    await http.runWithClient(
      () => tester.runAsync(callback),
      () => MockClient((_) async => http.Response('', 503)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Sin descarga previa informa el motivo y no penaliza el PIN', (
    tester,
  ) async {
    await submitPin(tester, '4826');
    expect(
      find.textContaining('Esta sección no está disponible sin conexión'),
      findsOneWidget,
    );
    expect((await LocalPinAttemptGuard.getState(pinContext)).failedAttempts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Sin modo aula guardado indica preparar la sección antes del PIN',
    (tester) async {
      await tester.runAsync(
        () => tester.pumpWidget(const MaterialApp(home: PinLoginScreen())),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Tu docente te ayudará a preparar la sección para empezar.'),
        findsOneWidget,
      );
      expect(find.textContaining('No hay una sección preparada'), findsNothing);
      expect(
        (await LocalPinAttemptGuard.getState(pinContext)).failedAttempts,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Con padrón preparado un PIN incorrecto sí cuenta como intento', (
    tester,
  ) async {
    await tester.runAsync(
      () => LocalStudentCache.replaceStudentsForSection(
        seccionId: 10,
        studentsByPin: {'4826': cachedStudent},
      ),
    );
    await submitPin(tester, '5837');
    expect((await LocalPinAttemptGuard.getState(pinContext)).failedAttempts, 1);
    expect(
      find.textContaining('Esta sección no está disponible sin conexión'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
