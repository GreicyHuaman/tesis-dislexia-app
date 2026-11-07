import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobile/main.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('disly-startup-test-');
    Hive.init(directory.path);
    await Hive.openBox('classroom_mode');
    await Hive.openBox('pin_attempt_guard');
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets('Muestra pantalla de ingreso de estudiante', (tester) async {
    await tester.pumpWidget(const DyslexiaScreeningApp());
    await tester.pumpAndSettle();
    expect(find.text('Bienvenido a Disly'), findsOneWidget);
    expect(find.text('Ingrese su PIN de 4 numeros.'), findsOneWidget);
    expect(
      find.text('Tu docente te ayudará a preparar la sección para empezar.'),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
