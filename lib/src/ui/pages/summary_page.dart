import 'package:flutter/material.dart';

import '../../app/ledger_state.dart';
import '../../domain/models.dart';
import '../../services/csv_exporter.dart';
import '../../services/local_ledger_repository.dart';
import '../edit_entry_sheet.dart';
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

  @override
  Widget build(BuildContext context) {
    final range = _range();
    final summary = widget.state.summaryFor(range);
    return PageFrame(
      title: '工时汇总',
      trailing: FilledButton.tonal(
        onPressed: () => _exportCsv(range),
        child: const Text('CSV'),
      ),
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final item in ['本月', '本周', '年度', '发薪周期', '自定义'])
              ChoiceChip(
                label: Text(item),
                selected: _mode == item,
                onSelected: (_) => setState(() => _mode = item),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                label: '总工时',
                value: hoursText(summary.totalHours),
                subtext: '${summary.attendanceDays}天 出勤',
                onTap: () => _showDrillDown(
                  '出勤 ${summary.attendanceDays} 天',
                  summary,
                  (calc) => true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricCard(
                label: '收入估算',
                value: moneyText(summary.income),
                subtext: '加班 ${hoursText(summary.overtimeHours)}',
                onTap: () => _showIncomeBreakdown(summary),
              ),
            ),
          ],
        ),
        SectionHeader(
          title: '工时拆分',
          actionLabel: '查看明细',
          onAction: () => _showDrillDown('全部明细', summary, (calc) => true),
        ),
        LedgerCard(
          child: Column(
            children: [
              _BreakdownRow(
                label: '普通',
                value: hoursText(summary.regularHours),
                color: LedgerColors.workAmber,
                fraction: summary.totalHours == 0
                    ? 0
                    : summary.regularHours / summary.totalHours,
              ),
              _BreakdownRow(
                label: '加班',
                value: hoursText(summary.overtimeHours),
                color: LedgerColors.overtimeMoss,
                fraction: summary.totalHours == 0
                    ? 0
                    : summary.overtimeHours / summary.totalHours,
              ),
              _BreakdownRow(
                label: '夜班',
                value:
                    '${summary.nightShiftCount}次 · ${hoursText(summary.nightHours)}',
                color: LedgerColors.nightSlate,
                fraction: summary.totalHours == 0
                    ? 0
                    : summary.nightHours / summary.totalHours,
              ),
            ],
          ),
        ),
        const SectionHeader(title: '明细'),
        LedgerCard(
          child: Column(
            children: [
              SettingTile(
                title: '导出 CSV',
                subtitle: '含计薪规则、收入拆分、跨天标记',
                trailing: '导出',
                onTap: () => _exportCsv(range),
              ),
              SettingTile(
                title: '时长偏长',
                subtitle: '${summary.longDurationDays}天',
                trailing: '查看日期',
                onTap: () => _showDrillDown(
                  '时长偏长',
                  summary,
                  (calc) =>
                      _longDayKeys(summary).contains(ymd(calc.entry.workDate)),
                ),
              ),
              SettingTile(
                title: '备注天数',
                subtitle: '${summary.noteDays}天',
                trailing: '查看记录',
                onTap: () => _showDrillDown(
                  '含备注记录',
                  summary,
                  (calc) => calc.entry.hasNote,
                ),
              ),
              SettingTile(
                title: '补贴',
                subtitle: moneyText(summary.allowance),
                trailing: '查看来源',
                onTap: () => _showDrillDown(
                  '补贴来源',
                  summary,
                  (calc) => calc.entry.allowanceTotal > 0,
                ),
              ),
              SettingTile(
                title: '扣款',
                subtitle: moneyText(summary.deduction),
                trailing: '查看来源',
                onTap: () => _showDrillDown(
                  '扣款来源',
                  summary,
                  (calc) => calc.entry.deductionTotal > 0,
                ),
              ),
              SettingTile(
                title: '加班',
                subtitle: '${summary.overtimeDays}天',
                trailing: '查看日期',
                onTap: () => _showDrillDown(
                  '加班记录',
                  summary,
                  (calc) => calc.overtimeHours > 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  DateRange _range() => switch (_mode) {
    '本周' => DateRange.week(widget.state.now),
    '年度' => DateRange.year(widget.state.now.year),
    '发薪周期' => widget.state.currentPayPeriod,
    '自定义' => DateRange.custom(
      widget.state.now.subtract(const Duration(days: 30)),
      widget.state.now,
      label: '近30天',
    ),
    _ => widget.state.currentMonth,
  };

  Future<void> _exportCsv(DateRange range) async {
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
      _snack('CSV 已导出：$path');
    } catch (_) {
      _snack('CSV 已生成：${csv.length} 字符；当前预览环境不支持写入文件');
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

  Set<String> _longDayKeys(LedgerSummary summary) {
    final totalsByDay = <String, double>{};
    for (final calc in summary.calculations) {
      final key = ymd(calc.entry.workDate);
      totalsByDay[key] =
          (totalsByDay[key] ?? 0) + calc.regularHours + calc.overtimeHours;
    }
    return {
      for (final item in totalsByDay.entries)
        if (item.value > 12) item.key,
    };
  }

  void _showDrillDown(
    String title,
    LedgerSummary summary,
    bool Function(EntryCalculation calc) filter,
  ) {
    final rows = summary.calculations.where(filter).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LedgerColors.paper,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty) const LedgerCard(child: Text('没有匹配记录')),
                for (final calc in rows.take(12)) ...[
                  WorkEntryTile(
                    entry: calc.entry,
                    onEdit: () {
                      Navigator.pop(context);
                      showEditWorkEntrySheet(
                        context,
                        widget.state,
                        day: calc.entry.workDate,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1),
              minHeight: 8,
              color: color,
              backgroundColor: LedgerColors.surfaceSoft,
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
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}
