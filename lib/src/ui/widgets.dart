import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'theme.dart';

String hoursText(double value) =>
    '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}h';
String moneyText(double value) =>
    '¥${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)}';

TextScaler cappedTextScaler(BuildContext context, {double maxScale = 1.35}) =>
    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: maxScale);

class FittedValueText extends StatelessWidget {
  const FittedValueText(
    this.text, {
    super.key,
    required this.style,
    this.alignment = Alignment.centerLeft,
    this.textAlign,
    this.maxScale = 1.12,
  });

  final String text;
  final TextStyle style;
  final Alignment alignment;
  final TextAlign? textAlign;
  final double maxScale;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(
        text,
        maxLines: 1,
        textAlign: textAlign,
        textScaler: cappedTextScaler(context, maxScale: maxScale),
        style: style,
      ),
    ),
  );
}

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sidePadding = constraints.maxWidth > ledgerContentMaxWidth
              ? (constraints.maxWidth - ledgerContentMaxWidth) / 2 + 16
              : 16.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(sidePadding, 18, sidePadding, 120),
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
          );
        },
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
        color: color ?? LedgerColors.surfaceRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: LedgerColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
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
          FittedValueText(
            value,
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
            FittedValueText(
              subtext!,
              maxScale: 1.08,
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
    final railColor = isNight
        ? LedgerColors.nightIndigo
        : isOvertime
        ? LedgerColors.successGreen
        : LedgerColors.primaryBlue;
    final chipColor = isNight
        ? LedgerColors.nightIndigoSoft
        : isOvertime
        ? LedgerColors.successGreenSoft
        : LedgerColors.primaryBlueSoft;
    final chipText = isNight ? LedgerColors.nightIndigo : LedgerColors.ink;
    return LedgerCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 44,
            margin: const EdgeInsets.only(top: 2, right: 10),
            decoration: BoxDecoration(
              color: railColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(entry.timeRangeLabel, style: _timeStyle(context)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: chipColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        entry.type.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: chipText,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: LedgerColors.surfaceSoft.withValues(alpha: .74),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        hoursText(entry.netHours),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: LedgerColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_metaText.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    _metaText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LedgerColors.muted,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                tooltip: '编辑',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
              if (onDelete != null)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(44, 32),
                    padding: EdgeInsets.zero,
                    foregroundColor: LedgerColors.errorBrick,
                  ),
                  onPressed: onDelete,
                  child: const Text('删除'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  TextStyle _timeStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!.copyWith(
        fontSize: 16,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  String get _metaText => [
    if (entry.locationName.isNotEmpty) entry.locationName,
    if (entry.jobTypeName.isNotEmpty) entry.jobTypeName,
    if (entry.breakMinutes > 0) '休 ${entry.breakMinutes} 分钟',
    if (entry.allowanceTotal > 0) '补贴 ${moneyText(entry.allowanceTotal)}',
    if (entry.deductionTotal > 0) '扣款 ${moneyText(entry.deductionTotal)}',
    if (entry.note.isNotEmpty) '备注：${entry.note}',
  ].join(' · ');
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

class SheetHeaderBlock extends StatelessWidget {
  const SheetHeaderBlock({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onClose,
    this.closeLabel = '关闭',
  });

  final String title;
  final String subtitle;
  final String closeLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
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
            TextButton(onPressed: onClose, child: Text(closeLabel)),
          ],
        ),
        Text(
          subtitle,
          style: const TextStyle(
            color: LedgerColors.muted,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.backgroundColor = LedgerColors.surfaceRaised,
    this.iconBackgroundColor = LedgerColors.primaryBlueSoft,
    this.iconColor = LedgerColors.primaryBlue,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color backgroundColor;
  final Color iconBackgroundColor;
  final Color iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      color: backgroundColor,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: LedgerColors.muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

Future<bool?> showLedgerConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
  String cancelText = '取消',
  bool destructive = false,
  IconData? icon,
}) {
  final resolvedIcon = icon ??
      (destructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded);
  return showDialog<bool>(
    context: context,
    builder: (context) => LedgerConfirmDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      destructive: destructive,
      icon: resolvedIcon,
    ),
  );
}

Future<void> showLedgerInfoDialog(
  BuildContext context, {
  required String title,
  required Widget content,
  String closeText = '关闭',
  IconData icon = Icons.info_outline_rounded,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => LedgerInfoDialog(
      title: title,
      content: content,
      closeText: closeText,
      icon: icon,
    ),
  );
}

class LedgerDialogShell extends StatelessWidget {
  const LedgerDialogShell({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    this.body,
    this.actions = const [],
    this.maxWidth = 460,
    this.maxHeightFactor = .82,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final Widget? body;
  final List<Widget> actions;
  final double maxWidth;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFactor;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: LedgerColors.paper,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: LedgerColors.hairline),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 32,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconBackgroundColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ),
                ],
              ),
              if (body != null) ...[
                const SizedBox(height: 12),
                Flexible(child: SingleChildScrollView(child: body!)),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: actions,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LedgerConfirmDialog extends StatelessWidget {
  const LedgerConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.icon,
    this.destructive = false,
  });

  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final IconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? LedgerColors.errorBrick : LedgerColors.primaryBlue;
    final accentSoft =
        destructive ? LedgerColors.warningOrangeSoft : LedgerColors.primaryBlueSoft;
    return LedgerDialogShell(
      title: title,
      icon: icon,
      iconColor: accent,
      iconBackgroundColor: accentSoft,
      maxWidth: 460,
      body: _ConfirmDialogBody(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: LedgerColors.errorBrick)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText),
        ),
      ],
    );
  }
}

class _ConfirmDialogBody extends StatelessWidget {
  const _ConfirmDialogBody(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(
        color: LedgerColors.muted,
        fontSize: 14,
        height: 1.45,
      ),
    );
  }
}

class LedgerInfoDialog extends StatelessWidget {
  const LedgerInfoDialog({
    super.key,
    required this.title,
    required this.content,
    required this.closeText,
    required this.icon,
  });

  final String title;
  final Widget content;
  final String closeText;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return LedgerDialogShell(
      title: title,
      icon: icon,
      iconColor: LedgerColors.primaryBlue,
      iconBackgroundColor: LedgerColors.primaryBlueSoft,
      maxWidth: 520,
      body: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(closeText),
        ),
      ],
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
    final hasAction = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: LedgerColors.muted),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Container(
                margin: const EdgeInsets.only(left: 10, top: 1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: LedgerColors.primaryBlueSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  trailing!,
                  style: const TextStyle(
                    color: LedgerColors.primaryBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            if (hasAction) ...[
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: LedgerColors.stone,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
