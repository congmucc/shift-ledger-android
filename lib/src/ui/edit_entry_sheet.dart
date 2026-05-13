import 'package:flutter/material.dart';

import '../app/ledger_state.dart';
import '../domain/models.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showEditWorkEntrySheet(
  BuildContext context,
  LedgerState state, {
  DateTime? day,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: LedgerColors.paper,
    builder: (context) => EditWorkEntrySheet(state: state, day: day),
  );
}

class EditWorkEntrySheet extends StatefulWidget {
  const EditWorkEntrySheet({super.key, required this.state, this.day});
  final LedgerState state;
  final DateTime? day;

  @override
  State<EditWorkEntrySheet> createState() => _EditWorkEntrySheetState();
}

class _EditWorkEntrySheetState extends State<EditWorkEntrySheet> {
  late DateTime _day;
  late DateTime _originalDay;
  late List<WorkEntry> _segments;

  @override
  void initState() {
    super.initState();
    _day = dateOnly(widget.day ?? widget.state.now);
    _originalDay = _day;
    final existing = widget.state.entriesForDay(_day);
    _segments = existing.isNotEmpty
        ? [...existing]
        : [widget.state.createTemplateEntry(day: _day)];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '新增 / 编辑工时记录',
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
              LedgerCard(
                color: LedgerColors.surfaceRaised,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('日期', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ymd(_day),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _moveDay(-1),
                          child: const Text('昨天'),
                        ),
                        TextButton(
                          onPressed: () => _moveDay(1),
                          child: const Text('明天'),
                        ),
                        IconButton(
                          tooltip: '选择日期',
                          onPressed: _pickDay,
                          icon: const Icon(Icons.calendar_month_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('计薪', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.state.defaultRule.name} · ${widget.state.defaultRule.baseType.label} ${widget.state.defaultRule.amountLabel}',
                      style: const TextStyle(color: LedgerColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final entry in _segments) ...[
                WorkEntryTile(
                  entry: entry,
                  onEdit: () => _editSegment(entry),
                  onDelete: _segments.length == 1
                      ? null
                      : () => _confirmDeleteSegment(entry),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addSegment,
                      icon: const Icon(Icons.add),
                      label: const Text('新增分段'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LedgerColors.errorBrick,
                      ),
                      onPressed: _confirmDeleteDay,
                      child: const Text('删除当天记录'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _moveDay(int offset) {
    _setDay(_day.add(Duration(days: offset)));
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    _setDay(picked);
  }

  void _setDay(DateTime day) {
    final nextDay = dateOnly(day);
    setState(() {
      _day = nextDay;
      _segments = _segments
          .map((entry) => _moveEntryToDay(entry, nextDay))
          .toList();
    });
  }

  WorkEntry _moveEntryToDay(WorkEntry entry, DateTime day) {
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      entry.startDateTime.hour,
      entry.startDateTime.minute,
    );
    var end = DateTime(
      day.year,
      day.month,
      day.day,
      entry.endDateTime.hour,
      entry.endDateTime.minute,
    );
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    return entry.copyWith(
      workDate: dateOnly(day),
      startDateTime: start,
      endDateTime: end,
    );
  }

  void _addSegment() {
    final template = widget.state.templates.firstWhere(
      (tpl) => tpl.type == EntryType.overtime,
      orElse: () => widget.state.templates.first,
    );
    setState(() {
      _segments = [
        ..._segments,
        widget.state.createTemplateEntry(day: _day, template: template),
      ];
    });
  }

  Future<void> _editSegment(WorkEntry entry) async {
    final updated = await showDialog<WorkEntry>(
      context: context,
      builder: (context) =>
          SegmentEditorDialog(entry: entry, rules: widget.state.payRules),
    );
    if (updated == null) return;
    setState(() {
      final index = _segments.indexWhere((item) => item.id == entry.id);
      if (index >= 0) _segments[index] = updated;
    });
  }

  Future<void> _confirmDeleteSegment(WorkEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除本段？'),
        content: Text('只删除 ${entry.timeRangeLabel} 这一段，其他分段和当天备注保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: LedgerColors.errorBrick,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _segments.removeWhere((item) => item.id == entry.id));
  }

  Future<void> _confirmDeleteDay() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除当天记录？'),
        content: const Text('删除后，这一天的所有分段、备注、补贴和扣款都会从汇总与 CSV 中移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: LedgerColors.errorBrick,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.state.deleteDay(_day);
    Navigator.pop(context);
  }

  Future<void> _save() async {
    if (_hasOverlaps()) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('时间有重叠，仍然保存？'),
          content: const Text('同一天存在重叠分段。个人账本允许特殊情况，但建议先核对开始/结束时间。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('返回修改'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('仍然保存'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    widget.state.replaceDayEntries(_originalDay, _day, _segments);
    Navigator.pop(context);
  }

  bool _hasOverlaps() {
    final sorted = [..._segments]
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i - 1].endDateTime.isAfter(sorted[i].startDateTime)) {
        return true;
      }
    }
    return false;
  }
}

class SegmentEditorDialog extends StatefulWidget {
  const SegmentEditorDialog({
    super.key,
    required this.entry,
    required this.rules,
  });
  final WorkEntry entry;
  final List<PayRule> rules;

  @override
  State<SegmentEditorDialog> createState() => _SegmentEditorDialogState();
}

class _SegmentEditorDialogState extends State<SegmentEditorDialog> {
  late final TextEditingController _start;
  late final TextEditingController _end;
  late final TextEditingController _break;
  late final TextEditingController _location;
  late final TextEditingController _note;
  late final TextEditingController _allowance;
  late final TextEditingController _deduction;
  late EntryType _type;
  late PayRule _rule;

  @override
  void initState() {
    super.initState();
    _start = TextEditingController(text: hm(widget.entry.startDateTime));
    _end = TextEditingController(text: hm(widget.entry.endDateTime));
    _break = TextEditingController(text: widget.entry.breakMinutes.toString());
    _location = TextEditingController(text: widget.entry.locationName);
    _note = TextEditingController(text: widget.entry.note);
    _allowance = TextEditingController(
      text: widget.entry.allowanceTotal.toStringAsFixed(0),
    );
    _deduction = TextEditingController(
      text: widget.entry.deductionTotal.toStringAsFixed(0),
    );
    _type = widget.entry.type;
    _rule = widget.rules.firstWhere(
      (rule) => rule.id == widget.entry.payRuleId,
      orElse: () => widget.entry.payRuleSnapshot,
    );
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _break.dispose();
    _location.dispose();
    _note.dispose();
    _allowance.dispose();
    _deduction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑本段'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _start,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      labelText: '开始 HH:mm',
                      suffixIcon: IconButton(
                        tooltip: '选择开始时间',
                        onPressed: () => _pickTime(_start),
                        icon: const Icon(Icons.schedule_outlined),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _end,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      labelText: '结束 HH:mm',
                      suffixIcon: IconButton(
                        tooltip: '选择结束时间',
                        onPressed: () => _pickTime(_end),
                        icon: const Icon(Icons.schedule_outlined),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _break,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '休息分钟'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<EntryType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: '类型'),
              items: EntryType.values
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<PayRule>(
              initialValue: _rule,
              decoration: const InputDecoration(labelText: '计薪规则'),
              items: widget.rules
                  .map(
                    (rule) => DropdownMenuItem(
                      value: rule,
                      child: Text('${rule.name} · ${rule.amountLabel}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _rule = value ?? _rule),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _location,
              decoration: const InputDecoration(labelText: '地点/岗位'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _allowance,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '补贴'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _deduction,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '扣款'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: '备注'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存本段')),
      ],
    );
  }

  void _save() {
    final startParts =
        _parseTime(_start.text) ??
        [widget.entry.startDateTime.hour, widget.entry.startDateTime.minute];
    final endParts =
        _parseTime(_end.text) ??
        [widget.entry.endDateTime.hour, widget.entry.endDateTime.minute];
    final day = widget.entry.workDate;
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      startParts[0],
      startParts[1],
    );
    var end = DateTime(day.year, day.month, day.day, endParts[0], endParts[1]);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    final adjustments = <Adjustment>[];
    final allowance = double.tryParse(_allowance.text) ?? 0;
    final deduction = double.tryParse(_deduction.text) ?? 0;
    if (allowance > 0) adjustments.add(Adjustment.allowance('手动补贴', allowance));
    if (deduction > 0) adjustments.add(Adjustment.deduction('手动扣款', deduction));
    Navigator.pop(
      context,
      widget.entry.copyWith(
        startDateTime: start,
        endDateTime: end,
        breakMinutes: int.tryParse(_break.text) ?? widget.entry.breakMinutes,
        type: _type,
        locationName: _location.text,
        note: _note.text,
        adjustments: adjustments,
        payRuleId: _rule.id,
        payRuleSnapshot: _rule,
      ),
    );
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final current = _parseTime(controller.text);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current?[0] ?? widget.entry.startDateTime.hour,
        minute: current?[1] ?? widget.entry.startDateTime.minute,
      ),
    );
    if (picked == null) return;
    controller.text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  }

  List<int>? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return [hour, minute];
  }
}
