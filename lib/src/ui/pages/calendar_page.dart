import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/ledger_state.dart';
import '../../domain/models.dart';
import '../edit_entry_sheet.dart';
import '../theme.dart';
import '../widgets.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.state});
  final LedgerState state;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month;
  late DateTime _selectedDay;
  bool _listMode = false;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.state.now.year, widget.state.now.month);
    _selectedDay = widget.state.now;
  }

  @override
  Widget build(BuildContext context) {
    final range = DateRange.month(_month.year, _month.month);
    final summary = widget.state.summaryFor(range);
    return PageFrame(
      title: '工时日历',
      trailing: IconButton(
        onPressed: () =>
            showEditWorkEntrySheet(context, widget.state, day: _selectedDay),
        icon: const Icon(Icons.add),
        tooltip: '补一段',
      ),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '上个月',
              onPressed: () =>
                  _selectMonth(DateTime(_month.year, _month.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: TextButton(
                onPressed: _showMonthPicker,
                child: Text(
                  '${_month.year} 年 ${_month.month} 月',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _jumpToToday,
              icon: const Icon(Icons.today_outlined, size: 18),
              label: const Text('今天'),
            ),
            IconButton(
              tooltip: '下个月',
              onPressed: () =>
                  _selectMonth(DateTime(_month.year, _month.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Text(
          '月计 ${hoursText(summary.totalHours)} · 出勤 ${summary.attendanceDays}天 · 加班 ${hoursText(summary.overtimeHours)}',
          key: const Key('calendar-month-compact-summary'),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: LedgerColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('日历')),
            ButtonSegment(value: true, label: Text('列表')),
          ],
          selected: {_listMode},
          onSelectionChanged: (values) =>
              setState(() => _listMode = values.first),
        ),
        const SizedBox(height: 12),
        if (_listMode)
          _MonthList(state: widget.state, range: range, onSelect: _selectDay)
        else
          _MonthGrid(
            state: widget.state,
            month: _month,
            selectedDay: _selectedDay,
            onSelect: _selectDay,
          ),
        SectionHeader(
          title:
              '${ymd(_selectedDay) == ymd(widget.state.now) ? '今日 · ' : ''}${_selectedDay.month} 月 ${_selectedDay.day} 日详情',
          actionLabel: '补一段',
          onAction: () =>
              showEditWorkEntrySheet(context, widget.state, day: _selectedDay),
        ),
        _DayDetails(state: widget.state, day: _selectedDay),
        const SizedBox(height: 10),
        _MonthSummaryGrid(summary: summary),
      ],
    );
  }

  void _selectDay(DateTime day) => setState(() {
    _selectedDay = dateOnly(day);
    _month = DateTime(day.year, day.month);
  });

  void _jumpToToday() => setState(() {
    _selectedDay = widget.state.now;
    _month = DateTime(widget.state.now.year, widget.state.now.month);
  });

  void _selectMonth(DateTime month) => setState(() => _applyMonth(month));

  void _applyMonth(DateTime month) {
    final targetMonth = DateTime(month.year, month.month);
    _month = targetMonth;
    final today = dateOnly(widget.state.now);
    _selectedDay =
        targetMonth.year == today.year && targetMonth.month == today.month
        ? today
        : targetMonth;
  }

  Future<void> _showMonthPicker() async {
    var pickerYear = _month.year;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: LedgerColors.paper,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '选择年月',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('完成'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => setSheetState(() => pickerYear--),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '$pickerYear 年',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setSheetState(() => pickerYear++),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  childAspectRatio: 2.1,
                  children: [
                    for (var month = 1; month <= 12; month++)
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: OutlinedButton(
                          onPressed: () {
                            setState(
                              () => _applyMonth(DateTime(pickerYear, month)),
                            );
                            Navigator.pop(context);
                          },
                          child: Text(
                            '$month月\n${hoursText(widget.state.summaryFor(DateRange.month(pickerYear, month)).totalHours)}',
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.state,
    required this.month,
    required this.selectedDay,
    required this.onSelect,
  });
  final LedgerState state;
  final DateTime month;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      key: const Key('calendar-month-grid'),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: Column(
        children: [
          TableCalendar<void>(
            locale: 'zh_CN',
            firstDay: DateTime(2000),
            lastDay: DateTime(2100, 12, 31),
            focusedDay: month,
            currentDay: state.now,
            headerVisible: false,
            sixWeekMonthsEnforced: true,
            availableGestures: AvailableGestures.horizontalSwipe,
            rowHeight: MediaQuery.textScalerOf(
              context,
            ).scale(56).clamp(56.0, 68.0),
            daysOfWeekHeight: 22,
            selectedDayPredicate: (day) => ymd(day) == ymd(selectedDay),
            onDaySelected: (selected, focused) => onSelect(selected),
            onPageChanged: (focused) {
              final today = dateOnly(state.now);
              final target =
                  focused.year == today.year && focused.month == today.month
                  ? today
                  : DateTime(focused.year, focused.month);
              onSelect(target);
            },
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: true,
              cellMargin: EdgeInsets.zero,
              cellPadding: EdgeInsets.zero,
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: LedgerColors.muted),
              weekendStyle: TextStyle(color: LedgerColors.muted),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: _buildCell,
              todayBuilder: _buildCell,
              selectedBuilder: _buildCell,
              outsideBuilder: _buildCell,
            ),
          ),
          const SizedBox(height: 6),
          const Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _LegendMark(color: LedgerColors.workAmber, label: '有工时'),
              _LegendMark(color: LedgerColors.overtimeMoss, label: '加班'),
              _LegendMark(color: LedgerColors.nightSlate, label: '夜班'),
              _LegendMark(color: LedgerColors.warningCopper, label: '备注'),
              _LegendMark(color: LedgerColors.infoBlue, label: '今日'),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildCell(BuildContext context, DateTime day, DateTime focusedDay) {
    final entries = state.entriesForDay(day);
    final summary = state.summaryFor(DateRange.custom(day, day));
    final inMonth = day.month == month.month;
    final selected = ymd(day) == ymd(selectedDay);
    final today = ymd(day) == ymd(state.now);
    final hasNote = entries.any((entry) => entry.hasNote);
    final hasOvertime = summary.overtimeHours > 0;
    final hasNight = summary.nightHours > 0;
    final hasWork = entries.isNotEmpty;
    final dateFill = selected
        ? LedgerColors.warningCopper
        : hasWork
        ? LedgerColors.workAmberSoft.withValues(alpha: .82)
        : Colors.transparent;
    final dateTextColor = selected
        ? Colors.white
        : inMonth
        ? LedgerColors.ink
        : LedgerColors.stone;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${today ? '今日，' : ''}${day.month}月${day.day}日，${hoursText(summary.totalHours)}，${entries.length}段${hasOvertime ? '，有加班' : ''}${hasNight ? '，有夜班' : ''}${hasNote ? '，有备注' : ''}',
      child: Opacity(
        opacity: inMonth ? 1 : .45,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: dateFill,
                  shape: BoxShape.circle,
                  border: today && !selected
                      ? Border.all(color: LedgerColors.infoBlue, width: 1.4)
                      : null,
                ),
                child: Text(
                  today ? '${day.day}今' : '${day.day}',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  textScaler: cappedTextScaler(context, maxScale: 1.18),
                  style: TextStyle(
                    color: today && !selected
                        ? LedgerColors.infoBlue
                        : dateTextColor,
                    fontWeight: selected || today || hasWork
                        ? FontWeight.w900
                        : FontWeight.w700,
                    fontSize: today ? 11 : 13,
                  ),
                ),
              ),
              SizedBox(
                height: 15,
                child: Center(
                  child: summary.totalHours > 0
                      ? Text(
                          hoursText(summary.totalHours),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textScaler: cappedTextScaler(context, maxScale: 1.12),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: LedgerColors.warningCopper,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              SizedBox(
                height: 6,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 3,
                  runSpacing: 2,
                  children: [
                    if (hasWork) const _Dot(color: LedgerColors.workAmber),
                    if (hasOvertime)
                      const _Dot(color: LedgerColors.overtimeMoss),
                    if (hasNight) const _Dot(color: LedgerColors.nightSlate),
                    if (hasNote) const _Dot(color: LedgerColors.warningCopper),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthSummaryGrid extends StatelessWidget {
  const _MonthSummaryGrid({required this.summary});
  final LedgerSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('总工时', hoursText(summary.totalHours), '出勤 ${summary.attendanceDays}天'),
      ('收入', moneyText(summary.income), '估算'),
      ('加班', hoursText(summary.overtimeHours), '${summary.overtimeDays}天'),
      ('夜班', '${summary.nightShiftCount}次', hoursText(summary.nightHours)),
      ('备注', '${summary.noteDays}天', '有备注日期'),
    ];
    return LedgerCard(
      key: const Key('calendar-month-summary-card'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final item in items)
            _MonthStat(label: item.$1, value: item.$2, subtext: item.$3),
        ],
      ),
    );
  }
}

class _MonthStat extends StatelessWidget {
  const _MonthStat({
    required this.label,
    required this.value,
    required this.subtext,
  });

  final String label;
  final String value;
  final String subtext;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: LedgerColors.surfaceRaised,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: LedgerColors.hairline),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: LedgerColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          subtext,
          style: const TextStyle(color: LedgerColors.muted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _LegendMark extends StatelessWidget {
  const _LegendMark({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _Dot(color: color),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(color: LedgerColors.muted, fontSize: 12),
      ),
    ],
  );
}

class _MonthList extends StatefulWidget {
  const _MonthList({
    required this.state,
    required this.range,
    required this.onSelect,
  });
  final LedgerState state;
  final DateRange range;
  final ValueChanged<DateTime> onSelect;

  @override
  State<_MonthList> createState() => _MonthListState();
}

class _MonthListState extends State<_MonthList> {
  int _visibleCount = 20;

  @override
  void didUpdateWidget(covariant _MonthList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range.start != widget.range.start) {
      _visibleCount = 20;
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = [
      for (
        var day = widget.range.start;
        day.isBefore(widget.range.endExclusive);
        day = day.add(const Duration(days: 1))
      )
        if (widget.state.entriesForDay(day).isNotEmpty) day,
    ];
    final visibleDays = days.take(_visibleCount).toList();
    if (days.isEmpty) {
      return LedgerCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('本月暂无记录'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => showEditWorkEntrySheet(
                context,
                widget.state,
                day: widget.range.start,
              ),
              child: const Text('新增第一段'),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final day in visibleDays)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => widget.onSelect(day),
              borderRadius: BorderRadius.circular(18),
              child: _MonthListRow(day: day, state: widget.state),
            ),
          ),
        if (_visibleCount < days.length)
          OutlinedButton(
            onPressed: () => setState(() => _visibleCount += 10),
            child: Text('继续加载 ${days.length - _visibleCount} 天记录'),
          ),
      ],
    );
  }
}

class _MonthListRow extends StatelessWidget {
  const _MonthListRow({required this.day, required this.state});
  final DateTime day;
  final LedgerState state;

  @override
  Widget build(BuildContext context) {
    final entries = state.entriesForDay(day);
    final summary = state.summaryFor(DateRange.custom(day, day));
    final meta = [
      if (summary.regularHours > 0) '普通 ${hoursText(summary.regularHours)}',
      if (summary.overtimeHours > 0) '加班 ${hoursText(summary.overtimeHours)}',
      if (summary.nightHours > 0) '夜班 ${hoursText(summary.nightHours)}',
      if (summary.allowance > 0) '补贴 ${moneyText(summary.allowance)}',
      if (summary.deduction > 0) '扣款 ${moneyText(summary.deduction)}',
      if (entries.any((entry) => entry.hasNote)) '有备注',
      if (summary.totalHours > 12) '时长偏长',
    ].join(' · ');
    return LedgerCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: LedgerColors.workAmberSoft.withValues(alpha: .46),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  day.day.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  _weekdayText(day.weekday),
                  style: const TextStyle(
                    color: LedgerColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${entries.length} 段',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    _SmallPill(hoursText(summary.totalHours)),
                    if (summary.income > 0)
                      _SmallPill(moneyText(summary.income)),
                  ],
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LedgerColors.muted,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: '编辑',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () => showEditWorkEntrySheet(context, state, day: day),
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
        ],
      ),
    );
  }

  String _weekdayText(int weekday) =>
      const ['一', '二', '三', '四', '五', '六', '日'][weekday - 1];
}

class _SmallPill extends StatelessWidget {
  const _SmallPill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: LedgerColors.surfaceSoft.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
    ),
  );
}

