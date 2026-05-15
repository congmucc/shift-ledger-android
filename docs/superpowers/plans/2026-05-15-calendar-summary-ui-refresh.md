# Calendar / List / Summary UI Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the approved three-page UI split so calendar owns date browsing, list owns compact chronological records, and summary owns only range totals / composition / payroll basis / export.

**Architecture:** Keep the changes inside the existing Flutter page files instead of introducing a new UI framework. Add one small filter state model to `calendar_page.dart`, reshape the existing `_MonthList` / `_MonthGrid` widgets to match the approved browsing behavior, and remove summary-page day drill-down so the information boundary between the pages becomes explicit.

**Tech Stack:** Flutter Material 3, `table_calendar`, existing `LedgerState` / `LedgerSummary` domain models, widget tests via `flutter_test`.

---

## File map

- **Modify:** `/Users/eason/Desktop/project/shift-ledger-android/lib/src/ui/pages/calendar_page.dart`
  - Add calendar/list filter state.
  - Keep the month summary in a compact 2x3 presentation.
  - Make calendar cell dots use stronger semantic colors.
  - Make list rows show ascending month order and compact multi-segment previews.
- **Modify:** `/Users/eason/Desktop/project/shift-ledger-android/lib/src/ui/pages/summary_page.dart`
  - Remove day-level drill-down blocks.
  - Replace them with range overview, income composition, pay-rule basis, and export-oriented actions.
- **Create:** `/Users/eason/Desktop/project/shift-ledger-android/test/widget/calendar_summary_pages_test.dart`
  - Focused regression tests for the approved page boundaries and list behavior.
- **Modify:** `/Users/eason/Desktop/project/shift-ledger-android/test/widget/app_flow_test.dart`
  - Update the old summary-page assertions that currently expect day drill-down UI.

---

### Task 1: Lock the approved UX boundary in widget tests

**Files:**
- Create: `/Users/eason/Desktop/project/shift-ledger-android/test/widget/calendar_summary_pages_test.dart`
- Modify: `/Users/eason/Desktop/project/shift-ledger-android/test/widget/app_flow_test.dart`

- [ ] **Step 1: Write the failing calendar/list test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ledger/main.dart';
import 'package:shift_ledger/src/app/ledger_state.dart';
import 'package:shift_ledger/src/domain/models.dart';

