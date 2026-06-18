import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('Muestra pantalla de ingreso de estudiante', (tester) async {
    await tester.pumpWidget(const DyslexiaScreeningApp());

    expect(find.text('Ingreso de estudiante'), findsOneWidget);
    expect(find.text('Ingresa tu PIN'), findsOneWidget);
  });
}
