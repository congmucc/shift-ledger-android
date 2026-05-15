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
  _CalendarFilter _filter = _CalendarFilter.all;

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
        _MonthSummaryGrid(summary: summary),
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
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in _CalendarFilter.values)
              _CalendarFilterChip(
                label: filter.label,
                selected: _filter == filter,
                onSelected: () => _changeFilter(filter),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_listMode)
          _MonthList(
            state: widget.state,
            range: range,
            onSelect: _selectDay,
            filter: _filter,
            matchesDay: _matchesCurrentFilter,
          )
        else
          _MonthGrid(
            state: widget.state,
            month: _month,
            selectedDay: _selectedDay,
            onSelect: _selectDay,
            onMonthChanged: _selectMonth,
            matchesDay: _matchesCurrentFilter,
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
    _month = DateTime(widget.state.now.year, widget.state.now.month);
    _selectedDay = _resolvedSelectionForMonth(
      _month,
      preferredDay: widget.state.now,
    );
  });

  void _selectMonth(DateTime month) => setState(() => _applyMonth(month));

  void _applyMonth(DateTime month) {
    final targetMonth = DateTime(month.year, month.month);
    _month = targetMonth;
    final today = dateOnly(widget.state.now);
    final defaultSelection =
        targetMonth.year == today.year && targetMonth.month == today.month
        ? today
        : targetMonth;
    _selectedDay = _resolvedSelectionForMonth(
      targetMonth,
      preferredDay: defaultSelection,
    );
  }

  void _changeFilter(_CalendarFilter filter) => setState(() {
    _filter = filter;
    if (!_matchesCurrentFilter(_selectedDay)) {
      final firstMatch = _firstMatchingDayInMonth(_month);
      if (firstMatch != null) _selectedDay = firstMatch;
    }
  });

  bool _matchesCurrentFilter(DateTime day) =>
      _matchesFilter(day, filter: _filter);

  bool _matchesFilter(DateTime day, {required _CalendarFilter filter}) {
    final date = dateOnly(day);
    final entries = widget.state.entriesForDay(date);
    final summary = widget.state.summaryFor(DateRange.custom(date, date));
    return switch (filter) {
      _CalendarFilter.all => entries.isNotEmpty,
      _CalendarFilter.overtime => summary.overtimeHours > 0,
      _CalendarFilter.night => summary.nightHours > 0,
      _CalendarFilter.note => entries.any((entry) => entry.hasNote),
      _CalendarFilter.longDuration => summary.totalHours > 12,
    };
  }

  DateTime _resolvedSelectionForMonth(
    DateTime month, {
    required DateTime preferredDay,
  }) {
    final normalizedPreferred = dateOnly(preferredDay);
    if (_matchesCurrentFilter(normalizedPreferred) &&
        normalizedPreferred.year == month.year &&
        normalizedPreferred.month == month.month) {
      return normalizedPreferred;
    }
    return _firstMatchingDayInMonth(month) ?? normalizedPreferred;
  }

  DateTime? _firstMatchingDayInMonth(DateTime month) {
    final range = DateRange.month(month.year, month.month);
    for (
      var day = range.start;
      day.isBefore(range.endExclusive);
      day = day.add(const Duration(days: 1))
    ) {
      if (_matchesCurrentFilter(day)) return day;
    }
    return null;
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
    required this.onMonthChanged,
    required this.matchesDay,
  });
  final LedgerState state;
  final DateTime month;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onMonthChanged;
  final bool Function(DateTime day) matchesDay;

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
            onPageChanged: (focused) =>
                onMonthChanged(DateTime(focused.year, focused.month)),
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
              _LegendMark(color: LedgerColors.primaryBlue, label: '有工时'),
              _LegendMark(color: LedgerColors.successGreen, label: '加班'),
              _LegendMark(color: LedgerColors.nightIndigo, label: '夜班'),
              _LegendMark(color: LedgerColors.errorRed, label: '超长'),
              _LegendMark(
                color: LedgerColors.warningOrange,
                label: '备注',
                markerText: '备',
              ),
              _LegendMark(
                color: LedgerColors.primaryBlue,
                label: '今日',
                marker: _TodayLegendMarker(),
              ),
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
    final hasLongDuration = summary.totalHours > 12;
    final hasWork = entries.isNotEmpty;
    final visibleByFilter = matchesDay(day);
    final dateFill = selected
        ? LedgerColors.primaryBlue
        : hasNight
        ? LedgerColors.nightIndigoSoft.withValues(alpha: .9)
        : hasOvertime
        ? LedgerColors.successGreenSoft.withValues(alpha: .9)
        : hasWork
        ? LedgerColors.primaryBlueSoft.withValues(alpha: .9)
        : Colors.transparent;
    final dateTextColor = selected
        ? Colors.white
        : inMonth
        ? LedgerColors.ink
        : LedgerColors.stone;
    final showHours = visibleByFilter && summary.totalHours > 0;
    final showMarkers = visibleByFilter;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${today ? '今日，' : ''}${day.month}月${day.day}日，${hoursText(summary.totalHours)}，${entries.length}段${hasOvertime ? '，有加班' : ''}${hasNight ? '，有夜班' : ''}${hasLongDuration ? '，时长偏长' : ''}${hasNote ? '，有备注' : ''}',
      child: Opacity(
        opacity: inMonth ? (visibleByFilter ? 1 : .58) : .34,
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
                      ? Border.all(color: LedgerColors.primaryBlue, width: 1.4)
                      : null,
                ),
                child: Text(
                  today ? '${day.day}今' : '${day.day}',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  textScaler: cappedTextScaler(context, maxScale: 1.18),
                  style: TextStyle(
                    color: today && !selected
                        ? LedgerColors.primaryBlue
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
                  child: showHours
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            hoursText(summary.totalHours),
                            maxLines: 1,
                            textScaler: cappedTextScaler(
                              context,
                              maxScale: 1.12,
                            ),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: LedgerColors.primaryBlue,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              SizedBox(
                height: 8,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 3,
                  runSpacing: 2,
                  children: [
                    if (showMarkers && hasWork)
                      const _Dot(color: LedgerColors.primaryBlue),
                    if (showMarkers && hasOvertime)
                      const _Dot(color: LedgerColors.successGreen),
                    if (showMarkers && hasNight)
                      const _Dot(color: LedgerColors.nightIndigo),
                    if (showMarkers && hasLongDuration)
                      const _Dot(color: LedgerColors.errorRed),
                    if (showMarkers && hasNote)
                      const _NoteMarker(color: LedgerColors.warningOrange),
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
    return LedgerCard(
      key: const Key('calendar-month-summary-card'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final statWidth = constraints.maxWidth >= 360
              ? (constraints.maxWidth - 16) / 3
              : (constraints.maxWidth - 8) / 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: LedgerColors.primaryBlueSoft.withValues(alpha: .8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.summarize_outlined,
                      size: 17,
                      color: LedgerColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '本月一览',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium!.copyWith(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedValueText(
                      '月计 ${hoursText(summary.totalHours)} · 出勤 ${summary.attendanceDays}天 · 加班 ${hoursText(summary.overtimeHours)}',
                      key: const Key('calendar-month-compact-summary'),
                      textAlign: TextAlign.end,
                      alignment: Alignment.centerRight,
                      maxScale: 1.08,
                      style: const TextStyle(
                        color: LedgerColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  SizedBox(
                    width: statWidth,
                    child: _MonthStatPill(
                      label: '总工时',
                      value: hoursText(summary.totalHours),
                      accent: LedgerColors.primaryBlue,
                    ),
                  ),
                  SizedBox(
                    width: statWidth,
                    child: _MonthStatPill(
                      label: '出勤',
                      value: '${summary.attendanceDays}天',
                      accent: LedgerColors.primaryBlue,
                    ),
                  ),
                  SizedBox(
                    width: statWidth,
                    child: _MonthStatPill(
                      label: '收入',
                      value: moneyText(summary.income),
                      accent: LedgerColors.successGreen,
                    ),
                  ),
                  SizedBox(
                    width: statWidth,
                    child: _MonthStatPill(
                      label: '加班',
                      value:
                          '${hoursText(summary.overtimeHours)}/${summary.overtimeDays}天',
                      accent: LedgerColors.successGreen,
                    ),
                  ),
                  SizedBox(
                    width: statWidth,
                    child: _MonthStatPill(
                      label: '夜班',
                      value:
                          '${summary.nightShiftCount}次/${hoursText(summary.nightHours)}',
                      accent: LedgerColors.nightIndigo,
                    ),
                  ),
                  SizedBox(
                    width: statWidth,
                    child: _MonthStatPill(
                      label: '备注',
                      value: '${summary.noteDays}天',
                      accent: LedgerColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthStatPill extends StatelessWidget {
  const _MonthStatPill({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: .24)),
    ),
    child: Row(
      children: [
        _Dot(color: accent),
        const SizedBox(width: 5),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          textScaler: cappedTextScaler(context, maxScale: 1.08),
          style: const TextStyle(
            color: LedgerColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                maxLines: 1,
                textScaler: cappedTextScaler(context, maxScale: 1.06),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  color: LedgerColors.ink,
                ),
              ),
            ),
          ),
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
  const _LegendMark({
    required this.color,
    required this.label,
    this.markerText,
    this.marker,
  });
  final Color color;
  final String label;
  final String? markerText;
  final Widget? marker;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      marker ??
          (markerText == null
              ? _Dot(color: color)
              : _NoteMarker(color: color, text: markerText!)),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(color: LedgerColors.muted, fontSize: 12),
      ),
    ],
  );
}

class _NoteMarker extends StatelessWidget {
  const _NoteMarker({required this.color, this.text = '备'});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: 11,
    height: 8,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: color.withValues(alpha: .55), width: .8),
    ),
    child: Text(
      text,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        color: color,
        fontSize: 6,
        height: 1,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _TodayLegendMarker extends StatelessWidget {
  const _TodayLegendMarker();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('calendar-legend-today-marker'),
    width: 12,
    height: 12,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: LedgerColors.primaryBlue, width: 1.1),
    ),
    child: const Text(
      '今',
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        color: LedgerColors.primaryBlue,
        fontSize: 6,
        height: 1,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

enum _CalendarFilter { all, overtime, night, note, longDuration }

extension on _CalendarFilter {
  String get label => switch (this) {
    _CalendarFilter.all => '全部',
    _CalendarFilter.overtime => '加班',
    _CalendarFilter.night => '夜班',
    _CalendarFilter.note => '有备注',
    _CalendarFilter.longDuration => '超长',
  };
}

class _CalendarFilterChip extends StatelessWidget {
  const _CalendarFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
    labelStyle: TextStyle(
      color: selected ? Colors.white : LedgerColors.ink,
      fontWeight: FontWeight.w700,
    ),
    side: BorderSide(
      color: selected ? LedgerColors.primaryBlue : LedgerColors.hairlineStrong,
    ),
    backgroundColor: LedgerColors.surfaceRaised,
    selectedColor: LedgerColors.primaryBlue,
    visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

class _MonthList extends StatefulWidget {
  const _MonthList({
    required this.state,
    required this.range,
    required this.onSelect,
    required this.filter,
    required this.matchesDay,
  });
  final LedgerState state;
  final DateRange range;
  final ValueChanged<DateTime> onSelect;
  final _CalendarFilter filter;
  final bool Function(DateTime day) matchesDay;

  @override
  State<_MonthList> createState() => _MonthListState();
}

class _MonthListState extends State<_MonthList> {
  int _visibleCount = 20;

  @override
  void didUpdateWidget(covariant _MonthList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range.start != widget.range.start ||
        oldWidget.filter != widget.filter) {
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
        if (widget.matchesDay(day)) day,
    ];
    final visibleDays = days.take(_visibleCount).toList();
    if (days.isEmpty) {
      return LedgerCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.filter == _CalendarFilter.all
                  ? '本月暂无记录'
                  : '本月暂无${widget.filter.label}记录',
            ),
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
              color: LedgerColors.primaryBlueSoft.withValues(alpha: .8),
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
    constraints: const BoxConstraints(maxWidth: 118),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: LedgerColors.surfaceSoft.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(99),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
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