void main() {
  testWidgets('calendar list keeps month-order and folds extra segments', (
    tester,
  ) async {
    final rule = PayRule.defaultHourly(hourlyRate: 35);
    final state = LedgerState(
      now: DateTime(2026, 5, 15),
      payRules: [rule],
      entries: [
        WorkEntry.create(
          id: 'd01',
          workDate: DateTime(2026, 5, 1),
          startDateTime: DateTime(2026, 5, 1, 9),
          endDateTime: DateTime(2026, 5, 1, 17, 30),
          payRule: rule,
          locationName: '门店 A',
        ),
        WorkEntry.create(
          id: 'd05-a',
          workDate: DateTime(2026, 5, 5),
          startDateTime: DateTime(2026, 5, 5, 8),
          endDateTime: DateTime(2026, 5, 5, 12),
          payRule: rule,
        ),
        WorkEntry.create(
          id: 'd05-b',
          workDate: DateTime(2026, 5, 5),
          startDateTime: DateTime(2026, 5, 5, 13),
          endDateTime: DateTime(2026, 5, 5, 18),
          payRule: rule,
        ),
        WorkEntry.create(
          id: 'd05-c',
          workDate: DateTime(2026, 5, 5),
          startDateTime: DateTime(2026, 5, 5, 18, 30),
          endDateTime: DateTime(2026, 5, 5, 20),
          type: EntryType.overtime,
          payRule: rule,
        ),
        WorkEntry.create(
          id: 'd05-d',
          workDate: DateTime(2026, 5, 5),
          startDateTime: DateTime(2026, 5, 5, 20, 30),
          endDateTime: DateTime(2026, 5, 5, 22),
          type: EntryType.overtime,
          payRule: rule,
        ),
      ],
    );

    await tester.pumpWidget(ShiftLedgerApp(state: state));
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
  });
}
```

- [ ] **Step 2: Write the failing summary-boundary test**

```dart
testWidgets('summary page shows aggregates instead of day drill-down', (
  tester,
) async {
  await tester.pumpWidget(
    ShiftLedgerApp(state: LedgerState.seeded(now: DateTime(2026, 5, 13))),
  );

  await tester.tap(find.text('汇总'));
  await tester.pumpAndSettle();

  expect(find.text('收入组成'), findsOneWidget);
  expect(find.text('计薪依据'), findsOneWidget);
  expect(find.text('导出'), findsWidgets);
  expect(find.text('按天查看'), findsNothing);
  expect(find.text('查看明细'), findsNothing);
  expect(find.text('全部日期'), findsNothing);
});
```

- [ ] **Step 3: Update the existing app-flow test so it stops asserting the old drill-down UI**

```dart
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

  await tester.tap(find.text('导出').first);
  await tester.pumpAndSettle();
  expect(find.text('导出 CSV？'), findsOneWidget);
  await tester.tap(find.text('确认导出'));
  await tester.pumpAndSettle();
  expect(find.textContaining('CSV 已生成'), findsOneWidget);

  await tester.tap(find.text('设置'));
  await tester.pumpAndSettle();
  expect(find.text('本地备份/恢复'), findsOneWidget);
});
```

- [ ] **Step 4: Run the widget tests to verify they fail against the current UI**

Run:
```bash
cd /Users/eason/Desktop/project/shift-ledger-android
flutter test test/widget/calendar_summary_pages_test.dart test/widget/app_flow_test.dart -r compact
```

Expected:
- FAIL because the current summary page still renders `按天查看` / `查看明细`
- FAIL because the current list rows do not yet show `1日 → 31日` and `+2段`

- [ ] **Step 5: Commit the failing-test baseline on the feature branch if you want explicit TDD checkpoints**

```bash
git add test/widget/calendar_summary_pages_test.dart test/widget/app_flow_test.dart
git commit -m "test: lock approved calendar and summary ux"
```

---

### Task 2: Rebuild the calendar page around the approved scanning behavior

**Files:**
- Modify: `/Users/eason/Desktop/project/shift-ledger-android/lib/src/ui/pages/calendar_page.dart`
- Test: `/Users/eason/Desktop/project/shift-ledger-android/test/widget/calendar_summary_pages_test.dart`

- [ ] **Step 1: Add filter state and a single source of truth for day matching inside `_CalendarPageState`**

```dart
enum _CalendarFilter { all, overtime, night, note, longDuration }

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month;
  late DateTime _selectedDay;
  bool _listMode = false;
  _CalendarFilter _filter = _CalendarFilter.all;

  bool _matchesFilter(DateTime day) {
    final entries = widget.state.entriesForDay(day);
    if (entries.isEmpty) return false;
    final summary = widget.state.summaryFor(DateRange.custom(day, day));
    return switch (_filter) {
      _CalendarFilter.all => true,
      _CalendarFilter.overtime => summary.overtimeHours > 0,
      _CalendarFilter.night => summary.nightHours > 0,
      _CalendarFilter.note => entries.any((entry) => entry.hasNote),
      _CalendarFilter.longDuration => summary.totalHours > 12,
    };
  }

  void _setFilter(_CalendarFilter value) {
    setState(() {
      _filter = value;
      if (!_matchesFilter(_selectedDay)) {
        final firstVisible = _firstMatchingDayInMonth();
        if (firstVisible != null) _selectedDay = firstVisible;
      }
    });
  }

  DateTime? _firstMatchingDayInMonth() {
    for (
      var day = DateTime(_month.year, _month.month, 1);
      day.month == _month.month;
      day = day.add(const Duration(days: 1))
    ) {
      if (_matchesFilter(day)) return day;
    }
    return null;
  }
}
```

- [ ] **Step 2: Insert the approved filter chip row below the 日历 / 列表 segmented control**

```dart
Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    _CalendarFilterChip(
      label: '全部',
      selected: _filter == _CalendarFilter.all,
      color: LedgerColors.primaryBlue,
      onTap: () => _setFilter(_CalendarFilter.all),
    ),
    _CalendarFilterChip(
      label: '加班',
      selected: _filter == _CalendarFilter.overtime,
      color: LedgerColors.successGreen,
      onTap: () => _setFilter(_CalendarFilter.overtime),
    ),
    _CalendarFilterChip(
      label: '夜班',
      selected: _filter == _CalendarFilter.night,
      color: LedgerColors.nightIndigo,
      onTap: () => _setFilter(_CalendarFilter.night),
    ),
    _CalendarFilterChip(
      label: '有备注',
      selected: _filter == _CalendarFilter.note,
      color: LedgerColors.warningOrange,
      onTap: () => _setFilter(_CalendarFilter.note),
    ),
    _CalendarFilterChip(
      label: '超长',
      selected: _filter == _CalendarFilter.longDuration,
      color: LedgerColors.errorRed,
      onTap: () => _setFilter(_CalendarFilter.longDuration),
    ),
  ],
),
```

- [ ] **Step 3: Pass the filter matcher into `_MonthGrid` and keep non-matching days structurally visible but visually quiet**

```dart
_MonthGrid(
  state: widget.state,
  month: _month,
  selectedDay: _selectedDay,
  onSelect: _selectDay,
  isDayVisible: _matchesFilter,
),
```

```dart
final visibleInFilter = isDayVisible(day);
final hasWork = entries.isNotEmpty && visibleInFilter;
final hasOvertime = summary.overtimeHours > 0 && visibleInFilter;
final hasNight = summary.nightHours > 0 && visibleInFilter;
final hasLongDuration = summary.totalHours > 12 && visibleInFilter;
final hasNote = entries.any((entry) => entry.hasNote) && visibleInFilter;
```

- [ ] **Step 4: Strengthen the semantic markers so the dots match the category color and remain readable at a glance**

```dart
SizedBox(
  height: 8,
  child: Wrap(
    alignment: WrapAlignment.center,
    spacing: 3,
    children: [
      if (hasWork) const _Dot(color: LedgerColors.primaryBlue),
      if (hasOvertime) const _Dot(color: LedgerColors.successGreen),
      if (hasNight) const _Dot(color: LedgerColors.nightIndigo),
      if (hasLongDuration) const _Dot(color: LedgerColors.errorRed),
      if (hasNote)
        const _NoteMarker(color: LedgerColors.warningOrange),
    ],
  ),
),
```

- [ ] **Step 5: Run the focused test and verify the filterable calendar shell still behaves**

Run:
```bash
cd /Users/eason/Desktop/project/shift-ledger-android
flutter test test/widget/calendar_summary_pages_test.dart --plain-name "calendar list keeps month-order and folds extra segments"
```

Expected:
- PASS once the calendar shell renders the new filter row and the child widgets receive the matching logic.

- [ ] **Step 6: Commit the calendar shell refresh**

```bash
git add lib/src/ui/pages/calendar_page.dart test/widget/calendar_summary_pages_test.dart
git commit -m "feat: refresh calendar filters and month scanning"
```

---

### Task 3: Make the month list compact, chronological, and segment-aware

**Files:**
- Modify: `/Users/eason/Desktop/project/shift-ledger-android/lib/src/ui/pages/calendar_page.dart`
- Test: `/Users/eason/Desktop/project/shift-ledger-android/test/widget/calendar_summary_pages_test.dart`

- [ ] **Step 1: Keep `_MonthList` in ascending month order and add the explicit sort label the mockup uses**

```dart
final days = [
  for (
    var day = widget.range.start;
    day.isBefore(widget.range.endExclusive);
    day = day.add(const Duration(days: 1))
  )
    if (widget.matchesFilter(day)) day,
];

return Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Align(
      alignment: Alignment.centerRight,
      child: _SmallPill('1日 → 31日'),
    ),
    const SizedBox(height: 8),
    ...visibleDays.map(...),
  ],
);
```

- [ ] **Step 2: Add a compact time-chip preview so 1 segment shows full time, 2 segments show both, and 3+ segments collapse to `+N段`**

```dart
List<String> _segmentPreview(List<WorkEntry> entries) {
  final labels = entries.map((entry) => entry.timeRangeLabel).toList();
  if (labels.length <= 2) return labels;
  return [labels[0], labels[1], '+${labels.length - 2}段'];
}
```

```dart
Wrap(
  spacing: 8,
  runSpacing: 6,
  children: [
    for (final label in _segmentPreview(entries))
      _SmallPill(label),
  ],
),
```

- [ ] **Step 3: Rebuild `_MonthListRow` so the left date block and status markers match the calendar semantics**

```dart
Container(
  width: 60,
  padding: const EdgeInsets.symmetric(vertical: 8),
  decoration: BoxDecoration(
    color: LedgerColors.primaryBlueSoft.withValues(alpha: .88),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: LedgerColors.hairline),
  ),
  child: Column(
    children: [
      Text(day.day.toString().padLeft(2, '0'), style: ...),
      Text(_weekdayText(day.weekday), style: ...),
      const SizedBox(height: 6),
      Wrap(
        spacing: 4,
        children: [
          const _Dot(color: LedgerColors.primaryBlue),
          if (summary.overtimeHours > 0)
            const _Dot(color: LedgerColors.successGreen),
          if (summary.nightHours > 0)
            const _Dot(color: LedgerColors.nightIndigo),
          if (summary.totalHours > 12)
            const _Dot(color: LedgerColors.errorRed),
        ],
      ),
    ],
  ),
),
```

- [ ] **Step 4: Keep the row information order stable: segment count → total hours → semantic chips → time preview → meta summary → amount / edit**

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        Text('${entries.length} 段', style: Theme.of(context).textTheme.titleMedium),
        _SmallPill(hoursText(summary.totalHours)),
        if (summary.overtimeHours > 0)
          _SemanticPill('加班 ${hoursText(summary.overtimeHours)}', LedgerColors.successGreen),
        if (summary.nightHours > 0)
          _SemanticPill('夜班', LedgerColors.nightIndigo),
        if (entries.any((entry) => entry.hasNote))
          _SemanticPill('有备注', LedgerColors.warningOrange),
        if (summary.totalHours > 12)
          _SemanticPill('超长', LedgerColors.errorRed),
      ],
    ),
    const SizedBox(height: 6),
    Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [for (final label in _segmentPreview(entries)) _SmallPill(label)],
    ),
    const SizedBox(height: 6),
    Text(meta, style: const TextStyle(color: LedgerColors.muted, fontSize: 13)),
  ],
),
```

