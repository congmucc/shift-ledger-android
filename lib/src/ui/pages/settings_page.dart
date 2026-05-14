import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/ledger_state.dart';
import '../../domain/models.dart';
import '../../services/backup_service.dart';
import '../../services/csv_exporter.dart';
import '../../services/local_ledger_repository.dart';
import '../../services/webdav_client.dart';
import '../pickers.dart';
import '../theme.dart';
import '../widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.state, this.repository});
  final LedgerState state;
  final LocalLedgerRepository? repository;

  @override
  Widget build(BuildContext context) {
    final rule = state.defaultRule;
    final backupStatus = _backupStatusDisplay(
      webDavConfig: state.webDavConfig,
      autoConfig: state.autoBackupConfig,
    );
    return PageFrame(
      title: '设置',
      children: [
        const Text('个人工时账本', style: TextStyle(color: LedgerColors.muted)),
        const SectionHeader(title: '常用规则'),
        LedgerCard(
          child: Column(
            children: [
              SettingTile(
                title: '班次模板',
                subtitle: state.templates
                    .map(
                      (tpl) =>
                          '${tpl.name} ${_time(tpl.startMinute)}-${_time(tpl.endMinute)}',
                    )
                    .join(' · '),
                trailing: '编辑',
                onTap: () => _showTemplateInfo(context),
              ),
              SettingTile(
                title: '计薪规则',
                subtitle:
                    '默认 ${rule.baseType.label} · ${rule.amountLabel} · ${ymd(rule.effectiveFrom)} 起',
                trailing: '编辑',
                onTap: () => showPayRuleSheet(context, state, rule),
              ),
              SettingTile(
                title: '规则历史',
                subtitle: state.payRules
                    .map((r) => '${r.baseType.label} ${r.amountLabel}')
                    .join(' · '),
                trailing: '${state.payRules.length}条',
                onTap: () => _showRuleHistory(context),
              ),
              SettingTile(
                title: '加班规则',
                subtitle:
                    '超过 ${rule.overtimeThresholdHours.toStringAsFixed(0)}h · ${rule.overtimeMultiplier}x · 不重复计算',
                trailing: '编辑',
                onTap: () => showPayRuleSheet(context, state, rule),
              ),
              SettingTile(
                title: '夜班规则',
                subtitle: '${state.nightRule.label} · 可改默认时段',
                trailing: '编辑',
                onTap: () => _showNightRuleSheet(context),
              ),
              SettingTile(
                title: '发薪周期',
                subtitle: _payPeriodLabel(state.payPeriod),
                trailing: '编辑',
                onTap: () => _showPayPeriodSheet(context),
              ),
            ],
          ),
        ),
        const SectionHeader(title: '导出与备份'),
        LedgerCard(
          child: Column(
            children: [
              SettingTile(
                title: 'CSV 导出',
                subtitle: '含规则快照与收入拆分',
                trailing: '导出',
                onTap: () => _exportCsv(context),
              ),
              SettingTile(
                title: '本地备份/恢复',
                subtitle: '记录、模板、规则、非敏感设置',
                trailing: '备份',
                onTap: () => _showLocalBackupSheet(context),
              ),
              SettingTile(
                title: '坚果云 WebDAV',
                subtitle: backupStatus.summary,
                trailing: '连接',
                onTap: () => showWebDavSheet(context, state),
              ),
              SettingTile(
                title: '最近删除',
                subtitle: _recentDeletedSubtitle(),
                trailing: state.recentDeletedDays.isEmpty ? null : '恢复',
                onTap: () => _showRecentlyDeletedSheet(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showTemplateInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LedgerColors.paper,
      builder: (context) => ShiftTemplateSheet(state: state),
    );
  }

  void _showRuleHistory(BuildContext context) {
    final rules = [...state.payRules]
      ..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LedgerColors.paper,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '规则历史',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
                const Text(
                  '每次修改计薪规则都会生成新版本；历史记录继续使用保存时的规则快照，避免旧工资被新规则改写。',
                  style: TextStyle(color: LedgerColors.muted),
                ),
                const SizedBox(height: 12),
                for (final rule in rules) ...[
                  LedgerCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${rule.name} · v${rule.version}${rule.isDefault ? ' · 当前默认' : ''}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${rule.baseType.label} · ${rule.amountLabel} · ${cnDateText(rule.effectiveFrom)} 起${rule.effectiveTo == null ? '' : '，至 ${cnDateText(rule.effectiveTo!)}'}',
                          style: const TextStyle(color: LedgerColors.muted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '标准 ${rule.standardHoursPerDay.toStringAsFixed(0)}h/天 · 加班 ${rule.overtimeMultiplier}x · 休息日 ${rule.restDayMultiplier}x',
                          style: const TextStyle(color: LedgerColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNightRuleSheet(BuildContext context) {
    final start = TextEditingController(
      text: (state.nightRule.startMinute ~/ 60).toString(),
    );
    final end = TextEditingController(
      text: (state.nightRule.endMinute ~/ 60).toString(),
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LedgerColors.paper,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '夜班规则',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: start,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '开始小时'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: end,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '结束小时'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    state.updateNightRule(
                      state.nightRule.copyWith(
                        startMinute:
                            clampInt(int.tryParse(start.text) ?? 22, 0, 23) *
                            60,
                        endMinute:
                            clampInt(int.tryParse(end.text) ?? 6, 0, 23) * 60,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _payPeriodLabel(PayPeriod period) => switch (period.mode) {
    PayPeriodMode.naturalMonth => '默认自然月',
    PayPeriodMode.monthlyStartDay => '每月 ${period.monthStartDay} 日起',
    PayPeriodMode.customRange =>
      '${ymd(period.customStartDate ?? state.now)} — ${ymd(period.customEndDate ?? state.now)}',
  };

  Future<void> _showPayPeriodSheet(BuildContext context) async {
    var mode = state.payPeriod.mode == PayPeriodMode.customRange
        ? PayPeriodMode.monthlyStartDay
        : state.payPeriod.mode;
    var monthStartDay = clampInt(state.payPeriod.monthStartDay, 1, 31);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LedgerColors.paper,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '发薪周期',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<PayPeriodMode>(
                    selected: {mode},
                    segments: const [
                      ButtonSegment(
                        value: PayPeriodMode.naturalMonth,
                        label: Text('自然月'),
                      ),
                      ButtonSegment(
                        value: PayPeriodMode.monthlyStartDay,
                        label: Text('固定日'),
                      ),
                    ],
                    onSelectionChanged: (values) =>
                        setSheetState(() => mode = values.first),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: mode == PayPeriodMode.monthlyStartDay,
                    title: const Text('每月起始日'),
                    subtitle: Text(
                      '$monthStartDay 日；短月会自动落到当月最后一天',
                      style: const TextStyle(color: LedgerColors.muted),
                    ),
                    trailing: const Icon(Icons.keyboard_arrow_up_outlined),
                    onTap: mode == PayPeriodMode.monthlyStartDay
                        ? () async {
                            final picked = await showLedgerMonthDayPicker(
                              context,
                              initialDay: monthStartDay,
                            );
                            if (picked != null && context.mounted) {
                              setSheetState(() => monthStartDay = picked);
                            }
                          }
                        : null,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      state.updatePayPeriod(
                        PayPeriod(mode: mode, monthStartDay: monthStartDay),
                      );
                      Navigator.pop(context);
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: '导出 CSV？',
      content: '会打开系统保存面板，请选择 CSV 保存位置；取消保存不会改动账本。',
      confirmText: '确认导出',
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final range = state.currentMonth;
    final csv = CsvExporter().exportEntries(
      entries: state.entries,
      rules: state.payRules,
      nightRule: state.nightRule,
      range: range,
    );
    try {
      if (repository == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('CSV 已生成：${csv.length} 字符')));
        return;
      }
      final path = await repository!.writeCsv(csv);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(path == null ? '已取消保存 CSV' : 'CSV 已保存：$path')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('CSV 已生成但保存失败，请重试或更换保存位置')));
      }
    }
  }

  Future<void> _showLocalBackupSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: LedgerColors.paper,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本地备份/恢复',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                '普通备份不包含坚果云应用授权密码；恢复前会覆盖当前记录、模板和规则。',
                style: TextStyle(color: LedgerColors.muted),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: repository == null
                    ? null
                    : () => _writeBackup(context),
                child: const Text('创建本地备份'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: repository == null
                    ? null
                    : () => _restoreLatestBackup(context),
                child: const Text('从最近本地备份恢复'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _writeBackup(BuildContext context) async {
    final confirmed = await _confirm(
      context,
      title: '创建本地备份？',
      content:
          '会打开系统保存面板，请选择 JSON 备份保存位置；同时保留一份 App 私有备份用于“最近本地备份恢复”。备份不包含 WebDAV 应用授权密码。',
      confirmText: '确认备份',
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    try {
      final path = await repository!.writeBackup(state.toSnapshot());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              path == null ? '已创建 App 私有备份；外部保存已取消' : '本地备份已保存：$path',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('本地备份创建失败，请重试或更换保存位置')));
      }
    }
  }

  Future<void> _restoreLatestBackup(BuildContext context) async {
    try {
      final path = await repository!.latestBackupPath();
      if (!context.mounted) return;
      if (path == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('还没有本地备份')));
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('恢复备份？'),
          content: Text('将用 $path 覆盖当前账本。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认恢复'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!context.mounted) return;
      final snapshot = await repository!.readBackup(path);
      state.restore(snapshot);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已从本地备份恢复')));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('读取本地备份失败，请确认备份文件仍可访问')));
      }
    }
  }

  Future<void> _showRecentlyDeletedSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: LedgerColors.paper,
      builder: (context) {
        final deletedDays = state.recentDeletedDays;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('最近删除', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text(
                  '用于找回误删的整天记录；恢复会把删除的分段放回原日期，不覆盖后来新增记录。',
                  style: TextStyle(color: LedgerColors.muted),
                ),
                const SizedBox(height: 12),
                if (deletedDays.isEmpty)
                  const LedgerCard(
                    color: LedgerColors.surfaceRaised,
                    child: Text('没有可恢复记录。'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: deletedDays.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = deletedDays[index];
                        return LedgerCard(
                          color: LedgerColors.surfaceRaised,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${ymd(item.day)} · ${item.segmentCount}段 · ${hoursText(item.totalHours)}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '删除于 ${dateTimeText(item.deletedAt)}',
                                style: const TextStyle(
                                  color: LedgerColors.muted,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton(
                                  onPressed: () =>
                                      _confirmRestoreDeletedDay(context, item),
                                  child: const Text('恢复这一天'),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmRestoreDeletedDay(
    BuildContext context,
    DeletedDayRecord item,
  ) async {
    final existingCount = state.entriesForDay(item.day).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('恢复 ${ymd(item.day)}？'),
        content: Text(
          existingCount == 0
              ? '会恢复 ${item.segmentCount} 段、合计 ${hoursText(item.totalHours)}。'
              : '这一天现在已有 $existingCount 段。恢复会把删除的 ${item.segmentCount} 段合并回来，不覆盖现有记录。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final restored = state.restoreDeletedDay(item.id);
    if (!context.mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(restored ? '已恢复 ${ymd(item.day)}' : '这条删除记录已不可恢复'),
      ),
    );
  }

  String _recentDeletedSubtitle() {
    if (state.recentDeletedDays.isEmpty) return '没有可恢复记录';
    final latest = state.recentDeletedDays.first;
    return '${state.recentDeletedDays.length}天可恢复，最近 ${ymd(latest.day)} · ${latest.segmentCount}段';
  }

  String _time(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmText,
  }) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
}

class ShiftTemplateSheet extends StatefulWidget {
  const ShiftTemplateSheet({super.key, required this.state});

  final LedgerState state;

  @override
  State<ShiftTemplateSheet> createState() => _ShiftTemplateSheetState();
}

class _ShiftTemplateSheetState extends State<ShiftTemplateSheet> {
  late ShiftTemplate _template;
  late final TextEditingController _name;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late final TextEditingController _break;
  late final TextEditingController _location;
  late final TextEditingController _allowance;
  late final TextEditingController _deduction;
  late EntryType _type;

  @override
  void initState() {
    super.initState();
    _template = widget.state.templates.first;
    _name = TextEditingController();
    _start = TextEditingController();
    _end = TextEditingController();
    _break = TextEditingController();
    _location = TextEditingController();
    _allowance = TextEditingController();
    _deduction = TextEditingController();
    _load(_template);
  }

  @override
  void dispose() {
    _name.dispose();
    _start.dispose();
    _end.dispose();
    _break.dispose();
    _location.dispose();
    _allowance.dispose();
    _deduction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '班次模板',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: _createTemplate,
                    child: const Text('新增'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                ],
              ),
              const Text(
                '常用班次会用于新增工时记录；修改后不会回写已经保存的历史记录。',
                style: TextStyle(color: LedgerColors.muted),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ShiftTemplate>(
                initialValue: _template,
                decoration: const InputDecoration(labelText: '选择模板'),
                items: widget.state.templates
                    .map(
                      (tpl) => DropdownMenuItem(
                        value: tpl,
                        child: Text(
                          '${tpl == widget.state.templates.first ? '默认 · ' : ''}${tpl.name} · ${_time(tpl.startMinute)}-${_time(tpl.endMinute)}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _template = value;
                    _load(value);
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: '模板名称'),
              ),
              const SizedBox(height: 10),
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _break,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '休息分钟'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<EntryType>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: '班次类型'),
                      items: EntryType.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _type = value ?? _type),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: '地点/岗位默认值',
                  helperText: '新增记录时自动带入；没有固定地点就留空。',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _allowance,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '默认补贴',
                        helperText: '默认 0',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _deduction,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '默认扣款',
                        helperText: '默认 0',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LedgerColors.errorBrick,
                  ),
                  onPressed: widget.state.templates.length <= 1
                      ? null
                      : _confirmDeleteTemplate,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除模板'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _template == widget.state.templates.first
                          ? null
                          : _setAsDefault,
                      child: const Text('设为默认'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('保存模板'),
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

  void _createTemplate() {
    final source = _template;
    final copy = source.copyWith(id: newId('tpl'), name: '${source.name} 副本');
    widget.state.updateShiftTemplate(copy);
    setState(() {
      _template = copy;
      _load(copy);
    });
  }

  void _setAsDefault() {
    widget.state.setDefaultShiftTemplate(_template.id);
    setState(() {});
  }

  void _load(ShiftTemplate template) {
    _name.text = template.name;
    _start.text = _time(template.startMinute);
    _end.text = _time(template.endMinute);
    _break.text = template.breakMinutes.toString();
    _location.text = [
      template.defaultLocationName,
      template.defaultJobTypeName,
    ].where((value) => value.trim().isNotEmpty).join(' / ');
    _allowance.text = template.defaultAdjustments
        .where((item) => item.type == AdjustmentType.allowance)
        .fold(0.0, (sum, item) => sum + item.amount)
        .toStringAsFixed(0);
    _deduction.text = template.defaultAdjustments
        .where((item) => item.type == AdjustmentType.deduction)
        .fold(0.0, (sum, item) => sum + item.amount)
        .toStringAsFixed(0);
    _type = template.type;
  }

  void _save() {
    final start = _parseTime(_start.text) ?? _template.startMinute;
    final end = _parseTime(_end.text) ?? _template.endMinute;
    final defaultAdjustments = <Adjustment>[];
    final allowance = double.tryParse(_allowance.text) ?? 0;
    final deduction = double.tryParse(_deduction.text) ?? 0;
    if (allowance > 0) {
      defaultAdjustments.add(Adjustment.allowance('默认补贴', allowance));
    }
    if (deduction > 0) {
      defaultAdjustments.add(Adjustment.deduction('默认扣款', deduction));
    }
    widget.state.updateShiftTemplate(
      _template.copyWith(
        name: _name.text.trim().isEmpty ? _template.name : _name.text.trim(),
        startMinute: start,
        endMinute: end,
        breakMinutes: asNonNegativeInt(_break.text, _template.breakMinutes),
        type: _type,
        defaultLocationName: _location.text.trim(),
        defaultJobTypeName: '',
        defaultAdjustments: defaultAdjustments,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _confirmDeleteTemplate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除模板？'),
        content: Text('只删除“${_template.name}”这个模板，已经保存的工时记录不会被删除。'),
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
    final deleted = widget.state.deleteShiftTemplate(_template.id);
    if (!deleted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('至少保留一个班次模板')));
      return;
    }
    setState(() {
      _template = widget.state.templates.first;
      _load(_template);
    });
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final minute = _parseTime(controller.text) ?? _template.startMinute;
    final picked = await showLedgerTimePicker(context, initialMinute: minute);
    if (picked == null || !mounted) return;
    controller.text = _time(picked);
  }

  int? _parseTime(String value) {
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
    return hour * 60 + minute;
  }

  String _time(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
}

Future<void> showPayRuleSheet(
  BuildContext context,
  LedgerState state,
  PayRule rule,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: LedgerColors.paper,
    builder: (context) => PayRuleSheet(state: state, initialRule: rule),
  );
}

class PayRuleSheet extends StatefulWidget {
  const PayRuleSheet({
    super.key,
    required this.state,
    required this.initialRule,
  });
  final LedgerState state;
  final PayRule initialRule;

  @override
  State<PayRuleSheet> createState() => _PayRuleSheetState();
}

class _PayRuleSheetState extends State<PayRuleSheet> {
  late PayBaseType _type;
  late final TextEditingController _name;
  late final TextEditingController _effective;
  late final TextEditingController _hourly;
  late final TextEditingController _daily;
  late final TextEditingController _monthly;
  late final TextEditingController _standard;
  late final TextEditingController _overtime;
  late final TextEditingController _overtimeBase;
  late final TextEditingController _restDayMultiplier;
  late DailyPayMode _dailyPayMode;

  @override
  void initState() {
    super.initState();
    final rule = widget.initialRule;
    _type = rule.baseType;
    _name = TextEditingController(text: rule.name);
    _effective = TextEditingController(text: ymd(rule.effectiveFrom));
    _hourly = TextEditingController(text: rule.hourlyRate.toStringAsFixed(0));
    _daily = TextEditingController(text: rule.dailyRate.toStringAsFixed(0));
    _monthly = TextEditingController(text: rule.monthlyRate.toStringAsFixed(0));
    _standard = TextEditingController(
      text: rule.standardHoursPerDay.toStringAsFixed(0),
    );
    _overtime = TextEditingController(text: rule.overtimeMultiplier.toString());
    _overtimeBase = TextEditingController(
      text: rule.overtimeBaseHourlyRate == 0
          ? ''
          : rule.overtimeBaseHourlyRate.toStringAsFixed(0),
    );
    _restDayMultiplier = TextEditingController(
      text: rule.restDayMultiplier.toString(),
    );
    _dailyPayMode = rule.dailyPayMode;
  }

  @override
  void dispose() {
    _name.dispose();
    _effective.dispose();
    _hourly.dispose();
    _daily.dispose();
    _monthly.dispose();
    _standard.dispose();
    _overtime.dispose();
    _overtimeBase.dispose();
    _restDayMultiplier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '计薪规则',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ],
              ),
              SegmentedButton<PayBaseType>(
                selected: {_type},
                segments: const [
                  ButtonSegment(value: PayBaseType.hourly, label: Text('按小时')),
                  ButtonSegment(value: PayBaseType.daily, label: Text('按天')),
                  ButtonSegment(value: PayBaseType.monthly, label: Text('按月')),
                ],
                onSelectionChanged: (values) =>
                    setState(() => _type = values.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: '规则名称'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _effective,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(
                  labelText: '生效日期 YYYY-MM-DD',
                  suffixIcon: IconButton(
                    tooltip: '选择生效日期',
                    onPressed: _pickEffectiveDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_type == PayBaseType.hourly)
                TextField(
                  controller: _hourly,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '小时工资 ¥/h'),
                ),
              if (_type == PayBaseType.daily) ...[
                TextField(
                  controller: _daily,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '每日工资 ¥/天'),
                ),
                const SizedBox(height: 10),
                SegmentedButton<DailyPayMode>(
                  selected: {_dailyPayMode},
                  segments: const [
                    ButtonSegment(
                      value: DailyPayMode.attendanceDay,
                      label: Text('按出勤日'),
                    ),
                    ButtonSegment(
                      value: DailyPayMode.shiftCount,
                      label: Text('按班次数'),
                    ),
                  ],
                  onSelectionChanged: (values) =>
                      setState(() => _dailyPayMode = values.first),
                ),
              ],
              if (_type == PayBaseType.monthly)
                TextField(
                  controller: _monthly,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '月薪 ¥/月'),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _standard,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '标准工时 h/天'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _overtime,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '加班倍率'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _overtimeBase,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '加班基准 ¥/h'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _restDayMultiplier,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '休息日倍率'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '历史处理：保存为新版本；旧记录继续使用记录内规则快照。',
                  style: TextStyle(color: LedgerColors.muted),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(onPressed: _save, child: const Text('保存')),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final initial = widget.initialRule;
    final rule = initial.copyWith(
      name: _name.text.trim().isEmpty ? initial.name : _name.text.trim(),
      baseType: _type,
      hourlyRate: asNonNegativeDouble(_hourly.text, initial.hourlyRate),
      dailyRate: asNonNegativeDouble(_daily.text, initial.dailyRate),
      monthlyRate: asNonNegativeDouble(_monthly.text, initial.monthlyRate),
      dailyPayMode: _dailyPayMode,
      effectiveFrom:
          DateTime.tryParse(_effective.text) ?? initial.effectiveFrom,
      standardHoursPerDay: asNonNegativeDouble(
        _standard.text,
        initial.standardHoursPerDay,
      ),
      overtimeMultiplier: asNonNegativeDouble(
        _overtime.text,
        initial.overtimeMultiplier,
      ),
      overtimeBaseHourlyRate: asNonNegativeDouble(_overtimeBase.text),
      restDayMultiplier: asNonNegativeDouble(
        _restDayMultiplier.text,
        initial.restDayMultiplier,
      ),
      version: initial.version + 1,
      isDefault: true,
    );
    widget.state.savePayRule(rule);
    Navigator.pop(context);
  }

  Future<void> _pickEffectiveDate() async {
    final current = DateTime.tryParse(_effective.text);
    final picked = await showLedgerDatePicker(
      context,
      initialDate: current ?? widget.initialRule.effectiveFrom,
    );
    if (picked == null || !mounted) return;
    _effective.text = ymd(picked);
  }
}

Future<void> showWebDavSheet(BuildContext context, LedgerState state) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: LedgerColors.paper,
    builder: (context) => WebDavSheet(state: state),
  );
}

class _BackupStatusDisplay {
  const _BackupStatusDisplay({required this.summary, required this.detail});

  final String summary;
  final String detail;
}

_BackupStatusDisplay _backupStatusDisplay({
  required WebDavConfig webDavConfig,
  required AutoBackupConfig autoConfig,
}) {
  if (!webDavConfig.isConfigured) {
    final hasPartialConfig =
        webDavConfig.url.isNotEmpty || webDavConfig.username.isNotEmpty;
    return _BackupStatusDisplay(
      summary: hasPartialConfig ? '需重新授权或补全配置' : '未连接；可配置坚果云备份',
      detail: hasPartialConfig ? 'WebDAV 信息不完整，自动备份不会运行。' : '还没有连接坚果云。',
    );
  }
  if (!autoConfig.enabled) {
    return _BackupStatusDisplay(
      summary: '已连接；未开启自动备份',
      detail: '${webDavConfig.username} · ${webDavConfig.remotePath}',
    );
  }
  return switch (autoConfig.lastStatus) {
    AutoBackupStatus.success => _BackupStatusDisplay(
      summary: autoConfig.lastSuccessAt == null
          ? '自动备份正常'
          : '自动备份正常；最近成功 ${dateTimeText(autoConfig.lastSuccessAt!)}',
      detail: '云端文件 ${autoConfig.remotePath}',
    ),
    AutoBackupStatus.skipped => _BackupStatusDisplay(
      summary: '内容未变化，已跳过',
      detail: autoConfig.lastAttemptAt == null
          ? '自动备份已开启。'
          : '最近检查 ${dateTimeText(autoConfig.lastAttemptAt!)}',
    ),
    AutoBackupStatus.waiting => _BackupStatusDisplay(
      summary: autoConfig.lastSuccessAt == null
          ? '自动备份等待中'
          : '等待下次自动备份；最近成功 ${dateTimeText(autoConfig.lastSuccessAt!)}',
      detail: '最小间隔 1 小时，每天最多 6 次。',
    ),
    AutoBackupStatus.configIncomplete => const _BackupStatusDisplay(
      summary: '需重新授权或补全配置',
      detail: '自动备份已开启，但 WebDAV 配置不完整。',
    ),
    AutoBackupStatus.failed => _BackupStatusDisplay(
      summary: autoConfig.lastError.isEmpty
          ? '最近自动备份失败'
          : '最近失败：${autoConfig.lastError}',
      detail: autoConfig.lastAttemptAt == null
          ? '请检查账号、应用授权密码和网络。'
          : '失败时间 ${dateTimeText(autoConfig.lastAttemptAt!)}',
    ),
    AutoBackupStatus.idle => const _BackupStatusDisplay(
      summary: '自动备份已开；等待首次备份',
      detail: '打开 App 或账本变化后会自动检查。',
    ),
  };
}

class WebDavSheet extends StatefulWidget {
  const WebDavSheet({super.key, required this.state});
  final LedgerState state;

  @override
  State<WebDavSheet> createState() => _WebDavSheetState();
}

class _WebDavSheetState extends State<WebDavSheet> {
  late final TextEditingController _url;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _remotePath;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final config = widget.state.webDavConfig;
    _url = TextEditingController(
      text: config.url.isEmpty ? 'https://dav.jianguoyun.com/dav/' : config.url,
    );
    _username = TextEditingController(text: config.username);
    _password = TextEditingController(text: config.appPassword);
    _remotePath = TextEditingController(text: config.remotePath);
  }

  @override
  void dispose() {
    _url.dispose();
    _username.dispose();
    _password.dispose();
    _remotePath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '坚果云 WebDAV',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                ],
              ),
              const Text(
                '手动备份即时执行；可选择开启省流量自动云备份。应用授权密码不会写入普通备份。',
                style: TextStyle(color: LedgerColors.muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                decoration: const InputDecoration(labelText: '服务器地址'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _username,
                decoration: const InputDecoration(labelText: '账号'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: '应用授权密码'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _remotePath,
                decoration: const InputDecoration(labelText: '远端备份文件名'),
              ),
              const SizedBox(height: 12),
              _buildAutoBackupSection(context),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: const Text('保存配置'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : _backup,
                    child: const Text('备份到坚果云'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : _restore,
                    child: const Text('从坚果云恢复'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : _list,
                    child: const Text('导入/导出列表'),
                  ),
                ],
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  WebDavConfig _config() => WebDavConfig(
    url: _url.text.trim(),
    username: _username.text.trim(),
    appPassword: _password.text,
    remotePath: _remotePath.text.trim().isEmpty
        ? 'shift-ledger-backup.json'
        : _remotePath.text.trim(),
  );

  Widget _buildAutoBackupSection(BuildContext context) {
    final autoConfig = widget.state.autoBackupConfig;
    final displayStatus = _displayAutoBackupStatus();
    final backupStatus = _backupStatusDisplay(
      webDavConfig: _config(),
      autoConfig: autoConfig.copyWith(lastStatus: displayStatus),
    );
    return Container(
      decoration: BoxDecoration(
        color: LedgerColors.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LedgerColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: autoConfig.enabled,
            title: const Text('自动云备份'),
            subtitle: const Text('推荐 · 最小间隔 1 小时 · 每天最多 6 次'),
            onChanged: (value) {
              final currentConfig = _config();
              final configured = currentConfig.isConfigured;
              setState(() {
                widget.state.updateWebDavConfig(currentConfig);
                widget.state.updateAutoBackupConfig(
                  autoConfig.copyWith(
                    enabled: value,
                    lastStatus: value
                        ? configured
                              ? AutoBackupStatus.waiting
                              : AutoBackupStatus.configIncomplete
                        : AutoBackupStatus.idle,
                    lastError: value && !configured ? '需重新授权或配置不完整' : '',
                  ),
                );
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _StatusLine(label: '打开 App 后自动检查', value: '已启用，开启后生效'),
                _StatusLine(label: '当前状态', value: backupStatus.summary),
                _StatusLine(label: '状态说明', value: backupStatus.detail),
                _StatusLine(
                  label: '云端文件',
                  value: widget.state.autoBackupConfig.remotePath,
                ),
                _StatusLine(
                  label: '上次自动备份',
                  value: autoConfig.lastSuccessAt == null
                      ? '尚未自动备份'
                      : dateTimeText(autoConfig.lastSuccessAt!),
                ),
                _StatusLine(label: '最近状态', value: displayStatus.label),
                if (autoConfig.lastStatus == AutoBackupStatus.failed &&
                    autoConfig.lastError.isNotEmpty)
                  _StatusLine(label: '失败原因', value: autoConfig.lastError),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AutoBackupStatus _displayAutoBackupStatus() {
    final autoConfig = widget.state.autoBackupConfig;
    if (autoConfig.enabled && !_config().isConfigured) {
      return AutoBackupStatus.configIncomplete;
    }
    return autoConfig.lastStatus;
  }

  void _save({bool showMessage = true}) {
    widget.state.updateWebDavConfig(_config());
    if (showMessage) _snack('WebDAV 配置已保存，普通备份不会包含应用密码');
  }

  Future<void> _backup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('备份到坚果云？'),
        content: const Text('会把当前记录、班次模板、计薪规则和非敏感设置上传到远端备份文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认备份'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      final config = _config().copyWith(lastBackupAt: DateTime.now());
      await WebDavClient().uploadBackup(
        config,
        BackupService().encode(widget.state.toSnapshot()),
      );
      widget.state.updateWebDavConfig(config);
      _snack('已备份到坚果云：${config.remotePath}');
    });
  }

  Future<void> _restore() async {
    final confirmed = await _confirmRestore();
    if (confirmed != true || !mounted) return;
    await _run(() async {
      final config = _config();
      final payload = await WebDavClient().downloadBackup(config);
      final snapshot = BackupService().decode(
        jsonDecode(payload) as Map<String, Object?>,
      );
      widget.state.updateWebDavConfig(config);
      widget.state.restore(snapshot);
      _snack('已从坚果云恢复，应用授权密码需重新输入');
    });
  }

  Future<bool?> _confirmRestore() => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('从坚果云恢复？'),
      content: const Text('这会用远端备份覆盖当前记录、模板和规则；应用授权密码不会随备份恢复，需要重新输入。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('确认恢复'),
        ),
      ],
    ),
  );

  Future<void> _list() async {
    await _run(() async {
      final config = _config();
      final listing = await WebDavClient().listBackups(config);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导入/导出列表'),
          content: SingleChildScrollView(
            child: Text(
              listing.length > 1200
                  ? '${listing.substring(0, 1200)}…'
                  : listing,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      _save(showMessage: false);
      await action();
    } catch (error) {
      _snack('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(color: LedgerColors.muted),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
