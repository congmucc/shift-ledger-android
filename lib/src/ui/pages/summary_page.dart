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
    return PageFrame(
      title: '工时汇总',
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
        const SizedBox(height: 12),
        _SummaryOverview(
          summary: summary,
          payrollBasisSummary:
              '${defaultRule.baseType.label} · ${defaultRule.amountLabel}',
        ),
        const SizedBox(height: 12),
        _IncomeCompositionCard(summary: summary),
        const SizedBox(height: 12),
        _PayrollBasisCard(
          range: range,
          rule: defaultRule,
          nightRule: widget.state.nightRule,
          exporting: _exporting,
          onExplain: () => _showIncomeBreakdown(summary),
          onExport: () => _exportCsv(range),
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
              Text('收入组成', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.filter_alt_outlined,
                    size: 18,
                    color: LedgerColors.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Text('当前范围', style: Theme.of(context).textTheme.labelMedium),
                  const Spacer(),
                  _ScopeBadge(text: '$mode · ${summary.range.dayCount}天'),
                ],
              ),
              const SizedBox(height: 10),
              if (custom) ...[
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
              ] else
                FittedValueText(
                  rangeText,
                  style: Theme.of(context).textTheme.titleMedium!,
                  maxScale: 1.08,
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
              _StatChip('出勤', '${summary.attendanceDays}天'),
              _StatChip(
                '计薪加班',
                '${summary.overtimeDays}天 / ${hoursText(summary.overtimeHours)}',
              ),
              _StatChip(
                '夜班',
                '${summary.nightShiftCount}次 / ${hoursText(summary.nightHours)}',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '备注 ${summary.noteDays} 天 · 偏长 ${summary.longDurationDays} 天 · 共 ${summary.calculations.length} 段',
            style: const TextStyle(color: LedgerColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text('计薪依据', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(
            payrollBasisSummary,
            style: const TextStyle(color: LedgerColors.muted, fontSize: 12),
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
    this.emphasized = false,
  });

  final String label;
  final String value;
  final String subtext;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
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

class _IncomeCompositionCard extends StatelessWidget {
  const _IncomeCompositionCard({required this.summary});

  final LedgerSummary summary;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '收入组成',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Line('基础收入', moneyText(summary.baseIncome)),
          _Line('计薪加班收入', moneyText(summary.overtimeIncome)),
          _Line('夜班收入', moneyText(summary.nightIncome)),
          _Line('补贴', moneyText(summary.allowance)),
          _Line('扣款', '-${moneyText(summary.deduction)}'),
          _Line('预计到手', moneyText(summary.income)),
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
    required this.exporting,
    required this.onExplain,
    required this.onExport,
  });

  final DateRange range;
  final PayRule rule;
  final NightRule nightRule;
  final bool exporting;
  final VoidCallback onExplain;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final overtimeBase = moneyText(rule.overtimeHourlyBase(range: range));
    return LedgerCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('计薪依据', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          SettingTile(
            title: '默认规则',
            subtitle:
                '${rule.name} · ${rule.baseType.label} · ${rule.amountLabel}',
          ),
          SettingTile(
            title: '计薪加班计算',
            subtitle:
                '超过 ${hoursText(rule.overtimeThresholdHours)} 后按 ${_factorText(rule.overtimeMultiplier)} · 基数 $overtimeBase/h',
          ),
          SettingTile(
            title: '夜班规则',
            subtitle:
                '${nightRule.label} · ${nightRule.mode.label} · ${_nightRuleValueText(nightRule)}',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onExplain,
                  child: const Text('计算说明'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: exporting ? null : onExport,
                  child: Text(exporting ? '导出中' : '导出 CSV'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
