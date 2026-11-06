import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/models/admin_models.dart';
import 'package:mobile/core/models/auth_user.dart';
import 'package:mobile/core/models/jornada_evaluacion.dart';
import 'package:mobile/core/services/admin_service.dart';
import 'package:mobile/core/services/connection_errors.dart';
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
  accessToken: 'student-form-test',
);
const section = AdminSection(
  id: 1,
  grado: 3,
  nombre: 'X',
  turno: 'MAÑANA',
  activo: true,
);

String isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

DateTime yearsAgo(int years) {
  final today = DateTime.now().toUtc().subtract(const Duration(hours: 5));
  final year = today.year - years;
  final lastDay = DateTime(year, today.month + 1, 0).day;
  return DateTime(year, today.month, today.day > lastDay ? lastDay : today.day);
}

AdminStudent studentRecord({
  String nombres = 'María José',
  String apellidos = "Huamán O'Connor",
  required String fechaNacimiento,
  bool consentimientoFirmado = true,
  String? fechaConsentimiento,
  bool activo = true,
}) => AdminStudent(
  id: 10,
  codigoEstudiante: null,
  nombres: nombres,
  apellidos: apellidos,
  fechaNacimiento: fechaNacimiento,
  pinCorto: consentimientoFirmado ? '5678' : null,
  seccionId: section.id,
  consentimientoFirmado: consentimientoFirmado,
  fechaConsentimiento: consentimientoFirmado
      ? fechaConsentimiento ?? isoDate(DateTime.now())
      : null,
  nivelLectura: 1,
  nivelFonologia: 1,
  activo: activo,
);

class StudentFormAdminService extends AdminService {
  List<AdminStudent> students = [];
  int createCalls = 0;
  int updateCalls = 0;
  String? lastConsentDate;

  StudentFormAdminService() : super(baseUrl: 'http://127.0.0.1:1');

  @override
  Future<List<AdminStudent>> fetchStudents({
    required String? authToken,
  }) async => students;

  @override
  Future<List<AdminSection>> fetchSections({
    required String? authToken,
  }) async => [section];

  @override
  Future<AdminStudent> createStudent({
    required String? authToken,
    String? codigoEstudiante,
    required String nombres,
    required String apellidos,
    required String fechaNacimiento,
    required int seccionId,
    required bool consentimientoFirmado,
    String? fechaConsentimiento,
    bool activo = true,
  }) async {
    if (authToken != teacher.accessToken || seccionId != section.id) {
      throw StateError('Cuenta o sección inesperada en la prueba.');
    }
    createCalls++;
    lastConsentDate = fechaConsentimiento;
    final student = studentRecord(
      nombres: nombres,
      apellidos: apellidos,
      fechaNacimiento: fechaNacimiento,
      consentimientoFirmado: consentimientoFirmado,
      fechaConsentimiento: fechaConsentimiento,
      activo: activo,
    );
    students = [student];
    return student;
  }

  @override
  Future<AdminStudent> updateStudent({
    required String? authToken,
    required int estudianteId,
    String? codigoEstudiante,
    required String nombres,
    required String apellidos,
    required String fechaNacimiento,
    int? seccionId,
    required bool consentimientoFirmado,
    String? fechaConsentimiento,
    required bool activo,
  }) async {
    if (estudianteId != 10) throw StateError('Estudiante inesperado.');
    updateCalls++;
    lastConsentDate = fechaConsentimiento;
    final student = studentRecord(
      nombres: nombres,
      apellidos: apellidos,
      fechaNacimiento: fechaNacimiento,
      consentimientoFirmado: consentimientoFirmado,
      fechaConsentimiento: fechaConsentimiento,
      activo: activo,
    );
    students = [student];
    return student;
  }
}

class StudentFormJornadaService extends JornadaService {
  @override
  Future<JornadaEvaluacion> obtenerJornadaActiva({
    required String? authToken,
    required int seccionId,
  }) async => JornadaEvaluacion(
    id: 100,
    seccionId: seccionId,
    responsableId: teacher.id,
    fechaInicio: DateTime.now(),
    fechaCierre: null,
    fechaExpiracion: DateTime.now().add(const Duration(hours: 8)),
    estado: 'ACTIVA',
    pruebaLecturaActiva: true,
    pruebaFonologiaActiva: true,
  );
}

