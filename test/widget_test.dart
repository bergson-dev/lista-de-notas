// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:lista_notas/main.dart';

void main() {
  testWidgets('Task app basic UI test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BigDayApp());

    // Verify that our app starts with the title 'Minha Jornada'.
    expect(find.text('Minha Jornada'), findsOneWidget);
    
    // Verify that the empty state is shown initially.
    expect(find.text('Tudo limpo por aqui!'), findsOneWidget);
  });
}
