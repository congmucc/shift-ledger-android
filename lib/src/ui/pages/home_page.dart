import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/ledger_state.dart';
import '../../domain/models.dart';
import '../edit_entry_sheet.dart';
import '../record_ui_summary.dart';
import '../theme.dart';
import '../widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.state,
    required this.openCalendar,
    required this.openSummary,
    required this.openSettings,
  });
  final LedgerState state;
  final VoidCallback openCalendar;
  final VoidCallback openSummary;
  final VoidCallback openSettings;

  @override
  Widget build(BuildContext context) {
    final todayEntries = state.entriesForDay(state.now);
    final todaySummary = state.summaryFor(
      DateRange.custom(state.now, state.now, label: '今日'),
    );
    final period = state.summaryFor(state.currentPayPeriod);
    return PageFrame(
      title: '今日',
      trailing: FilledButton(
        onPressed: () => showEditWorkEntrySheet(context, state, day: state.now),
        child: const Text('补一段'),
      ),
      children: [
        _TodayOverviewCard(
          day: state.now,
          entries: todayEntries,
          summary: todaySummary,
          rule: state.ruleForDate(state.now),
          onTap: () => showEditWorkEntrySheet(context, state, day: state.now),
        ),
        if (todayEntries.isNotEmpty) ...[
          const SectionHeader(title: '今天分段', actionLabel: '管理'),
          for (var index = 0; index < todayEntries.length; index++) ...[
            WorkEntryTile(
              entry: todayEntries[index],
              onEdit: () => showEditWorkEntrySheet(
                context,
                state,
                day: todayEntries[index].workDate,
              ),
            ),
            if (index != todayEntries.length - 1) const SizedBox(height: 6),
          ],
        ],
        SectionHeader(
          title: '本周期进度',
          actionLabel: '查看汇总',
          onAction: openSummary,
        ),
        LedgerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${ymd(state.currentPayPeriod.start)} — ${ymd(state.currentPayPeriod.endInclusive)}',
                      style: const TextStyle(
                        color: LedgerColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${state.currentPayPeriod.dayCount}天',
                    style: const TextStyle(
                      color: LedgerColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  value: _periodProgress(state.currentPayPeriod, state.now),
                  color: LedgerColors.primaryBlue,
                  backgroundColor: LedgerColors.hairline,
                ),
              ),
              const SizedBox(height: 7),
              _PeriodMetrics(summary: period),
              const SizedBox(height: 7),
              Container(height: 1, color: LedgerColors.hairline),
              const SizedBox(height: 7),
              Text(
                '预计收入 ${moneyText(period.income)} · 共 ${period.calculations.length} 段记录',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LedgerColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SectionHeader(title: '快捷操作'),
        LedgerInlineGroup(
          spacing: 6,
          children: [
            LedgerPill('查日历', selected: true, onTap: openCalendar),
            LedgerPill('看汇总', color: LedgerColors.muted, onTap: openSummary),
          ],
        ),
      ],
    );
  }
}

class _TodayOverviewCard extends StatelessWidget {
  const _TodayOverviewCard({
    required this.day,
    required this.entries,
    required this.summary,
    required this.rule,
    required this.onTap,
  });