void main() {
  late Directory temporaryDirectory;
  late StudentFormAdminService adminService;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'disly-student-test-',
    );
    Hive.init(temporaryDirectory.path);
    await Hive.openBox('classroom_mode');
    adminService = StudentFormAdminService();
  });

  tearDown(() async {
    await Hive.close();
    await temporaryDirectory.delete(recursive: true);
  });

  Future<void> openForm(WidgetTester tester, {bool editing = false}) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminPanelScreen(
            currentUser: teacher,
            adminService: adminService,
            jornadaService: StudentFormJornadaService(),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Hive.box('classroom_mode').flush();
    });
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Estudiantes'));
    await tester.pumpAndSettle();
    await tester.tap(
      editing ? find.byTooltip('Editar') : find.text('Nuevo estudiante'),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );

  Future<void> enter(WidgetTester tester, String label, String value) async {
    await tester.ensureVisible(field(label));
    await tester.enterText(field(label), value);
    await tester.pump();
  }

  Future<void> fillStudent(WidgetTester tester, String birthDate) async {
    await enter(tester, 'Nombres', '  María José  ');
    await enter(tester, 'Apellidos', "  Huamán O'Connor  ");
    await enter(tester, 'Fecha nacimiento', birthDate);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
  }

  Future<void> toggle(WidgetTester tester, String label) async {
    final control = find.widgetWithText(SwitchListTile, label);
    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
    await tester.tap(control);
    await tester.pumpAndSettle();
  }

  const activationMessage =
      'Para activar al estudiante se requiere consentimiento informado firmado.';
  for (final date in [null, '', 'fecha inválida previa']) {
    testWidgets('CP050 guarda inactivo sin consentimiento con fecha $date', (
      tester,
    ) async {
      await openForm(tester);
      await fillStudent(tester, isoDate(yearsAgo(8)));
      if (date != null) {
        await enter(tester, 'Fecha consentimiento', date);
      }
      await toggle(tester, 'Consentimiento firmado');
      await toggle(tester, 'Activo');
      expect(
        tester.widget<TextField>(field('Fecha consentimiento')).enabled,
        isFalse,
      );
      await save(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(adminService.createCalls, 1);
      final student = adminService.students.single;
      expect(student.activo, isFalse);
      expect(student.consentimientoFirmado, isFalse);
      expect(student.fechaConsentimiento, isNull);
      expect(student.pinCorto, isNull);
      expect(adminService.lastConsentDate, isNull);
      expect(find.text(activationMessage), findsNothing);
      expect(find.textContaining('Exception:'), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Regenerar PIN',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('CP050 bloquea activo sin consentimiento y permite corregirlo', (
    tester,
  ) async {
    await openForm(tester);
    await fillStudent(tester, isoDate(yearsAgo(8)));
    await toggle(tester, 'Consentimiento firmado');
    await save(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(activationMessage), findsOneWidget);
    expect(find.textContaining('Exception:'), findsNothing);
    expect(adminService.createCalls, 0);
    expect(
      tester.widget<TextField>(field('Nombres')).controller?.text,
      '  María José  ',
    );
    await toggle(tester, 'Activo');
    await save(tester);
    expect(adminService.createCalls, 1);
    expect(adminService.students.single.activo, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'CP050 edita inactivo y exige consentimiento y fecha para activarlo',
    (tester) async {
      adminService.students = [
        studentRecord(
          fechaNacimiento: isoDate(yearsAgo(8)),
          consentimientoFirmado: false,
          activo: false,
        ),
      ];
      await openForm(tester, editing: true);
      await save(tester);
      expect(adminService.updateCalls, 1);
      expect(adminService.lastConsentDate, isNull);
      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();
      await toggle(tester, 'Activo');
      await save(tester);
      expect(find.text(activationMessage), findsOneWidget);
      expect(adminService.updateCalls, 1);
      await toggle(tester, 'Consentimiento firmado');
      await enter(tester, 'Fecha consentimiento', '');
      await save(tester);
      expect(
        find.text('Ingresa la fecha del consentimiento firmado.'),
        findsOneWidget,
      );
      expect(adminService.updateCalls, 1);
      await enter(tester, 'Fecha consentimiento', isoDate(DateTime.now()));
      await save(tester);
      expect(adminService.updateCalls, 2);
      final student = adminService.students.single;
      expect(student.activo, isTrue);
      expect(student.consentimientoFirmado, isTrue);
      expect(student.pinCorto, '5678');
      expect(tester.takeException(), isNull);
    },
  );

  for (final editing in [false, true]) {
    test(
      'AdminService envía inactivo sin consentimiento, edición=$editing',
      () async {
        const service = AdminService(baseUrl: 'https://example.invalid');
        await http.runWithClient(
          () async {
            final student = editing
                ? await service.updateStudent(
                    authToken: 'test-token',
                    estudianteId: 10,
                    nombres: 'Estudiante',
                    apellidos: 'Prueba',
                    fechaNacimiento: isoDate(yearsAgo(8)),
                    seccionId: 1,
                    consentimientoFirmado: false,
                    activo: false,
                  )
                : await service.createStudent(
                    authToken: 'test-token',
                    nombres: 'Estudiante',
                    apellidos: 'Prueba',
                    fechaNacimiento: isoDate(yearsAgo(8)),
                    seccionId: 1,
                    consentimientoFirmado: false,
                    activo: false,
                  );
            expect(student.activo, isFalse);
            expect(student.consentimientoFirmado, isFalse);
            expect(student.pinCorto, isNull);
          },
          () => MockClient((request) async {
            expect(request.method, editing ? 'PATCH' : 'POST');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['activo'], isFalse);
            expect(body['consentimiento_firmado'], isFalse);
            expect(body.containsKey('fecha_consentimiento'), isFalse);
            return http.Response(jsonEncode({'id': 10, ...body}), 200);
          }),
        );
      },
    );
  }

  test(
    'El rechazo de activación del servidor no añade Exception al mensaje',
    () async {
      await http.runWithClient(
        () => expectLater(
          const AdminService().createStudent(
            authToken: 'test-token',
            nombres: 'Estudiante',
            apellidos: 'Prueba',
            fechaNacimiento: isoDate(yearsAgo(8)),
            seccionId: 1,
            consentimientoFirmado: false,
            activo: true,
          ),
          throwsA(
            isA<RequestFailure>().having(
              (error) => error.toString(),
              'mensaje visible',
              activationMessage,
            ),
          ),
        ),
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({'detail': activationMessage}),
            400,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
    },
  );

  for (final label in ['Nombres', 'Apellidos']) {
    for (final value in ['', '   ']) {
      testWidgets('$label no admite ${value.isEmpty ? "vacío" : "espacios"}', (
        tester,
      ) async {
        await openForm(tester);
        await fillStudent(tester, isoDate(yearsAgo(8)));
        await enter(tester, label, value);
        await save(tester);

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.text('Ingresa los ${label.toLowerCase()} del estudiante.'),
          findsOneWidget,
        );
        expect(adminService.createCalls, 0);
        expect(adminService.updateCalls, 0);
        expect(
          tester.widget<TextField>(field('Fecha nacimiento')).controller!.text,
          isoDate(yearsAgo(8)),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  final invalidDates = <String, (String, String)>{
    'fecha vacía': ('', 'Ingresa la fecha de nacimiento del estudiante.'),
    'fecha imposible': (
      '2018-02-30',
      'La fecha de nacimiento debe tener formato YYYY-MM-DD o DD/MM/YYYY.',
    ),
    'formato inválido': (
      'texto',
      'La fecha de nacimiento debe tener formato YYYY-MM-DD o DD/MM/YYYY.',
    ),
    'fecha futura': (
      isoDate(
        DateTime.now()
            .toUtc()
            .subtract(const Duration(hours: 5))
            .add(const Duration(days: 1)),
      ),
      'La fecha de nacimiento no puede ser futura.',
    ),
    'año 2006': (
      '2006-01-01',
      'El estudiante debe tener entre 8 y 9 años cumplidos.',
    ),
    '7 años': (
      isoDate(yearsAgo(7)),
      'El estudiante debe tener entre 8 y 9 años cumplidos.',
    ),
    '10 años': (
      isoDate(yearsAgo(10)),
      'El estudiante debe tener entre 8 y 9 años cumplidos.',
    ),
    'un día antes de cumplir 8': (
      isoDate(yearsAgo(8).add(const Duration(days: 1))),
      'El estudiante debe tener entre 8 y 9 años cumplidos.',
    ),
  };
  for (final entry in invalidDates.entries) {
    testWidgets('Rechaza ${entry.key} sin cerrar ni enviar el formulario', (
      tester,
    ) async {
      await openForm(tester);
      await fillStudent(tester, entry.value.$1);
      await save(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(entry.value.$2), findsOneWidget);
      expect(adminService.createCalls, 0);
      expect(adminService.updateCalls, 0);
      expect(
        tester.widget<TextField>(field('Nombres')).controller!.text,
        '  María José  ',
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final years in [8, 9]) {
    testWidgets('CP007 registra estudiante de $years años con consentimiento', (
      tester,
    ) async {
      await openForm(tester);
      await fillStudent(tester, isoDate(yearsAgo(years)));
      await save(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(adminService.createCalls, 1);
      final student = adminService.students.single;
      expect(student.nombres, 'María José');
      expect(student.apellidos, "Huamán O'Connor");
      expect(student.fechaNacimiento, isoDate(yearsAgo(years)));
      expect(student.seccionId, section.id);
      expect(student.activo, isTrue);
      expect(student.consentimientoFirmado, isTrue);
      expect(student.fechaConsentimiento, isoDate(DateTime.now()));
      expect(student.pinCorto, '5678');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Permite registrar un día antes de cumplir 10 años', (
    tester,
  ) async {
    await openForm(tester);
    await fillStudent(
      tester,
      isoDate(yearsAgo(10).add(const Duration(days: 1))),
    );
    await save(tester);
    expect(adminService.createCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Normaliza una fecha DD/MM/YYYY antes de enviarla', (
    tester,
  ) async {
    final birthDate = yearsAgo(8);
    await openForm(tester);
    await fillStudent(
      tester,
      '${birthDate.day}/${birthDate.month}/${birthDate.year}',
    );
    await save(tester);
    expect(adminService.students.single.fechaNacimiento, isoDate(birthDate));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Los errores se corrigen en el mismo formulario', (tester) async {
    await openForm(tester);
    await save(tester);
    expect(find.text('Ingresa los nombres del estudiante.'), findsOneWidget);
    expect(find.text('Ingresa los apellidos del estudiante.'), findsOneWidget);
    expect(
      find.text('Ingresa la fecha de nacimiento del estudiante.'),
      findsOneWidget,
    );
    await fillStudent(tester, isoDate(yearsAgo(8)));
    await save(tester);
    expect(adminService.createCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Con consentimiento firmado exige su fecha sin cerrar', (
    tester,
  ) async {
    await openForm(tester);
    await fillStudent(tester, isoDate(yearsAgo(8)));
    await enter(tester, 'Fecha consentimiento', '');
    await save(tester);
    expect(
      find.text('Ingresa la fecha del consentimiento firmado.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(adminService.createCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Editar un registro antiguo exige corregir sus datos', (
    tester,
  ) async {
    adminService.students = [studentRecord(fechaNacimiento: '2006-01-01')];
    await openForm(tester, editing: true);
    await save(tester);
    expect(
      find.text('El estudiante debe tener entre 8 y 9 años cumplidos.'),
      findsOneWidget,
    );
    expect(adminService.updateCalls, 0);
    await enter(tester, 'Fecha nacimiento', isoDate(yearsAgo(9)));
    await save(tester);
    expect(adminService.createCalls, 0);
    expect(adminService.updateCalls, 1);
    expect(adminService.students.single.pinCorto, '5678');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancelar no registra ni actualiza estudiantes', (tester) async {
    await openForm(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(adminService.createCalls, 0);
    expect(adminService.updateCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
