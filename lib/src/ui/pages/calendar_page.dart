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
              onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1),
              ),
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
              onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: '总工时',
                value: hoursText(summary.totalHours),
                compact: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricCard(
                label: '出勤',
                value: '${summary.attendanceDays}天',
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: '加班',
                value: hoursText(summary.overtimeHours),
                subtext: '${summary.overtimeDays}天',
                compact: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricCard(
                label: '夜班',
                value: '${summary.nightShiftCount}次',
                subtext: hoursText(summary.nightHours),
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
                              () => _month = DateTime(pickerYear, month),
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
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          TableCalendar<void>(
            firstDay: DateTime(2000),
            lastDay: DateTime(2100, 12, 31),
            focusedDay: month,
            currentDay: state.now,
            headerVisible: false,
            sixWeekMonthsEnforced: true,
            availableGestures: AvailableGestures.horizontalSwipe,
            rowHeight: 64,
            daysOfWeekHeight: 26,
            selectedDayPredicate: (day) => ymd(day) == ymd(selectedDay),
            onDaySelected: (selected, focused) => onSelect(selected),
            onPageChanged: (focused) => onSelect(focused),
            calendarStyle: const CalendarStyle(outsideDaysVisible: true),
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
          const SizedBox(height: 8),
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
    final fill = !inMonth
        ? LedgerColors.surface
        : hasWork
        ? LedgerColors.workAmberSoft.withValues(alpha: .55)
        : LedgerColors.surfaceRaised;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${today ? '今日，' : ''}${day.month}月${day.day}日，${hoursText(summary.totalHours)}，${entries.length}段${hasOvertime ? '，有加班' : ''}${hasNight ? '，有夜班' : ''}${hasNote ? '，有备注' : ''}',
      child: Container(
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: BoxDecoration(
          color: fill.withValues(alpha: inMonth ? 1 : .42),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            width: selected || today ? 1.8 : 1,
            color: selected
                ? LedgerColors.warningCopper
                : today
                ? LedgerColors.infoBlue
                : LedgerColors.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${day.day}',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    textScaler: cappedTextScaler(context, maxScale: 1.25),
                    style: TextStyle(
                      color: inMonth ? LedgerColors.ink : LedgerColors.stone,
                      fontWeight: today ? FontWeight.w900 : FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (today)
                  Text(
                    '今',
                    textScaler: cappedTextScaler(context, maxScale: 1.25),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: LedgerColors.infoBlue,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            if (summary.totalHours > 0)
              Text(
                hoursText(summary.totalHours),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: cappedTextScaler(context, maxScale: 1.25),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            Wrap(
              spacing: 3,
              runSpacing: 2,
              children: [
                if (hasWork) const _Dot(color: LedgerColors.workAmber),
                if (hasOvertime) const _Dot(color: LedgerColors.overtimeMoss),
                if (hasNight) const _Dot(color: LedgerColors.nightSlate),
                if (hasNote) const _Dot(color: LedgerColors.warningCopper),
              ],
            ),
          ],
        ),
      ),
    );
  }
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

class _MonthList extends StatelessWidget {
  const _MonthList({
    required this.state,
    required this.range,
    required this.onSelect,
  });
  final LedgerState state;
  final DateRange range;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (
          var day = range.start;
          day.isBefore(range.endExclusive);
          day = day.add(const Duration(days: 1))
        )
          if (state.entriesForDay(day).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => onSelect(day),
                borderRadius: BorderRadius.circular(18),
                child: _MonthListRow(day: day, state: state),
              ),
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
      '普通 ${hoursText(summary.regularHours)}',
      if (summary.overtimeHours > 0) '加班 ${hoursText(summary.overtimeHours)}',
      if (summary.nightHours > 0) '夜班 ${hoursText(summary.nightHours)}',
      if (entries.any((entry) => entry.hasNote)) '有备注',
      if (summary.totalHours > 12) '时长偏长',
    ].join(' · ');
    return LedgerCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${day.month.toString().padLeft(2, '0')}/${day.day.toString().padLeft(2, '0')} · ${entries.length} 段',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(meta, style: const TextStyle(color: LedgerColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hoursText(summary.totalHours),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton(
                onPressed: () =>
                    showEditWorkEntrySheet(context, state, day: day),
                child: const Text('编辑'),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
        Text(
          '当天合计 ${hoursText(summary.totalHours)} · 普通 ${hoursText(summary.regularHours)} · 加班 ${hoursText(summary.overtimeHours)}',
          style: const TextStyle(color: LedgerColors.muted),
        ),
        const SizedBox(height: 10),
        for (final entry in entries) ...[
          WorkEntryTile(
            entry: entry,
            onEdit: () => showEditWorkEntrySheet(context, state, day: day),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton(
          onPressed: () => showEditWorkEntrySheet(context, state, day: day),
          child: const Text('删除当天记录 / 编辑'),
        ),
      ],
    );
  }
}
