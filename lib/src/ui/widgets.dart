import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'theme.dart';

const equalTimeRangeErrorText = '开始和结束时间不能相同。';

String hoursText(double value) =>
    '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}h';
String moneyText(double value) =>
    '¥${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)}';

TextScaler cappedTextScaler(BuildContext context, {double maxScale = 1.35}) =>
    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: maxScale);

bool useDenseTwoColumnLayout(
  BuildContext context, {
  double widthBreakpoint = 360,
  double textScaleBreakpoint = 1.35,
}) =>
    MediaQuery.of(context).size.width < widthBreakpoint ||
    MediaQuery.textScalerOf(context).scale(1) > textScaleBreakpoint;

void showLedgerSnackBar(
  BuildContext context,
  String message, {
  SnackBarAction? action,
  Duration? duration,
}) {
  if (action != null) {
    showLedgerSnackBarOn(
      ScaffoldMessenger.of(context),
      message,
      action: action,
      duration: duration,
    );
    return;
  }
  final overlay =
      Overlay.maybeOf(context, rootOverlay: true) ??
      Navigator.maybeOf(context, rootNavigator: true)?.overlay;
  if (overlay == null) {
    showLedgerSnackBarOn(
      ScaffoldMessenger.of(context),
      message,
      duration: duration,
    );
    return;
  }
  _showLedgerTopToast(overlay, message);
}

void showLedgerSnackBarOn(
  ScaffoldMessengerState messenger,
  String message, {
  SnackBarAction? action,
  Duration? duration,
}) {
  _hideLedgerTopToast();
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: action,
      duration: duration ?? const Duration(seconds: 4),
    ),
  );
}

OverlayEntry? _ledgerTopToastEntry;

void _showLedgerTopToast(OverlayState overlay, String message) {
  _hideLedgerTopToast();
  _ledgerTopToastEntry = OverlayEntry(
    builder: (context) =>
        _LedgerTopToast(message: message, onDone: _hideLedgerTopToast),
  );
  overlay.insert(_ledgerTopToastEntry!);
}

void _hideLedgerTopToast() {
  _ledgerTopToastEntry?.remove();
  _ledgerTopToastEntry = null;
}

class _LedgerTopToast extends StatefulWidget {
  const _LedgerTopToast({required this.message, required this.onDone});

  final String message;
  final VoidCallback onDone;

  @override
  State<_LedgerTopToast> createState() => _LedgerTopToastState();
}

