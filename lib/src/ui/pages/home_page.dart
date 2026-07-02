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
              Text(
                '${ymd(state.currentPayPeriod.start)} — ${ymd(state.currentPayPeriod.endInclusive)}',
                style: const TextStyle(
                  color: LedgerColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: CompactMetric(
                      label: '总工时',
                      value: hoursText(period.totalHours),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: CompactMetric(
                      label: '出勤',
                      value: '${period.attendanceDays}天',
                      color: LedgerColors.hairlineStrong,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: CompactMetric(
                      label: '加班',
                      value: hoursText(period.overtimeHours),
                      color: LedgerColors.successGreen,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: CompactMetric(
                      label: '夜班',
                      value: '${period.nightShiftCount}次',
                      color: LedgerColors.nightIndigo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                '出勤 ${period.attendanceDays}天 · 加班 ${hoursText(period.overtimeHours)} · 夜班 ${period.nightShiftCount}次',
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
            LedgerPill(
              '补今天',
              selected: true,
              onTap: () =>
                  showEditWorkEntrySheet(context, state, day: state.now),
            ),
            LedgerPill('查日历', color: LedgerColors.muted, onTap: openCalendar),
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
    required this.onTap,
  });

  final DateTime day;
  final List<WorkEntry> entries;
  final LedgerSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final recordSummary = summarizeRecordEntries(entries);
    final extraPayrollOvertime = math.max(
      0.0,
      summary.overtimeHours - recordSummary.manualOvertimeHours,
    );
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: LedgerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
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
                      const SizedBox(height: 3),
                      FittedValueText(
                        hoursText(summary.totalHours),
                        style: const TextStyle(
                          color: LedgerColors.ink,
                          fontSize: 37,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                        maxScale: 1.04,
                      ),
                      Text(
                        entries.isEmpty
                            ? '今天还没有记录'
                            : '${entries.length}段 · 净工时${entries.any((entry) => entry.hasNote) ? ' · 有备注' : ''}',
                        style: const TextStyle(
                          color: LedgerColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedValueText(
                      moneyText(summary.income),
                      alignment: Alignment.centerRight,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: LedgerColors.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '预计收入',
                      style: TextStyle(color: LedgerColors.muted, fontSize: 12),
                    ),
                  ],
                ),
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

String _weekdayText(int weekday) =>
    const ['一', '二', '三', '四', '五', '六', '日'][weekday - 1];
