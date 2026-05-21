import 'package:flutter/material.dart';

import '../../app/ledger_state.dart';
import '../../domain/models.dart';
import '../../services/csv_exporter.dart';
import '../../services/local_ledger_repository.dart';
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
    final defaultRule = widget.state.defaultRule;
    final empty = summary.calculations.isEmpty;
    return PageFrame(
      title: '汇总',
      trailing: FilledButton.tonal(
        onPressed: _exporting ? null : () => _exportCsv(range),
        child: Text(_exporting ? '导出中' : '导出'),
      ),
      children: [
        _RangeSelector(
          mode: _mode,
          range: range,
          summary: summary,
          onModeChanged: (value) => setState(() {
            _mode = value;
            if (value == '自定义') _ensureCustomRange();
          }),
          onPickStart: _mode == '自定义' ? _pickCustomStart : null,
          onPickEnd: _mode == '自定义' ? _pickCustomEnd : null,
        ),
        const SizedBox(height: 6),
        if (empty) ...[
          _SummaryEmptyState(mode: _mode),
          const SizedBox(height: 6),
          _PayrollBasisCard(
            range: range,
            rule: defaultRule,
            nightRule: widget.state.nightRule,
            onExplain: () => _showIncomeBreakdown(summary),
          ),
        ] else ...[
          _SummaryOverview(
            summary: summary,
            payrollBasisSummary:
                '${defaultRule.baseType.label} · ${defaultRule.amountLabel}',
          ),
          const SizedBox(height: 7),
          _SummaryTrendCard(summary: summary),
          const SizedBox(height: 7),
          _WorkHoursTable(summary: summary),
          const SizedBox(height: 7),
          _IncomeCompositionCard(summary: summary),
          const SizedBox(height: 6),
          _PayrollBasisCard(
            range: range,
            rule: defaultRule,
            nightRule: widget.state.nightRule,
            onExplain: () => _showIncomeBreakdown(summary),
          ),
        ],
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
    final confirmed = await showLedgerConfirmDialog(
      context,
      title: '导出 CSV？',
      message: '会打开系统保存面板，请选择 CSV 保存位置；取消保存不会改动账本。',
      confirmText: '确认导出',
      icon: Icons.file_download_outlined,
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
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('收入组成', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              _Line('基础收入', moneyText(summary.baseIncome)),
              _Line('计薪加班收入', moneyText(summary.overtimeIncome)),
              _Line('夜班收入', moneyText(summary.nightIncome)),
              _Line('补贴', moneyText(summary.allowance)),
              _Line('扣款', '-${moneyText(summary.deduction)}'),
              const Divider(height: 24),
              _Line('预计到手', moneyText(summary.income)),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    showLedgerSnackBar(context, message);
  }
}

class _SummaryEmptyState extends StatelessWidget {
  const _SummaryEmptyState({required this.mode});

  final String mode;

  @override
  Widget build(BuildContext context) {
    final scopeLabel = switch (mode) {
      '本周' => '本周',
      '年度' => '今年',
      '发薪周期' => '当前发薪周期',
      '自定义' => '这个自定义范围',
      _ => '这个月',
    };
    return NoticeCard(
      icon: Icons.query_stats_outlined,
      title: '$scopeLabel 还没有记录',
      body: '先去首页补今天，或到日历补录。',
      iconBackgroundColor: LedgerColors.surfaceSoft,
      iconColor: LedgerColors.primaryBlue,
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.mode,
    required this.range,
    required this.summary,
    required this.onModeChanged,
    this.onPickStart,
    this.onPickEnd,
  });

  final String mode;
  final DateRange range;
  final LedgerSummary summary;
  final ValueChanged<String> onModeChanged;
  final VoidCallback? onPickStart;
  final VoidCallback? onPickEnd;

  @override
  Widget build(BuildContext context) {
    final custom = onPickStart != null || onPickEnd != null;
    final rangeText =
        '${_compactCnDate(range.start)}—${_compactCnDate(range.endInclusive)}';
    final rangeName = switch (mode) {
      '本月' => '本月自然月',
      '本周' => '本周',
      '年度' => '年度',
      '发薪周期' => range.label ?? '发薪周期',
      '自定义' => '自定义范围',
      _ => mode,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: LedgerColors.surfaceSoft.withValues(alpha: .7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: LedgerColors.hairline),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in ['本月', '本周', '年度', '发薪周期', '自定义'])
                  _RangeModePill(
                    label: item,
                    selected: mode == item,
                    onTap: () => onModeChanged(item),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$rangeName · $rangeText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: LedgerColors.muted,
                    fontSize: 11.5,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ScopeBadge(text: '${summary.range.dayCount}天 · 范围 ›'),
            ],
          ),
        ),
        if (range.label != null && range.label!.startsWith('每月')) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              range.label!,
              style: const TextStyle(
                color: LedgerColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        if (custom) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _RangeDateButton(
                  label: ymd(range.start),
                  onTap: onPickStart,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('至', style: TextStyle(color: LedgerColors.muted)),
              ),
              Expanded(
                child: _RangeDateButton(
                  label: ymd(range.endInclusive),
                  onTap: onPickEnd,
                ),
              ),
            ],
          ),
        ],
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
    borderRadius: BorderRadius.circular(11),
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 11),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? LedgerColors.surfaceRaised : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        border: selected ? Border.all(color: LedgerColors.hairline) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textScaler: cappedTextScaler(context, maxScale: 1.12),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? LedgerColors.primaryBlue : LedgerColors.muted,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: LedgerColors.primaryBlueSoft,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
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
    required this.payrollBasisSummary,
  });

  final LedgerSummary summary;
  final String payrollBasisSummary;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Semantics(
        label:
            '汇总概览，总工时 ${hoursText(summary.totalHours)}，预计收入 ${moneyText(summary.income)}，出勤 ${summary.attendanceDays} 天，加班 ${hoursText(summary.overtimeHours)}，夜班 ${summary.nightShiftCount} 次',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final incomeFlex = constraints.maxWidth < 360 ? 7 : 6;
                return Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _CoreMetricBox(
                        label: '总工时',
                        value: hoursText(summary.totalHours),
                        dotColor: LedgerColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      flex: incomeFlex,
                      child: _CoreMetricBox(
                        label: '收入估算',
                        value: moneyText(summary.income),
                        dotColor: LedgerColors.hairlineStrong,
                        emphasizeValue: true,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: _SmallMetricBox('出勤', '${summary.attendanceDays}天'),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _SmallMetricBox(
                    '加班',
                    hoursText(summary.overtimeHours),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _SmallMetricBox('夜班', '${summary.nightShiftCount}次'),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _SmallMetricBox('补贴', moneyText(summary.allowance)),
                ),
              ],
            ),
            const SizedBox(height: 7),
            LedgerInlineGroup(
              spacing: 6,
              children: [
                LedgerPill(
                  '计薪 $payrollBasisSummary',
                  color: LedgerColors.muted,
                  dense: true,
                ),
                if (summary.deduction > 0)
                  LedgerPill(
                    '扣款 ${moneyText(summary.deduction)}',
                    color: LedgerColors.errorRed,
                    dense: true,
                  ),
                if (summary.longDurationDays > 0)
                  LedgerPill(
                    '超长 ${summary.longDurationDays}天',
                    color: LedgerColors.errorRed,
                    dense: true,
                  ),
                LedgerPill(
                  '${summary.calculations.length}段',
                  color: LedgerColors.muted,
                  dense: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoreMetricBox extends StatelessWidget {
  const _CoreMetricBox({
    required this.label,
    required this.value,
    required this.dotColor,
    this.emphasizeValue = false,
  });

  final String label;
  final String value;
  final Color dotColor;
  final bool emphasizeValue;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: BoxDecoration(
      color: LedgerColors.surfaceSoft.withValues(alpha: .52),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: LedgerColors.hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _MetricDot(color: dotColor),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        const SizedBox(height: 6),
        FittedValueText(
          value,
          maxScale: 1.06,
          style: TextStyle(
            fontSize: emphasizeValue ? 20 : 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
            color: LedgerColors.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

class _MetricDot extends StatelessWidget {
  const _MetricDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _SmallMetricBox extends StatelessWidget {
  const _SmallMetricBox(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
    decoration: BoxDecoration(
      color: LedgerColors.surfaceRaised,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: LedgerColors.hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: LedgerColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        FittedValueText(
          value,
          maxScale: 1.04,
          style: const TextStyle(
            color: LedgerColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

enum _TrendSeries { total, regular, overtime, night, attendance, income }

extension on _TrendSeries {
  String get label => switch (this) {
    _TrendSeries.total => '总工时',
    _TrendSeries.regular => '普通',
    _TrendSeries.overtime => '加班',
    _TrendSeries.night => '夜班',
    _TrendSeries.attendance => '出勤',
    _TrendSeries.income => '收入',
  };

  Color get color => switch (this) {
    _TrendSeries.total => LedgerColors.primaryBlue,
    _TrendSeries.regular => const Color(0xFF60A5FA),
    _TrendSeries.overtime => LedgerColors.successGreen,
    _TrendSeries.night => LedgerColors.nightIndigo,
    _TrendSeries.attendance => LedgerColors.hairlineStrong,
    _TrendSeries.income => LedgerColors.ink,
  };
}

class _SummaryTrendCard extends StatefulWidget {
  const _SummaryTrendCard({required this.summary});
  final LedgerSummary summary;

  @override
  State<_SummaryTrendCard> createState() => _SummaryTrendCardState();
}

class _SummaryTrendCardState extends State<_SummaryTrendCard> {
  final Set<_TrendSeries> _selected = {
    _TrendSeries.total,
    _TrendSeries.overtime,
  };

  @override
  Widget build(BuildContext context) {
    final points = _dailyPoints(widget.summary);
    if (points.isEmpty) return const SizedBox.shrink();
    final chartLabel = _trendSemanticLabel(points);
    return LedgerCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '工时趋势',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Text(
                '最近记录日',
                style: TextStyle(
                  color: LedgerColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            label: chartLabel,
            image: true,
            child: Container(
              height: 142,
              decoration: BoxDecoration(
                color: LedgerColors.surfaceRaised,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: LedgerColors.hairline),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: CustomPaint(
                  painter: _TrendChartPainter(
                    points: points,
                    selected: _selected,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          LedgerInlineGroup(
            spacing: 6,
            children: [
              for (final series in _TrendSeries.values)
                _TrendToggle(
                  label: series.label,
                  color: series.color,
                  selected: _selected.contains(series),
                  onTap: () => setState(() {
                    if (_selected.contains(series)) {
                      if (_selected.length > 1) _selected.remove(series);
                    } else {
                      _selected.add(series);
                    }
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _trendSemanticLabel(List<_DailyTrendPoint> points) {
    final days = points.length;
    final total = points.fold<double>(0, (sum, point) => sum + point.total);
    final overtime = points.fold<double>(
      0,
      (sum, point) => sum + point.overtime,
    );
    final night = points.fold<double>(0, (sum, point) => sum + point.night);
    final income = points.fold<double>(0, (sum, point) => sum + point.income);
    final peak = points.reduce((a, b) => a.total >= b.total ? a : b);
    return '工时趋势图，$days 个记录日，总工时 ${hoursText(total)}，加班 ${hoursText(overtime)}，夜班 ${hoursText(night)}，收入 ${moneyText(income)}，最高日 ${peak.day.month}月${peak.day.day}日 ${hoursText(peak.total)}';
  }

  List<_DailyTrendPoint> _dailyPoints(LedgerSummary summary) {
    final byDay = <String, _DailyTrendPoint>{};
    for (final calculation in summary.calculations) {
      final day = dateOnly(calculation.entry.workDate);
      final key = ymd(day);
      final current = byDay[key] ?? _DailyTrendPoint(day: day);
      byDay[key] = current.add(calculation);
    }
    final points = byDay.values.toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    return points;
  }
}

class _TrendToggle extends StatelessWidget {
  const _TrendToggle({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: selected ? 1 : .42,
    child: LedgerPill(
      label,
      color: color,
      background: selected ? null : LedgerColors.surfaceRaised,
      dense: true,
      selected: selected,
      onTap: onTap,
    ),
  );
}

class _DailyTrendPoint {
  const _DailyTrendPoint({
    required this.day,
    this.total = 0,
    this.regular = 0,
    this.overtime = 0,
    this.night = 0,
    this.income = 0,
    this.attendance = 1,
  });

  final DateTime day;
  final double total;
  final double regular;
  final double overtime;
  final double night;
  final double income;
  final double attendance;

  _DailyTrendPoint add(EntryCalculation calculation) => _DailyTrendPoint(
    day: day,
    total: total + calculation.entry.netHours,
    regular: regular + calculation.regularHours,
    overtime: overtime + calculation.overtimeHours,
    night: night + calculation.nightHours,
    income: income + calculation.income,
    attendance: 1,
  );

  double valueFor(_TrendSeries series) => switch (series) {
    _TrendSeries.total => total,
    _TrendSeries.regular => regular,
    _TrendSeries.overtime => overtime,
    _TrendSeries.night => night,
    _TrendSeries.attendance => attendance,
    _TrendSeries.income => income,
  };
}

class _TrendChartPainter extends CustomPainter {
  const _TrendChartPainter({required this.points, required this.selected});
  final List<_DailyTrendPoint> points;
  final Set<_TrendSeries> selected;

  @override
  void paint(Canvas canvas, Size size) {
    const leftAxis = 30.0;
    const rightAxis = 42.0;
    const top = 8.0;
    const bottom = 26.0;
    final chart = Rect.fromLTWH(
      leftAxis,
      top,
      size.width - leftAxis - rightAxis,
      size.height - top - bottom,
    );
    final gridPaint = Paint()
      ..color = LedgerColors.hairline
      ..strokeWidth = 1;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    for (final tick in [0.0, .5, 1.0]) {
      final y = chart.bottom - chart.height * tick;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    final hourSeries = selected.where((s) => s != _TrendSeries.income);
    final hasHourSeries = hourSeries.isNotEmpty;
    final maxHours = _maxFor(hourSeries);
    final maxIncome = _maxFor([_TrendSeries.income]);
    if (hasHourSeries) {
      _drawLabel(
        canvas,
        textPainter,
        '${maxHours.toStringAsFixed(0)}h',
        0,
        top,
      );
      _drawLabel(
        canvas,
        textPainter,
        '${(maxHours / 2).toStringAsFixed(0)}h',
        0,
        chart.center.dy - 6,
      );
      _drawLabel(canvas, textPainter, '0h', 0, chart.bottom - 10);
      _drawLabel(canvas, textPainter, '小时', 0, chart.bottom + 8);
    }
    if (selected.contains(_TrendSeries.income)) {
      _drawLabel(
        canvas,
        textPainter,
        moneyText(maxIncome),
        chart.right + 6,
        top,
        alignRight: false,
      );
      _drawLabel(
        canvas,
        textPainter,
        moneyText(maxIncome / 2),
        chart.right + 6,
        chart.center.dy - 6,
        alignRight: false,
      );
      _drawLabel(
        canvas,
        textPainter,
        '¥0',
        chart.right + 6,
        chart.bottom - 10,
        alignRight: false,
      );
      _drawLabel(
        canvas,
        textPainter,
        '收入',
        chart.right + 6,
        chart.bottom + 8,
        alignRight: false,
      );
    }
    for (final series in selected) {
      _drawSeries(
        canvas,
        chart,
        series,
        series == _TrendSeries.income ? maxIncome : maxHours,
      );
    }
    if (points.isNotEmpty) {
      _drawLabel(
        canvas,
        textPainter,
        '${points.first.day.month}/${points.first.day.day}',
        chart.left,
        chart.bottom + 8,
      );
      _drawLabel(
        canvas,
        textPainter,
        '${points.last.day.month}/${points.last.day.day}',
        chart.right - 34,
        chart.bottom + 8,
      );
    }
  }

  double _maxFor(Iterable<_TrendSeries> series) {
    var maxValue = 0.0;
    for (final point in points) {
      for (final item in series) {
        final value = point.valueFor(item);
        if (value > maxValue) maxValue = value;
      }
    }
    return maxValue <= 0 ? 1 : maxValue;
  }

  void _drawSeries(
    Canvas canvas,
    Rect chart,
    _TrendSeries series,
    double maxValue,
  ) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = series.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = series == _TrendSeries.total ? 2.8 : 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x = points.length == 1
          ? chart.center.dx
          : chart.left + chart.width * index / (points.length - 1);
      final y =
          chart.bottom -
          chart.height * (point.valueFor(series) / maxValue).clamp(0, 1);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x = points.length == 1
          ? chart.center.dx
          : chart.left + chart.width * index / (points.length - 1);
      final y =
          chart.bottom -
          chart.height * (point.valueFor(series) / maxValue).clamp(0, 1);
      _drawPointMarker(canvas, Offset(x, y), series, paint.color);
    }
  }

  void _drawPointMarker(
    Canvas canvas,
    Offset center,
    _TrendSeries series,
    Color color,
  ) {
    final fill = Paint()
      ..color = LedgerColors.surfaceRaised
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    const radius = 2.8;
    switch (series) {
      case _TrendSeries.total:
        canvas.drawCircle(center, radius, fill);
        canvas.drawCircle(center, radius, stroke);
      case _TrendSeries.regular:
        final rect = Rect.fromCenter(
          center: center,
          width: radius * 2,
          height: radius * 2,
        );
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, stroke);
      case _TrendSeries.overtime:
        final path = Path()
          ..moveTo(center.dx, center.dy - radius)
          ..lineTo(center.dx + radius, center.dy + radius)
          ..lineTo(center.dx - radius, center.dy + radius)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
      case _TrendSeries.night:
      case _TrendSeries.income:
        final path = Path()
          ..moveTo(center.dx, center.dy - radius)
          ..lineTo(center.dx + radius, center.dy)
          ..lineTo(center.dx, center.dy + radius)
          ..lineTo(center.dx - radius, center.dy)
          ..close();
        canvas.drawPath(path, fill);
        canvas.drawPath(path, stroke);
      case _TrendSeries.attendance:
        canvas.drawCircle(center, 2.1, Paint()..color = color);
    }
  }

  void _drawLabel(
    Canvas canvas,
    TextPainter painter,
    String text,
    double x,
    double y, {
    bool alignRight = false,
  }) {
    painter.text = TextSpan(
      text: text,
      style: const TextStyle(
        color: LedgerColors.muted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    );
    painter.layout();
    painter.paint(canvas, Offset(alignRight ? x - painter.width : x, y));
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.selected != selected;
}

class _WorkHoursTable extends StatelessWidget {
  const _WorkHoursTable({required this.summary});
  final LedgerSummary summary;

  @override
  Widget build(BuildContext context) {
    final allRows = _rows();
    final rows = allRows.take(4).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    final maxHours = rows
        .map((row) => row.total)
        .fold<double>(
          0,
          (previous, value) => value > previous ? value : previous,
        );
    final shownCount = rows.length;
    final totalCount = allRows.length;
    return LedgerCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Semantics(
        label:
            '工时构成，总工时 ${hoursText(summary.totalHours)}，普通 ${hoursText(summary.regularHours)}，加班 ${hoursText(summary.overtimeHours)}，夜班 ${hoursText(summary.nightHours)}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '工时构成',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  totalCount > shownCount
                      ? '最近 $shownCount / $totalCount 天'
                      : '最近记录日',
                  style: const TextStyle(
                    color: LedgerColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _WorkHoursCompositionBar(summary: summary),
            const SizedBox(height: 7),
            for (final row in rows) ...[
              _WorkHoursRow(row: row, maxHours: maxHours),
              if (row != rows.last) const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  List<_DailyTrendPoint> _rows() {
    final byDay = <String, _DailyTrendPoint>{};
    for (final calculation in summary.calculations) {
      final day = dateOnly(calculation.entry.workDate);
      final key = ymd(day);
      byDay[key] = (byDay[key] ?? _DailyTrendPoint(day: day)).add(calculation);
    }
    final rows = byDay.values.toList()..sort((a, b) => b.day.compareTo(a.day));
    return rows;
  }
}

class _WorkHoursCompositionBar extends StatelessWidget {
  const _WorkHoursCompositionBar({required this.summary});

  final LedgerSummary summary;

  @override
  Widget build(BuildContext context) {
    final regular = summary.regularHours.clamp(0, double.infinity).toDouble();
    final overtime = summary.overtimeHours.clamp(0, double.infinity).toDouble();
    final night = summary.nightHours.clamp(0, double.infinity).toDouble();
    final accounted = regular + overtime + night;
    final other = (summary.totalHours - accounted)
        .clamp(0, double.infinity)
        .toDouble();
    final parts = [
      _HoursPart('普通', regular, LedgerColors.primaryBlue),
      _HoursPart('加班', overtime, LedgerColors.successGreen),
      _HoursPart('夜班', night, LedgerColors.nightIndigo),
      if (other > 0) _HoursPart('其他', other, LedgerColors.hairlineStrong),
    ].where((part) => part.value > 0).toList();
    if (parts.isEmpty) return const SizedBox.shrink();
    final total = parts.fold<double>(0, (sum, part) => sum + part.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 13,
            child: Row(
              children: [
                for (final part in parts)
                  Expanded(
                    flex: (part.value / total * 1000).round().clamp(1, 1000),
                    child: ColoredBox(color: part.color),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 7),
        LedgerInlineGroup(
          spacing: 6,
          children: [
            for (final part in parts)
              _HoursLegendPill(
                label: part.label,
                value: part.value,
                total: total,
                color: part.color,
              ),
          ],
        ),
      ],
    );
  }
}

class _HoursPart {
  const _HoursPart(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;
}

class _HoursLegendPill extends StatelessWidget {
  const _HoursLegendPill({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final double value;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = total <= 0 ? 0 : (value / total * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: LedgerColors.surfaceSoft.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MetricDot(color: color),
          const SizedBox(width: 5),
          Text(
            '$label ${hoursText(value)} · $percent%',
            style: const TextStyle(
              color: LedgerColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkHoursRow extends StatelessWidget {
  const _WorkHoursRow({required this.row, required this.maxHours});
  final _DailyTrendPoint row;
  final double maxHours;

  @override
  Widget build(BuildContext context) {
    final ratio = maxHours <= 0 ? 0.0 : row.total / maxHours;
    final percent = (ratio.clamp(0.0, 1.0) * 100).round();
    final parts = [
      _HoursPart('普通', row.regular, LedgerColors.primaryBlue),
      _HoursPart('加班', row.overtime, LedgerColors.successGreen),
      _HoursPart('夜班', row.night, LedgerColors.nightIndigo),
    ].where((part) => part.value > 0).toList();
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${row.day.month}/${row.day.day}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                row.day.weekdayCn,
                style: const TextStyle(
                  color: LedgerColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 11,
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: LedgerColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0xFFECEFF4)),
                ),
                child: FractionallySizedBox(
                  widthFactor: ratio.clamp(0.0, 1.0),
                  alignment: Alignment.centerLeft,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: Row(
                      children: [
                        if (parts.isEmpty)
                          const Expanded(
                            child: ColoredBox(color: LedgerColors.primaryBlue),
                          )
                        else
                          for (final part in parts)
                            Expanded(
                              flex: (part.value / row.total * 1000)
                                  .round()
                                  .clamp(1, 1000),
                              child: ColoredBox(color: part.color),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '占最高日 $percent%',
                style: const TextStyle(
                  color: LedgerColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          child: Text(
            hoursText(row.total),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

extension on DateTime {
  String get weekdayCn =>
      const ['一', '二', '三', '四', '五', '六', '日'][weekday - 1];
}

class _IncomeCompositionCard extends StatelessWidget {
  const _IncomeCompositionCard({required this.summary});

  final LedgerSummary summary;

  @override
  Widget build(BuildContext context) {
    final maxValue = [
      summary.baseIncome,
      summary.overtimeIncome,
      summary.nightIncome,
      summary.allowance,
      summary.deduction,
    ].fold<double>(0, (max, value) => value > max ? value : max);
    return LedgerCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '收入组成',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (summary.calculations.isEmpty) ...[
            const SizedBox(height: 2),
            const Text(
              '保存记录后自动生成收入拆分。',
              style: TextStyle(
                color: LedgerColors.muted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 6),
          _CompositionRow(
            label: '基础',
            value: summary.baseIncome,
            maxValue: maxValue,
            color: LedgerColors.primaryBlue,
          ),
          _CompositionRow(
            label: '加班',
            value: summary.overtimeIncome,
            maxValue: maxValue,
            color: LedgerColors.successGreen,
          ),
          _CompositionRow(
            label: '夜班',
            value: summary.nightIncome,
            maxValue: maxValue,
            color: LedgerColors.nightIndigo,
          ),
          _CompositionRow(
            label: '补贴',
            value: summary.allowance,
            maxValue: maxValue,
            color: LedgerColors.warningOrange,
          ),
          if (summary.deduction > 0)
            _CompositionRow(
              label: '扣款',
              value: summary.deduction,
              maxValue: maxValue,
              color: LedgerColors.errorRed,
              prefix: '-',
            ),
        ],
      ),
    );
  }
}

class _CompositionRow extends StatelessWidget {
  const _CompositionRow({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    this.prefix = '',
  });

  final String label;
  final double value;
  final double maxValue;
  final Color color;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final ratio = maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Container(
              height: 8,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: LedgerColors.surfaceSoft,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0xFFECEFF4)),
              ),
              child: FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: FittedValueText(
              '$prefix${moneyText(value)}',
              alignment: Alignment.centerRight,
              textAlign: TextAlign.right,
              maxScale: 1.04,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: LedgerColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayrollBasisCard extends StatelessWidget {
  const _PayrollBasisCard({
    required this.range,
    required this.rule,
    required this.nightRule,
    required this.onExplain,
  });

  final DateRange range;
  final PayRule rule;
  final NightRule nightRule;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final overtimeBase = moneyText(rule.overtimeHourlyBase(range: range));
    return LedgerCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('计薪依据', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          SettingTile(
            iconLabel: '薪',
            title: '默认规则',
            subtitle:
                '${rule.name} · ${rule.baseType.label} · ${rule.amountLabel}',
          ),
          SettingTile(
            iconLabel: '加',
            iconColor: LedgerColors.successGreen,
            iconBackgroundColor: LedgerColors.successGreenSoft,
            title: '计薪加班计算',
            subtitle:
                '超过 ${hoursText(rule.overtimeThresholdHours)} 后按 ${_factorText(rule.overtimeMultiplier)} · 基数 $overtimeBase/h',
          ),
          SettingTile(
            iconLabel: '夜',
            iconColor: LedgerColors.nightIndigo,
            iconBackgroundColor: LedgerColors.nightIndigoSoft,
            title: '夜班规则',
            subtitle:
                '${nightRule.label} · ${nightRule.mode.label} · ${_nightRuleValueText(nightRule)}',
          ),
          const SizedBox(height: 6),
          LedgerActionGroup(
            children: [
              OutlinedButton(onPressed: onExplain, child: const Text('计算说明')),
            ],
          ),
        ],
      ),
    );
  }
}

String _compactCnDate(DateTime value) =>
    '${value.year}年${value.month}月${value.day}日';

String _factorText(double value) =>
    '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}x';

String _nightRuleValueText(NightRule rule) {
  return switch (rule.mode) {
    NightAllowanceMode.fixed => '每次 ${moneyText(rule.fixedAmount)}',
    NightAllowanceMode.hourly => '每小时 ${moneyText(rule.hourlyAmount)}',
    NightAllowanceMode.multiplier => '按 ${_factorText(rule.multiplier)} 计算',
  };
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
