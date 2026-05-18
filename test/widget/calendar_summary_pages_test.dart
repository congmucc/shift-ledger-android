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

  LedgerState buildMultiFilterState() {
    final rule = PayRule.defaultHourly(hourlyRate: 35);
    return LedgerState(
      now: DateTime(2026, 5, 15),
      payRules: [rule],
      entries: [
        WorkEntry.create(
          id: 'combo_night_overtime',
          workDate: DateTime(2026, 5, 3),
          startDateTime: DateTime(2026, 5, 3, 22),
          endDateTime: DateTime(2026, 5, 3, 23, 30),
          type: EntryType.overtime,
          payRule: rule,
        ),
        WorkEntry.create(
          id: 'overtime_only',
          workDate: DateTime(2026, 5, 4),
          startDateTime: DateTime(2026, 5, 4, 19),
          endDateTime: DateTime(2026, 5, 4, 21),
          type: EntryType.overtime,
          payRule: rule,
        ),
        WorkEntry.create(
          id: 'note_long_only',
          workDate: DateTime(2026, 5, 5),
          startDateTime: DateTime(2026, 5, 5, 8),
          endDateTime: DateTime(2026, 5, 5, 21, 30),
          payRule: rule,
          note: '超长班',
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
      await tester.tap(find.byIcon(Icons.sticky_note_2_outlined).last);
      await tester.pumpAndSettle();

      expect(find.text('1日 → 31日'), findsOneWidget);
      expect(find.text('这个月还没有备注'), findsOneWidget);
      expect(find.text('切回“全部”或直接补一段。'), findsOneWidget);
      expect(find.textContaining('你可以先切回“全部”'), findsNothing);

      final headerTop = tester.getTopLeft(find.text('1日 → 31日')).dy;
      final emptyTop = tester.getTopLeft(find.text('这个月还没有备注')).dy;
      expect(headerTop, lessThan(emptyTop));
    },
  );

  testWidgets('calendar filters support stacked multi-select narrowing', (
    tester,
  ) async {
    await tester.pumpWidget(ShiftLedgerApp(state: buildMultiFilterState()));

    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('列表'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bolt_rounded));
    await tester.pumpAndSettle();
    expect(find.text('22:00—23:30'), findsOneWidget);
    expect(find.text('19:00—21:00'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.nightlight_round));
    await tester.pumpAndSettle();
    expect(find.text('22:00—23:30'), findsOneWidget);
    expect(find.text('19:00—21:00'), findsNothing);
    expect(find.text('08:00—21:30'), findsNothing);

    await tester.tap(find.byIcon(Icons.nightlight_round));
    await tester.pumpAndSettle();
    expect(find.text('22:00—23:30'), findsOneWidget);
    expect(find.text('19:00—21:00'), findsOneWidget);
  });

  testWidgets('summary page keeps the approved aggregate boundary', (
    tester,
  ) async {
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
    expect(find.text('导出 CSV'), findsNothing);
    expect(find.text('按天查看'), findsNothing);
    expect(find.text('查看明细'), findsNothing);
    expect(find.text('全部日期'), findsNothing);
  });

  testWidgets(
    'summary page collapses record-dependent sections for empty ranges',
    (tester) async {
      await tester.pumpWidget(
        ShiftLedgerApp(state: LedgerState.empty(now: DateTime(2026, 5, 15))),
      );

      await tester.tap(find.text('汇总'));
      await tester.pumpAndSettle();
      expect(find.text('先去首页补今天，或到日历补录。'), findsOneWidget);
      expect(find.text('收入组成'), findsNothing);
      expect(find.text('总工时'), findsNothing);
      expect(find.text('收入估算'), findsNothing);
      expect(find.text('计薪依据'), findsOneWidget);
      expect(find.text('计算说明'), findsOneWidget);
    },
  );

  testWidgets('calendar keeps a clear empty day detail for unrecorded days', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ShiftLedgerApp(state: LedgerState.empty(now: DateTime(2026, 5, 15))),
    );

    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('超时'), findsOneWidget);
    expect(find.text('左右滑动'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('新增分段'),
      240,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('今日 · 暂无记录'), findsOneWidget);
    expect(find.text('这一天还没有记录'), findsOneWidget);
    expect(find.text('新增分段'), findsOneWidget);
    expect(find.text('休息日可留空，需要时再补录。'), findsOneWidget);
    expect(find.textContaining('如果这天只是休息，可以直接留空'), findsNothing);
  });

  testWidgets('calendar filter chips stay fully visible on phone width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ShiftLedgerApp(state: buildMultiFilterState()));

    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();

    expect(find.text('超时'), findsOneWidget);
    final timeoutChipRight = tester.getTopRight(find.text('超时')).dx;
    expect(timeoutChipRight, lessThanOrEqualTo(390));
  });
}
