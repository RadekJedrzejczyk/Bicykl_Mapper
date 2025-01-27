import '../lib/map_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Test my widget', (WidgetTester tester) async {
    MyApp application = MyApp();

    await tester.pumpWidget(application);
    expect(find.text('Dodaj przystanek'), findsOneWidget);
  });
}
