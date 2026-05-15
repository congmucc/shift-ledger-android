import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ledger/main.dart';
import 'package:shift_ledger/src/app/ledger_state.dart';
import 'package:shift_ledger/src/domain/models.dart';

void main() {
  LedgerState buildMonthListState() {
    final rule = PayRule.defaultHourly(hourlyRate: 35);
    return LedgerState(
      now: DateTime(2026, 5, 15),
      payRules: [rule],
      entries: [
        WorkEntry.create(
          id: 'may_1_regular',
          workDate: DateTime(2026, 5, 1),
          startDateTime: DateTime(2026, 5, 1, 9),
          endDateTime: DateTime(2026, 5, 1, 17, 30),
          payRule: rule,
        ),
        WorkEntry.create(
          id: 'may_5_morning',
          workDate: DateTime(2026, 5, 5),
          startDateTime: DateTime(2026, 5, 5, 8),
          endDateTime: DateTime(2026, 5, 5, 12),
          payRule: rule,
        ),
        WorkEntry.create(
          id: 'may_5_afternoon',
          workDate: DateTime(2026, 5, 5),
          startDateTime: DateTime(2026, 5, 5, 13),
          endDateTime: DateTime(2026, 5, 5, 18),
          payRule: rule,
        ),
        WorkEntry.create(
          id: 'may_5_evening',
          workDate: DateTime(2026, 5, 5),
          startDateTime: DateTime(2026, 5, 5, 19),
          endDateTime: DateTime(2026, 5, 5, 21),
          type: EntryType.overtime,
          payRule: rule,
        ),
        WorkEntry.create(
          id: 'may_5_late',
          workDate: DateTime(2026, 5, 5),
          startDateTime: DateTime(2026, 5, 5, 22),
          endDateTime: DateTime(2026, 5, 5, 23),
          type: EntryType.overtime,
          payRule: rule,
        ),
      ],
    );
  }

  LedgerState buildSummaryState() {
    final rule = PayRule.defaultHourly(hourlyRate: 35);
    return LedgerState(
      now: DateTime(2026, 5, 15),
      payRules: [rule],
      entries: [
        WorkEntry.create(
          id: 'summary_seed',
          workDate: DateTime(2026, 5, 15),
          startDateTime: DateTime(2026, 5, 15, 9),
          endDateTime: DateTime(2026, 5, 15, 17),
          payRule: rule,
        ),
      ],
    );
  }

  testWidgets('calendar list mode locks the approved monthly chronology', (
    tester,
  ) async {
    await tester.pumpWidget(ShiftLedgerApp(state: buildMonthListState()));

    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('列表'));
    await tester.pumpAndSettle();

    expect(find.text('1日 → 31日'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('05'), findsOneWidget);
    expect(find.text('09:00—17:30'), findsOneWidget);
    expect(find.text('08:00—12:00'), findsOneWidget);
    expect(find.text('13:00—18:00'), findsOneWidget);
    expect(find.text('+2段'), findsOneWidget);
    expect(find.text('19:00—21:00'), findsNothing);
    expect(find.text('22:00—23:00'), findsNothing);

    final may01Top = tester.getTopLeft(find.text('01')).dy;
    final may05Top = tester.getTopLeft(find.text('05')).dy;
    expect(may01Top, lessThan(may05Top));
  });

  testWidgets(
    'calendar list mode keeps chronology header for filter-empty months',
    (tester) async {
      await tester.pumpWidget(ShiftLedgerApp(state: buildMonthListState()));

      await tester.tap(find.text('日历'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('列表'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '有备注'));
      await tester.pumpAndSettle();

      expect(find.text('1日 → 31日'), findsOneWidget);
      expect(find.text('本月暂无有备注记录'), findsOneWidget);

      final headerTop = tester.getTopLeft(find.text('1日 → 31日')).dy;
      final emptyTop = tester.getTopLeft(find.text('本月暂无有备注记录')).dy;
      expect(headerTop, lessThan(emptyTop));
    },
  );

  testWidgets(
    'summary page locks the approved boundary before implementation',
    (tester) async {
      await tester.pumpWidget(ShiftLedgerApp(state: buildSummaryState()));

      await tester.tap(find.text('汇总'));
      await tester.pumpAndSettle();

      final summaryExportAction = find.descendant(
        of: find.byType(Scaffold),
        matching: find.widgetWithText(FilledButton, '导出'),
      );

      expect(find.text('收入组成'), findsOneWidget);
      expect(find.text('计薪依据'), findsOneWidget);
      expect(summaryExportAction, findsOneWidget);
      expect(find.text('按天查看'), findsNothing);
      expect(find.text('查看明细'), findsNothing);
      expect(find.text('全部日期'), findsNothing);
    },
  );
}