class _LedgerTopToastState extends State<_LedgerTopToast> {
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _dismissTimer = Timer(const Duration(milliseconds: 2200), widget.onDone);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return IgnorePointer(
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, topInset > 0 ? 8 : 12, 16, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: LedgerColors.ink,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x220F172A),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.message,
                          textScaler: cappedTextScaler(context, maxScale: 1.15),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final fitted = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(
          text,
          maxLines: 1,
          textAlign: textAlign,
          textScaler: cappedTextScaler(context, maxScale: maxScale),
          style: style,
        ),
      );
      if (!constraints.maxWidth.isFinite) return fitted;
      return SizedBox(width: double.infinity, child: fitted);
    },
  );
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
    this.controller,
    required this.children,
  });
  final String title;
  final String? eyebrow;
  final Widget? trailing;
  final ScrollController? controller;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sidePadding = constraints.maxWidth > ledgerContentMaxWidth
              ? (constraints.maxWidth - ledgerContentMaxWidth) / 2 + 12
              : 12.0;
          return ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(sidePadding, 8, sidePadding, 92),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (eyebrow != null && eyebrow!.trim().isNotEmpty) ...[
                          Text(
                            eyebrow!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: LedgerColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 12),
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
    this.padding = const EdgeInsets.all(12),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LedgerColors.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class LedgerPill extends StatelessWidget {
  const LedgerPill(
    this.label, {
    super.key,
    this.color = LedgerColors.primaryBlue,
    this.background,
    this.onTap,
    this.dense = false,
    this.selected = false,
  });

  final String label;
  final Color color;
  final Color? background;
  final VoidCallback? onTap;
  final bool dense;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? color
        : background ??
              Color.alphaBlend(color.withValues(alpha: .10), Colors.white);
    final fg = selected ? Colors.white : color;
    final pill = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: BoxConstraints(
            minHeight: onTap == null ? (dense ? 25 : 26) : 44,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 8 : 9,
            vertical: dense ? 4 : 5,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: .22),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler: cappedTextScaler(context, maxScale: 1.08),
            style: TextStyle(
              color: fg,
              fontSize: dense ? 11 : 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
    return onTap == null
        ? pill
        : Semantics(
            button: true,
            selected: selected,
            label: label,
            child: pill,
          );
  }
}

class CompactMetric extends StatelessWidget {
  const CompactMetric({
    super.key,
    required this.label,
    required this.value,
    this.color = LedgerColors.primaryBlue,
    this.flexValue = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool flexValue;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 44),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
    decoration: BoxDecoration(
      color: LedgerColors.surfaceSoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: LedgerColors.hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            LedgerDot(color: color, size: 6),
            const SizedBox(width: 4),
            Expanded(
              child: FittedValueText(
                value,
                maxScale: 1.04,
                style: TextStyle(
                  color: LedgerColors.ink,
                  fontSize: flexValue ? 16 : 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: LedgerColors.muted,
            fontSize: 9.5,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class LedgerDot extends StatelessWidget {
  const LedgerDot({super.key, required this.color, this.size = 6});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 38,
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
        fontSize: 15,
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
    final titleStyle = Theme.of(context).textTheme.titleMedium!.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w800,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(1, 11, 1, 7),
      child: Row(
        children: [
          Expanded(child: Text(title, style: titleStyle)),
          if (actionLabel != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    color: LedgerColors.primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SheetHeaderBlock extends StatelessWidget {
  const SheetHeaderBlock({
    super.key,
    required this.title,
    this.subtitle,
    required this.onClose,
    this.closeLabel = '关闭',
  });

  final String title;
  final String? subtitle;
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
        if (subtitle != null && subtitle!.trim().isNotEmpty)
          Text(
            subtitle!,
            style: const TextStyle(
              color: LedgerColors.muted,
              fontSize: 12,
              height: 1.25,
            ),
          ),
      ],
    );
  }
}

class EntryTypeSegmentedField extends StatelessWidget {
  const EntryTypeSegmentedField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = '类型',
    this.helperText,
  });

  final EntryType value;
  final ValueChanged<EntryType> onChanged;
  final String label;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: const TextStyle(
              color: LedgerColors.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<EntryType>(
            showSelectedIcon: false,
            selected: {value},
            segments: EntryType.values
                .map(
                  (type) => ButtonSegment<EntryType>(
                    value: type,
                    label: Text(type.label),
                  ),
                )
                .toList(),
            onSelectionChanged: (values) => onChanged(values.first),
          ),
        ),
      ],
    );
  }
}

class LedgerPickerButtonField extends StatelessWidget {
  const LedgerPickerButtonField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon = Icons.tune_rounded,
    this.helperText,
    this.enabled = true,
  });

  final String label;
  final String value;
  final String? helperText;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final muted = enabled ? LedgerColors.muted : LedgerColors.stone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: TextStyle(color: muted, fontSize: 12, height: 1.35),
          ),
        ],
        const SizedBox(height: 5),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: enabled ? onTap : null,
            child: Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: enabled ? LedgerColors.ink : LedgerColors.stone,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
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
    this.body,
    this.backgroundColor = LedgerColors.surfaceRaised,
    this.iconBackgroundColor = LedgerColors.primaryBlueSoft,
    this.iconColor = LedgerColors.primaryBlue,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Color backgroundColor;
  final Color iconBackgroundColor;
  final Color iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      color: backgroundColor,
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBackgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (body != null && body!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    body!,
                    style: const TextStyle(
                      color: LedgerColors.muted,
                      fontSize: 12,
                      height: 1.28,
                    ),
                  ),
                ],
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
  final resolvedIcon =
      icon ??
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: LedgerColors.paper,
            borderRadius: BorderRadius.circular(22),
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: iconBackgroundColor,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
              if (body != null) ...[
                const SizedBox(height: 9),
                Flexible(child: SingleChildScrollView(child: body!)),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 10),
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
    final accent = destructive
        ? LedgerColors.errorBrick
        : LedgerColors.primaryBlue;
    final accentSoft = destructive
        ? LedgerColors.warningOrangeSoft
        : LedgerColors.primaryBlueSoft;
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
        fontSize: 13,
        height: 1.35,
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
    this.subtitle,
    this.trailing,
    this.onTap,
    this.icon,
    this.iconLabel,
    this.iconColor,
    this.iconBackgroundColor,
  });
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? iconLabel;
  final Color? iconColor;
  final Color? iconBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final hasAction = onTap != null;
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    final showChevron = hasAction && trailing == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: hasSubtitle
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (icon != null || iconLabel != null) ...[
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBackgroundColor ?? LedgerColors.primaryBlueSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: icon != null
                    ? Icon(
                        icon,
                        size: 15,
                        color: iconColor ?? LedgerColors.primaryBlue,
                      )
                    : Text(
                        iconLabel!,
                        style: TextStyle(
                          color: iconColor ?? LedgerColors.primaryBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              const SizedBox(width: 9),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (hasSubtitle) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LedgerColors.muted,
                        fontSize: 11.3,
                        height: 1.25,
                      ),
                    ),
                  ],
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
                decoration: const BoxDecoration(),
                child: Text(
                  hasAction ? '$trailing ›' : trailing!,
                  style: const TextStyle(
                    color: LedgerColors.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ),
            if (showChevron) ...[
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
