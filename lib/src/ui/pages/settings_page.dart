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
    final defaultTemplate = state.templates.first;
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
                subtitle:
                    '默认 ${defaultTemplate.name} ${_time(defaultTemplate.startMinute)}-${_time(defaultTemplate.endMinute)} · 共 ${state.templates.length} 套模板',
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
                subtitle:
                    '共 ${state.payRules.length} 个版本 · 当前 ${rule.baseType.label} ${rule.amountLabel}',
                trailing: '${state.payRules.length}条',
                onTap: () => _showRuleHistory(context),
              ),
              SettingTile(
                title: '计薪加班规则',
                subtitle:
                    '超过 ${rule.overtimeThresholdHours.toStringAsFixed(0)}h 后按 ${rule.overtimeMultiplier}x 结算，不改变记录类型',
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
                subtitle: '系统保存面板 + 一份 App 私有最近备份',
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
                          '普通上限 ${rule.standardHoursPerDay.toStringAsFixed(0)}h/天 · 计薪加班 ${rule.overtimeMultiplier}x · 休息日 ${rule.restDayMultiplier}x',
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
    var startMinute = state.nightRule.startMinute;
    var endMinute = state.nightRule.endMinute;
    showModalBottomSheet<void>(
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
                  SheetHeaderBlock(
                    title: '夜班规则',
                    subtitle: '夜班补贴仍按当前规则计算，这里只决定什么时间段会被识别为夜班。',
                    onClose: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 12),
                  NoticeCard(
                    icon: Icons.nightlight_round,
                    title: '${_time(startMinute)} — ${_time(endMinute)}',
                    body:
                        '当前按 ${state.nightRule.mode.label} 计算；跨天班次只要落在这个区间，就会按夜班规则参与计算。',
                  ),
                  const SizedBox(height: 12),
                  LedgerCard(
                    color: LedgerColors.surfaceRaised,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '夜班判定时段',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '建议保持整点，便于和班次模板保持一致。',
                          style: TextStyle(
                            color: LedgerColors.muted,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: LedgerPickerButtonField(
                                label: '开始时间',
                                value: _time(startMinute),
                                icon: Icons.bedtime_outlined,
                                onTap: () async {
                                  final picked = await showLedgerTimePicker(
                                    context,
                                    initialMinute: startMinute,
                                    minuteInterval: 60,
                                  );
                                  if (picked == null || !context.mounted) return;
                                  setSheetState(() => startMinute = picked);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: LedgerPickerButtonField(
                                label: '结束时间',
                                value: _time(endMinute),
                                icon: Icons.wb_sunny_outlined,
                                onTap: () async {
                                  final picked = await showLedgerTimePicker(
                                    context,
                                    initialMinute: endMinute,
                                    minuteInterval: 60,
                                  );
                                  if (picked == null || !context.mounted) return;
                                  setSheetState(() => endMinute = picked);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        state.updateNightRule(
                          state.nightRule.copyWith(
                            startMinute: startMinute,
                            endMinute: endMinute,
                          ),
                        );
                        Navigator.pop(context);
                      },
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
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
                  SheetHeaderBlock(
                    title: '发薪周期',
                    subtitle: '发薪周期会影响首页“本周期进度”、汇总默认范围和导出时的账本理解方式。',
                    onClose: () => Navigator.pop(context),
                    closeLabel: '取消',
                  ),
                  const SizedBox(height: 12),
                  NoticeCard(
                    icon: Icons.calendar_view_month_outlined,
                    title: _payPeriodLabel(
                      PayPeriod(mode: mode, monthStartDay: monthStartDay),
                    ),
                    body: mode == PayPeriodMode.monthlyStartDay
                        ? '短月会自动落到当月最后一天，适合按公司结薪日查看整个周期。'
                        : '自然月更适合个人记账；每月 1 日到月底自动形成一个周期。',
                  ),
                  const SizedBox(height: 12),
                  LedgerCard(
                    color: LedgerColors.surfaceRaised,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '周期模式',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SegmentedButton<PayPeriodMode>(
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
                    ),
                    const SizedBox(height: 10),
                        LedgerPickerButtonField(
                          label: '每月起始日',
                          value: '$monthStartDay 日',
                          helperText: '29、30、31 遇到短月时自动按当月最后一天计算。',
                          icon: Icons.event_repeat_outlined,
                          enabled: mode == PayPeriodMode.monthlyStartDay,
                          onTap: () async {
                            final picked = await showLedgerMonthDayPicker(
                              context,
                              initialDay: monthStartDay,
                            );
                            if (picked != null && context.mounted) {
                              setSheetState(() => monthStartDay = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        state.updatePayPeriod(
                          PayPeriod(mode: mode, monthStartDay: monthStartDay),
                        );
                        Navigator.pop(context);
                      },
                      child: const Text('保存'),
                    ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SheetHeaderBlock(
                  title: '本地备份/恢复',
                  subtitle: '本地备份适合手动留档；恢复会覆盖当前记录、模板和规则，但不包含 WebDAV 应用授权密码。',
                  onClose: () => Navigator.pop(context),
                ),
                const SizedBox(height: 12),
                const NoticeCard(
                  icon: Icons.save_alt_rounded,
                  title: '会保留一份 App 私有最近备份',
                  body: '即使你取消系统文件保存，这份最近备份也会留在 App 内，用于“从最近本地备份恢复”。',
                ),
                const SizedBox(height: 12),
                LedgerCard(
                  color: LedgerColors.surfaceRaised,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '创建备份',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '会导出 JSON 文件，并同时更新一份最近本地备份，方便误操作后快速恢复。',
                        style: TextStyle(
                          color: LedgerColors.muted,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: repository == null
                              ? null
                              : () => _writeBackup(context),
                          child: const Text('创建本地备份'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                LedgerCard(
                  color: LedgerColors.surfaceRaised,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '恢复最近本地备份',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '适合快速撤销大改动。恢复前建议先再导出一份当前数据，避免把最近录入内容覆盖掉。',
                        style: TextStyle(
                          color: LedgerColors.muted,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: repository == null
                              ? null
                              : () => _restoreLatestBackup(context),
                          child: const Text('从最近本地备份恢复'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
      final confirmed = await showLedgerConfirmDialog(
        context,
        title: '恢复备份？',
        message: '将用 $path 覆盖当前账本。',
        confirmText: '确认恢复',
        icon: Icons.restore_page_outlined,
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
                SheetHeaderBlock(
                  title: '最近删除',
                  subtitle: '用于找回误删的整天记录；恢复会把删除的分段放回原日期，不覆盖后来新增记录。',
                  onClose: () => Navigator.pop(context),
                ),
                const SizedBox(height: 12),
                if (deletedDays.isEmpty)
                  const NoticeCard(
                    icon: Icons.delete_sweep_outlined,
                    title: '没有可恢复记录',
                    body: '整天删除后才会出现在这里；单段删除不会进入最近删除列表。',
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
    final confirmed = await showLedgerConfirmDialog(
      context,
      title: '恢复 ${ymd(item.day)}？',
      message: existingCount == 0
          ? '会恢复 ${item.segmentCount} 段、合计 ${hoursText(item.totalHours)}。'
          : '这一天现在已有 $existingCount 段。恢复会把删除的 ${item.segmentCount} 段合并回来，不覆盖现有记录。',
      confirmText: '确认恢复',
      icon: Icons.restore_from_trash_outlined,
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
    bool destructive = false,
    IconData? icon,
  }) => showLedgerConfirmDialog(
    context,
    title: title,
    message: content,
    confirmText: confirmText,
    destructive: destructive,
    icon: icon,
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
    final compact =
        MediaQuery.of(context).size.width < 520 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final isDefaultTemplate = _template == widget.state.templates.first;
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
              SheetHeaderBlock(
                title: '班次模板',
                subtitle: '常用班次会用于新增工时记录；修改后不会回写已经保存的历史记录。',
                onClose: () => Navigator.pop(context),
              ),
              const SizedBox(height: 12),
              LedgerCard(
                color: LedgerColors.surfaceRaised,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '正在编辑',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        if (isDefaultTemplate)
                          _templateFlag(
                            label: '默认',
                            background: LedgerColors.primaryBlueSoft,
                            foreground: LedgerColors.primaryBlue,
                          ),
                        if (_template.isBuiltIn) ...[
                          const SizedBox(width: 6),
                          _templateFlag(
                            label: '内置',
                            background: LedgerColors.surfaceSoft,
                            foreground: LedgerColors.muted,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _template.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_time(_template.startMinute)} — ${_time(_template.endMinute)} · ${_template.type.label}',
                      style: const TextStyle(
                        color: LedgerColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '当前共 ${widget.state.templates.length} 个模板，可快速切换后继续编辑。',
                            style: const TextStyle(
                              color: LedgerColors.muted,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _pickTemplate,
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: const Text('切换模板'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _createTemplate,
                        icon: const Icon(Icons.add),
                        label: const Text('基于当前模板新增副本'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LedgerCard(
                color: LedgerColors.surfaceRaised,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '基础信息',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: '模板名称'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _location,
                      decoration: const InputDecoration(
                        labelText: '地点/岗位默认值',
                        helperText: '新增记录时自动带入；没有固定地点就留空。',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _break,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '休息分钟'),
                    ),
                    const SizedBox(height: 10),
                    EntryTypeSegmentedField(
                      label: '班次类型',
                      helperText: '直接决定记录回看时显示为普通、加班段还是夜班。',
                      value: _type,
                      onChanged: (value) => setState(() => _type = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LedgerCard(
                color: LedgerColors.surfaceRaised,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '时间与默认金额',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    _buildFieldPair(
                      compact: compact,
                      first: TextField(
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
                      second: TextField(
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
                    const SizedBox(height: 10),
                    _buildFieldPair(
                      compact: compact,
                      first: TextField(
                        controller: _allowance,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '默认补贴',
                          helperText: '默认 0',
                        ),
                      ),
                      second: TextField(
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
              ),
              const SizedBox(height: 12),
              LedgerCard(
                color: LedgerColors.surfaceRaised,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '模板操作',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _template.isBuiltIn
                          ? '内置模板不能删除；如果改乱了，可以只恢复当前这个模板。'
                          : '自定义模板可以删除；已保存的历史记录不会受影响。',
                      style: const TextStyle(
                        color: LedgerColors.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_template.isBuiltIn)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _confirmRestoreCurrentTemplate,
                          icon: const Icon(Icons.restore_outlined),
                          label: const Text('恢复当前内置模板'),
                        ),
                      ),
                    if (_template.isBuiltIn) const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: LedgerColors.errorBrick,
                        ),
                        onPressed:
                            _template.isBuiltIn ||
                                widget.state.templates.length <= 1
                            ? null
                            : _confirmDeleteTemplate,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('删除模板'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildFieldPair(
                      compact: compact,
                      first: OutlinedButton(
                        onPressed: isDefaultTemplate ? null : _setAsDefault,
                        child: Text(isDefaultTemplate ? '当前已是默认' : '设为默认'),
                      ),
                      second: FilledButton(
                        onPressed: _save,
                        child: const Text('保存模板'),
                      ),
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

  Widget _buildFieldPair({
    required bool compact,
    required Widget first,
    required Widget second,
  }) {
    if (compact) {
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

  Future<void> _pickTemplate() async {
    final selected = await showModalBottomSheet<ShiftTemplate>(
      context: context,
      backgroundColor: LedgerColors.paper,
      isScrollControlled: true,
      builder: (context) {
        final templates = widget.state.templates;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SheetHeaderBlock(
                    title: '选择模板',
                    subtitle: '切换后继续编辑，不会影响已经保存的历史记录。',
                    onClose: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: templates.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final tpl = templates[index];
                        final isSelected = tpl.id == _template.id;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => Navigator.pop(context, tpl),
                            child: LedgerCard(
                              color: isSelected
                                  ? LedgerColors.primaryBlueSoft
                                  : LedgerColors.surfaceRaised,
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? LedgerColors.primaryBlue
                                          : LedgerColors.surfaceSoft,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isSelected
                                          ? Icons.check_rounded
                                          : Icons.schedule_outlined,
                                      color: isSelected
                                          ? Colors.white
                                          : LedgerColors.primaryBlue,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                tpl.name,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                            ),
                                            if (tpl == templates.first)
                                              _templateFlag(
                                                label: '默认',
                                                background:
                                                    LedgerColors.primaryBlueSoft,
                                                foreground:
                                                    LedgerColors.primaryBlue,
                                              ),
                                            if (tpl.isBuiltIn) ...[
                                              const SizedBox(width: 6),
                                              _templateFlag(
                                                label: '内置',
                                                background:
                                                    LedgerColors.surfaceSoft,
                                                foreground: LedgerColors.muted,
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_time(tpl.startMinute)} — ${_time(tpl.endMinute)} · ${tpl.type.label} · 休息 ${tpl.breakMinutes} 分钟',
                                          style: const TextStyle(
                                            color: LedgerColors.muted,
                                            fontSize: 13,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() {
      _template = selected;
      _load(selected);
    });
  }

  Widget _templateFlag({
    required String label,
    required Color background,
    required Color foreground,
  }) {
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

  Future<void> _confirmRestoreCurrentTemplate() async {
    if (!_template.isBuiltIn) return;
    final confirmed = await showLedgerConfirmDialog(
      context,
      title: '恢复当前模板？',
      message: '会把“${_template.name}”恢复成系统默认值；你自己新增的模板不会被改动。',
      confirmText: '确认恢复',
      icon: Icons.restore_outlined,
    );
    if (confirmed != true || !mounted) return;
    final restored = widget.state.restoreShiftTemplate(_template.id);
    if (!restored) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前模板不支持恢复默认')));
      return;
    }
    setState(() {
      _template = widget.state.templates.firstWhere(
        (template) => template.id == _template.id,
      );
      _load(_template);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已恢复“${_template.name}”默认模板')));
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
    final confirmed = await showLedgerConfirmDialog(
      context,
      title: '删除模板？',
      message: '只删除“${_template.name}”这个模板，已经保存的工时记录不会被删除。',
      confirmText: '确认删除',
      destructive: true,
      icon: Icons.delete_outline,
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
    final compact =
        MediaQuery.of(context).size.width < 520 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final effectiveLabel = _effective.text.trim().isEmpty
        ? ymd(widget.initialRule.effectiveFrom)
        : _effective.text.trim();
    final basePreview = switch (_type) {
      PayBaseType.hourly =>
        '按小时 · ${_hourly.text.trim().isEmpty ? moneyText(widget.initialRule.hourlyRate) : '¥${_hourly.text.trim()}/h'}',
      PayBaseType.daily =>
        '按天 · ${_daily.text.trim().isEmpty ? moneyText(widget.initialRule.dailyRate) : '¥${_daily.text.trim()}/天'}',
      PayBaseType.monthly =>
        '按月 · ${_monthly.text.trim().isEmpty ? moneyText(widget.initialRule.monthlyRate) : '¥${_monthly.text.trim()}/月'}',
    };
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
              SheetHeaderBlock(
                title: '计薪规则',
                subtitle: '这套规则只影响工资计算；记录是否显示为加班，取决于你选择的班次类型或加班模板。',
                onClose: () => Navigator.pop(context),
                closeLabel: '取消',
              ),
              const SizedBox(height: 12),
              NoticeCard(
                icon: Icons.payments_outlined,
                title: _name.text.trim().isEmpty
                    ? widget.initialRule.name
                    : _name.text.trim(),
                body: '$basePreview · $effectiveLabel 起',
              ),
              const SizedBox(height: 12),
              LedgerCard(
                color: LedgerColors.surfaceRaised,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '版本信息',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    _buildFieldPair(
                      compact: compact,
                      first: TextField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: '规则名称'),
                      ),
                      second: TextField(
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
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LedgerCard(
                color: LedgerColors.surfaceRaised,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '计薪基础',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '先确定按小时 / 按天 / 按月，再填写对应的基础单价。',
                      style: TextStyle(
                        color: LedgerColors.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<PayBaseType>(
                        selected: {_type},
                        segments: const [
                          ButtonSegment(
                            value: PayBaseType.hourly,
                            label: Text('按小时'),
                          ),
                          ButtonSegment(
                            value: PayBaseType.daily,
                            label: Text('按天'),
                          ),
                          ButtonSegment(
                            value: PayBaseType.monthly,
                            label: Text('按月'),
                          ),
                        ],
                        onSelectionChanged: (values) =>
                            setState(() => _type = values.first),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_type == PayBaseType.hourly)
                      TextField(
                        controller: _hourly,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '小时工资 ¥/h',
                        ),
                      ),
                    if (_type == PayBaseType.daily) ...[
                      TextField(
                        controller: _daily,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '每日工资 ¥/天',
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<DailyPayMode>(
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
                      ),
                    ],
                    if (_type == PayBaseType.monthly)
                      TextField(
                        controller: _monthly,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '月薪 ¥/月'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LedgerCard(
                color: LedgerColors.surfaceRaised,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '补充规则',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '这些设置会影响工资拆分与休息日结算，但不会把普通班次自动改成“加班段”。',
                      style: TextStyle(
                        color: LedgerColors.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildFieldPair(
                      compact: compact,
                      first: TextField(
                        controller: _standard,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '普通工时上限 h/天',
                        ),
                      ),
                      second: TextField(
                        controller: _overtime,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '计薪加班倍率'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildFieldPair(
                      compact: compact,
                      first: TextField(
                        controller: _overtimeBase,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '计薪加班基准 ¥/h',
                        ),
                      ),
                      second: TextField(
                        controller: _restDayMultiplier,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '休息日倍率'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const NoticeCard(
                icon: Icons.history_toggle_off_rounded,
                title: '保存后会生成新版本',
                body: '旧记录继续使用记录内规则快照，避免历史工资被新规则回写。',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _save, child: const Text('保存')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldPair({
    required bool compact,
    required Widget first,
    required Widget second,
  }) {
    if (compact) {
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
  bool _showPassword = false;

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
    final displayStatus = _displayAutoBackupStatus();
    final connectionStatus = _backupStatusDisplay(
      webDavConfig: _config(),
      autoConfig: widget.state.autoBackupConfig.copyWith(lastStatus: displayStatus),
    );
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
              SheetHeaderBlock(
                title: '坚果云 WebDAV',
                subtitle: '手动备份即时执行；也可以开启省流量自动云备份。应用授权密码不会写入普通备份。',
                onClose: () => Navigator.pop(context),
              ),
              const SizedBox(height: 12),
              const NoticeCard(
                icon: Icons.cloud_sync_outlined,
                title: '推荐使用应用授权密码',
                body: '比账号主密码更安全；普通本地备份和导出文件都不会包含这项敏感信息。',
              ),
              const SizedBox(height: 12),
              NoticeCard(
                icon: _config().isConfigured
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                title: '连接状态',
                body: '${connectionStatus.summary}。${connectionStatus.detail}',
                iconBackgroundColor: _config().isConfigured
                    ? LedgerColors.successGreenSoft
                    : LedgerColors.warningOrangeSoft,
                iconColor: _config().isConfigured
                    ? LedgerColors.successGreen
                    : LedgerColors.warningOrange,
              ),
              const SizedBox(height: 12),
              LedgerCard(
                color: LedgerColors.surfaceRaised,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '连接信息',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _url,
                      decoration: const InputDecoration(
                        labelText: '服务器地址',
                        helperText: '坚果云一般是 https://dav.jianguoyun.com/dav/',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _username,
                      decoration: const InputDecoration(
                        labelText: '账号',
                        helperText: '通常是坚果云登录邮箱或用户名。',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _password,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: '应用授权密码',
                        helperText: '建议使用应用授权密码，而不是账号主密码。',
                        suffixIcon: IconButton(
                          tooltip: _showPassword ? '隐藏密码' : '显示密码',
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _remotePath,
                      decoration: const InputDecoration(
                        labelText: '远端备份文件名',
                        helperText: '例如 shift-ledger-backup.json，可按账本区分。',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildAutoBackupSection(context),
              const SizedBox(height: 12),
              LedgerCard(
                color: LedgerColors.surfaceRaised,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '手动操作',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '先保存配置，再按需手动备份、恢复或查看云端文件列表。',
                      style: TextStyle(
                        color: LedgerColors.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _busy ? null : _save,
                            child: const Text('保存配置'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _backup,
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text('备份到坚果云'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _restore,
                            icon: const Icon(Icons.cloud_download_outlined),
                            label: const Text('从坚果云恢复'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _list,
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: const Text('导入/导出列表'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
    final confirmed = await showLedgerConfirmDialog(
      context,
      title: '备份到坚果云？',
      message: '会把当前记录、班次模板、计薪规则和非敏感设置上传到远端备份文件。',
      confirmText: '确认备份',
      icon: Icons.cloud_upload_outlined,
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

  Future<bool?> _confirmRestore() => showLedgerConfirmDialog(
    context,
    title: '从坚果云恢复？',
    message: '这会用远端备份覆盖当前记录、模板和规则；应用授权密码不会随备份恢复，需要重新输入。',
    confirmText: '确认恢复',
    icon: Icons.cloud_download_outlined,
  );

  Future<void> _list() async {
    await _run(() async {
      final config = _config();
      final listing = await WebDavClient().listBackups(config);
      if (!mounted) return;
      showLedgerInfoDialog(
        context,
        title: '导入/导出列表',
        icon: Icons.inventory_2_outlined,
        content: Text(
          listing.length > 1200 ? '${listing.substring(0, 1200)}…' : listing,
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
