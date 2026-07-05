import 'package:flutter_test/flutter_test.dart';
import 'package:lembretes_app/main.dart';

void main() {
  testWidgets('App renders welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MeuApp());
    expect(find.text('MeuApp Lembretes'), findsNothing);
  });

  test('identifica rotas exclusivas do idoso', () {
    expect(isElderlyOnlyRoute('/elderly-home'), isTrue);
    expect(isElderlyOnlyRoute('/elderly-profile'), isTrue);
    expect(isElderlyOnlyRoute('/edit-profile'), isTrue);
    expect(isElderlyOnlyRoute('/recording-audio'), isTrue);
    expect(isElderlyOnlyRoute('/take-photo-confirmation'), isTrue);

    expect(isElderlyOnlyRoute('/messages'), isFalse);
    expect(isElderlyOnlyRoute('/emergency-alert'), isFalse);
    expect(isElderlyOnlyRoute('/supervisor-dashboard'), isFalse);
  });
}
