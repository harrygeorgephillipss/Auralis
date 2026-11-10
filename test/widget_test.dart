import 'package:auralis/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Auralis renders primary navigation and local library entry point',
      (tester) async {
    await tester.pumpWidget(const AuralisApp());

    expect(find.text('Auralis'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Listen without limits.'), findsOneWidget);
    expect(find.text('Import music'), findsOneWidget);
  });

  testWidgets('library explains how to import local audio', (tester) async {
    await tester.pumpWidget(const AuralisApp());

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    expect(find.text('Your music'), findsOneWidget);
    expect(find.text('Your library is empty'), findsOneWidget);
    expect(find.textContaining('choose audio files from your phone'),
        findsOneWidget);
  });

  testWidgets('downloads page clearly reports that online downloads are not '
      'integrated', (tester) async {
    await tester.pumpWidget(const AuralisApp());

    await tester.tap(find.text('Downloads'));
    await tester.pumpAndSettle();

    expect(find.text('Downloads'), findsWidgets);
    expect(find.textContaining('does not download online tracks yet'),
        findsOneWidget);
  });

  testWidgets('settings can be opened from the app bar', (tester) async {
    await tester.pumpWidget(const AuralisApp());

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Audio engine'), findsOneWidget);
  });
}
