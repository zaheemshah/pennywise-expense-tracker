
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/main.dart';

void main() {
testWidgets('Expense Tracker opens', (WidgetTester tester) async {
await tester.pumpWidget(const ExpenseTrackerApp());

await tester.pumpAndSettle();

expect(find.text('Expense Tracker'), findsOneWidget);
});
}