- [ ] **Step 5: Re-run the dedicated list test and verify the chronological sample rows render as approved**

Run:
```bash
cd /Users/eason/Desktop/project/shift-ledger-android
flutter test test/widget/calendar_summary_pages_test.dart --plain-name "calendar list keeps month-order and folds extra segments" -r compact
```

Expected:
- PASS with `1日 → 31日`, `09:00—17:30`, `08:00—12:00`, `13:00—18:00`, and `+2段` present.

- [ ] **Step 6: Commit the list-page refresh**

```bash
git add lib/src/ui/pages/calendar_page.dart test/widget/calendar_summary_pages_test.dart
git commit -m "feat: tighten calendar list chronology and segment preview"
```

---

### Task 4: Strip summary page back to totals, composition, payroll basis, and export

**Files:**
- Modify: `/Users/eason/Desktop/project/shift-ledger-android/lib/src/ui/pages/summary_page.dart`
- Modify: `/Users/eason/Desktop/project/shift-ledger-android/test/widget/app_flow_test.dart`
- Test: `/Users/eason/Desktop/project/shift-ledger-android/test/widget/calendar_summary_pages_test.dart`

- [ ] **Step 1: Remove the day drill-down state from `build()` and keep only range + aggregate data**

```dart
@override
Widget build(BuildContext context) {
  final range = _range();
  final summary = widget.state.summaryFor(range);

  return PageFrame(
    title: '工时汇总',
    trailing: FilledButton(
      onPressed: _exporting ? null : () => _exportCsv(range),
      child: Text(_exporting ? '导出中' : '导出'),
    ),
    children: [
      _RangeSelector(...),
      const SizedBox(height: 12),
      _SummaryRangeCard(range: range),
      const SizedBox(height: 12),
      _SummaryOverview(summary: summary),
      const SizedBox(height: 12),
      _SummaryCompositionCard(summary: summary),
      const SizedBox(height: 12),
      _SummaryPayRuleCard(
        rules: widget.state.payRules,
        nightRule: widget.state.nightRule,
        onShowBreakdown: () => _showIncomeBreakdown(summary),
        onExport: () => _exportCsv(range),
      ),
    ],
  );
}
```

