import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'theme.dart';

Future<DateTime?> showLedgerDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? minimumDate,
  DateTime? maximumDate,
}) async {
  var selected = dateOnly(initialDate);
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: LedgerColors.paper,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => _PickerSheet(
        title: '选择日期',
        helper: '当前选择：${cnDateText(selected)}',
        onConfirm: () => Navigator.pop(context, selected),
        child: SizedBox(
          height: 216,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            dateOrder: DatePickerDateOrder.ymd,
            initialDateTime: selected,
            minimumDate: minimumDate ?? DateTime(2000),
            maximumDate: maximumDate ?? DateTime(2100),
            onDateTimeChanged: (value) =>
                setSheetState(() => selected = dateOnly(value)),
          ),
        ),
      ),
    ),
  );
}

Future<int?> showLedgerTimePicker(
  BuildContext context, {
  required int initialMinute,
}) async {
  var selected = DateTime(2026, 1, 1, initialMinute ~/ 60, initialMinute % 60);
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: LedgerColors.paper,
    builder: (context) => _PickerSheet(
      title: '选择时间',
      onConfirm: () =>
          Navigator.pop(context, selected.hour * 60 + selected.minute),
      child: SizedBox(
        height: 216,
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          use24hFormat: true,
          minuteInterval: 5,
          initialDateTime: selected,
          onDateTimeChanged: (value) => selected = value,
        ),
      ),
    ),
  );
}

Future<int?> showLedgerMonthDayPicker(
  BuildContext context, {
  required int initialDay,
}) async {
  var selected = initialDay.clamp(1, 31);
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: LedgerColors.paper,
    builder: (context) => _PickerSheet(
      title: '每月起始日',
      helper: '29、30、31 遇到短月时自动按当月最后一天计算。',
      onConfirm: () => Navigator.pop(context, selected),
      child: SizedBox(
        height: 216,
        child: CupertinoPicker(
          scrollController: FixedExtentScrollController(
            initialItem: selected - 1,
          ),
          itemExtent: 44,
          onSelectedItemChanged: (index) => selected = index + 1,
          children: [
            for (var day = 1; day <= 31; day++) Center(child: Text('$day 日')),
          ],
        ),
      ),
    ),
  );
}

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.child,
    required this.onConfirm,
    this.helper,
  });

  final String title;
  final String? helper;
  final Widget child;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                  child: const Text('取消'),
                ),
                FilledButton(onPressed: onConfirm, child: const Text('完成')),
              ],
            ),
            if (helper != null) ...[
              const SizedBox(height: 4),
              Text(helper!, style: const TextStyle(color: LedgerColors.muted)),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
