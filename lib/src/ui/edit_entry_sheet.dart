import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/ledger_state.dart';
import '../domain/models.dart';
import 'pickers.dart';
import 'record_ui_summary.dart';
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
  late List<WorkEntry> _segments;
  late List<WorkEntry> _loadedSegments;
  late bool _openedWithExistingDay;
  bool _showDangerActions = false;

  @override
  void initState() {
    super.initState();
    _loadDay(dateOnly(widget.day ?? widget.state.now));
  }

  @override
  Widget build(BuildContext context) {
    final compactActions = useDenseTwoColumnLayout(context);
    final summaryRule = widget.state.ruleForDate(
      _day,
      preferredRuleId: _segments.isEmpty ? null : _segments.first.payRuleId,
    );
    final dayRecordSummary = summarizeRecordEntries(_segments);
    final deleteTargetDay = _day;
    final canDeleteDay =
        widget.state.entriesForDay(deleteTargetDay).isNotEmpty;
    final deleteTargetEntries = widget.state.entriesForDay(deleteTargetDay);
    final deleteTargetSummary = widget.state.summaryFor(
      DateRange.custom(deleteTargetDay, deleteTargetDay),
    );
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
              if (_openedWithExistingDay) ...[
                Text(
                  '保存会覆盖当天记录。',
                  style: TextStyle(
                    color: LedgerColors.muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
              ] else
                const SizedBox(height: 12),
              LedgerCard(
                color: LedgerColors.surfaceRaised,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '日期',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        _MetaChip(
                          label: '${dayRecordSummary.segmentCount}段',
                          background: LedgerColors.surfaceSoft,
                          foreground: LedgerColors.muted,
                        ),
                        const SizedBox(width: 6),
                        _MetaChip(
                          label: '合计 ${hoursText(dayRecordSummary.totalHours)}',
                          background: LedgerColors.primaryBlueSoft,
                          foreground: LedgerColors.primaryBlue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text(
                          ymd(_day),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        OutlinedButton(
                          onPressed: () => _moveDay(-1),
                          child: const Text('昨天'),
                        ),
                        OutlinedButton(
                          onPressed: () => _moveDay(1),
                          child: const Text('明天'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickDay,
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: const Text('选择日期'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('计薪', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${summaryRule.name} · ${summaryRule.baseType.label} ${summaryRule.amountLabel}',
                      style: const TextStyle(color: LedgerColors.muted),
                    ),
                    if (summaryRule.overtimeThresholdHours > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        '超过 ${hoursText(summaryRule.overtimeThresholdHours)} 后会按计薪规则拆分，但不会自动把普通班次显示成“加班段”。',
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '当天分段',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (dayRecordSummary.manualOvertimeHours > 0)
                    _MetaChip(
                      label:
                          '加班段 ${hoursText(dayRecordSummary.manualOvertimeHours)}',
                      background: LedgerColors.successGreenSoft,
                      foreground: LedgerColors.successGreen,
                    ),
                  if (dayRecordSummary.nightHours > 0) ...[
                    const SizedBox(width: 6),
                    _MetaChip(
                      label: '夜班 ${hoursText(dayRecordSummary.nightHours)}',
                      background: LedgerColors.nightIndigoSoft,
                      foreground: LedgerColors.nightIndigo,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              for (final entry in _segments) ...[
                WorkEntryTile(
                  entry: entry,
                  onEdit: () => _editSegment(entry),
                  onDelete: () => _confirmDeleteSegment(entry),
                ),
                const SizedBox(height: 10),
              ],
              if (_segments.isEmpty) ...[
                LedgerCard(
                  color: LedgerColors.surfaceRaised,
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    _openedWithExistingDay
                        ? '当前没有分段了。点击保存后不会新增记录，也可以继续新增分段。'
                        : '这一天还没有分段。先点“新增分段”再保存；如果只是查看，直接关闭即可。',
                    style: TextStyle(
                      color: LedgerColors.muted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              LedgerCard(
                color: LedgerColors.surfaceRaised,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('操作', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    _buildActionButtons(
                      compact: compactActions,
                      primary: FilledButton(
                        onPressed: _save,
                        child: const Text('保存'),
                      ),
                      secondary: OutlinedButton.icon(
                        onPressed: _addSegment,
                        icon: const Icon(Icons.add),
                        label: const Text('新增分段'),
                      ),
                    ),
                  ],
                ),
              ),
              if (canDeleteDay) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: LedgerColors.errorBrick,
                      side: const BorderSide(color: LedgerColors.errorRed),
                    ),
                    onPressed: () => setState(
                      () => _showDangerActions = !_showDangerActions,
                    ),
                    icon: Icon(
                      _showDangerActions
                          ? Icons.expand_less
                          : Icons.warning_amber_outlined,
                    ),
                    label: Text(_showDangerActions ? '收起危险操作' : '危险操作'),
                  ),
                ),
                if (_showDangerActions) ...[
                  const SizedBox(height: 6),
                  LedgerCard(
                    color: LedgerColors.surfaceRaised,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: LedgerColors.warningOrangeSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.delete_sweep_outlined,
                                color: LedgerColors.errorBrick,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                '只删除打开编辑时的原日期。改到其他日期后，请先保存或关闭，再回到目标日期删除。',
                                style: TextStyle(
                                  color: LedgerColors.muted,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: LedgerColors.errorBrick,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _confirmDeleteDay,
                            icon: const Icon(Icons.delete_outline),
                            label: Text(
                              '删除 ${ymd(deleteTargetDay)} 全部记录'
                              '（${deleteTargetEntries.length}段 · ${hoursText(deleteTargetSummary.totalHours)}）',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons({
    required bool compact,
    required Widget primary,
    required Widget secondary,
  }) {
    if (compact) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: double.infinity, child: primary),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: secondary),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: secondary),
        const SizedBox(width: 10),
        Expanded(child: primary),
      ],
    );
  }

  Future<void> _moveDay(int offset) =>
      _switchDay(_day.add(Duration(days: offset)));

  Future<void> _pickDay() async {
    final picked = await showLedgerDatePicker(context, initialDate: _day);
    if (picked == null || !mounted) return;
    await _switchDay(picked);
  }

  Future<void> _switchDay(DateTime day) async {
    final nextDay = dateOnly(day);
    if (ymd(nextDay) == ymd(_day)) return;
    if (_hasUnsavedChanges()) {
      final confirmed = await showLedgerConfirmDialog(
        context,
        title: '切换日期并放弃当前修改？',
        message: '当前还没保存。切到 ${ymd(nextDay)} 后，会重新加载那一天的已保存分段。',
        confirmText: '切换日期',
        cancelText: '继续编辑',
        icon: Icons.calendar_month_outlined,
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _showDangerActions = false;
      _loadDay(nextDay);
    });
  }

  void _loadDay(DateTime day) {
    final existing = widget.state.entriesForDay(day);
    _day = day;
    _openedWithExistingDay = existing.isNotEmpty;
    _loadedSegments = [...existing];
    _segments = [...existing];
  }

  bool _hasUnsavedChanges() =>
      _entriesSignature(_segments) != _entriesSignature(_loadedSegments);

  String _entriesSignature(List<WorkEntry> entries) =>
      jsonEncode(entries.map((entry) => entry.toJson()).toList());

  void _addSegment() {
    final template = _segments.isEmpty
        ? widget.state.templates.first
        : widget.state.templates.firstWhere(
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
    if (updated == null || !mounted) return;
    setState(() {
      final index = _segments.indexWhere((item) => item.id == entry.id);
      if (index >= 0) _segments[index] = updated;
    });
  }

  Future<void> _confirmDeleteSegment(WorkEntry entry) async {
    if (_segments.length == 1) {
      final targetDayLabel = ymd(_day);
      final confirmed = await showLedgerConfirmDialog(
        context,
        title: '删除最后一段？',
        message: _openedWithExistingDay
            ? '这一天只剩 ${entry.timeRangeLabel} 这一段。删除后，保存时会清空 $targetDayLabel 的全部记录。'
            : '当前只剩 ${entry.timeRangeLabel} 这一段。删除后，保存时不会在 $targetDayLabel 新增任何分段。',
        confirmText: '确认删除',
        destructive: true,
        icon: Icons.delete_outline,
      );
      if (confirmed != true || !mounted) return;
      setState(() {
        _showDangerActions = false;
        _segments.removeWhere((item) => item.id == entry.id);
      });
      return;
    }
    final confirmed = await showLedgerConfirmDialog(
      context,
      title: '删除本段？',
      message: '只删除 ${entry.timeRangeLabel} 这一段，其他分段和当天备注保留。',
      confirmText: '确认删除',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _segments.removeWhere((item) => item.id == entry.id));
  }

  Future<void> _confirmDeleteDay() async {
    final targetDay = _day;
    final entries = widget.state.entriesForDay(targetDay);
    final summary = widget.state.summaryFor(
      DateRange.custom(targetDay, targetDay),
    );
    final confirmed = await showLedgerConfirmDialog(
      context,
      title: '删除 ${ymd(targetDay)} 全部记录？',
      message:
          '将删除 ${entries.length} 段、合计 ${hoursText(summary.totalHours)}。'
          '删除后，这一天的备注、补贴和扣款都会从汇总与 CSV 中移除。',
      confirmText: '确认删除',
      destructive: true,
      icon: Icons.delete_sweep_outlined,
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final deleted = widget.state.deleteDay(targetDay);
    Navigator.pop(context);
    if (deleted == null) return;
    showLedgerSnackBarOn(
      messenger,
      '已删除 ${ymd(deleted.day)} 全部记录'
      '（${deleted.segmentCount}段 · ${hoursText(deleted.totalHours)}）',
      action: SnackBarAction(
        label: '撤销',
        onPressed: () => widget.state.restoreDeletedDay(deleted.id),
      ),
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _save() async {
    if (_segments.isEmpty && !_openedWithExistingDay) {
      final rootContext = Navigator.of(context, rootNavigator: true).context;
      Navigator.pop(context);
      showLedgerSnackBar(rootContext, '这一天还没有分段，未新增记录');
      return;
    }
    if (_segments.isEmpty) {
      final confirmed = await showLedgerConfirmDialog(
        context,
        title: '清空 ${ymd(_day)} 记录？',
        message: '当前已经没有分段了。继续保存后，会清空 ${ymd(_day)} 这一天的全部记录。',
        confirmText: '确认清空',
        destructive: true,
        icon: Icons.delete_sweep_outlined,
      );
      if (confirmed != true || !mounted) return;
    }
    if (_hasOverlaps()) {
      final confirmed = await showLedgerConfirmDialog(
        context,
        title: '时间有重叠，仍然保存？',
        message: '同一天存在重叠分段。个人账本允许特殊情况，但建议先核对开始/结束时间。',
        confirmText: '仍然保存',
        cancelText: '返回修改',
        icon: Icons.schedule_outlined,
      );
      if (confirmed != true || !mounted) return;
    }
    if (!context.mounted) return;
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final savedDay = _day;
    widget.state.replaceDayEntries(savedDay, savedDay, _segments);
    Navigator.pop(context);
    showLedgerSnackBar(
      rootContext,
      _segments.isEmpty
          ? '已清空 ${ymd(savedDay)} 记录'
          : '已保存 ${ymd(savedDay)} 记录',
    );
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
    final stackedFields = useDenseTwoColumnLayout(
      context,
      textScaleBreakpoint: 1.45,
    );
    final draftStart = _draftStartDateTime;
    final draftEnd = _draftEndDateTime;
    final draftCrossesMidnight = _draftCrossesMidnight;
    final draftHasEqualTime = _draftHasEqualTime;
    return LedgerDialogShell(
      title: '编辑本段',
      icon: Icons.tune_rounded,
      iconColor: LedgerColors.primaryBlue,
      iconBackgroundColor: LedgerColors.primaryBlueSoft,
      maxWidth: 520,
      maxHeightFactor: .88,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${widget.entry.timeRangeLabel} · ${hoursText(widget.entry.netHours)}',
              style: const TextStyle(color: LedgerColors.muted, fontSize: 13),
            ),
          ),
          const SizedBox(height: 10),
          _buildFieldPair(
            stacked: stackedFields,
            first: LedgerPickerButtonField(
              label: '开始时间',
              value: _start.text,
              icon: Icons.schedule_outlined,
              onTap: () => _pickTime(_start),
            ),
            second: LedgerPickerButtonField(
              label: '结束时间',
              value: _end.text,
              icon: Icons.schedule_outlined,
              onTap: () => _pickTime(_end),
            ),
          ),
          if (draftHasEqualTime) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: LedgerColors.errorRed,
                  ),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    equalTimeRangeErrorText,
                    style: TextStyle(
                      color: LedgerColors.errorRed,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (draftCrossesMidnight) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.bedtime_outlined,
                    size: 16,
                    color: LedgerColors.warningOrange,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '结束时间不晚于开始时间，会按跨天记录处理：${hm(draftStart)} → 次日 ${hm(draftEnd)}。',
                    style: const TextStyle(
                      color: LedgerColors.muted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _break,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '休息分钟'),
          ),
          const SizedBox(height: 10),
          EntryTypeSegmentedField(
            value: _type,
            onChanged: (value) => setState(() => _type = value),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<PayRule>(
            initialValue: _rule,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '计薪规则'),
            items: widget.rules
                .map(
                  (rule) => DropdownMenuItem(
                    value: rule,
                    child: Text(
                      '${rule.name} · ${rule.amountLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            selectedItemBuilder: (context) => widget.rules
                .map(
                  (rule) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${rule.name} · ${rule.amountLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
          _buildFieldPair(
            stacked: stackedFields,
            first: TextField(
              controller: _allowance,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '补贴'),
            ),
            second: TextField(
              controller: _deduction,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '扣款'),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: '备注'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: draftHasEqualTime ? null : _save,
          child: const Text('保存本段'),
        ),
      ],
    );
  }

  Widget _buildFieldPair({
    required bool stacked,
    required Widget first,
    required Widget second,
  }) {
    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [first, const SizedBox(height: 10), second],
      );
    }
    return Row(
      children: [
        Expanded(child: first),
        const SizedBox(width: 10),
        Expanded(child: second),
      ],
    );
  }

  Future<void> _save() async {
    if (_draftHasEqualTime) {
      showLedgerSnackBar(context, equalTimeRangeErrorText);
      return;
    }
    final start = _draftStartDateTime;
    final end = _draftEndDateTime;
    if (_draftCrossesMidnight) {
      final confirmed = await showLedgerConfirmDialog(
        context,
        title: '按跨天记录保存？',
        message:
            '当前时间顺序会跨到次日，这一段会记为 ${dateTimeText(start)} 到 ${dateTimeText(end)}。',
        confirmText: '确认保存',
        icon: Icons.bedtime_outlined,
      );
      if (confirmed != true || !mounted) return;
    }
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
        breakMinutes: asNonNegativeInt(_break.text, widget.entry.breakMinutes),
        type: _type,
        locationName: _location.text,
        note: _note.text,
        adjustments: adjustments,
        payRuleId: _rule.id,
        payRuleSnapshot: _rule,
      ),
    );
  }

  DateTime get _draftStartDateTime {
    final startParts =
        _parseTime(_start.text) ??
        [widget.entry.startDateTime.hour, widget.entry.startDateTime.minute];
    final day = widget.entry.workDate;
    return DateTime(day.year, day.month, day.day, startParts[0], startParts[1]);
  }

  DateTime get _draftEndDateTime {
    final endParts =
        _parseTime(_end.text) ??
        [widget.entry.endDateTime.hour, widget.entry.endDateTime.minute];
    final day = widget.entry.workDate;
    var end = DateTime(day.year, day.month, day.day, endParts[0], endParts[1]);
    return normalizeOvernightEnd(_draftStartDateTime, end);
  }

  bool get _draftCrossesMidnight =>
      _sameDayDraftEndDateTime.isBefore(_draftStartDateTime);

  bool get _draftHasEqualTime =>
      _sameDayDraftEndDateTime.isAtSameMomentAs(_draftStartDateTime);

  DateTime get _sameDayDraftEndDateTime {
    final endParts =
        _parseTime(_end.text) ??
        [widget.entry.endDateTime.hour, widget.entry.endDateTime.minute];
    final day = widget.entry.workDate;
    return DateTime(day.year, day.month, day.day, endParts[0], endParts[1]);
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final current = _parseTime(controller.text);
    final picked = await showLedgerTimePicker(
      context,
      initialMinute:
          (current?[0] ?? widget.entry.startDateTime.hour) * 60 +
          (current?[1] ?? widget.entry.startDateTime.minute),
    );
    if (picked == null || !mounted) return;
    setState(() {
      controller.text =
          '${(picked ~/ 60).toString().padLeft(2, '0')}:${(picked % 60).toString().padLeft(2, '0')}';
    });
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
