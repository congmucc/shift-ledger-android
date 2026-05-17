import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/ledger_state.dart';
import '../../domain/models.dart';
import '../edit_entry_sheet.dart';
import '../record_ui_summary.dart';
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
    final monthEntries = widget.state.entries
        .where(
          (entry) => range.overlaps(entry.startDateTime, entry.endDateTime),
        )
        .toList();
    final recordSummary = summarizeRecordEntries(monthEntries);
    final selectedMatchesFilter =
        _filter.isAll || _matchesCurrentFilter(_selectedDay);
    final monthHasFilterMatch =
        _filter.isAll || _firstMatchingDayInMonth(_month) != null;
    final selectedEntries = widget.state.entriesForDay(_selectedDay);
    final filterCounts = {
      for (final filter in _CalendarFilter.values)
        filter: filter.isAll
            ? summary.attendanceDays
            : _countMatchingDays(range, filter),
    };
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
        _MonthSummaryGrid(summary: summary, recordSummary: recordSummary),
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
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final showSwipeHint =
                    _filter.isAll && constraints.maxWidth < 420;
                return Row(
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: LedgerColors.primaryBlue,
                    ),
                    const SizedBox(width: 6),
                    Text('筛选', style: Theme.of(context).textTheme.labelMedium),
                    const Spacer(),
                    if (showSwipeHint)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.swipe_left_alt_rounded,
                            size: 16,
                            color: LedgerColors.muted,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '左右滑动',
                            style: TextStyle(
                              color: LedgerColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    else if (!_filter.isAll)
                      TextButton(
                        onPressed: () => _changeFilter(_CalendarFilter.all),
                        child: const Text('清除'),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in _CalendarFilter.values) ...[
                    _CalendarFilterChip(
                      icon: filter.icon,
                      label: filter.label,
                      count: filterCounts[filter] ?? 0,
                      selected: _filter == filter,
                      onSelected: () => _changeFilter(filter),
                    ),
                    if (filter != _CalendarFilter.values.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
            filter: _filter,
          ),
        SectionHeader(
          title: !_filter.isAll && !monthHasFilterMatch
              ? '${_month.month} 月暂无${_filter.label}记录'
              : selectedEntries.isEmpty
              ? ymd(_selectedDay) == ymd(widget.state.now)
                    ? '今日 · 暂无记录'
                    : '${_selectedDay.month} 月 ${_selectedDay.day} 日 · 暂无记录'
              : '${ymd(_selectedDay) == ymd(widget.state.now) ? '今日 · ' : ''}${_selectedDay.month} 月 ${_selectedDay.day} 日详情${selectedMatchesFilter ? '' : '（未命中${_filter.label}）'}',
          actionLabel: '补一段',
          onAction: () =>
              showEditWorkEntrySheet(context, widget.state, day: _selectedDay),
        ),
        if (!_filter.isAll && !selectedMatchesFilter) ...[
          LedgerCard(
            padding: const EdgeInsets.all(12),
            color: LedgerColors.warningOrangeSoft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.filter_alt_outlined,
                    size: 18,
                    color: LedgerColors.warningOrange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    monthHasFilterMatch
                        ? '当前筛选为“${_filter.label}”，这一天不在筛选结果中；下面仍保留原始详情，方便继续查看或补录。'
                        : '当前月份暂无“${_filter.label}”记录；下面仍保留所选日期的原始详情，避免筛选上下文混淆。',
                    style: const TextStyle(
                      color: LedgerColors.ink,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
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
    final recordSummary = summarizeRecordEntries(entries);
    return switch (filter) {
      _CalendarFilter.all => entries.isNotEmpty,
      _CalendarFilter.overtime => recordSummary.manualOvertimeHours > 0,
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

  int _countMatchingDays(DateRange range, _CalendarFilter filter) {
    var count = 0;
    for (
      var day = range.start;
      day.isBefore(range.endExclusive);
      day = day.add(const Duration(days: 1))
    ) {
      if (_matchesFilter(day, filter: filter)) count++;
    }
    return count;
  }

  Future<void> _showMonthPicker() async {
    var pickerYear = _month.year;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LedgerColors.paper,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final mediaQuery = MediaQuery.of(context);
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final tileHeight = textScale >= 1.8
              ? 92.0
              : textScale >= 1.35
              ? 78.0
              : 60.0;
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: mediaQuery.size.height * 0.82,
              ),
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
                    Flexible(
                      child: SingleChildScrollView(
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                mainAxisExtent: tileHeight,
                              ),
                          itemCount: 12,
                          itemBuilder: (context, index) {
                            final month = index + 1;
                            return OutlinedButton(
                              onPressed: () {
                                setState(
                                  () =>
                                      _applyMonth(DateTime(pickerYear, month)),
                                );
                                Navigator.pop(context);
                              },
                              child: Text(
                                '$month月\n${hoursText(widget.state.summaryFor(DateRange.month(pickerYear, month)).totalHours)}',
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
    required this.filter,
  });
  final LedgerState state;
  final DateTime month;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onMonthChanged;
  final bool Function(DateTime day) matchesDay;
  final _CalendarFilter filter;

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
              _LegendMark(color: LedgerColors.successGreen, label: '加班段'),
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
    final recordSummary = summarizeRecordEntries(entries);
    final inMonth = day.month == month.month;
    final selected = ymd(day) == ymd(selectedDay);
    final today = ymd(day) == ymd(state.now);
    final hasNote = entries.any((entry) => entry.hasNote);
    final hasOvertime = recordSummary.manualOvertimeHours > 0;
    final hasNight = summary.nightHours > 0;
    final hasLongDuration = summary.totalHours > 12;
    final hasWork = entries.isNotEmpty;
    final visibleByFilter = filter.isAll ? true : matchesDay(day);
    final isQuietDay = !visibleByFilter && !selected;
    final dateFill = selected
        ? LedgerColors.primaryBlue
        : !visibleByFilter
        ? Colors.transparent
        : hasNight
        ? LedgerColors.nightIndigoSoft.withValues(alpha: .9)
        : hasOvertime
        ? LedgerColors.successGreenSoft.withValues(alpha: .9)
        : hasWork
        ? LedgerColors.primaryBlueSoft.withValues(alpha: .9)
        : LedgerColors.surfaceSoft.withValues(alpha: .92);
    final dateTextColor = selected
        ? Colors.white
        : isQuietDay
        ? (today ? LedgerColors.primaryBlue : LedgerColors.muted)
        : inMonth
        ? LedgerColors.ink
        : LedgerColors.stone;
    final showHours = visibleByFilter && summary.totalHours > 0;
    final showMarkers = visibleByFilter;
    final showEmptyMarker = filter.isAll && !hasWork;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${today ? '今日，' : ''}${day.month}月${day.day}日，${hoursText(summary.totalHours)}，${entries.length}段${hasOvertime ? '，有加班段' : ''}${hasNight ? '，有夜班' : ''}${hasLongDuration ? '，时长偏长' : ''}${hasNote ? '，有备注' : ''}${isQuietDay ? '，不在当前筛选范围内' : ''}',
      child: Opacity(
        opacity: inMonth ? (visibleByFilter ? 1 : .42) : .24,
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
                    fontWeight: selected || today
                        ? FontWeight.w900
                        : visibleByFilter && hasWork
                        ? FontWeight.w800
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
                    if (showEmptyMarker)
                      const _Dot(color: LedgerColors.hairlineStrong),
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
  const _MonthSummaryGrid({required this.summary, required this.recordSummary});
  final LedgerSummary summary;
  final RecordUiSummary recordSummary;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      key: const Key('calendar-month-summary-card'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
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
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: LedgerColors.primaryBlueSoft.withValues(alpha: .8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.summarize_outlined,
                      size: 16,
                      color: LedgerColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '本月一览',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium!.copyWith(fontSize: 15),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FittedValueText(
                      '月计 ${hoursText(summary.totalHours)} · 出勤 ${summary.attendanceDays}天 · ${recordSummary.segmentCount}段',
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
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 5,
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
                      label: '加班段',
                      value:
                          '${hoursText(recordSummary.manualOvertimeHours)}/${recordSummary.manualOvertimeDays}天',
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
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
  bool get isAll => this == _CalendarFilter.all;

  String get label => switch (this) {
    _CalendarFilter.all => '全部',
    _CalendarFilter.overtime => '加班段',
    _CalendarFilter.night => '夜班',
    _CalendarFilter.note => '有备注',
    _CalendarFilter.longDuration => '超时',
  };

  IconData get icon => switch (this) {
    _CalendarFilter.all => Icons.grid_view_rounded,
    _CalendarFilter.overtime => Icons.bolt_rounded,
    _CalendarFilter.night => Icons.nightlight_round,
    _CalendarFilter.note => Icons.sticky_note_2_outlined,
    _CalendarFilter.longDuration => Icons.schedule_outlined,
  };
}

class _CalendarFilterChip extends StatelessWidget {
  const _CalendarFilterChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onSelected,
    borderRadius: BorderRadius.circular(18),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? LedgerColors.primaryBlue : LedgerColors.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? LedgerColors.primaryBlue
              : LedgerColors.hairlineStrong,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: selected ? Colors.white : LedgerColors.primaryBlue,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : LedgerColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: .18)
                    : LedgerColors.surfaceSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected ? Colors.white : LedgerColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
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
    ]..sort((a, b) => a.compareTo(b));
    final visibleDays = days.take(_visibleCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LedgerCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.swap_vert_rounded,
                size: 18,
                color: LedgerColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Text(
                '1日 → 31日',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (days.isEmpty)
          LedgerCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: LedgerColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.filter == _CalendarFilter.all
                            ? Icons.event_busy_outlined
                            : widget.filter.icon,
                        color: LedgerColors.primaryBlue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.filter == _CalendarFilter.all
                            ? '这个月还没有记录'
                            : '这个月还没有${widget.filter.label}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.filter == _CalendarFilter.all
                      ? '列表只显示已记录日期。'
                      : '切回“全部”或直接补一段。',
                  style: const TextStyle(
                    color: LedgerColors.muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
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
          )
        else ...[
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
    final recordSummary = summarizeRecordEntries(entries);
    final hasNote = entries.any((entry) => entry.hasNote);
    final hasOvertime = recordSummary.manualOvertimeHours > 0;
    final hasNight = summary.nightHours > 0;
    final hasLongDuration = summary.totalHours > 12;
    final metaParts = [
      if (recordSummary.regularHours > 0)
        '普通 ${hoursText(recordSummary.regularHours)}',
      if (recordSummary.manualOvertimeHours > 0)
        '加班段 ${hoursText(recordSummary.manualOvertimeHours)}',
      if (summary.allowance > 0) '补贴 ${moneyText(summary.allowance)}',
      if (summary.deduction > 0) '扣款 ${moneyText(summary.deduction)}',
    ];
    final previewEntries = entries.take(2).toList();
    final hiddenCount = entries.length - previewEntries.length;

    return LedgerCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonthListDateBlock(
            day: day,
            hasWork: entries.isNotEmpty,
            hasOvertime: hasOvertime,
            hasNight: hasNight,
            hasLongDuration: hasLongDuration,
            hasNote: hasNote,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${entries.length} 段',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    _SmallPill('合计 ${hoursText(summary.totalHours)}'),
                    if (hasOvertime)
                      const _SmallPill(
                        '加班段',
                        backgroundColor: LedgerColors.successGreenSoft,
                        foregroundColor: LedgerColors.successGreen,
                      ),
                    if (hasNight)
                      const _SmallPill(
                        '夜班',
                        backgroundColor: LedgerColors.nightIndigoSoft,
                        foregroundColor: LedgerColors.nightIndigo,
                      ),
                    if (hasNote)
                      const _SmallPill(
                        '有备注',
                        backgroundColor: LedgerColors.warningOrangeSoft,
                        foregroundColor: LedgerColors.warningOrange,
                      ),
                    if (hasLongDuration)
                      const _SmallPill(
                        '超长',
                        backgroundColor: Color(0xFFFCE8E6),
                        foregroundColor: LedgerColors.errorRed,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in previewEntries)
                      _SmallPill(_entryPreviewLabel(entry), maxWidth: 138),
                    if (hiddenCount > 0)
                      _SmallPill(
                        '+$hiddenCount段',
                        backgroundColor: LedgerColors.primaryBlueSoft,
                        foregroundColor: LedgerColors.primaryBlue,
                      ),
                  ],
                ),
                if (metaParts.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    metaParts.join(' · '),
                    style: const TextStyle(
                      color: LedgerColors.muted,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (summary.income > 0)
                Text(
                  moneyText(summary.income),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: LedgerColors.successGreen,
                  ),
                ),
              if (summary.income > 0) const SizedBox(height: 2),
              Text(
                '编辑',
                style: const TextStyle(
                  color: LedgerColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                tooltip: '编辑',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () =>
                    showEditWorkEntrySheet(context, state, day: day),
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _entryPreviewLabel(WorkEntry entry) =>
      '${hm(entry.startDateTime)}—${hm(entry.endDateTime)}';
}

class _MonthListDateBlock extends StatelessWidget {
  const _MonthListDateBlock({
    required this.day,
    required this.hasWork,
    required this.hasOvertime,
    required this.hasNight,
    required this.hasLongDuration,
    required this.hasNote,
  });

  final DateTime day;
  final bool hasWork;
  final bool hasOvertime;
  final bool hasNight;
  final bool hasLongDuration;
  final bool hasNote;

  @override
  Widget build(BuildContext context) => Container(
    width: 60,
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
    decoration: BoxDecoration(
      color: LedgerColors.primaryBlueSoft.withValues(alpha: .8),
      borderRadius: BorderRadius.circular(18),
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
          style: const TextStyle(color: LedgerColors.muted, fontSize: 11),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 3,
          runSpacing: 2,
          children: [
            if (hasWork) const _Dot(color: LedgerColors.primaryBlue),
            if (hasOvertime) const _Dot(color: LedgerColors.successGreen),
            if (hasNight) const _Dot(color: LedgerColors.nightIndigo),
            if (hasLongDuration) const _Dot(color: LedgerColors.errorRed),
            if (hasNote) const _NoteMarker(color: LedgerColors.warningOrange),
          ],
        ),
      ],
    ),
  );

  String _weekdayText(int weekday) =>
      const ['一', '二', '三', '四', '五', '六', '日'][weekday - 1];
}

class _SmallPill extends StatelessWidget {
  const _SmallPill(
    this.text, {
    this.backgroundColor,
    this.foregroundColor,
    this.maxWidth = 118,
  });
  final String text;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(maxWidth: maxWidth),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: backgroundColor ?? LedgerColors.surfaceSoft.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(99),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: foregroundColor ?? LedgerColors.ink,
        ),
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
    final recordSummary = summarizeRecordEntries(entries);
    if (entries.isEmpty) {
      return LedgerCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: LedgerColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.coffee_outlined,
                    size: 18,
                    color: LedgerColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '这一天还没有记录',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '休息日可留空，需要时再补录。',
              style: TextStyle(
                color: LedgerColors.muted,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
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
              if (recordSummary.regularHours > 0)
                _SmallPill('普通 ${hoursText(recordSummary.regularHours)}'),
              if (recordSummary.manualOvertimeHours > 0)
                _SmallPill(
                  '加班段 ${hoursText(recordSummary.manualOvertimeHours)}',
                ),
              if (summary.nightHours > 0)
                _SmallPill('夜班 ${hoursText(summary.nightHours)}'),
              if (summary.allowance > 0)
                _SmallPill('补贴 ${moneyText(summary.allowance)}'),
              if (summary.deduction > 0)
                _SmallPill('扣款 ${moneyText(summary.deduction)}'),
            ],
          ),
        ),
        if (summary.overtimeHours > recordSummary.manualOvertimeHours) ...[
          const SizedBox(height: 8),
          Text(
            '这一天有 ${hoursText(summary.overtimeHours - recordSummary.manualOvertimeHours)} 会按“计薪加班”结算，但记录类型仍保持普通班次。',
            style: const TextStyle(
              color: LedgerColors.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
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
