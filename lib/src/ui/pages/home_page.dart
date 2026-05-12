import 'package:flutter/material.dart';

import '../../app/ledger_state.dart';
import '../../domain/models.dart';
import '../edit_entry_sheet.dart';
import '../theme.dart';
import '../widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.state, required this.openCalendar, required this.openSummary});
  final LedgerState state;
  final VoidCallback openCalendar;
  final VoidCallback openSummary;

  @override
  Widget build(BuildContext context) {
    final todayEntries = state.entriesForDay(state.now);
    final todaySummary = state.summaryFor(DateRange.custom(state.now, state.now, label: '今日'));
    final period = state.summaryFor(state.currentPayPeriod);
    return PageFrame(
      title: '今日记录',
      trailing: IconButton(onPressed: () => showEditWorkEntrySheet(context, state), icon: const Icon(Icons.add_circle_outline), tooltip: '新增'),
      children: [
        MetricCard(
          label: '今日已记录',
          value: hoursText(todaySummary.totalHours),
          subtext: '${todayEntries.length}段 · 加班 ${hoursText(todaySummary.overtimeHours)} · ${todayEntries.any((e) => e.hasNote) ? '有备注' : '无备注'}',
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
                FilledButton(onPressed: () => showEditWorkEntrySheet(context, state), child: const Text('创建 09:00-18:00 记录')),
              ],
            ),
          )
        else
          for (final entry in todayEntries) ...[
            WorkEntryTile(entry: entry, onEdit: () => showEditWorkEntrySheet(context, state, day: entry.workDate)),
            const SizedBox(height: 10),
          ],
        SectionHeader(title: '本周期进度', actionLabel: '看汇总', onAction: openSummary),
        LedgerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${ymd(state.currentPayPeriod.start)} — ${ymd(state.currentPayPeriod.endInclusive)}', style: const TextStyle(color: LedgerColors.muted)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _MiniStat(label: '总工时', value: hoursText(period.totalHours)),
                  _MiniStat(label: '出勤', value: '${period.attendanceDays}天'),
                  _MiniStat(label: '加班', value: hoursText(period.overtimeHours)),
                  _MiniStat(label: '夜班', value: '${period.nightShiftCount}次'),
                ],
              ),
            ],
          ),
        ),
        const SectionHeader(title: '快捷操作'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ActionChip(label: const Text('查日历'), onPressed: openCalendar),
            ActionChip(label: const Text('套用模板'), onPressed: () => showEditWorkEntrySheet(context, state)),
            ActionChip(label: const Text('补一段'), onPressed: () => showEditWorkEntrySheet(context, state, day: state.now)),
            ActionChip(label: const Text('看某一天'), onPressed: openCalendar),
            ActionChip(label: const Text('导出 CSV'), onPressed: openSummary),
          ],
        ),
      ],
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
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: LedgerColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}
