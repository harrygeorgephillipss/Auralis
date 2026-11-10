import 'package:auralis/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Auralis shell renders its primary navigation', (tester) async {
    await tester.pumpWidget(const AuralisApp());

    expect(find.text('Auralis'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
  });
}
