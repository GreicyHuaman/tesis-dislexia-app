import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/models/admin_models.dart';
import 'package:mobile/features/admin/widgets/section_form_dialog.dart';

void main() {
  Future<void> openForm(
    WidgetTester tester, {
    AdminSection? section,
    ValueChanged<SectionFormData?>? onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final result = await showDialog<SectionFormData>(
                  context: context,
                  builder: (_) => SectionFormDialog(section: section),
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

  Finder nameField() => find.widgetWithText(TextFormField, 'Nombre de sección');

  testWidgets('El grado es tercero y no puede editarse', (tester) async {
    await openForm(tester);

    final field = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Grado'),
    );
    expect(field.initialValue, '3.º de primaria');
    expect(field.enabled, isFalse);
    expect(find.widgetWithText(TextField, '3.º de primaria'), findsOneWidget);
  });

  testWidgets('No guarda sin seleccionar turno', (tester) async {
    await openForm(tester);
    await tester.enterText(nameField(), 'A');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Selecciona un turno.'), findsOneWidget);
    expect(find.byType(SectionFormDialog), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('Valida el nombre obligatorio de la sección', (tester) async {
    await openForm(tester);
    await tester.enterText(nameField(), '  ');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa el nombre de la sección.'), findsOneWidget);
    expect(find.byType(SectionFormDialog), findsOneWidget);
  });

  for (final (label, expected) in [('Mañana', 'MAÑANA'), ('Tarde', 'TARDE')]) {
    testWidgets('Guarda con turno $label estandarizado', (tester) async {
      SectionFormData? saved;
      await openForm(tester, onResult: (result) => saved = result);
      await tester.enterText(nameField(), ' A ');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(saved, (nombre: 'A', turno: expected, activo: true));
      expect(find.byType(SectionFormDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('El turno solo ofrece Mañana y Tarde', (tester) async {
    await openForm(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text('Mañana').last, findsOneWidget);
    expect(find.text('Tarde').last, findsOneWidget);
    expect(find.text('Noche'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  for (final legacyTurno in ['MANANA', ' mañana ', 'MAÑANA', 'TARDE']) {
    testWidgets('Edita el turno existente "$legacyTurno"', (tester) async {
      SectionFormData? saved;
      final section = AdminSection(
        id: 1,
        grado: 3,
        nombre: 'A',
        turno: legacyTurno,
        activo: false,
      );
      await openForm(
        tester,
        section: section,
        onResult: (result) => saved = result,
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(saved, (
        nombre: 'A',
        turno: legacyTurno == 'TARDE' ? 'TARDE' : 'MAÑANA',
        activo: false,
      ));
    });
  }

  for (final invalidTurno in [null, '', 'turno mañana']) {
    testWidgets('Exige corregir el turno antiguo "$invalidTurno"', (
      tester,
    ) async {
      final section = AdminSection(
        id: 1,
        grado: 3,
        nombre: 'A',
        turno: invalidTurno,
        activo: true,
      );
      await openForm(tester, section: section);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Selecciona un turno.'), findsOneWidget);
      expect(find.byType(SectionFormDialog), findsOneWidget);
    });
  }

  testWidgets('Cancelar no devuelve datos para guardar', (tester) async {
    SectionFormData? saved;
    bool completed = false;
    await openForm(
      tester,
      onResult: (result) {
        saved = result;
        completed = true;
      },
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(saved, isNull);
    expect(find.byType(SectionFormDialog), findsNothing);
  });
}