- [ ] **Step 2: Delete the now-conflicting day-browsing helpers and replace them with dedicated aggregate cards**

```dart
// Remove these unused drill-down structures once the new cards compile:
// - _groupSummaryByDay
// - _showDayRows
// - _InsightGrid
// - _SummaryDrillDownSheet / _SummaryDrillDownSheetState
// - _ExpandedSegmentLine
// - _DaySummaryRow
```

```dart
class _SummaryRangeCard extends StatelessWidget {
  const _SummaryRangeCard({required this.range});
  final DateRange range;

  @override
  Widget build(BuildContext context) => LedgerCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('范围', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Text(range.label ?? '${ymd(range.start)} — ${ymd(range.endInclusive)}'),
        const SizedBox(height: 4),
        const Text('这里只看总数、组成、规则依据，不再重复按天浏览'),
      ],
    ),
  );
}
```

- [ ] **Step 3: Rebuild the overview block into 2 large cards plus 4 compact metrics**

```dart
class _SummaryOverview extends StatelessWidget {
  const _SummaryOverview({required this.summary});
  final LedgerSummary summary;

  @override
  Widget build(BuildContext context) => LedgerCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: _LargeSummaryMetric('总工时', hoursText(summary.totalHours), '${summary.attendanceDays} 天出勤')),
            const SizedBox(width: 8),
            Expanded(child: _LargeSummaryMetric('收入估算', moneyText(summary.income), '按当前规则试算')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _CompactSummaryMetric('加班', hoursText(summary.overtimeHours))),
            const SizedBox(width: 8),
            Expanded(child: _CompactSummaryMetric('夜班', '${summary.nightShiftCount}次')),
            const SizedBox(width: 8),
            Expanded(child: _CompactSummaryMetric('补贴', moneyText(summary.allowance))),
            const SizedBox(width: 8),
            Expanded(child: _CompactSummaryMetric('扣款', moneyText(summary.deduction))),
          ],
        ),
      ],
    ),
  );
}
```

- [ ] **Step 4: Add the income-composition and payroll-basis cards, keeping actions export-oriented instead of navigation-oriented**

