import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobile/core/models/admin_models.dart';
import 'package:mobile/core/models/auth_user.dart';
import 'package:mobile/core/models/jornada_evaluacion.dart';
import 'package:mobile/core/repositories/local_classroom_mode_storage.dart';
import 'package:mobile/core/models/student.dart';
import 'package:mobile/core/repositories/local_student_cache.dart';
import 'package:mobile/core/services/admin_service.dart';
import 'package:mobile/core/services/jornada_service.dart';
import 'package:mobile/features/admin/screens/admin_panel_screen.dart';

const teacher = AuthUser(
  id: 2,
  nombres: 'Jessica',
  apellidos: 'Linares',
  email: 'jessica@edu.com',
  rol: 'MAESTRO',
  gradoScope: null,
  activo: true,
  accessToken: 'teacher-test',
);
const director = AuthUser(
  id: 1,
  nombres: 'Director',
  apellidos: 'Prueba',
  email: 'director@edu.com',
  rol: 'DIRECTORA',
  gradoScope: null,
  activo: true,
  accessToken: 'director-test',
);
const sectionX = AdminSection(
  id: 10,
  grado: 3,
  nombre: 'X',
  turno: 'MAÑANA',
  activo: true,
);
const sectionA = AdminSection(
  id: 1,
  grado: 3,
  nombre: 'A',
  turno: 'MAÑANA',
  activo: true,
);
const sectionE = AdminSection(
  id: 5,
  grado: 3,
  nombre: 'E',
  turno: 'MAÑANA',
  activo: true,
);

class FakeAdminService extends AdminService {
  final Map<String, List<AdminSection>> sectionsByToken;
  Completer<List<AdminSection>>? delayedDirectorSections;
  List<AdminStudent> students = [];
  bool failStudentFetch = false;

  FakeAdminService(this.sectionsByToken);

  @override
  Future<List<AdminStudent>> fetchStudents({required String? authToken}) async {
    if (failStudentFetch) throw StateError('No se pudo descargar el padrón.');
    return students;
  }

  @override
  Future<List<AdminSection>> fetchSections({required String? authToken}) async {
    if (authToken == director.accessToken && delayedDirectorSections != null) {
      return delayedDirectorSections!.future;
    }
    final sections = sectionsByToken[authToken];
    if (sections == null) throw StateError('Token no definido en la prueba.');
    return sections;
  }

  @override
  Future<List<AcademicUser>> fetchUsers({required String? authToken}) async =>
      [];

  @override
  Future<List<TeacherSectionLink>> fetchTeacherSectionLinks({
    required String? authToken,
  }) async => [];
}

class FakeJornadaService extends JornadaService {
  final List<int> queriedSectionIds = [];
  final List<int> activatedSectionIds = [];
  final Set<int> sectionsWithoutActiveJornada = {};
  bool alreadyActive = false;
  JornadaEvaluacion? jornadaOverride;

  @override
  Future<JornadaEvaluacion> activarJornada({
    required String? authToken,
    required int seccionId,
    bool pruebaLecturaActiva = true,
    bool pruebaFonologiaActiva = true,
    int duracionHoras = 8,
  }) async {
    activatedSectionIds.add(seccionId);
    if (alreadyActive) throw Exception('Ya existe una jornada activa');
    return jornadaOverride ?? testJornada(seccionId);
  }

  @override
  Future<JornadaEvaluacion> obtenerJornadaActiva({
    required String? authToken,
    required int seccionId,
  }) async {
    queriedSectionIds.add(seccionId);
    if (sectionsWithoutActiveJornada.contains(seccionId)) {
      throw Exception('No hay jornada activa para esta sección.');
    }
    return jornadaOverride ?? testJornada(seccionId);
  }
}

JornadaEvaluacion testJornada(int sectionId, {bool expired = false}) =>
    JornadaEvaluacion(
      id: sectionId + 100,
      seccionId: sectionId,
      responsableId: 1,
      fechaInicio: DateTime.now(),
      fechaCierre: null,
      fechaExpiracion: DateTime.now().add(Duration(hours: expired ? -1 : 8)),
      estado: 'ACTIVA',
      pruebaLecturaActiva: true,
      pruebaFonologiaActiva: true,
    );

AdminStudent testStudent({
  int id = 1,
  int seccionId = 10,
  String? pin = '4826',
  bool activo = true,
  bool consentimiento = true,
}) => AdminStudent(
  id: id,
  codigoEstudiante: null,
  nombres: 'Estudiante $id',
  apellidos: 'Prueba',
  fechaNacimiento: '2018-01-01',
  pinCorto: pin,
  seccionId: seccionId,
  consentimientoFirmado: consentimiento,
  fechaConsentimiento: '2026-11-04',
  nivelLectura: 2,
  nivelFonologia: 3,
  activo: activo,
);

