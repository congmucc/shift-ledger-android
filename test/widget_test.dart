import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ledger/main.dart';
import 'package:shift_ledger/src/app/ledger_state.dart';

void main() {
  testWidgets('Shift Ledger launches to today workbench', (tester) async {
    await tester.pumpWidget(
      ShiftLedgerApp(state: LedgerState.seeded(now: DateTime(2026, 5, 13))),
    );
    expect(find.text('今日记录'), findsOneWidget);
    expect(find.text('今日已记录'), findsOneWidget);
  });
}
