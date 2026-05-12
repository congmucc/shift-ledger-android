import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ledger/main.dart';
import 'package:shift_ledger/src/app/ledger_state.dart';

void main() {
  testWidgets('main navigation exposes home calendar add summary settings', (tester) async {
    await tester.pumpWidget(ShiftLedgerApp(
      state: LedgerState.seeded(now: DateTime(2026, 5, 13)),
    ));

    expect(find.text('今日记录'), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('日历'), findsOneWidget);
    expect(find.text('＋'), findsWidgets);
    expect(find.text('汇总'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('can add edit and delete a work record', (tester) async {
    final state = LedgerState.empty(now: DateTime(2026, 5, 13));
    await tester.pumpWidget(ShiftLedgerApp(state: state));

    await tester.tap(find.text('＋').last);
    await tester.pumpAndSettle();
    expect(find.text('新增 / 编辑工时记录'), findsOneWidget);

    await tester.ensureVisible(find.text('保存').last);
    await tester.tap(find.text('保存').last);
    await tester.pumpAndSettle();
    expect(state.entries.length, 1);
    expect(find.textContaining('09:00 — 18:00'), findsWidgets);

    await tester.tap(find.text('编辑').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增分段'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存').last);
    await tester.tap(find.text('保存').last);
    await tester.pumpAndSettle();
    expect(state.entries.length, 2);

    await tester.tap(find.text('编辑').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('删除当天记录'));
    await tester.tap(find.text('删除当天记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();
    expect(state.entries, isEmpty);
  });

  testWidgets('summary and settings expose export backup and WebDAV actions', (tester) async {
    await tester.pumpWidget(ShiftLedgerApp(
      state: LedgerState.seeded(now: DateTime(2026, 5, 13)),
    ));

    await tester.tap(find.text('汇总'));
    await tester.pumpAndSettle();
    expect(find.text('工时汇总'), findsOneWidget);
    expect(find.text('CSV'), findsWidgets);
    await tester.scrollUntilVisible(find.text('导出 CSV'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('导出 CSV'), findsWidgets);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('本地备份/恢复'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('本地备份/恢复'), findsOneWidget);
    expect(find.text('坚果云 WebDAV'), findsOneWidget);
  });
}