void main() {
  late Directory temporaryDirectory;
  late FakeAdminService adminService;
  late FakeJornadaService jornadaService;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'disly-scope-test-',
    );
    Hive.init(temporaryDirectory.path);
    await Hive.openBox('classroom_mode');
    await LocalStudentCache.init();
    adminService = FakeAdminService({
      'teacher-test': [sectionX],
      'director-test': [sectionA, sectionX],
    });
    jornadaService = FakeJornadaService();
  });

  tearDown(() async {
    await Hive.close();
    await temporaryDirectory.delete(recursive: true);
  });

  Future<void> showPanel(WidgetTester tester, AuthUser user) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminPanelScreen(
            currentUser: user,
            adminService: adminService,
            jornadaService: jornadaService,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Hive.box('classroom_mode').flush();
    });
    await tester.pumpAndSettle();
  }

  Future<void> downloadSection(WidgetTester tester) async {
    final button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Descargar sección'),
        matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
      ),
    );
    final callback = button.onPressed;
    if (callback is! Future<void> Function()) {
      throw StateError(
        'La descarga debe tener una acción asíncrona habilitada.',
      );
    }
    await tester.runAsync(callback);
    await tester.pumpAndSettle();
  }

  DropdownButtonFormField<int> classroomSelector(WidgetTester tester) =>
      tester.widget<DropdownButtonFormField<int>>(
        find.byType(DropdownButtonFormField<int>).first,
      );

  DropdownButton<int> sectionDropdown(
    WidgetTester tester, {
    Finder? formField,
  }) => tester.widget<DropdownButton<int>>(
    find.descendant(
      of: formField ?? find.byType(DropdownButtonFormField<int>).first,
      matching: find.byWidgetPredicate(
        (widget) => widget is DropdownButton<int>,
      ),
    ),
  );

  testWidgets('Modo aula ofrece solo 3 X al docente', (tester) async {
    await showPanel(tester, teacher);
    final selector = classroomSelector(tester);
    expect(selector.initialValue, sectionX.id);
    expect(sectionDropdown(tester).items!.map((item) => item.value), [
      sectionX.id,
    ]);
    expect(jornadaService.queriedSectionIds, [sectionX.id]);
    expect(find.text('3 A'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CP037: solo ofrece 3 E aunque no tenga jornada activa', (
    tester,
  ) async {
    adminService.sectionsByToken['teacher-test'] = [sectionE];
    jornadaService.sectionsWithoutActiveJornada.add(sectionE.id);
    await showPanel(tester, teacher);

    expect(classroomSelector(tester).initialValue, sectionE.id);
    expect(sectionDropdown(tester).items!.map((item) => item.value), [
      sectionE.id,
    ]);
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    expect(find.text('3 E').last, findsOneWidget);
    expect(find.text('3 D'), findsNothing);
    await tester.tap(find.text('3 E').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Verificar jornada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verificar jornada'));
    await tester.pumpAndSettle();

    expect(jornadaService.queriedSectionIds, [sectionE.id, sectionE.id]);
    expect(jornadaService.activatedSectionIds, isEmpty);
    expect(
      find.textContaining('No hay jornada activa para esta sección.'),
      findsOneWidget,
    );
    expect(find.textContaining('solo puede gestionar'), findsNothing);
    expect(await LocalClassroomModeStorage.getCurrent(), isNull);
    expect(classroomSelector(tester).initialValue, sectionE.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El selector de nuevo estudiante también se limita a 3 X', (
    tester,
  ) async {
    await showPanel(tester, teacher);
    await tester.tap(find.widgetWithText(Tab, 'Estudiantes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo estudiante'));
    await tester.pumpAndSettle();

    final formField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(DropdownButtonFormField<int>),
    );
    final selector = tester.widget<DropdownButtonFormField<int>>(formField);
    expect(selector.initialValue, sectionX.id);
    expect(
      sectionDropdown(
        tester,
        formField: formField,
      ).items!.map((item) => item.value),
      [sectionX.id],
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('No reutiliza un modo aula guardado de otra sección', (
    tester,
  ) async {
    await tester.runAsync(
      () => LocalClassroomModeStorage.saveFromJornada(
        jornada: testJornada(sectionA.id),
        sectionDisplayName: '3 A',
      ),
    );
    await showPanel(tester, teacher);

    expect(classroomSelector(tester).initialValue, sectionX.id);
    expect(jornadaService.queriedSectionIds, [sectionX.id]);
    expect(await LocalClassroomModeStorage.getCurrent(), isNull);
    expect(
      find.textContaining('Se desactivó el modo aula local'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Modo aula activo en este dispositivo: 3 A'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mantiene un modo aula guardado de la sección asignada', (
    tester,
  ) async {
    await tester.runAsync(
      () => LocalClassroomModeStorage.saveFromJornada(
        jornada: testJornada(sectionX.id),
        sectionDisplayName: '3 X',
      ),
    );
    await showPanel(tester, teacher);

    expect(classroomSelector(tester).initialValue, sectionX.id);
    expect(
      (await LocalClassroomModeStorage.getCurrent())?.seccionId,
      sectionX.id,
    );
    expect(
      find.textContaining('Modo aula activo en este dispositivo: 3 X'),
      findsOneWidget,
    );
  });

  testWidgets('Sin asignaciones no activa jornadas ni crea estudiantes', (
    tester,
  ) async {
    adminService.sectionsByToken['teacher-test'] = [];
    await showPanel(tester, teacher);

    final selector = classroomSelector(tester);
    expect(selector.initialValue, isNull);
    expect(sectionDropdown(tester).items, isEmpty);
    expect(selector.onChanged, isNull);
    expect(
      find.text(
        'No tienes secciones activas asignadas. Solicita la asignación al director.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('Activar jornada'),
              matching: find.byWidgetPredicate(
                (widget) => widget is FilledButton,
              ),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(jornadaService.queriedSectionIds, isEmpty);
    expect(
      tester
          .widget<OutlinedButton>(
            find.ancestor(
              of: find.text('Descargar sección'),
              matching: find.byWidgetPredicate(
                (widget) => widget is OutlinedButton,
              ),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.widgetWithText(Tab, 'Estudiantes'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ElevatedButton>(
            find.ancestor(
              of: find.text('Nuevo estudiante'),
              matching: find.byWidgetPredicate(
                (widget) => widget is ElevatedButton,
              ),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Actualizar elimina una selección que ya no está asignada', (
    tester,
  ) async {
    await showPanel(tester, teacher);
    adminService.sectionsByToken['teacher-test'] = [];
    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();

    expect(classroomSelector(tester).initialValue, isNull);
    expect(sectionDropdown(tester).items, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cambiar de director a docente recarga el alcance', (
    tester,
  ) async {
    await showPanel(tester, director);
    expect(sectionDropdown(tester).items!.length, 2);
    await showPanel(tester, teacher);

    expect(sectionDropdown(tester).items!.map((item) => item.value), [
      sectionX.id,
    ]);
    expect(classroomSelector(tester).initialValue, sectionX.id);
    expect(find.text('Panel docente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Una carga antigua no repone las secciones del director', (
    tester,
  ) async {
    adminService.delayedDirectorSections = Completer<List<AdminSection>>();
    await tester.pumpWidget(
      MaterialApp(
        home: AdminPanelScreen(
          currentUser: director,
          adminService: adminService,
          jornadaService: jornadaService,
        ),
      ),
    );
    await tester.pump();
    await showPanel(tester, teacher);
    adminService.delayedDirectorSections!.complete([sectionA, sectionX]);
    await tester.pumpAndSettle();

    expect(sectionDropdown(tester).items!.map((item) => item.value), [
      sectionX.id,
    ]);
    expect(jornadaService.queriedSectionIds, [sectionX.id]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CP013 descarga solo los estudiantes habilitados de 3 X', (
    tester,
  ) async {
    adminService.students = [
      testStudent(),
      testStudent(id: 2, pin: '5837'),
      testStudent(id: 3, pin: '6948', activo: false),
      testStudent(id: 4, pin: '7059', consentimiento: false),
      testStudent(id: 5, pin: '8160', seccionId: sectionA.id),
    ];
    await showPanel(tester, teacher);
    await downloadSection(tester);

    expect(jornadaService.activatedSectionIds, [sectionX.id]);
    expect(LocalStudentCache.countStudentsForSection(sectionX.id), 2);
    expect(LocalStudentCache.countStudentsForSection(sectionA.id), 0);
    final student = LocalStudentCache.findByPinForSection(
      pin: '4826',
      seccionId: sectionX.id,
    )!;
    expect(student.nivelLectura, 2);
    expect(student.nivelFonologia, 3);
    expect(
      (await LocalClassroomModeStorage.getCurrent())?.seccionId,
      sectionX.id,
    );
    expect(
      find.textContaining('Sección 3 X descargada: 2 estudiantes'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Descargar sección recupera una jornada que ya está activa', (
    tester,
  ) async {
    adminService.students = [testStudent()];
    jornadaService.alreadyActive = true;
    await showPanel(tester, teacher);
    await downloadSection(tester);
    expect(jornadaService.activatedSectionIds, [sectionX.id]);
    expect(
      (await LocalClassroomModeStorage.getCurrent())?.jornadaId,
      testJornada(sectionX.id).id,
    );
    expect(
      find.textContaining('Sección 3 X descargada: 1 estudiante'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Una descarga elimina estudiantes retirados sin borrar otra sección',
    (tester) async {
      await tester.runAsync(() async {
        for (final entry in [
          (pin: '9012', section: sectionX.id),
          (pin: '3456', section: sectionA.id),
        ]) {
          await LocalStudentCache.saveStudentByPin(
            pin: entry.pin,
            student: Student(
              id: 99,
              nombres: 'Anterior',
              apellidos: 'Prueba',
              fechaNacimiento: null,
              seccionId: entry.section,
              consentimientoFirmado: true,
              activo: true,
            ),
          );
        }
      });
      adminService.students = [testStudent()];
      await showPanel(tester, teacher);
      await downloadSection(tester);
      expect(LocalStudentCache.findByPin('9012'), isNull);
      expect(LocalStudentCache.findByPin('3456'), isNotNull);
      expect(LocalStudentCache.findByPin('4826'), isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Sin estudiantes habilitados no confirma una descarga', (
    tester,
  ) async {
    await showPanel(tester, teacher);
    await downloadSection(tester);
    expect(
      find.textContaining('no tiene estudiantes habilitados'),
      findsOneWidget,
    );
    expect(jornadaService.activatedSectionIds, isEmpty);
    expect(await LocalClassroomModeStorage.getCurrent(), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Un error de descarga no guarda un modo aula ni informa éxito', (
    tester,
  ) async {
    await showPanel(tester, teacher);
    adminService.failStudentFetch = true;
    await downloadSection(tester);
    expect(
      find.textContaining('No se pudo descargar el padrón'),
      findsOneWidget,
    );
    expect(jornadaService.activatedSectionIds, isEmpty);
    expect(await LocalClassroomModeStorage.getCurrent(), isNull);
    expect(LocalStudentCache.countStudentsForSection(sectionX.id), 0);
    expect(find.textContaining('Sección 3 X descargada:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final pin in [null, '123', 'ABCD']) {
    testWidgets('Rechaza el PIN inválido $pin antes de confirmar la descarga', (
      tester,
    ) async {
      adminService.students = [testStudent(pin: pin)];
      await showPanel(tester, teacher);
      await downloadSection(tester);
      expect(find.textContaining('no tiene un PIN válido'), findsOneWidget);
      expect(jornadaService.activatedSectionIds, isEmpty);
      expect(await LocalClassroomModeStorage.getCurrent(), isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('No confirma una descarga con PIN duplicados', (tester) async {
    adminService.students = [testStudent(), testStudent(id: 2)];
    await showPanel(tester, teacher);
    await downloadSection(tester);
    expect(find.textContaining('contiene PIN duplicados'), findsOneWidget);
    expect(await LocalClassroomModeStorage.getCurrent(), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('No guarda la descarga si la jornada está vencida', (
    tester,
  ) async {
    adminService.students = [testStudent()];
    await showPanel(tester, teacher);
    jornadaService.jornadaOverride = testJornada(sectionX.id, expired: true);
    await downloadSection(tester);
    expect(find.textContaining('no tiene una jornada vigente'), findsOneWidget);
    expect(await LocalClassroomModeStorage.getCurrent(), isNull);
    expect(LocalStudentCache.countStudentsForSection(sectionX.id), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('No guarda una jornada que pertenece a otra sección', (
    tester,
  ) async {
    adminService.students = [testStudent()];
    await showPanel(tester, teacher);
    jornadaService.jornadaOverride = testJornada(sectionA.id);
    await downloadSection(tester);
    expect(find.textContaining('no tiene una jornada vigente'), findsOneWidget);
    expect(await LocalClassroomModeStorage.getCurrent(), isNull);
    expect(LocalStudentCache.countStudentsForSection(sectionX.id), 0);
    expect(tester.takeException(), isNull);
  });
}
