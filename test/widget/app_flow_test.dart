import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ledger/main.dart';
import 'package:shift_ledger/src/app/ledger_state.dart';

void main() {
  testWidgets('main navigation exposes home calendar add summary settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShiftLedgerApp(state: LedgerState.seeded(now: DateTime(2026, 5, 13))),
    );

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

  testWidgets('summary and settings expose export backup and WebDAV actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShiftLedgerApp(state: LedgerState.seeded(now: DateTime(2026, 5, 13))),
    );

    await tester.tap(find.text('汇总'));
    await tester.pumpAndSettle();
    expect(find.text('工时汇总'), findsOneWidget);
    expect(find.text('CSV'), findsWidgets);
    await tester.tap(find.text('查看明细'));
    await tester.pumpAndSettle();
    expect(find.text('全部明细'), findsOneWidget);
    await tester.tap(find.text('关闭').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSV'));
    await tester.pumpAndSettle();
    expect(find.text('导出 CSV？'), findsOneWidget);
    await tester.tap(find.text('确认导出'));
    await tester.pumpAndSettle();
    expect(find.textContaining('CSV 已生成'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('本地备份/恢复'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('本地备份/恢复'), findsOneWidget);
    expect(find.text('坚果云 WebDAV'), findsOneWidget);
  });

  testWidgets(
    'calendar list and settings sheets expose review-critical details',
    (tester) async {
      final state = LedgerState.seeded(now: DateTime(2026, 5, 13));
      await tester.pumpWidget(ShiftLedgerApp(state: state));

      await tester.tap(find.text('日历'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('列表'));
      await tester.pumpAndSettle();
      expect(find.textContaining('普通 8h'), findsOneWidget);
      expect(find.textContaining('夜班'), findsWidgets);
      expect(find.text('编辑'), findsWidgets);

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(find.text('班次模板'), findsOneWidget);
      expect(find.text('早班模板'), findsNothing);
      await tester.tap(find.text('班次模板'));
      await tester.pumpAndSettle();
      expect(find.text('保存模板'), findsOneWidget);
      expect(find.text('模板名称'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, '模板名称'), '白班');
      await tester.tap(find.text('保存模板'));
      await tester.pumpAndSettle();
      expect(state.templates.first.name, '白班');

      await tester.tap(find.text('计薪规则'));
      await tester.pumpAndSettle();
      expect(find.text('按小时'), findsWidgets);
      expect(find.text('按天'), findsWidgets);
      expect(find.text('按月'), findsWidgets);
      expect(find.text('加班基准 ¥/h'), findsOneWidget);
      expect(find.text('休息日倍率'), findsOneWidget);
      await tester.tap(find.text('取消').last);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('坚果云 WebDAV'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('坚果云 WebDAV'));
      await tester.pumpAndSettle();
      expect(find.text('自动云备份'), findsOneWidget);
      expect(find.textContaining('最小间隔 1 小时'), findsOneWidget);
      expect(find.textContaining('每天最多 6 次'), findsOneWidget);
      expect(find.textContaining('打开 App 后自动检查'), findsOneWidget);
      final autoSwitch = tester.widget<Switch>(
        find.descendant(
          of: find.byType(SwitchListTile),
          matching: find.byType(Switch),
        ),
      );
      expect(autoSwitch.value, isFalse);
      await tester.tap(find.text('自动云备份'));
      await tester.pumpAndSettle();
      expect(find.textContaining('需重新授权'), findsWidgets);
      await tester.ensureVisible(find.text('从坚果云恢复'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从坚果云恢复'));
      await tester.pumpAndSettle();
      expect(find.text('从坚果云恢复？'), findsOneWidget);
    },
  );
}
