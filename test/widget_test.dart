import 'package:flutter_test/flutter_test.dart';
import 'package:estudiante_app/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EstudianteApp());

    // Verify that our welcome text is present.
    expect(find.text('Estudiante App'), findsOneWidget);
    expect(find.text('Tu portal de aprendizaje'), findsOneWidget);
  });
}
