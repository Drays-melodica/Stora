import 'package:flutter_test/flutter_test.dart';
import 'package:stora/app.dart';

void main() {
  testWidgets('STORA affiche l\'écran de démarrage', (WidgetTester tester) async {
    await tester.pumpWidget(const StoraApp());
    await tester.pump();

    expect(find.text('STORA'), findsWidgets);
  });
}