```dart
class _SummaryCompositionCard extends StatelessWidget {
  const _SummaryCompositionCard({required this.summary});
  final LedgerSummary summary;

  @override
  Widget build(BuildContext context) => LedgerCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('收入组成', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            const Text('范围内聚合', style: TextStyle(color: LedgerColors.muted)),
          ],
        ),
        const SizedBox(height: 12),
        _BreakdownRow(
          label: '普通工时',
          value: '${hoursText(summary.regularHours)} · ${moneyText(summary.baseIncome)}',
          color: LedgerColors.primaryBlue,
          fraction: summary.totalHours == 0 ? 0 : summary.regularHours / summary.totalHours,
        ),
        _BreakdownRow(
          label: '加班工时',
          value: '${hoursText(summary.overtimeHours)} · ${moneyText(summary.overtimeIncome)}',
          color: LedgerColors.successGreen,
          fraction: summary.totalHours == 0 ? 0 : summary.overtimeHours / summary.totalHours,
        ),
        _BreakdownRow(
          label: '夜班补偿',
          value: '${summary.nightShiftCount}次 · ${moneyText(summary.nightIncome)}',
          color: LedgerColors.nightIndigo,
          fraction: summary.totalHours == 0 ? 0 : summary.nightHours / summary.totalHours,
        ),
      ],
    ),
  );
}
```

```dart
class _SummaryPayRuleCard extends StatelessWidget {
  const _SummaryPayRuleCard({
    required this.rules,
    required this.nightRule,
    required this.onShowBreakdown,
    required this.onExport,
  });

  final List<PayRule> rules;
  final NightShiftRule nightRule;
  final VoidCallback onShowBreakdown;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) => LedgerCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('计薪依据', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          '按小时 ${moneyText(rules.first.hourlyRate)}/h · 超 8h 后按 1.5x 计算 · 夜班补贴 ${moneyText(nightRule.allowancePerShift)}/次',
          style: const TextStyle(color: LedgerColors.muted, height: 1.5),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.tonal(onPressed: onShowBreakdown, child: const Text('计算说明')),
            OutlinedButton(onPressed: onExport, child: const Text('导出 CSV')),
          ],
        ),
      ],
    ),
  );
}
```

- [ ] **Step 5: Run the summary tests, then clean up any dead-code warnings by removing the old drill-down classes**

Run:
```bash
cd /Users/eason/Desktop/project/shift-ledger-android
flutter test test/widget/calendar_summary_pages_test.dart test/widget/app_flow_test.dart -r compact
flutter analyze
```

Expected:
- Widget tests PASS with `收入组成`, `计薪依据`, and `导出` visible.
- `flutter analyze` returns `No issues found!` after the unused day-drilldown helpers are deleted.

- [ ] **Step 6: Commit the summary-page boundary cleanup**

```bash
git add lib/src/ui/pages/summary_page.dart test/widget/calendar_summary_pages_test.dart test/widget/app_flow_test.dart
git commit -m "feat: simplify summary page to aggregates and payroll basis"
```

---

### Task 5: Full verification before handoff

**Files:**
- Verify only

- [ ] **Step 1: Run the full test suite**

Run:
```bash
cd /Users/eason/Desktop/project/shift-ledger-android
flutter test
```

Expected:
- Full suite PASS without regressions in home, settings, backup, or export flows.

- [ ] **Step 2: Run analyzer one more time on the final tree**

Run:
```bash
cd /Users/eason/Desktop/project/shift-ledger-android
flutter analyze
```

Expected:
- `No issues found!`

- [ ] **Step 3: Do a manual smoke check of the three page boundaries on a local device or web runner**

```bash
cd /Users/eason/Desktop/project/shift-ledger-android
flutter run -d chrome
```

Manual checklist:
- Calendar page shows 2x3 month summary, filter chips, stronger semantic dots, and selected-day detail.
- List mode shows dates in month order (`1日 → 31日`) and collapses extra segments into `+N段`.
- Summary page no longer exposes per-day browsing and only shows range totals, composition, payroll basis, and export.

- [ ] **Step 4: Commit the verified final UI refresh**

```bash
git add lib/src/ui/pages/calendar_page.dart lib/src/ui/pages/summary_page.dart test/widget/calendar_summary_pages_test.dart test/widget/app_flow_test.dart
git commit -m "feat: land approved calendar list and summary refresh"
```
