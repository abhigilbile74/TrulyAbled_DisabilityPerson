import 'package:flutter_test/flutter_test.dart';
import 'package:trulyabled/main.dart';

void main() {
  testWidgets('app starts on the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('TrulyAbled'), findsOneWidget);
  });
}