  final DateTime day;
  final List<WorkEntry> entries;
  final LedgerSummary summary;
  final PayRule rule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final recordSummary = summarizeRecordEntries(entries);
    final extraPayrollOvertime = math.max(
      0.0,
      summary.overtimeHours - recordSummary.manualOvertimeHours,
    );
    final compact = useDenseTwoColumnLayout(
      context,
      widthBreakpoint: 340,
      textScaleBreakpoint: 1.28,
    );
    final workMetric = _TodayMetricBlock(
      label: '总工时',
      color: LedgerColors.primaryBlue,
      value: hoursText(summary.totalHours),
      detail: entries.isEmpty
          ? '今天还没有记录'
          : '${entries.length}段 · 净工时${entries.any((entry) => entry.hasNote) ? ' · 有备注' : ''}',
      alignment: CrossAxisAlignment.start,
    );
    final incomeMetric = _TodayMetricBlock(
      label: '预计收入',
      color: LedgerColors.successGreen,
      value: moneyText(summary.income),
      detail: _incomeExplanation(summary, rule),
      alignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
    );
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: LedgerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${day.month}月${day.day}日 · 周${_weekdayText(day.weekday)}',
              style: const TextStyle(
                color: LedgerColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (compact) ...[
              workMetric,
              const SizedBox(height: 10),
              Container(height: 1, color: LedgerColors.hairline),
              const SizedBox(height: 10),
              incomeMetric,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: workMetric),
                  Container(
                    width: 1,
                    height: 96,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: LedgerColors.hairlineStrong,
                  ),
                  Expanded(child: incomeMetric),
                ],
              ),
            const SizedBox(height: 7),
            LedgerInlineGroup(
              spacing: 6,
              children: [
                if (recordSummary.regularHours > 0)
                  LedgerPill('普通 ${hoursText(recordSummary.regularHours)}'),
                if (recordSummary.manualOvertimeHours > 0)
                  LedgerPill(
                    '加班 ${hoursText(recordSummary.manualOvertimeHours)}',
                    color: LedgerColors.successGreen,
                  ),
                if (recordSummary.nightDays > 0)
                  LedgerPill(
                    '夜班 ${recordSummary.nightDays}次',
                    color: LedgerColors.nightIndigo,
                  ),
                if (summary.allowance > 0)
                  LedgerPill(
                    '补贴 ${moneyText(summary.allowance)}',
                    color: LedgerColors.warningOrange,
                  ),
                LedgerPill('${entries.length}段', color: LedgerColors.muted),
              ],
            ),
            if (entries.isEmpty) ...[
              const SizedBox(height: 7),
              FilledButton.tonal(onPressed: onTap, child: const Text('补今天')),
            ] else if (extraPayrollOvertime > 0) ...[
              const SizedBox(height: 7),
              Text(
                '另有 ${hoursText(extraPayrollOvertime)} 按“计薪加班”结算。',
                style: const TextStyle(color: LedgerColors.muted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodayMetricBlock extends StatelessWidget {
  const _TodayMetricBlock({
    required this.label,
    required this.color,
    required this.value,
    required this.detail,
    required this.alignment,
  });

  final String label;
  final Color color;
  final String value;
  final String detail;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: alignment,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Row(
        mainAxisAlignment: alignment == CrossAxisAlignment.end
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          LedgerDot(color: color, size: 7),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: LedgerColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      FittedValueText(
        value,
        alignment: alignment == CrossAxisAlignment.end
            ? Alignment.centerRight
            : Alignment.centerLeft,
        textAlign: alignment == CrossAxisAlignment.end
            ? TextAlign.right
            : TextAlign.left,
        maxScale: 1.04,
        style: const TextStyle(
          color: LedgerColors.ink,
          fontSize: 34,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      const SizedBox(height: 3),
      Text(
        detail,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: alignment == CrossAxisAlignment.end
            ? TextAlign.right
            : TextAlign.left,
        style: const TextStyle(
          color: LedgerColors.muted,
          fontSize: 11.5,
          height: 1.3,
        ),
      ),
    ],
  );
}

class _PeriodMetrics extends StatelessWidget {
  const _PeriodMetrics({required this.summary});

  final LedgerSummary summary;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('总工时', hoursText(summary.totalHours), LedgerColors.primaryBlue),
      ('出勤', '${summary.attendanceDays}天', LedgerColors.primaryBlue),
      ('加班', hoursText(summary.overtimeHours), LedgerColors.successGreen),
      ('夜班', '${summary.nightShiftCount}次', LedgerColors.nightIndigo),
    ];
    if (useDenseTwoColumnLayout(context)) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final metric in metrics)
            SizedBox(
              width: (MediaQuery.sizeOf(context).width - 54) / 2,
              child: CompactMetric(
                label: metric.$1,
                value: metric.$2,
                color: metric.$3,
              ),
            ),
        ],
      );
    }
    return Row(
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          Expanded(
            child: _PeriodMetric(
              label: metrics[index].$1,
              value: metrics[index].$2,
              color: metrics[index].$3,
            ),
          ),
          if (index != metrics.length - 1)
            Container(
              width: 1,
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: LedgerColors.hairlineStrong,
            ),
        ],
      ],
    );
  }
}

class _PeriodMetric extends StatelessWidget {
  const _PeriodMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LedgerDot(color: color, size: 6),
          const SizedBox(width: 4),
          Flexible(
            child: FittedValueText(
              value,
              alignment: Alignment.center,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LedgerColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 3),
      Text(
        label,
        style: const TextStyle(
          color: LedgerColors.muted,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

double _periodProgress(DateRange range, DateTime now) {
  final elapsed = dateOnly(now).difference(range.start).inDays + 1;
  return (elapsed / range.dayCount).clamp(0, 1);
}

String _incomeExplanation(LedgerSummary summary, PayRule rule) {
  if (summary.calculations.isEmpty) {
    return '${rule.baseType.label} · ${rule.amountLabel}';
  }
  if (rule.baseType != PayBaseType.hourly) {
    return '${rule.baseType.label} · ${rule.amountLabel}';
  }
  final parts = <String>[];
  if (summary.baseIncome > 0) {
    parts.add('${hoursText(summary.regularHours)} × ${rule.amountLabel}');
  }
  if (summary.overtimeIncome > 0) {
    parts.add('加班 ${moneyText(summary.overtimeIncome)}');
  }
  if (summary.nightIncome > 0) {
    parts.add('夜班 ${moneyText(summary.nightIncome)}');
  }
  if (summary.allowance > 0) parts.add('补贴 ${moneyText(summary.allowance)}');
  if (summary.deduction > 0) parts.add('扣款 −${moneyText(summary.deduction)}');
  if (parts.isEmpty) return '${rule.baseType.label} · ${rule.amountLabel}';
  return '${parts.join(' + ')} = ${moneyText(summary.income)}';
}

String _weekdayText(int weekday) =>
    const ['一', '二', '三', '四', '五', '六', '日'][weekday - 1];
