import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/ledger_state.dart';
import '../../domain/models.dart';
import '../edit_entry_sheet.dart';
import '../record_ui_summary.dart';
import '../theme.dart';
import '../widgets.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.state,
    this.initialSelectedDay,
    this.onSelectedDayChanged,
  });
  final LedgerState state;
  final DateTime? initialSelectedDay;
  final ValueChanged<DateTime>? onSelectedDayChanged;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month;
  late DateTime _selectedDay;
  bool _listMode = false;
  final Set<_CalendarFilter> _selectedFilters = <_CalendarFilter>{};
  final _scrollController = ScrollController();
  final _detailKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final initialDay = dateOnly(widget.initialSelectedDay ?? widget.state.now);
    _month = DateTime(initialDay.year, initialDay.month);
    _selectedDay = initialDay;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    final hasActiveFilters = _selectedFilters.isNotEmpty;
    final activeFilterLabel = _calendarFilterSelectionLabel(_selectedFilters);
    final activeFilterIcon = _calendarFilterSelectionIcon(_selectedFilters);
    final selectedMatchesFilter =
        !hasActiveFilters || _matchesActiveFilters(_selectedDay);
    final monthHasFilterMatch =
        !hasActiveFilters || _firstMatchingDayInMonth(_month) != null;
    final selectedEntries = widget.state.entriesForDay(_selectedDay);
    final filterCounts = {
      for (final filter in _CalendarFilter.values)
        filter: filter.isAll
            ? summary.attendanceDays
            : _countMatchingDays(range, filter),
    };
    return PageFrame(
      controller: _scrollController,
      title: '日历',
      eyebrow: '${_month.year}年${_month.month}月',
      trailing: FilledButton.tonalIcon(
        key: const Key('calendar-add-entry-action'),
        onPressed: () =>
            showEditWorkEntrySheet(context, widget.state, day: _selectedDay),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('补一段'),
      ),
      children: [
        Row(
          children: [
            _ToolButton(
              tooltip: '上个月',
              onPressed: () =>
                  _selectMonth(DateTime(_month.year, _month.month - 1)),
              child: const Icon(Icons.chevron_left, size: 18),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: _ToolButton(
                onPressed: _showMonthPicker,
                child: Text(
                  '${_month.year}年${_month.month}月',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            _ToolButton(onPressed: _jumpToToday, child: const Text('今天')),
            const SizedBox(width: 5),
            _ToolButton(
              tooltip: '下个月',
              onPressed: () =>
                  _selectMonth(DateTime(_month.year, _month.month + 1)),
              child: const Icon(Icons.chevron_right, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 7),
        _MonthSummaryGrid(summary: summary, recordSummary: recordSummary),
        const SizedBox(height: 7),
        _ModeSwitch(
          listMode: _listMode,
          onChanged: (value) => setState(() => _listMode = value),
        ),
        const SizedBox(height: 7),
        LayoutBuilder(
          builder: (context, constraints) {
            final useCompactFilterLabels = constraints.maxWidth < 420;
            final chips = [
              for (final filter in _CalendarFilter.values)
                _CalendarFilterChip(
                  key: Key('calendar-filter-${filter.name}'),
                  icon: filter.icon,
                  label: useCompactFilterLabels
                      ? filter.compactLabel
                      : filter.label,
                  count: filterCounts[filter] ?? 0,
                  showCount: !useCompactFilterLabels,
                  selected: filter.isAll
                      ? !hasActiveFilters
                      : _selectedFilters.contains(filter),
                  onSelected: () => _changeFilter(filter),
                ),
            ];
            return LedgerInlineGroup(spacing: 5, children: chips);
          },
        ),
        const SizedBox(height: 7),
        if (_listMode)
          _MonthList(
            state: widget.state,
            range: range,
            selectedDay: _selectedDay,
            onSelect: _selectDay,
            filters: _selectedFilters,
            activeFilterLabel: activeFilterLabel,
            activeFilterIcon: activeFilterIcon,
            matchesDay: _matchesActiveFilters,
          )
        else
          _MonthGrid(
            state: widget.state,
            month: _month,
            selectedDay: _selectedDay,
            onSelect: _selectDay,
            onMonthChanged: _selectMonth,
            filters: _selectedFilters,
            matchesDay: _matchesActiveFilters,
          ),
        KeyedSubtree(
          key: _detailKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: hasActiveFilters && !monthHasFilterMatch
                    ? '${_month.month} 月暂无$activeFilterLabel记录'
                    : selectedEntries.isEmpty
                    ? ymd(_selectedDay) == ymd(widget.state.now)
                          ? '今日 · 暂无记录'
                          : '${_selectedDay.month} 月 ${_selectedDay.day} 日 · 暂无记录'
                    : '${ymd(_selectedDay) == ymd(widget.state.now) ? '今日 · ' : ''}${_selectedDay.month} 月 ${_selectedDay.day} 日详情${selectedMatchesFilter ? '' : '（未命中$activeFilterLabel）'}',
                actionLabel: '补一段',
                onAction: () => showEditWorkEntrySheet(
                  context,
                  widget.state,
                  day: _selectedDay,
                ),
              ),
              if (hasActiveFilters && !selectedMatchesFilter) ...[
                LedgerCard(
                  padding: const EdgeInsets.all(10),
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
                              ? '当前筛选为“$activeFilterLabel”，这一天不在筛选结果中；下面仍保留原始详情，方便继续查看或补录。'
                              : '当前月份暂无“$activeFilterLabel”记录；下面仍保留所选日期的原始详情，避免筛选上下文混淆。',
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
                const SizedBox(height: 6),
              ],
              _DayDetails(state: widget.state, day: _selectedDay),
            ],
          ),
        ),
      ],
    );
  }

  void _selectDay(DateTime day) {
    final shouldRevealDetails = _listMode;
    setState(() {
      _selectedDay = dateOnly(day);
      _month = DateTime(day.year, day.month);
      widget.onSelectedDayChanged?.call(_selectedDay);
    });
    if (shouldRevealDetails) _revealSelectedDayDetails();
  }

  void _revealSelectedDayDetails() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final detailContext = _detailKey.currentContext;
      if (detailContext == null) return;
      Scrollable.ensureVisible(
        detailContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  void _jumpToToday() => setState(() {
    _month = DateTime(widget.state.now.year, widget.state.now.month);
    _selectedDay = _resolvedSelectionForMonth(
      _month,
      preferredDay: widget.state.now,
    );
    widget.onSelectedDayChanged?.call(_selectedDay);
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
    widget.onSelectedDayChanged?.call(_selectedDay);
  }

  void _changeFilter(_CalendarFilter filter) => setState(() {
    if (filter.isAll) {
      _selectedFilters.clear();
    } else if (!_selectedFilters.remove(filter)) {
      _selectedFilters.add(filter);
    }
    if (_selectedFilters.isNotEmpty && !_matchesActiveFilters(_selectedDay)) {
      final firstMatch = _firstMatchingDayInMonth(_month);
      if (firstMatch != null) _selectedDay = firstMatch;
    }
  });

  bool _matchesActiveFilters(DateTime day) =>
      _selectedFilters.every((filter) => _matchesFilter(day, filter: filter));

  bool _matchesSelectionAnchor(DateTime day) {
    if (_selectedFilters.isEmpty) {
      return widget.state.entriesForDay(dateOnly(day)).isNotEmpty;
    }
    return _matchesActiveFilters(day);
  }

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
    if (_matchesSelectionAnchor(normalizedPreferred) &&
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
      if (_matchesSelectionAnchor(day)) return day;
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
                padding: const EdgeInsets.all(10),
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
                    const SizedBox(height: 6),
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
                    const SizedBox(height: 6),
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
    required this.filters,
  });
  final LedgerState state;
  final DateTime month;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onMonthChanged;
  final bool Function(DateTime day) matchesDay;
  final Set<_CalendarFilter> filters;

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
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerVisible: false,
            sixWeekMonthsEnforced: true,
            availableGestures: AvailableGestures.horizontalSwipe,
            rowHeight: MediaQuery.textScalerOf(
              context,
            ).scale(52).clamp(52.0, 64.0),
            daysOfWeekHeight: 20,
            selectedDayPredicate: (day) => ymd(day) == ymd(selectedDay),
            onDaySelected: (selected, focused) => onSelect(selected),
            onPageChanged: (focused) =>
                onMonthChanged(DateTime(focused.year, focused.month)),
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: true,
              cellMargin: EdgeInsets.zero,
              cellPadding: EdgeInsets.zero,
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              dowTextFormatter: (date, locale) =>
                  const ['一', '二', '三', '四', '五', '六', '日'][date.weekday - 1],
              weekdayStyle: const TextStyle(
                color: LedgerColors.muted,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              weekendStyle: const TextStyle(
                color: LedgerColors.muted,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: _buildCell,
              todayBuilder: _buildCell,
              selectedBuilder: _buildCell,
              outsideBuilder: _buildCell,
            ),
          ),
          const SizedBox(
            key: Key('calendar-legend-today-marker'),
            width: 0,
            height: 0,
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
    final visibleByFilter = filters.isEmpty ? true : matchesDay(day);
    final isQuietDay = !visibleByFilter && !selected;
    final dateFill = selected
        ? LedgerColors.surfaceRaised
        : hasWork && visibleByFilter
        ? LedgerColors.surfaceSoft.withValues(alpha: .76)
        : Colors.transparent;
    final dateTextColor = selected
        ? LedgerColors.primaryBlue
        : isQuietDay
        ? (today ? LedgerColors.primaryBlue : LedgerColors.muted)
        : inMonth
        ? LedgerColors.ink
        : LedgerColors.stone;
    final showHours = visibleByFilter && summary.totalHours > 0;
    final showMarkers = visibleByFilter;
    final showEmptyMarker = filters.isEmpty && !hasWork;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${today ? '今日，' : ''}${day.month}月${day.day}日，${hoursText(summary.totalHours)}，${entries.length}段${hasOvertime ? '，有加班段' : ''}${hasNight ? '，有夜班' : ''}${hasLongDuration ? '，时长偏长' : ''}${hasNote ? '，有备注' : ''}${isQuietDay ? '，不在当前筛选范围内' : ''}',
      child: Opacity(
        opacity: inMonth ? (visibleByFilter ? 1 : .42) : .24,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: dateFill,
                  borderRadius: BorderRadius.circular(12),
                  border: selected
                      ? Border.all(color: LedgerColors.primaryBlue, width: 1.5)
                      : today
                      ? Border.all(
                          color: LedgerColors.primaryBlue.withValues(
                            alpha: .58,
                          ),
                          width: 1.2,
                        )
                      : hasWork && visibleByFilter
                      ? Border.all(color: LedgerColors.hairline)
                      : null,
                ),
                child: Text(
                  '${day.day}',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  textScaler: cappedTextScaler(context, maxScale: 1.18),
                  style: TextStyle(
                    color: (today || selected)
                        ? LedgerColors.primaryBlue
                        : dateTextColor,
                    fontWeight: selected || today
                        ? FontWeight.w900
                        : visibleByFilter && hasWork
                        ? FontWeight.w800
                        : FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(
                height: 11,
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
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: LedgerColors.muted,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              SizedBox(
                height: 9,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 2.5,
                  runSpacing: 1,
                  children: [
                    if (showMarkers && hasWork)
                      const _CalendarStatusMark.dot(
                        color: LedgerColors.primaryBlue,
                      ),
                    if (showMarkers && hasOvertime)
                      const _CalendarStatusMark.plus(
                        color: LedgerColors.successGreen,
                      ),
                    if (showMarkers && hasNight)
                      const _CalendarStatusMark.text(
                        '夜',
                        color: LedgerColors.nightIndigo,
                      ),
                    if (showMarkers && hasLongDuration)
                      const _CalendarStatusMark.text(
                        '!',
                        color: LedgerColors.errorRed,
                      ),
                    if (showMarkers && hasNote)
                      const _CalendarStatusMark.note(
                        color: LedgerColors.warningOrange,
                      ),
                    if (showEmptyMarker)
                      const _CalendarStatusMark.dot(
                        color: LedgerColors.hairlineStrong,
                      ),
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

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.onPressed,
    required this.child,
    this.tooltip,
  });

  final VoidCallback onPressed;
  final Widget child;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: LedgerColors.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LedgerColors.hairline),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            color: LedgerColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          child: child,
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.listMode, required this.onChanged});
  final bool listMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: LedgerColors.surfaceSoft,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: LedgerColors.hairline),
    ),
    child: Row(
      children: [
        Expanded(
          child: _ModeChoice(
            label: '月历',
            selected: !listMode,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _ModeChoice(
            label: '列表',
            selected: listMode,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    ),
  );
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      height: 29,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? LedgerColors.surfaceRaised : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: selected ? Border.all(color: const Color(0xFFD6E9FF)) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? LedgerColors.primaryBlue : LedgerColors.muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

class _MonthSummaryGrid extends StatelessWidget {
  const _MonthSummaryGrid({required this.summary, required this.recordSummary});
  final LedgerSummary summary;
  final RecordUiSummary recordSummary;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      key: const Key('calendar-month-summary-card'),
      padding: EdgeInsets.zero,
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final statWidth = constraints.maxWidth >= 360
              ? (constraints.maxWidth - 18) / 4
              : (constraints.maxWidth - 8) / 2;
          final chips = [
            _MonthStatPill(
              label: '月计',
              value: hoursText(summary.totalHours),
              accent: LedgerColors.primaryBlue,
            ),
            _MonthStatPill(
              label: '出勤',
              value: '${summary.attendanceDays}天',
              accent: LedgerColors.hairlineStrong,
            ),
            _MonthStatPill(
              label: '加班',
              value: hoursText(recordSummary.manualOvertimeHours),
              accent: LedgerColors.successGreen,
            ),
            _MonthStatPill(
              label: '分段',
              value: '${recordSummary.segmentCount}段',
              accent: LedgerColors.hairlineStrong,
            ),
          ];
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final chip in chips) SizedBox(width: statWidth, child: chip),
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
    constraints: const BoxConstraints(minHeight: 44),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
    decoration: BoxDecoration(
      color: LedgerColors.surfaceSoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE7EBF0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Dot(color: accent),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: cappedTextScaler(context, maxScale: 1.08),
                style: const TextStyle(
                  color: LedgerColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            textScaler: cappedTextScaler(context, maxScale: 1.06),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              color: LedgerColors.ink,
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

enum _CalendarStatusMarkKind { dot, text, note }

class _CalendarStatusMark extends StatelessWidget {
  const _CalendarStatusMark.dot({required this.color})
    : text = '',
      kind = _CalendarStatusMarkKind.dot;

  const _CalendarStatusMark.text(this.text, {required this.color})
    : kind = _CalendarStatusMarkKind.text;

  const _CalendarStatusMark.plus({required Color color})
    : this.text('+', color: color);

  const _CalendarStatusMark.note({required this.color})
    : text = '',
      kind = _CalendarStatusMarkKind.note;

  final String text;
  final Color color;
  final _CalendarStatusMarkKind kind;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 8, height: 8, child: Center(child: _inner()));

  Widget _inner() => switch (kind) {
    _CalendarStatusMarkKind.dot => Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
    _CalendarStatusMarkKind.note => Container(
      width: 8,
      height: 3,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
    ),
    _CalendarStatusMarkKind.text => Container(
      width: 8,
      height: 8,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: .8),
      ),
      child: Text(
        text,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: color,
          fontSize: text == '夜' ? 5.4 : 6.2,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  };
}

enum _CalendarFilter { all, overtime, night, note, longDuration }

extension on _CalendarFilter {
  bool get isAll => this == _CalendarFilter.all;

  String get label => switch (this) {
    _CalendarFilter.all => '全部',
    _CalendarFilter.overtime => '加班',
    _CalendarFilter.night => '夜班',
    _CalendarFilter.note => '备注',
    _CalendarFilter.longDuration => '超时',
  };

  String get compactLabel => switch (this) {
    _CalendarFilter.all => '全部',
    _CalendarFilter.overtime => '加班',
    _CalendarFilter.night => '夜班',
    _CalendarFilter.note => '备注',
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

String _calendarFilterSelectionLabel(Set<_CalendarFilter> filters) {
  if (filters.isEmpty) return '全部';
  return filters.map((filter) => filter.label).join(' + ');
}

IconData _calendarFilterSelectionIcon(Set<_CalendarFilter> filters) {
  if (filters.isEmpty) return Icons.grid_view_rounded;
  if (filters.length == 1) return filters.first.icon;
  return Icons.filter_alt_rounded;
}

class _CalendarFilterChip extends StatelessWidget {
  const _CalendarFilterChip({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.showCount,
    required this.selected,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool showCount;
  final bool selected;
  final VoidCallback onSelected;

  Color get _filterColor => switch (icon) {
    Icons.bolt_rounded => LedgerColors.successGreen,
    Icons.nightlight_round => LedgerColors.nightIndigo,
    Icons.sticky_note_2_outlined => LedgerColors.warningOrange,
    Icons.schedule_outlined => LedgerColors.errorRed,
    _ => LedgerColors.primaryBlue,
  };

  @override
  Widget build(BuildContext context) {
    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: selected
            ? Color.alphaBlend(
                _filterColor.withValues(alpha: .11),
                Colors.white,
              )
            : LedgerColors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? _filterColor.withValues(alpha: .35)
              : LedgerColors.hairlineStrong,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: _filterColor.withValues(alpha: .08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x080F172A),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _filterColor),
          const SizedBox(width: 4),
          Text(
            label,
            textScaler: cappedTextScaler(context, maxScale: 1.06),
            style: TextStyle(
              color: selected ? _filterColor : LedgerColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
            ),
          ),
          if (showCount && count > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? _filterColor.withValues(alpha: .10)
                    : LedgerColors.surfaceSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected ? _filterColor : LedgerColors.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: showCount ? '$label，$count 天' : label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSelected,
          borderRadius: BorderRadius.circular(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Center(widthFactor: 1, heightFactor: 1, child: chip),
          ),
        ),
      ),
    );
  }
}

class _MonthList extends StatelessWidget {
  const _MonthList({
    required this.state,
    required this.range,
    required this.selectedDay,
    required this.onSelect,
    required this.filters,
    required this.activeFilterLabel,
    required this.activeFilterIcon,
    required this.matchesDay,
  });
  final LedgerState state;
  final DateRange range;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelect;
  final Set<_CalendarFilter> filters;
  final String activeFilterLabel;
  final IconData activeFilterIcon;
  final bool Function(DateTime day) matchesDay;

  @override
  Widget build(BuildContext context) {
    final days = [
      for (
        var day = range.start;
        day.isBefore(range.endExclusive);
        day = day.add(const Duration(days: 1))
      )
        if (filters.isEmpty
            ? state.entriesForDay(day).isNotEmpty
            : matchesDay(day))
          day,
    ]..sort((a, b) => a.compareTo(b));
    final lastDay = range.endExclusive.subtract(const Duration(days: 1)).day;
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
                '1日 → $lastDay日',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text(
                days.isEmpty ? '无记录' : '已记录 ${days.length} 天',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (days.isEmpty)
          _MonthListEmptyState(
            state: state,
            range: range,
            filters: filters,
            activeFilterLabel: activeFilterLabel,
            activeFilterIcon: activeFilterIcon,
          )
        else
          _MonthListBody(
            state: state,
            days: days,
            selectedDay: selectedDay,
            onSelect: onSelect,
          ),
      ],
    );
  }
}

class _MonthListEmptyState extends StatelessWidget {
  const _MonthListEmptyState({
    required this.state,
    required this.range,
    required this.filters,
    required this.activeFilterLabel,
    required this.activeFilterIcon,
  });

  final LedgerState state;
  final DateRange range;
  final Set<_CalendarFilter> filters;
  final String activeFilterLabel;
  final IconData activeFilterIcon;

  @override
  Widget build(BuildContext context) => LedgerCard(
    padding: const EdgeInsets.all(10),
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
                filters.isEmpty ? Icons.event_busy_outlined : activeFilterIcon,
                color: LedgerColors.primaryBlue,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                filters.isEmpty ? '这个月还没有记录' : '这个月还没有$activeFilterLabel',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          filters.isEmpty ? '列表只显示已记录日期。' : '切回“全部”或直接补一段。',
          style: const TextStyle(
            color: LedgerColors.muted,
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 6),
        FilledButton(
          onPressed: () =>
              showEditWorkEntrySheet(context, state, day: range.start),
          child: const Text('新增第一段'),
        ),
      ],
    ),
  );
}

class _MonthListBody extends StatelessWidget {
  const _MonthListBody({
    required this.state,
    required this.days,
    required this.selectedDay,
    required this.onSelect,
  });

  final LedgerState state;
  final List<DateTime> days;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final needsBoundedScroll = days.length > 3;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final maxListHeight = (viewportHeight * 0.40).clamp(318.0, 380.0);
    final rows = _buildRows(context);
    final body = Column(children: rows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 5),
          child: Row(
            children: [
              Text('按周排列', style: Theme.of(context).textTheme.labelMedium),
              const Spacer(),
              Text('点日期看详情', style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
        LedgerCard(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          child: needsBoundedScroll
              ? SizedBox(
                  height: maxListHeight,
                  child: SingleChildScrollView(
                    primary: false,
                    physics: const ClampingScrollPhysics(),
                    child: body,
                  ),
                )
              : body,
        ),
      ],
    );
  }

  List<Widget> _buildRows(BuildContext context) {
    final widgets = <Widget>[];
    for (var index = 0; index < days.length; index++) {
      final day = days[index];
      final previousDay = index == 0 ? null : days[index - 1];
      final showWeekHeader = index == 0 || !_isSameWeek(previousDay!, day);
      if (showWeekHeader) {
        if (widgets.isNotEmpty) {
          widgets.add(const Divider(height: 8, color: LedgerColors.hairline));
        }
        widgets.add(_MonthListWeekHeader(day: day));
      } else {
        widgets.add(const Divider(height: 1, color: LedgerColors.hairline));
      }
      final selected = ymd(day) == ymd(selectedDay);
      widgets.add(
        InkWell(
          key: Key('calendar-list-day-${ymd(day)}'),
          onTap: () => onSelect(day),
          borderRadius: BorderRadius.circular(13),
          child: _MonthListRow(day: day, state: state, selected: selected),
        ),
      );
    }
    return widgets;
  }

  bool _isSameWeek(DateTime a, DateTime b) {
    final startA = dateOnly(a).subtract(Duration(days: a.weekday - 1));
    final startB = dateOnly(b).subtract(Duration(days: b.weekday - 1));
    return ymd(startA) == ymd(startB);
  }
}

class _MonthListWeekHeader extends StatelessWidget {
  const _MonthListWeekHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final weekStart = dateOnly(day).subtract(Duration(days: day.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 3, 4, 2),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: LedgerColors.hairlineStrong,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${weekStart.month}.${weekStart.day} - ${weekEnd.month}.${weekEnd.day}',
            style: const TextStyle(
              color: LedgerColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthListRow extends StatelessWidget {
  const _MonthListRow({
    required this.day,
    required this.state,
    required this.selected,
  });
  final DateTime day;
  final LedgerState state;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final entries = state.entriesForDay(day);
    final summary = state.summaryFor(DateRange.custom(day, day));
    final recordSummary = summarizeRecordEntries(entries);
    final hasNote = entries.any((entry) => entry.hasNote);
    final hasOvertime = recordSummary.manualOvertimeHours > 0;
    final hasNight = summary.nightHours > 0;
    final hasLongDuration = summary.totalHours > 12;
    final previewEntries = entries.take(1).toList();
    final hiddenCount = entries.length - previewEntries.length;
    final previewText = previewEntries.map(_entryPreviewLabel).join(' · ');
    final metaParts = [
      if (previewText.isNotEmpty) previewText,
      if (hiddenCount > 0) '+$hiddenCount段',
      if (recordSummary.regularHours > 0)
        '普通 ${hoursText(recordSummary.regularHours)}',
      if (recordSummary.manualOvertimeHours > 0)
        '加班 ${hoursText(recordSummary.manualOvertimeHours)}',
      if (hasNight) '夜班',
      if (hasNote) '备注',
      if (summary.allowance > 0) '补贴 ${moneyText(summary.allowance)}',
      if (summary.deduction > 0) '扣款 ${moneyText(summary.deduction)}',
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      constraints: const BoxConstraints(minHeight: 54),
      decoration: BoxDecoration(
        color: selected ? LedgerColors.primaryBlueSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        border: selected
            ? Border.all(color: LedgerColors.primaryBlue.withValues(alpha: .32))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _MonthListDateBlock(
            day: day,
            hasWork: entries.isNotEmpty,
            hasOvertime: hasOvertime,
            hasNight: hasNight,
            hasLongDuration: hasLongDuration,
            hasNote: hasNote,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entries.length}段 · 合计 ${hoursText(summary.totalHours)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 12.5),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 4,
                  runSpacing: 0,
                  children: [
                    for (final part in metaParts)
                      Text(
                        part,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: LedgerColors.muted,
                          fontSize: 11,
                          height: 1.18,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (selected)
                const Text(
                  '已选',
                  style: TextStyle(
                    color: LedgerColors.primaryBlue,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                )
              else if (summary.income > 0)
                Text(
                  moneyText(summary.income),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: LedgerColors.successGreen,
                  ),
                ),
              Icon(
                selected
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.chevron_right_rounded,
                size: 17,
                color: selected ? LedgerColors.primaryBlue : LedgerColors.stone,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _entryPreviewLabel(WorkEntry entry) => entry.isCrossDay
      ? '${hm(entry.startDateTime)}—次日${hm(entry.endDateTime)}'
      : '${hm(entry.startDateTime)}—${hm(entry.endDateTime)}';
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
  Widget build(BuildContext context) => SizedBox(
    width: 42,
    child: Column(
      children: [
        Text(
          day.day.toString().padLeft(2, '0'),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        Text(
          _weekdayText(day.weekday),
          style: const TextStyle(
            color: LedgerColors.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 3,
          runSpacing: 2,
          children: [
            if (hasWork)
              const _CalendarStatusMark.dot(color: LedgerColors.primaryBlue),
            if (hasOvertime)
              const _CalendarStatusMark.plus(color: LedgerColors.successGreen),
            if (hasNight)
              const _CalendarStatusMark.text(
                '夜',
                color: LedgerColors.nightIndigo,
              ),
            if (hasLongDuration)
              const _CalendarStatusMark.text('!', color: LedgerColors.errorRed),
            if (hasNote)
              const _CalendarStatusMark.note(color: LedgerColors.warningOrange),
          ],
        ),
      ],
    ),
  );

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
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: LedgerColors.ink,
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
        padding: const EdgeInsets.all(10),
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
            const SizedBox(height: 6),
            const Text(
              '休息日可留空，需要时再补录。',
              style: TextStyle(
                color: LedgerColors.muted,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
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
          child: LedgerInlineGroup(
            spacing: 8,
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
          const SizedBox(height: 6),
          Text(
            '这一天有 ${hoursText(summary.overtimeHours - recordSummary.manualOvertimeHours)} 会按“计薪加班”结算，但记录类型仍保持普通班次。',
            style: const TextStyle(
              color: LedgerColors.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 6),
        for (final entry in entries) ...[
          WorkEntryTile(
            entry: entry,
            onEdit: () => showEditWorkEntrySheet(context, state, day: day),
          ),
          const SizedBox(height: 6),
        ],
        OutlinedButton(
          onPressed: () => showEditWorkEntrySheet(context, state, day: day),
          child: const Text('管理当天分段'),
        ),
      ],
    );
  }
}
