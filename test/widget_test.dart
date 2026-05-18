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

  testWidgets('startup notice is shown when bootstrap reports local data issues', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShiftLedgerApp(
        state: LedgerState.empty(now: DateTime(2026, 5, 13)),
        startupNotice: const AppStartupNotice(
          title: '本地账本读取失败',
          message: '检测到最近本地备份，可到“设置 > 本地备份/恢复”尝试恢复。',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本地账本读取失败'), findsOneWidget);
    expect(find.textContaining('设置 > 本地备份/恢复'), findsOneWidget);
  });
}