class _DayDetails extends StatelessWidget {
  const _DayDetails({required this.state, required this.day});
  final LedgerState state;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final entries = state.entriesForDay(day);
    final summary = state.summaryFor(DateRange.custom(day, day));
    if (entries.isEmpty) {
      return LedgerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('这一天还没有记录。'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => showEditWorkEntrySheet(context, state, day: day),
              child: const Text('新增分段'),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LedgerCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          color: LedgerColors.surfaceRaised,
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _SmallPill('合计 ${hoursText(summary.totalHours)}'),
              _SmallPill('普通 ${hoursText(summary.regularHours)}'),
              if (summary.overtimeHours > 0)
                _SmallPill('加班 ${hoursText(summary.overtimeHours)}'),
              if (summary.nightHours > 0)
                _SmallPill('夜班 ${hoursText(summary.nightHours)}'),
              if (summary.allowance > 0)
                _SmallPill('补贴 ${moneyText(summary.allowance)}'),
              if (summary.deduction > 0)
                _SmallPill('扣款 ${moneyText(summary.deduction)}'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final entry in entries) ...[
          WorkEntryTile(
            entry: entry,
            onEdit: () => showEditWorkEntrySheet(context, state, day: day),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton(
          onPressed: () => showEditWorkEntrySheet(context, state, day: day),
          child: const Text('管理当天分段'),
        ),
      ],
    );
  }
}
