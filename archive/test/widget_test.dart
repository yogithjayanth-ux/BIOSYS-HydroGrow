import 'package:flutter_test/flutter_test.dart';
import 'package:hydrosense_companion_app_549065841/hydrosense_app.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const HydroSenseApp());
    await tester.pumpAndSettle();
    expect(find.text('HydroSense'), findsOneWidget);
  });
}
