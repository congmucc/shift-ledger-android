import 'package:flutter/material.dart';

import '../../app/ledger_state.dart';
import '../../domain/models.dart';
import '../../services/csv_exporter.dart';
import '../../services/local_ledger_repository.dart';
import '../edit_entry_sheet.dart';
import '../pickers.dart';
import '../theme.dart';
import '../widgets.dart';

class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key, required this.state, this.repository});
  final LedgerState state;
  final LocalLedgerRepository? repository;

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  String _mode = '本月';
  bool _exporting = false;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  Widget build(BuildContext context) {
    final range = _range();
    final summary = widget.state.summaryFor(range);
    final dayRows = _groupSummaryByDay(summary);
    return PageFrame(
      title: '工时汇总',
      trailing: FilledButton.tonal(
        onPressed: _exporting ? null : () => _exportCsv(range),
        child: Text(_exporting ? '导出中' : 'CSV'),
      ),
      children: [
        _RangeSelector(
          mode: _mode,
          range: range,
          onModeChanged: (value) => setState(() {
            _mode = value;
            if (value == '自定义') _ensureCustomRange();
          }),
          onPickStart: _mode == '自定义' ? _pickCustomStart : null,
          onPickEnd: _mode == '自定义' ? _pickCustomEnd : null,
        ),
        const SizedBox(height: 12),
        _SummaryOverview(
          summary: summary,
          onHoursTap: () => _showDayRows('出勤明细', dayRows),
          onIncomeTap: () => _showIncomeBreakdown(summary),
        ),
        SectionHeader(
          title: '按天查看',
          actionLabel: '查看明细',
          onAction: () => _showDayRows('全部明细', dayRows),
        ),
        LedgerCard(
          padding: const EdgeInsets.all(12),
          child: _InsightGrid(
            items: [
              _InsightItem(
                title: '全部日期',
                value: '${summary.attendanceDays}天',
                subtitle: '按日期汇总每一天',
                onTap: () => _showDayRows('全部明细', dayRows),
              ),
              _InsightItem(
                title: '时长偏长',
                value: '${summary.longDurationDays}天',
                subtitle: '单日超过 12h',
                onTap: () => _showDayRows(
                  '时长偏长',
                  dayRows.where((row) => row.totalHours > 12).toList(),
                ),
              ),
              _InsightItem(
                title: '备注',
                value: '${summary.noteDays}天',
                subtitle: '只看有备注的日期',
                onTap: () => _showDayRows(
                  '含备注日期',
                  dayRows.where((row) => row.hasNote).toList(),
                ),
              ),
              _InsightItem(
                title: '补贴',
                value: moneyText(summary.allowance),
                subtitle: '有金额的日期',
                onTap: () => _showDayRows(
                  '补贴日期',
                  dayRows.where((row) => row.allowance > 0).toList(),
                ),
              ),
              _InsightItem(
                title: '扣款',
                value: moneyText(summary.deduction),
                subtitle: '有金额的日期',
                onTap: () => _showDayRows(
                  '扣款日期',
                  dayRows.where((row) => row.deduction > 0).toList(),
                ),
              ),
              _InsightItem(
                title: '加班',
                value: '${summary.overtimeDays}天',
                subtitle: hoursText(summary.overtimeHours),
                onTap: () => _showDayRows(
                  '加班日期',
                  dayRows.where((row) => row.overtimeHours > 0).toList(),
                ),
              ),
            ],
          ),
        ),
        const SectionHeader(title: '工时与收入拆分'),
        LedgerCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _BreakdownRow(
                label: '普通',
                value: hoursText(summary.regularHours),
                color: LedgerColors.primaryBlue,
                fraction: summary.totalHours == 0
                    ? 0
                    : summary.regularHours / summary.totalHours,
              ),
              _BreakdownRow(
                label: '加班',
                value:
                    '${hoursText(summary.overtimeHours)} · ${summary.overtimeDays}天',
                color: LedgerColors.successGreen,
                fraction: summary.totalHours == 0
                    ? 0
                    : summary.overtimeHours / summary.totalHours,
              ),
              _BreakdownRow(
                label: '夜班',
                value:
                    '${summary.nightShiftCount}次 · ${hoursText(summary.nightHours)}',
                color: LedgerColors.nightIndigo,
                fraction: summary.totalHours == 0
                    ? 0
                    : summary.nightHours / summary.totalHours,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        LedgerCard(
          padding: const EdgeInsets.all(12),
          child: SettingTile(
            title: '导出 CSV',
            subtitle: '含计薪规则、收入拆分、跨天标记',
            trailing: _exporting ? '导出中' : '导出',
            onTap: _exporting ? null : () => _exportCsv(range),
          ),
        ),
      ],
    );
  }

  DateRange _range() {
    return switch (_mode) {
      '本周' => DateRange.week(widget.state.now),
      '年度' => DateRange.year(widget.state.now.year),
      '发薪周期' => widget.state.currentPayPeriod,
      '自定义' => _customRange(),
      _ => widget.state.currentMonth,
    };
  }

  DateRange _customRange() {
    _ensureCustomRange();
    final start = _customStart!;
    final end = _customEnd!;
    return start.isAfter(end)
        ? DateRange.custom(end, start)
        : DateRange.custom(start, end);
  }

  void _ensureCustomRange() {
    _customEnd ??= widget.state.now;
    _customStart ??= widget.state.now.subtract(const Duration(days: 30));
  }

  Future<void> _pickCustomStart() async {
    _ensureCustomRange();
    final picked = await showLedgerDatePicker(
      context,
      initialDate: _customStart!,
      maximumDate: _customEnd,
    );
    if (picked == null || !mounted) return;
    setState(() => _customStart = picked);
  }

  Future<void> _pickCustomEnd() async {
    _ensureCustomRange();
    final picked = await showLedgerDatePicker(
      context,
      initialDate: _customEnd!,
      minimumDate: _customStart,
    );
    if (picked == null || !mounted) return;
    setState(() => _customEnd = picked);
  }

  Future<void> _exportCsv(DateRange range) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出 CSV？'),
        content: const Text('会打开系统保存面板，请选择 CSV 保存位置；取消保存不会改动账本。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认导出'),
          ),
        ],
      ),
    );
    if (confirmed != true || _exporting || !mounted) return;
    setState(() => _exporting = true);
    final csv = CsvExporter().exportEntries(
      entries: widget.state.entries,
      rules: widget.state.payRules,
      nightRule: widget.state.nightRule,
      range: range,
    );
    try {
      if (widget.repository == null) {
        _snack('CSV 已生成：${csv.length} 字符');
        return;
      }
      final path = await widget.repository!.writeCsv(csv);
      _snack(path == null ? '已取消保存 CSV' : 'CSV 已保存：$path');
    } catch (_) {
      _snack('CSV 已生成但保存失败，请重试或更换保存位置');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showIncomeBreakdown(LedgerSummary summary) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: LedgerColors.paper,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('收入构成', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              _Line('基础收入', moneyText(summary.baseIncome)),
              _Line('加班收入', moneyText(summary.overtimeIncome)),
              _Line('夜班收入', moneyText(summary.nightIncome)),
              _Line('补贴', moneyText(summary.allowance)),
              _Line('扣款', '-${moneyText(summary.deduction)}'),
            ],
          ),
        ),
      ),
    );
  }

  List<_DaySummaryRow> _groupSummaryByDay(LedgerSummary summary) {
    final byDay = <String, List<EntryCalculation>>{};
    for (final calc in summary.calculations) {
      byDay.putIfAbsent(ymd(calc.entry.workDate), () => []).add(calc);
    }
    final rows = byDay.values.map((items) => _DaySummaryRow(items)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return rows;
  }

  void _showDayRows(String title, List<_DaySummaryRow> rows) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LedgerColors.paper,
      builder: (context) => _SummaryDrillDownSheet(
        title: title,
        rows: rows,
        state: widget.state,
        templateNameFor: _templateNameFor,
      ),
    );
  }

  String? _templateNameFor(WorkEntry entry) {
    final id = entry.templateId;
    if (id == null) return null;
    for (final template in widget.state.templates) {
      if (template.id == id) return template.name;
    }
    return null;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.mode,
    required this.range,
    required this.onModeChanged,
    this.onPickStart,
    this.onPickEnd,
  });

  final String mode;
  final DateRange range;
  final ValueChanged<String> onModeChanged;
  final VoidCallback? onPickStart;
  final VoidCallback? onPickEnd;

  @override
  Widget build(BuildContext context) {
    final custom = onPickStart != null || onPickEnd != null;
    final rangeText =
        range.label ?? '${ymd(range.start)} — ${ymd(range.endInclusive)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in ['本月', '本周', '年度', '发薪周期', '自定义']) ...[
                _RangeModePill(
                  label: item,
                  selected: mode == item,
                  onTap: () => onModeChanged(item),
                ),
                if (item != '自定义') const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        LedgerCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              const Icon(
                Icons.filter_alt_outlined,
                size: 18,
                color: LedgerColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Text('范围', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(width: 8),
              if (custom) ...[
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _RangeDateButton(
                          label: ymd(range.start),
                          onTap: onPickStart,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '至',
                          style: TextStyle(color: LedgerColors.muted),
                        ),
                      ),
                      Expanded(
                        child: _RangeDateButton(
                          label: ymd(range.endInclusive),
                          onTap: onPickEnd,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                Expanded(
                  child: FittedValueText(
                    rangeText,
                    style: Theme.of(context).textTheme.titleMedium!,
                    maxScale: 1.08,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RangeModePill extends StatelessWidget {
  const _RangeModePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(9),
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? LedgerColors.primaryBlueSoft : LedgerColors.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: selected
              ? LedgerColors.primaryBlueSoft
              : LedgerColors.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            const Icon(Icons.check, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            textScaler: cappedTextScaler(context, maxScale: 1.12),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _RangeDateButton extends StatelessWidget {
  const _RangeDateButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: onTap,
    child: Container(
      alignment: Alignment.center,
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: LedgerColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LedgerColors.hairline),
      ),
      child: FittedValueText(
        label,
        textAlign: TextAlign.center,
        alignment: Alignment.center,
        maxScale: 1.12,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
    ),
  );
}

class _SummaryOverview extends StatelessWidget {
  const _SummaryOverview({
    required this.summary,
    required this.onHoursTap,
    required this.onIncomeTap,
  });

  final LedgerSummary summary;
  final VoidCallback onHoursTap;
  final VoidCallback onIncomeTap;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: '总工时',
                  value: hoursText(summary.totalHours),
                  subtext: '${summary.attendanceDays}天出勤',
                  onTap: onHoursTap,
                  emphasized: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniMetric(
                  label: '收入估算',
                  value: moneyText(summary.income),
                  subtext:
                      '补 ${moneyText(summary.allowance)} / 扣 ${moneyText(summary.deduction)}',
                  onTap: onIncomeTap,
                  emphasized: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatChip('加班', hoursText(summary.overtimeHours)),
              _StatChip('夜班', '${summary.nightShiftCount}次'),
              _StatChip('备注', '${summary.noteDays}天'),
              _StatChip('偏长', '${summary.longDurationDays}天'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.subtext,
    this.onTap,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final String subtext;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: LedgerColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LedgerColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          FittedValueText(
            value,
            maxScale: 1.1,
            style: TextStyle(
              fontSize: emphasized ? 23 : 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: LedgerColors.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          FittedValueText(
            subtext,
            maxScale: 1.06,
            style: const TextStyle(color: LedgerColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: child,
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: LedgerColors.surfaceSoft.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      '$label $value',
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
    ),
  );
}

class _InsightItem {
  const _InsightItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback onTap;
}

class _InsightGrid extends StatelessWidget {
  const _InsightGrid({required this.items});
  final List<_InsightItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 420 ? 3 : 2;
        final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _InsightTile(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.item});
  final _InsightItem item;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: item.onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: LedgerColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LedgerColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: LedgerColors.muted,
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedValueText(
            item.value,
            style: Theme.of(context).textTheme.titleMedium!,
            maxScale: 1.08,
          ),
          Text(
            item.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: LedgerColors.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _SummaryDrillDownSheet extends StatefulWidget {
  const _SummaryDrillDownSheet({
    required this.title,
    required this.rows,
    required this.state,
    required this.templateNameFor,
  });

  final String title;
  final List<_DaySummaryRow> rows;
  final LedgerState state;
  final String? Function(WorkEntry entry) templateNameFor;

  @override
  State<_SummaryDrillDownSheet> createState() => _SummaryDrillDownSheetState();
}

class _SummaryDrillDownSheetState extends State<_SummaryDrillDownSheet> {
  static const _pageSize = 15;
  int _visibleCount = _pageSize;

  @override
  Widget build(BuildContext context) {
    final visibleRows = widget.rows.take(_visibleCount).toList();
    final shownCount = visibleRows.length;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.84,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                ],
              ),
              Text(
                widget.rows.isEmpty
                    ? '没有匹配日期'
                    : '按天汇总 · 已显示 $shownCount / ${widget.rows.length} 天',
                style: const TextStyle(color: LedgerColors.muted),
              ),
              const SizedBox(height: 12),
              if (widget.rows.isEmpty) const LedgerCard(child: Text('没有匹配日期')),
              for (final row in visibleRows) ...[
                _DaySummaryCard(
                  row: row,
                  state: widget.state,
                  templateNameFor: widget.templateNameFor,
                ),
                const SizedBox(height: 8),
              ],
              if (_visibleCount < widget.rows.length)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _visibleCount += _pageSize),
                    child: Text('继续加载 ${widget.rows.length - _visibleCount} 天'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DaySummaryCard extends StatefulWidget {
  const _DaySummaryCard({
    required this.row,
    required this.state,
    required this.templateNameFor,
  });

  final _DaySummaryRow row;
  final LedgerState state;
  final String? Function(WorkEntry entry) templateNameFor;

  @override
  State<_DaySummaryCard> createState() => _DaySummaryCardState();
}

class _DaySummaryCardState extends State<_DaySummaryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final breakdown = row.breakdownText(widget.templateNameFor);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: LedgerColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LedgerColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: FittedValueText(
                  '${cnDateText(row.date)} · ${_weekdayText(row.date.weekday)} · ${row.entries.length}段',
                  maxScale: 1.15,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _DenseValuePill(hoursText(row.totalHours)),
              const SizedBox(width: 6),
              _DenseValuePill(moneyText(row.income)),
              const SizedBox(width: 2),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(44, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  showEditWorkEntrySheet(context, widget.state, day: row.date);
                },
                child: const Text('编辑'),
              ),
            ],
          ),
          if (breakdown.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              breakdown,
              textScaler: cappedTextScaler(context, maxScale: 1.12),
              style: const TextStyle(
                color: LedgerColors.muted,
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ],
          _ExpandDetailsButton(
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const SizedBox(height: 4),
            for (final calc in row.calculations) ...[
              _ExpandedSegmentLine(
                calc: calc,
                templateName: widget.templateNameFor(calc.entry),
              ),
              if (calc != row.calculations.last)
                const Divider(height: 8, color: LedgerColors.hairline),
            ],
          ],
        ],
      ),
    );
  }
}

class _ExpandDetailsButton extends StatelessWidget {
  const _ExpandDetailsButton({required this.expanded, required this.onTap});
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(44, 30),
        padding: const EdgeInsets.symmetric(horizontal: 0),
        foregroundColor: LedgerColors.primaryBlue,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      icon: Icon(
        expanded
            ? Icons.keyboard_arrow_up_rounded
            : Icons.keyboard_arrow_down_rounded,
        size: 18,
      ),
      label: Text(expanded ? '收起明细' : '展开明细'),
    ),
  );
}

class _ExpandedSegmentLine extends StatelessWidget {
  const _ExpandedSegmentLine({required this.calc, required this.templateName});

  final EntryCalculation calc;
  final String? templateName;

  @override
  Widget build(BuildContext context) {
    final entry = calc.entry;
    final name = templateName ?? entry.type.label;
    final hours = calc.regularHours + calc.overtimeHours;
    final tags = [
      if (calc.regularHours > 0) '普通 ${hoursText(calc.regularHours)}',
      if (calc.overtimeHours > 0) '加班 ${hoursText(calc.overtimeHours)}',
      if (calc.nightHours > 0) '夜班 ${hoursText(calc.nightHours)}',
      if (entry.allowanceTotal > 0) '补 ${moneyText(entry.allowanceTotal)}',
      if (entry.deductionTotal > 0) '扣 ${moneyText(entry.deductionTotal)}',
      if (entry.isCrossDay) '跨天',
      if (entry.hasNote) '备注',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: FittedValueText(
                  '${entry.timeRangeLabel} · $name ${hoursText(hours > 0 ? hours : entry.netHours)}',
                  maxScale: 1.12,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    moneyText(calc.income),
                    textScaler: cappedTextScaler(context, maxScale: 1.1),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              tags.join(' · '),
              textScaler: cappedTextScaler(context, maxScale: 1.1),
              style: const TextStyle(color: LedgerColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _DenseValuePill extends StatelessWidget {
  const _DenseValuePill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 92),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: LedgerColors.surfaceRaised,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: LedgerColors.hairline),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        textScaler: cappedTextScaler(context, maxScale: 1.08),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.2,
        ),
      ),
    ),
  );
}

class _DaySummaryRow {
  _DaySummaryRow(List<EntryCalculation> calculations)
    : calculations = [
        ...calculations,
      ]..sort((a, b) => a.entry.startDateTime.compareTo(b.entry.startDateTime));

  final List<EntryCalculation> calculations;

  DateTime get date => calculations.first.entry.workDate;
  List<WorkEntry> get entries =>
      calculations.map((calc) => calc.entry).toList();
  double get regularHours => _sum((calc) => calc.regularHours);
  double get overtimeHours => _sum((calc) => calc.overtimeHours);
  double get nightHours => _sum((calc) => calc.nightHours);
  double get totalHours =>
      _sum((calc) => calc.regularHours + calc.overtimeHours);
  double get allowance =>
      entries.fold(0.0, (sum, entry) => sum + entry.allowanceTotal);
  double get deduction =>
      entries.fold(0.0, (sum, entry) => sum + entry.deductionTotal);
  double get income => _sum((calc) => calc.income);
  bool get hasNote => entries.any((entry) => entry.hasNote);

  String breakdownText(String? Function(WorkEntry entry) templateNameFor) {
    final byName = <String, double>{};
    for (final calc in calculations) {
      final entry = calc.entry;
      final name = templateNameFor(entry) ?? entry.type.label;
      final hours = calc.regularHours + calc.overtimeHours;
      byName[name] = (byName[name] ?? 0) + (hours > 0 ? hours : entry.netHours);
    }
    final parts = [
      for (final item in byName.entries) '${item.key} ${hoursText(item.value)}',
      if (allowance > 0) '补 ${moneyText(allowance)}',
      if (deduction > 0) '扣 ${moneyText(deduction)}',
      if (hasNote) '备注',
    ];
    return parts.join(' · ');
  }

  double _sum(double Function(EntryCalculation calc) selector) =>
      calculations.fold(0.0, (sum, calc) => sum + selector(calc));
}

String _weekdayText(int weekday) =>
    '周${const ['一', '二', '三', '四', '五', '六', '日'][weekday - 1]}';

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.color,
    required this.fraction,
  });
  final String label;
  final String value;
  final Color color;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 46, child: Text(label)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: fraction.clamp(0, 1),
                minHeight: 7,
                color: color,
                backgroundColor: LedgerColors.surfaceSoft,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: FittedValueText(
              value,
              textAlign: TextAlign.right,
              alignment: Alignment.centerRight,
              maxScale: 1.08,
              style: Theme.of(context).textTheme.titleMedium!,
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 10),
        Flexible(
          child: FittedValueText(
            value,
            alignment: Alignment.centerRight,
            textAlign: TextAlign.right,
            maxScale: 1.08,
            style: Theme.of(context).textTheme.titleMedium!,
          ),
        ),
      ],
    ),
  );
}
