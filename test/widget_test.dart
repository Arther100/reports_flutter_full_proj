// Power Operations App Widget Tests

import 'package:flutter_test/flutter_test.dart';

import 'package:power_operations_app/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PowerOperationsApp());

    // Verify that the app loads with Dashboard title
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
