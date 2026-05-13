import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'theme.dart';

String hoursText(double value) =>
    '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}h';
String moneyText(double value) =>
    '¥${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)}';

TextScaler cappedTextScaler(BuildContext context, {double maxScale = 1.35}) =>
    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: maxScale);

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    this.trailing,
    required this.children,
  });
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class LedgerCard extends StatelessWidget {
  const LedgerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? LedgerColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: LedgerColors.hairline),
      ),
      child: child,
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.subtext,
    this.onTap,
    this.compact = false,
  });
  final String label;
  final String value;
  final String? subtext;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = LedgerCard(
      padding: EdgeInsets.all(compact ? 12 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 24 : 34,
              fontWeight: FontWeight.w800,
              letterSpacing: compact ? -0.6 : -1.2,
              color: LedgerColors.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (subtext != null) ...[
            const SizedBox(height: 4),
            Text(
              subtext!,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: LedgerColors.muted),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: content,
    );
  }
}

class WorkEntryTile extends StatelessWidget {
  const WorkEntryTile({
    super.key,
    required this.entry,
    this.onEdit,
    this.onDelete,
  });
  final WorkEntry entry;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isNight = entry.type == EntryType.night;
    final isOvertime =
        entry.type == EntryType.overtime || entry.isRestDayOvertime;
    final chipColor = isNight
        ? LedgerColors.nightSlate
        : isOvertime
        ? LedgerColors.overtimeMossSoft
        : LedgerColors.workAmberSoft;
    final chipText = isNight ? Colors.white : LedgerColors.ink;
    return LedgerCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.timeRangeLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: chipColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        entry.type.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: chipText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (entry.locationName.isNotEmpty) entry.locationName,
                    '休 ${entry.breakMinutes} 分钟',
                    if (entry.allowanceTotal > 0)
                      '补贴 ${moneyText(entry.allowanceTotal)}',
                    if (entry.deductionTotal > 0)
                      '扣款 ${moneyText(entry.deductionTotal)}',
                    if (entry.note.isNotEmpty) '备注：${entry.note}',
                  ].join(' · '),
                  style: const TextStyle(color: LedgerColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hoursText(entry.netHours),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton(onPressed: onEdit, child: const Text('编辑')),
              if (onDelete != null)
                TextButton(onPressed: onDelete, child: const Text('删除本段')),
            ],
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class SettingTile extends StatelessWidget {
  const SettingTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: LedgerColors.muted),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(
                  color: LedgerColors.warningCopper,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
