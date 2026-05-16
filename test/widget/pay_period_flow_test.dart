import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ledger/main.dart';
import 'package:shift_ledger/src/app/ledger_state.dart';
import 'package:shift_ledger/src/domain/models.dart';
import 'package:shift_ledger/src/ui/widgets.dart';

void main() {
  testWidgets('changing pay period from settings propagates to home and summary flows', (
    tester,
  ) async {
    final rule = PayRule.defaultHourly(hourlyRate: 35);
    final state = LedgerState(
      now: DateTime(2026, 5, 13),
      payRules: [rule],
      payPeriod: const PayPeriod(
        mode: PayPeriodMode.naturalMonth,
        monthStartDay: 10,
      ),
      entries: [
        WorkEntry.create(
          id: 'may_05',
          workDate: DateTime(2026, 5, 5),
          startDateTime: DateTime(2026, 5, 5, 9),
          endDateTime: DateTime(2026, 5, 5, 18),
          breakMinutes: 60,
          payRule: rule,
        ),
        WorkEntry.create(
          id: 'may_12',
          workDate: DateTime(2026, 5, 12),
          startDateTime: DateTime(2026, 5, 12, 9),
          endDateTime: DateTime(2026, 5, 12, 18),
          breakMinutes: 60,
          payRule: rule,
        ),
      ],
    );

    await tester.pumpWidget(ShiftLedgerApp(state: state));

    await tester.scrollUntilVisible(
      find.text('2026-05-01 — 2026-05-31'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('2026-05-01 — 2026-05-31'), findsOneWidget);
    expect(find.text('16h'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    final payPeriodTile = tester
        .widgetList<SettingTile>(find.byType(SettingTile))
        .firstWhere((tile) => tile.title == '发薪周期');
    payPeriodTile.onTap!.call();
    await tester.pumpAndSettle();

    await tester.tap(find.text('固定日'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('2026-05-10 — 2026-06-09'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('2026-05-10 — 2026-06-09'), findsOneWidget);
    expect(find.text('8h'), findsWidgets);
    expect(find.text('1天'), findsWidgets);

    await tester.tap(find.text('汇总'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发薪周期'));
    await tester.pumpAndSettle();

    expect(find.text('每月10日起'), findsOneWidget);
    expect(find.text('发薪周期 · 31天'), findsOneWidget);
    expect(find.text('8h'), findsWidgets);
  });
}
