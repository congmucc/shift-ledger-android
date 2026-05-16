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
      title: '今日记录',
      children: [
        _TodayOverviewCard(
          entries: todayEntries,
          summary: todaySummary,
          onTap: () => showEditWorkEntrySheet(context, state, day: state.now),
        ),
        const SectionHeader(title: '今天分段'),
        if (todayEntries.isEmpty)
          LedgerCard(
            color: LedgerColors.surfaceRaised,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('今天还没有记录。'),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => showEditWorkEntrySheet(context, state),
                  child: const Text('补今天'),
                ),
                const SizedBox(height: 6),
                const Text(
                  '会先带出默认 09:00-18:00，并预设 60 分钟休息；保存前都可以改。',
                  style: TextStyle(color: LedgerColors.muted),
                ),
              ],
            ),
          )
        else
          for (final entry in todayEntries) ...[
            WorkEntryTile(
              entry: entry,
              onEdit: () =>
                  showEditWorkEntrySheet(context, state, day: entry.workDate),
            ),
            const SizedBox(height: 10),
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
                style: const TextStyle(color: LedgerColors.muted),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _MiniStat(label: '总工时', value: hoursText(period.totalHours)),
                  _MiniStat(label: '出勤', value: '${period.attendanceDays}天'),
                  _MiniStat(
                    label: '计薪加班',
                    value: hoursText(period.overtimeHours),
                  ),
                  _MiniStat(label: '夜班', value: '${period.nightShiftCount}次'),
                ],
              ),
            ],
          ),
        ),
        SectionHeader(
          title: '快捷操作',
          actionLabel: '更多',
          onAction: () => _showMoreActions(context),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ActionChip(label: const Text('查日历'), onPressed: openCalendar),
            ActionChip(
              label: const Text('补今天'),
              onPressed: () =>
                  showEditWorkEntrySheet(context, state, day: state.now),
            ),
            ActionChip(label: const Text('看汇总'), onPressed: openSummary),
          ],
        ),
      ],
    );
  }

  void _showMoreActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: LedgerColors.paper,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('更多操作', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text(
                '低频入口不放在首页主按钮里，避免打断今天记录。',
                style: TextStyle(color: LedgerColors.muted),
              ),
              const SizedBox(height: 12),
              LedgerCard(
                color: LedgerColors.surfaceRaised,
                child: Column(
                  children: [
                    SettingTile(
                      title: '补其他日期',
                      subtitle: '去日历选择日期后补一段',
                      trailing: '日历',
                      onTap: () {
                        Navigator.pop(context);
                        openCalendar();
                      },
                    ),
                    SettingTile(
                      title: '导出 CSV',
                      subtitle: '去汇总页导出当前统计明细',
                      trailing: '汇总',
                      onTap: () {
                        Navigator.pop(context);
                        openSummary();
                      },
                    ),
                    SettingTile(
                      title: '模板、备份和规则',
                      subtitle: '去设置管理班次模板、计薪规则和备份',
                      trailing: '设置',
                      onTap: () {
                        Navigator.pop(context);
                        openSettings();
                      },
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

class _TodayOverviewCard extends StatelessWidget {
  const _TodayOverviewCard({
    required this.entries,
    required this.summary,
    required this.onTap,
  });

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
    final chips = <_SummaryChipData>[
      if (recordSummary.regularHours > 0)
        _SummaryChipData(
          label: '普通 ${hoursText(recordSummary.regularHours)}',
          background: LedgerColors.primaryBlueSoft,
          foreground: const Color(0xFF1D4ED8),
          border: const Color(0xFFBFDBFE),
        ),
      if (recordSummary.manualOvertimeHours > 0)
        _SummaryChipData(
          label: '加班段 ${hoursText(recordSummary.manualOvertimeHours)}',
          background: LedgerColors.successGreenSoft,
          foreground: const Color(0xFF166534),
          border: const Color(0xFFBBF7D0),
        ),
      if (recordSummary.nightDays > 0)
        _SummaryChipData(
          label: '夜班 ${recordSummary.nightDays}次',
          background: LedgerColors.nightIndigoSoft,
          foreground: LedgerColors.nightIndigo,
          border: const Color(0xFFDDD6FE),
        ),
      if (summary.allowance > 0)
        _SummaryChipData(
          label: '补贴 ${moneyText(summary.allowance)}',
          background: LedgerColors.successGreenSoft,
          foreground: const Color(0xFF166534),
          border: const Color(0xFFBBF7D0),
        ),
      if (summary.deduction > 0)
        _SummaryChipData(
          label: '扣款 ${moneyText(summary.deduction)}',
          background: LedgerColors.warningOrangeSoft,
          foreground: const Color(0xFF9A3412),
          border: const Color(0xFFFED7AA),
        ),
      _SummaryChipData(
        label: '${entries.length}段',
        background: LedgerColors.surfaceSoft,
        foreground: LedgerColors.muted,
        border: LedgerColors.hairline,
      ),
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: LedgerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '今日已记录',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                if (entries.isNotEmpty)
                  const _SummaryChip(
                    data: _SummaryChipData(
                      label: '已完成',
                      background: LedgerColors.successGreenSoft,
                      foreground: Color(0xFF166534),
                      border: Color(0xFFBBF7D0),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            FittedValueText(
              hoursText(summary.totalHours),
              style: const TextStyle(
                color: LedgerColors.ink,
                fontSize: 52,
                fontWeight: FontWeight.w900,
                letterSpacing: -2.4,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              maxScale: 1.04,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [for (final chip in chips) _SummaryChip(data: chip)],
            ),
            if (extraPayrollOvertime > 0) ...[
              const SizedBox(height: 10),
              Text(
                '工资估算里另有 ${hoursText(extraPayrollOvertime)} 会按“计薪加班”计算，但记录类型仍保持普通班次。',
                style: const TextStyle(
                  color: LedgerColors.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryChipData {
  const _SummaryChipData({
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color border;
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.data});

  final _SummaryChipData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: data.background,
        border: Border.all(color: data.border),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        data.label,
        style: TextStyle(
          color: data.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedValueText(
            value,
            style: Theme.of(context).textTheme.titleMedium!,
            maxScale: 1.08,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: LedgerColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
