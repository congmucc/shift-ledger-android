import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ledger/main.dart';
import 'package:shift_ledger/src/app/ledger_state.dart';
import 'package:shift_ledger/src/domain/models.dart';
import 'package:shift_ledger/src/ui/edit_entry_sheet.dart';
import 'package:shift_ledger/src/ui/theme.dart';
import 'package:shift_ledger/src/ui/widgets.dart';

void main() {
  testWidgets('uses iOS Neutral palette for the app shell', (tester) async {
    await tester.pumpWidget(
      ShiftLedgerApp(state: LedgerState.seeded(now: DateTime(2026, 5, 13))),
    );

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.scaffoldBackgroundColor, const Color(0xFFF9FAFB));
    expect(LedgerColors.paper, const Color(0xFFF9FAFB));
    expect(LedgerColors.workAmber, const Color(0xFF0066CC));
    expect(LedgerColors.overtimeMoss, const Color(0xFF34C759));
    expect(LedgerColors.warningCopper, const Color(0xFFFF9500));
  });

  testWidgets(
    'home summarizes multiple overtime segments with wrapping chips',
    (tester) async {
      final day = DateTime(2026, 5, 13);
      final rule = PayRule.defaultHourly(hourlyRate: 35);
      final state = LedgerState(
        now: day,
        payRules: [rule],
        entries: [
          WorkEntry.create(
            id: 'regular',
            workDate: day,
            startDateTime: DateTime(2026, 5, 13, 9),
            endDateTime: DateTime(2026, 5, 13, 12),
            payRule: rule,
            locationName: '门店 A',
          ),
          WorkEntry.create(
            id: 'overtime_1',
            workDate: day,
            startDateTime: DateTime(2026, 5, 13, 13),
            endDateTime: DateTime(2026, 5, 13, 14),
            type: EntryType.overtime,
            payRule: rule,
          ),
          WorkEntry.create(
            id: 'overtime_2',
            workDate: day,
            startDateTime: DateTime(2026, 5, 13, 20),
            endDateTime: DateTime(2026, 5, 13, 22),
            type: EntryType.overtime,
            payRule: rule,
          ),
        ],
      );

      await tester.pumpWidget(ShiftLedgerApp(state: state));

      expect(find.text('普通 3h'), findsOneWidget);
      expect(find.text('加班 3h'), findsOneWidget);
      expect(find.text('3段'), findsOneWidget);
      expect(find.text('13:00 — 14:00'), findsOneWidget);
      expect(find.text('20:00 — 22:00'), findsOneWidget);
      expect(find.text('夜班 0次'), findsNothing);
    },
  );

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

    await tester.tap(find.byTooltip('编辑').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增分段'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存').last);
    await tester.tap(find.text('保存').last);
    await tester.pumpAndSettle();
    expect(state.entries.length, 2);

    await tester.tap(find.byTooltip('编辑').first);
    await tester.pumpAndSettle();
    expect(find.text('删除当天记录'), findsNothing);
    await tester.ensureVisible(find.text('危险操作'));
    await tester.tap(find.text('危险操作'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('删除 2026-05-13 全部记录'));
    await tester.tap(find.textContaining('删除 2026-05-13 全部记录'));
    await tester.pumpAndSettle();
    expect(find.text('删除 2026-05-13 全部记录？'), findsOneWidget);
    expect(find.textContaining('将删除 2 段'), findsOneWidget);
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();
    expect(state.entries, isEmpty);
  });

  testWidgets('day delete is hidden after moving the edit sheet date', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShiftLedgerApp(state: LedgerState.seeded(now: DateTime(2026, 5, 13))),
    );

    await tester.tap(find.byTooltip('编辑').first);
    await tester.pumpAndSettle();
    expect(find.text('危险操作'), findsOneWidget);
    await tester.ensureVisible(find.text('危险操作'));
    await tester.tap(find.text('危险操作'));
    await tester.pumpAndSettle();
    expect(find.textContaining('删除 2026-05-13 全部记录'), findsOneWidget);
    await tester.tap(find.text('明天'));
    await tester.pumpAndSettle();
    expect(find.text('危险操作'), findsNothing);
    expect(find.textContaining('删除 2026-05-13 全部记录'), findsNothing);
    await tester.tap(find.text('昨天'));
    await tester.pumpAndSettle();
    expect(find.text('危险操作'), findsOneWidget);
    expect(find.textContaining('删除 2026-05-13 全部记录'), findsNothing);
  });

  testWidgets('home keeps only the three primary quick actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShiftLedgerApp(state: LedgerState.seeded(now: DateTime(2026, 5, 13))),
    );

    await tester.scrollUntilVisible(
      find.text('快捷操作'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('补今天'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('快捷操作'), findsOneWidget);
    expect(find.text('补今天'), findsOneWidget);
    expect(find.text('查日历'), findsOneWidget);
    expect(find.text('看汇总'), findsOneWidget);
    expect(find.text('套用模板'), findsNothing);
    expect(find.text('补一段'), findsNothing);
    expect(find.text('看某一天'), findsNothing);
    expect(find.text('导出 CSV'), findsNothing);

    expect(find.text('更多'), findsOneWidget);
    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();
    expect(find.text('更多操作'), findsOneWidget);
    expect(find.text('补其他日期'), findsOneWidget);
    expect(find.text('导出 CSV'), findsOneWidget);
    expect(find.text('模板、备份和规则'), findsOneWidget);
    await tester.tap(find.text('模板、备份和规则'));
    await tester.pumpAndSettle();
    expect(find.text('个人工时账本'), findsOneWidget);
  });

  testWidgets('empty home uses补今天 with adjustable default hint', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShiftLedgerApp(state: LedgerState.empty(now: DateTime(2026, 5, 13))),
    );

    expect(find.text('今天还没有记录。'), findsOneWidget);
    expect(find.text('补今天'), findsOneWidget);
    expect(find.textContaining('默认 09:00-18:00'), findsOneWidget);
    expect(find.text('创建 09:00-18:00 记录'), findsNothing);
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
    expect(find.text('收入组成'), findsOneWidget);
    expect(find.text('计薪依据'), findsOneWidget);
    expect(find.text('查看明细'), findsNothing);
    expect(find.text('全部明细'), findsNothing);
    final summaryExportAction = find.descendant(
      of: find.byType(Scaffold),
      matching: find.widgetWithText(FilledButton, '导出'),
    );
    await tester.tap(summaryExportAction);
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
    expect(find.text('未连接；可配置坚果云备份'), findsOneWidget);
    expect(find.text('最近删除'), findsOneWidget);
    expect(find.text('没有可恢复记录'), findsOneWidget);
  });

  testWidgets('deleted day can be restored from settings recent deleted', (
    tester,
  ) async {
    final state = LedgerState.seeded(now: DateTime(2026, 5, 13));
    await tester.pumpWidget(ShiftLedgerApp(state: state));

    await tester.tap(find.byTooltip('编辑').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('危险操作'));
    await tester.tap(find.text('危险操作'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('删除 2026-05-13 全部记录'));
    await tester.tap(find.textContaining('删除 2026-05-13 全部记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(state.entriesForDay(DateTime(2026, 5, 13)), isEmpty);
    expect(state.recentDeletedDays.length, 1);
    expect(find.text('撤销'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('最近删除'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('1天可恢复'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .ancestor(of: find.text('最近删除'), matching: find.byType(InkWell))
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('恢复这一天'), findsOneWidget);
    await tester.tap(find.text('恢复这一天'));
    await tester.pumpAndSettle();
    expect(find.text('恢复 2026-05-13？'), findsOneWidget);
    await tester.tap(find.text('确认恢复'));
    await tester.pumpAndSettle();

    expect(state.entriesForDay(DateTime(2026, 5, 13)).length, 2);
    expect(state.recentDeletedDays, isEmpty);
  });

  testWidgets('settings summarizes configured backup status', (tester) async {
    final state = LedgerState(
      now: DateTime(2026, 5, 13),
      webDavConfig: WebDavConfig(
        url: 'https://dav.jianguoyun.com/dav/',
        username: 'u@example.com',
        appPassword: 'app-pass',
      ),
      autoBackupConfig: AutoBackupConfig(
        enabled: true,
        lastSuccessAt: DateTime(2026, 5, 14, 8, 30),
        lastStatus: AutoBackupStatus.success,
      ),
    );
    await tester.pumpWidget(ShiftLedgerApp(state: state));

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('坚果云 WebDAV'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('自动备份正常；最近成功 2026-05-14 08:30'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .ancestor(of: find.text('坚果云 WebDAV'), matching: find.byType(InkWell))
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('当前状态'), findsOneWidget);
    expect(find.textContaining('自动备份正常；最近成功 2026-05-14 08:30'), findsWidgets);
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
      expect(find.textContaining('普通 8h'), findsWidgets);
      expect(find.textContaining('夜班'), findsWidgets);
      expect(find.text('2026年 5月 1日 · 0 段'), findsNothing);
      expect(find.byTooltip('编辑'), findsWidgets);

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(find.text('班次模板'), findsOneWidget);
      expect(find.text('早班模板'), findsNothing);
      await tester.tap(find.text('班次模板'));
      await tester.pumpAndSettle();
      expect(find.text('保存模板'), findsOneWidget);
      expect(find.text('模板名称'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, '模板名称'), '白班');
      expect(find.text('地点/岗位默认值'), findsOneWidget);
      expect(find.text('默认补贴'), findsOneWidget);
      expect(find.text('默认扣款'), findsOneWidget);
      await tester.ensureVisible(find.text('保存模板'));
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

  testWidgets('calendar exposes today jump and survives large text scale', (
    tester,
  ) async {
    final state = LedgerState.seeded(now: DateTime(2026, 5, 13));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(ShiftLedgerApp(state: state));

    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    expect(find.text('今天'), findsOneWidget);
    expect(
      MediaQuery.textScalerOf(tester.element(find.text('工时日历'))).scale(10),
      20,
    );

    await tester.tap(find.byTooltip('下个月'));
    await tester.pumpAndSettle();
    expect(find.text('2026 年 6 月'), findsOneWidget);

    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();
    expect(find.text('2026 年 5 月'), findsOneWidget);
    expect(
      find.byKey(const Key('calendar-legend-today-marker')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar month picker stays usable at large text scale', (
    tester,
  ) async {
    final state = LedgerState.seeded(now: DateTime(2026, 5, 13));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(ShiftLedgerApp(state: state));

    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026 年 5 月'));
    await tester.pumpAndSettle();

    expect(find.text('选择年月'), findsOneWidget);
    expect(find.textContaining('1月'), findsWidgets);
    expect(find.textContaining('12月'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings segmented sheets stay usable at large text scale', (
    tester,
  ) async {
    final state = LedgerState.seeded(now: DateTime(2026, 5, 13));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(ShiftLedgerApp(state: state));

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    final payPeriodTile = tester
        .widgetList<SettingTile>(find.byType(SettingTile))
        .firstWhere((tile) => tile.title == '发薪周期');
    payPeriodTile.onTap!.call();
    await tester.pumpAndSettle();
    expect(find.text('自然月'), findsOneWidget);
    expect(find.text('固定日'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();

    final payRuleTile = tester
        .widgetList<SettingTile>(find.byType(SettingTile))
        .firstWhere((tile) => tile.title == '计薪规则');
    payRuleTile.onTap!.call();
    await tester.pumpAndSettle();
    expect(find.text('按小时'), findsWidgets);
    expect(find.text('按天'), findsWidgets);
    expect(find.text('按月'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('segment editor dialog stays usable at large text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final rule = PayRule.defaultHourly(hourlyRate: 35);
    final entry = WorkEntry.create(
      id: 'segment_probe',
      workDate: DateTime(2026, 5, 13),
      startDateTime: DateTime(2026, 5, 13, 9),
      endDateTime: DateTime(2026, 5, 13, 18),
      payRule: rule,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SegmentEditorDialog(entry: entry, rules: [rule]),
        ),
      ),
    );

    expect(find.text('编辑本段'), findsOneWidget);
    expect(find.text('开始 HH:mm'), findsOneWidget);
    expect(find.text('结束 HH:mm'), findsOneWidget);
    expect(find.text('保存本段'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('summary and calendar stay dense at normal text scale', (
    tester,
  ) async {
    final state = LedgerState.seeded(now: DateTime(2026, 5, 13));
    await tester.pumpWidget(ShiftLedgerApp(state: state));

    await tester.tap(find.text('汇总'));
    await tester.pumpAndSettle();
    final summaryBottom = tester.getBottomLeft(find.text('计薪依据').first).dy;
    expect(summaryBottom, lessThan(700));

    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    expect(find.textContaining('月计 15h'), findsOneWidget);
    final calendarBottom = tester.getBottomLeft(find.text('13今')).dy;
    expect(calendarBottom, lessThan(620));
    expect(find.text('13今'), findsOneWidget);
    expect(find.byKey(const Key('calendar-month-grid')), findsOneWidget);
    final monthSummaryCard = find.byKey(
      const Key('calendar-month-summary-card'),
    );
    expect(
      find.descendant(of: monthSummaryCard, matching: find.text('出勤')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: monthSummaryCard, matching: find.text('2天')),
      findsWidgets,
    );
    expect(
      find.descendant(of: monthSummaryCard, matching: find.text('1次/7h')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: monthSummaryCard, matching: find.text('备注')),
      findsOneWidget,
    );
    expect(find.text('0天备注'), findsNothing);
    expect(monthSummaryCard, findsOneWidget);
    expect(
      tester.getTopLeft(monthSummaryCard).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('calendar-month-grid'))).dy,
      ),
    );
    await tester.scrollUntilVisible(
      find.textContaining('09:00 — 12:00'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('09:00 — 12:00'), findsWidgets);
    expect(find.text('管理当天分段'), findsWidgets);
    expect(find.text('删除当天记录 / 编辑'), findsNothing);
  });

  testWidgets(
    'edit sheet keeps save and danger actions reachable at large text',
    (tester) async {
      final state = LedgerState.seeded(now: DateTime(2026, 5, 13));
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(ShiftLedgerApp(state: state));

      await tester.tap(find.text('＋').last);
      await tester.pumpAndSettle();
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.text('新增 / 编辑工时记录')),
        ).scale(10),
        20,
      );
      await tester.ensureVisible(find.text('保存').last);
      expect(find.text('保存'), findsWidgets);
      await tester.ensureVisible(find.text('危险操作'));
      expect(find.text('危险操作'), findsOneWidget);
      await tester.tap(find.text('危险操作'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('删除 2026-05-13 全部记录'));
      expect(find.textContaining('删除 2026-05-13 全部记录'), findsOneWidget);
      expect(find.text('首页'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shift templates can carry defaults and be deleted', (
    tester,
  ) async {
    final state = LedgerState.empty(now: DateTime(2026, 5, 13));
    state.updateShiftTemplate(
      ShiftTemplate.standard(
        payRuleId: state.defaultRule.id,
      ).copyWith(id: 'tpl_custom', name: '周末店班'),
    );
    await tester.pumpWidget(ShiftLedgerApp(state: state));

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('班次模板'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<ShiftTemplate>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('周末店班').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '地点/岗位默认值'), '南山店');
    await tester.enterText(find.widgetWithText(TextField, '默认补贴'), '0');
    await tester.enterText(find.widgetWithText(TextField, '默认扣款'), '5');
    await tester.ensureVisible(find.text('保存模板'));
    await tester.tap(find.text('保存模板'));
    await tester.pumpAndSettle();

    final entry = state.createTemplateEntry(
      day: DateTime(2026, 5, 14),
      template: state.templates.firstWhere((tpl) => tpl.id == 'tpl_custom'),
    );
    expect(entry.locationName, '南山店');
    expect(entry.allowanceTotal, 0);
    expect(entry.deductionTotal, 5);

    await tester.tap(find.text('班次模板'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<ShiftTemplate>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('周末店班').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('删除模板'));
    await tester.tap(find.text('删除模板'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();
    expect(state.templates.any((tpl) => tpl.id == 'tpl_custom'), isFalse);
  });

  testWidgets(
    'built-in template keeps only single-template restore and cannot be deleted',
    (tester) async {
      final state = LedgerState.empty(now: DateTime(2026, 5, 13));
      state.updateShiftTemplate(
        state.templates.first.copyWith(
          name: '白班',
          breakMinutes: 45,
          defaultLocationName: '南山店',
        ),
      );
      state.updateShiftTemplate(
        ShiftTemplate.standard(
          payRuleId: state.defaultRule.id,
        ).copyWith(id: 'tpl_custom', name: '周末店班'),
      );

      await tester.pumpWidget(ShiftLedgerApp(state: state));

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('班次模板'));
      await tester.pumpAndSettle();

      expect(find.text('恢复当前内置模板'), findsOneWidget);
      expect(find.text('恢复全部内置模板'), findsNothing);
      final deleteBuiltIn = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '删除模板'),
      );
      expect(deleteBuiltIn.onPressed, isNull);

      await tester.ensureVisible(find.text('恢复当前内置模板'));
      await tester.tap(find.text('恢复当前内置模板'));
      await tester.pumpAndSettle();
      expect(find.text('恢复当前模板？'), findsOneWidget);
      expect(find.text('确认恢复'), findsOneWidget);
      await tester.tap(find.text('确认恢复'));
      await tester.pumpAndSettle();

      expect(
        state.templates.firstWhere(
          (template) => template.id == ShiftTemplate.standardId,
        ),
        isA<ShiftTemplate>()
            .having((template) => template.name, 'name', '标准班次')
            .having((template) => template.breakMinutes, 'breakMinutes', 0),
      );
    },
  );

  testWidgets(
    'moving a day onto another populated date preserves target entries and refreshes pay rule snapshot',
    (tester) async {
      final oldRule = PayRule.defaultHourly(hourlyRate: 35).copyWith(
        id: 'rule_old',
        effectiveFrom: DateTime(2026, 5, 1),
        effectiveTo: DateTime(2026, 5, 13),
        isDefault: false,
      );
      final newRule = PayRule.defaultHourly(hourlyRate: 48).copyWith(
        id: 'rule_new',
        effectiveFrom: DateTime(2026, 5, 14),
        isDefault: true,
      );
      final state = LedgerState(
        now: DateTime(2026, 5, 13),
        payRules: [oldRule, newRule],
        templates: [ShiftTemplate.standard(payRuleId: newRule.id)],
        entries: [
          WorkEntry.create(
            id: 'source_entry',
            workDate: DateTime(2026, 5, 13),
            startDateTime: DateTime(2026, 5, 13, 9),
            endDateTime: DateTime(2026, 5, 13, 18),
            breakMinutes: 60,
            type: EntryType.regular,
            payRule: oldRule,
          ),
          WorkEntry.create(
            id: 'target_entry',
            workDate: DateTime(2026, 5, 14),
            startDateTime: DateTime(2026, 5, 14, 13),
            endDateTime: DateTime(2026, 5, 14, 18),
            type: EntryType.regular,
            payRule: newRule,
          ),
        ],
      );

      await tester.pumpWidget(ShiftLedgerApp(state: state));

      await tester.tap(find.byTooltip('编辑').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('明天'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('保存').last);
      await tester.tap(find.text('保存').last);
      await tester.pumpAndSettle();

      final moved = state.entries.firstWhere(
        (entry) => entry.id == 'source_entry',
      );
      expect(ymd(moved.workDate), '2026-05-14');
      expect(moved.payRuleId, 'rule_new');
      expect(moved.payRuleSnapshot.id, 'rule_new');
      expect(state.entriesForDay(DateTime(2026, 5, 14)).length, 2);
      expect(state.entries.any((entry) => entry.id == 'target_entry'), isTrue);
    },
  );

  testWidgets('enabling auto backup saves current WebDAV fields first', (
    tester,
  ) async {
    final state = LedgerState.empty(now: DateTime(2026, 5, 13));
    await tester.pumpWidget(ShiftLedgerApp(state: state));

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('坚果云 WebDAV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('坚果云 WebDAV'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '账号'),
      'u@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '应用授权密码'),
      'app-pass',
    );
    await tester.tap(find.text('自动云备份'));
    await tester.pumpAndSettle();

    expect(state.webDavConfig.isConfigured, isTrue);
    expect(state.webDavConfig.username, 'u@example.com');
    expect(state.webDavConfig.appPassword, 'app-pass');
    expect(state.autoBackupConfig.enabled, isTrue);
    expect(state.autoBackupConfig.lastStatus, AutoBackupStatus.waiting);
  });
}
