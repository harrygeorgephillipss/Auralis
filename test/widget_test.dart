import 'package:auralis/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Auralis renders primary navigation and home content',
      (tester) async {
    await tester.pumpWidget(const AuralisApp());

    expect(find.text('Auralis'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Listen without limits.'), findsOneWidget);
  });

  testWidgets('navigation switches between sections without losing shell',
      (tester) async {
    await tester.pumpWidget(const AuralisApp());

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    expect(find.text('Your library'), findsOneWidget);
    expect(find.text('Auralis'), findsOneWidget);
    expect(find.text('Nothing playing'), findsOneWidget);

    await tester.tap(find.text('Downloads'));
    await tester.pumpAndSettle();

    expect(find.text('Downloads'), findsWidgets);
    expect(find.text('Your authorized downloads will appear here.'),
        findsOneWidget);
  });

  testWidgets('settings can be opened from the app bar', (tester) async {
    await tester.pumpWidget(const AuralisApp());

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(
      find.text('Themes, player layouts, audio and provider preferences.'),
      findsOneWidget,
    );
  });
}
