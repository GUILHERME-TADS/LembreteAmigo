import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/main.dart';

void main() {
  testWidgets('App renders welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MeuApp());
    expect(find.text('MeuApp Lembretes'), findsNothing);
  });
}
