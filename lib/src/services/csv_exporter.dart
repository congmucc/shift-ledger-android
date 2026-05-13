import '../domain/models.dart';
import 'pay_calculator.dart';

class CsvExporter {
  String exportEntries({
    required List<WorkEntry> entries,
    required List<PayRule> rules,
    required NightRule nightRule,
    required DateRange range,
  }) {
    final summary = PayCalculator().summarize(
      entries: entries,
      rules: rules,
      nightRule: nightRule,
      range: range,
    );
    final rows = <List<Object?>>[
      [
        '归属日期',
        '开始日期时间',
        '结束日期时间',
        '跨天标记',
        '休息分钟',
        '净工时',
        '普通工时',
        '加班工时',
        '夜班工时',
        '计薪规则名称',
        '计薪类型',
        '规则快照摘要',
        '基础收入',
        '加班收入',
        '夜班收入',
        '补贴',
        '扣款',
        '收入合计',
        '备注',
      ],
      for (final calc in summary.calculations) _row(calc),
      [],
      [
        '汇总区间',
        range.label ?? '${ymd(range.start)} — ${ymd(range.endInclusive)}',
      ],
      ['总工时', summary.totalHours],
      ['普通工时', summary.regularHours],
      ['加班工时', summary.overtimeHours],
      ['夜班工时', summary.nightHours],
      ['出勤天数', summary.attendanceDays],
      ['收入合计', summary.income.toStringAsFixed(2)],
    ];
    return rows.map((row) => row.map(_escape).join(',')).join('\n');
  }

  List<Object?> _row(EntryCalculation calc) {
    final entry = calc.entry;
    return [
      ymd(entry.workDate),
      dateTimeText(entry.startDateTime),
      dateTimeText(entry.endDateTime),
      entry.isCrossDay ? '是' : '否',
      entry.breakMinutes,
      entry.netHours.toStringAsFixed(2),
      calc.regularHours.toStringAsFixed(2),
      calc.overtimeHours.toStringAsFixed(2),
      calc.nightHours.toStringAsFixed(2),
      entry.payRuleSnapshot.name,
      entry.payRuleSnapshot.baseType.label,
      entry.payRuleSnapshot.snapshotSummary,
      calc.baseIncome.toStringAsFixed(2),
      calc.overtimeIncome.toStringAsFixed(2),
      calc.nightIncome.toStringAsFixed(2),
      entry.allowanceTotal.toStringAsFixed(2),
      entry.deductionTotal.toStringAsFixed(2),
      calc.income.toStringAsFixed(2),
      entry.note,
    ];
  }

  String _escape(Object? value) {
    final text = value?.toString() ?? '';
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }
}
