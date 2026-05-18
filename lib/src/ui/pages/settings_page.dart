import 'package:flutter/material.dart';

import '../../app/ledger_state.dart';
import '../../domain/models.dart';
import '../../services/csv_exporter.dart';
import '../../services/local_ledger_repository.dart';
import '../pickers.dart';
import '../settings_backup.dart';
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
    final backupStatus = buildBackupStatusDisplay(
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
                title: '夜班规则',
                subtitle: state.nightRule.label,
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
                trailing: '导出',
                onTap: () => _exportCsv(context),
              ),
              SettingTile(
                title: '本地备份/恢复',
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
                  '历史记录沿用保存时快照。',
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
        builder: (context, setSheetState) {
          final invalidTimeOrder = startMinute == endMinute;
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
                      title: '夜班规则',
                      onClose: () => Navigator.pop(context),
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
                          const SizedBox(height: 4),
                          Text(
                            '${state.nightRule.mode.label} · 跨天记录按该区间判定',
                            style: const TextStyle(
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
                                    if (picked == null || !context.mounted) {
                                      return;
                                    }
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
                                    if (picked == null || !context.mounted) {
                                      return;
                                    }
                                    setSheetState(() => endMinute = picked);
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (invalidTimeOrder) ...[
                            const SizedBox(height: 8),
                            const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.error_outline_rounded,
                                    size: 16,
                                    color: LedgerColors.errorRed,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Expanded(
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
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: invalidTimeOrder
                            ? null
                            : () {
                                final rootContext = Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).context;
                                state.updateNightRule(
                                  state.nightRule.copyWith(
                                    startMinute: startMinute,
                                    endMinute: endMinute,
                                  ),
                                );
                                Navigator.pop(context);
                                showLedgerSnackBar(rootContext, '夜班规则已保存');
                              },
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
                    onClose: () => Navigator.pop(context),
                    closeLabel: '取消',
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
                        const SizedBox(height: 4),
                        Text(
                          _payPeriodLabel(
                            PayPeriod(mode: mode, monthStartDay: monthStartDay),
                          ),
                          style: const TextStyle(
                            color: LedgerColors.muted,
                            fontSize: 13,
                            height: 1.35,
                          ),
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
                        if (mode == PayPeriodMode.monthlyStartDay) ...[
                          const SizedBox(height: 10),
                          LedgerPickerButtonField(
                            label: '每月起始日',
                            value: '$monthStartDay 日',
                            helperText: '29、30、31 遇到短月时自动按当月最后一天计算。',
                            icon: Icons.event_repeat_outlined,
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final rootContext = Navigator.of(
                          context,
                          rootNavigator: true,
                        ).context;
                        state.updatePayPeriod(
                          PayPeriod(mode: mode, monthStartDay: monthStartDay),
                        );
                        Navigator.pop(context);
                        showLedgerSnackBar(rootContext, '发薪周期已保存');
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
        showLedgerSnackBar(context, 'CSV 已生成：${csv.length} 字符');
        return;
      }
      final path = await repository!.writeCsv(csv);
      if (context.mounted) {
        showLedgerSnackBar(
          context,
          path == null ? '已取消保存 CSV' : 'CSV 已保存：$path',
        );
      }
    } catch (_) {
      if (context.mounted) {
        showLedgerSnackBar(context, 'CSV 已生成但保存失败，请重试或更换保存位置');
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
                  subtitle: '恢复会覆盖当前记录、模板和规则。',
                  onClose: () => Navigator.pop(context),
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
                        '会导出 JSON，并同步更新最近本地备份。',
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
                        '恢复本地备份',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '可快速回退最近备份，也支持选择其他手机导出的 JSON 备份文件。',
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
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: repository == null
                              ? null
                              : () => _restoreFromPickedBackup(context),
                          child: const Text('选择备份文件恢复'),
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
        showLedgerSnackBar(
          context,
          path == null ? '已创建 App 私有备份；外部保存已取消' : '本地备份已保存：$path',
        );
      }
    } catch (_) {
      if (context.mounted) {
        showLedgerSnackBar(context, '本地备份创建失败，请重试或更换保存位置');
      }
    }
  }

  Future<void> _restoreLatestBackup(BuildContext context) async {
    try {
      final path = await repository!.latestBackupPath();
      if (!context.mounted) return;
      if (path == null) {
        showLedgerSnackBar(context, '没有最近本地备份，请选择备份文件');
        await _restoreFromPickedBackup(context);
        return;
      }
      await _restoreBackupFromPath(context, path);
    } catch (_) {
      if (context.mounted) {
        showLedgerSnackBar(context, '读取本地备份失败，请确认备份文件仍可访问');
      }
    }
  }

  Future<void> _restoreFromPickedBackup(BuildContext context) async {
    try {
      final path = await repository!.pickBackupFilePath();
      if (!context.mounted || path == null) return;
      await _restoreBackupFromPath(context, path);
    } catch (_) {
      if (context.mounted) {
        showLedgerSnackBar(context, '读取备份文件失败，请确认选择的是可访问的 JSON 备份');
      }
    }
  }

  Future<void> _restoreBackupFromPath(BuildContext context, String path) async {
    final confirmed = await showLedgerConfirmDialog(
      context,
      title: '恢复备份？',
      message: '将用 $path 覆盖当前账本。',
      confirmText: '确认恢复',
      icon: Icons.restore_page_outlined,
    );
    if (confirmed != true || !context.mounted) return;
    final backup = await repository!.readBackupResult(path);
    state.restore(backup.snapshot);
    if (!context.mounted) return;
    final warning = decodeWarningMessage(backup.diagnostics);
    showLedgerSnackBar(
      context,
      warning == null ? '已从本地备份恢复' : '已从本地备份恢复；$warning',
    );
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
                  onClose: () => Navigator.pop(context),
                ),
                const SizedBox(height: 12),
                if (deletedDays.isEmpty)
                  const NoticeCard(
                    icon: Icons.delete_sweep_outlined,
                    title: '没有可恢复记录',
                    body: '整天删除后会出现在这里。',
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
    final restored = state.restoreDeletedDay(item.id);
    if (!context.mounted) return;
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.pop(context);
    showLedgerSnackBar(
      rootContext,
      restored ? '已恢复 ${ymd(item.day)}' : '这条删除记录已不可恢复',
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
  String? _copyLockedTemplateId;

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
    final compact = useDenseTwoColumnLayout(context);
    final isDefaultTemplate = _template == widget.state.templates.first;
    final invalidTimeOrder = _hasEqualTimeOrder;
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
                subtitle: '新增记录时会优先带出这里的班次。',
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
                            '共 ${widget.state.templates.length} 套模板',
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
                          label: const Text('切换'),
                        ),
                      ],
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
                      '模板内容',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _name,
                      onChanged: (_) => _clearCopyLock(),
                      decoration: const InputDecoration(labelText: '模板名称'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _location,
                      onChanged: (_) => _clearCopyLock(),
                      decoration: const InputDecoration(labelText: '地点 / 岗位'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _break,
                      onChanged: (_) => _clearCopyLock(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '休息分钟'),
                    ),
                    const SizedBox(height: 10),
                    EntryTypeSegmentedField(
                      label: '班次类型',
                      value: _type,
                      onChanged: (value) => setState(() {
                        _type = value;
                        _clearCopyLock();
                      }),
                    ),
                    const SizedBox(height: 10),
                    _buildFieldPair(
                      compact: compact,
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
                    if (invalidTimeOrder) ...[
                      const SizedBox(height: 8),
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.error_outline_rounded,
                              size: 16,
                              color: LedgerColors.errorRed,
                            ),
                          ),
                          SizedBox(width: 6),
                          Expanded(
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
                    ],
                    const SizedBox(height: 10),
                    _buildFieldPair(
                      compact: compact,
                      first: TextField(
                        controller: _allowance,
                        onChanged: (_) => _clearCopyLock(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '补贴'),
                      ),
                      second: TextField(
                        controller: _deduction,
                        onChanged: (_) => _clearCopyLock(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '扣款'),
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
                          ? '内置模板可恢复默认，不能删除。'
                          : '删除不会影响已经保存的历史记录。',
                      style: const TextStyle(
                        color: LedgerColors.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildFieldPair(
                      compact: compact,
                      first: OutlinedButton.icon(
                        onPressed: _copyLockedTemplateId == _template.id
                            ? null
                            : _createTemplate,
                        icon: const Icon(Icons.add),
                        label: const Text('新增副本'),
                      ),
                      second: OutlinedButton.icon(
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
                    if (_template.isBuiltIn)
                      _buildFieldPair(
                        compact: compact,
                        first: OutlinedButton(
                          onPressed: isDefaultTemplate ? null : _setAsDefault,
                          child: Text(isDefaultTemplate ? '当前已是默认' : '设为默认'),
                        ),
                        second: OutlinedButton.icon(
                          onPressed: _confirmRestoreCurrentTemplate,
                          icon: const Icon(Icons.restore_outlined),
                          label: const Text('恢复当前内置模板'),
                        ),
                      ),
                    if (!_template.isBuiltIn)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: isDefaultTemplate ? null : _setAsDefault,
                          child: Text(isDefaultTemplate ? '当前已是默认' : '设为默认'),
                        ),
                      ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: invalidTimeOrder ? null : _save,
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
      _copyLockedTemplateId = copy.id;
      _load(copy);
    });
    _snack('已新增模板副本“${copy.name}”');
  }

  void _setAsDefault() {
    widget.state.setDefaultShiftTemplate(_template.id);
    setState(() {});
    _snack('已设“${_template.name}”为默认模板');
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
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleMedium,
                                              ),
                                            ),
                                            if (tpl == templates.first)
                                              _templateFlag(
                                                label: '默认',
                                                background: LedgerColors
                                                    .primaryBlueSoft,
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
      _copyLockedTemplateId = null;
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
      showLedgerSnackBar(context, '当前模板不支持恢复默认');
      return;
    }
    setState(() {
      _template = widget.state.templates.firstWhere(
        (template) => template.id == _template.id,
      );
      _load(_template);
    });
    showLedgerSnackBar(context, '已恢复“${_template.name}”默认模板');
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

  bool get _hasEqualTimeOrder {
    final start = _parseTime(_start.text) ?? _template.startMinute;
    final end = _parseTime(_end.text) ?? _template.endMinute;
    return start == end;
  }

  void _save() {
    if (_hasEqualTimeOrder) {
      _snack(equalTimeRangeErrorText);
      return;
    }
    final start = _parseTime(_start.text) ?? _template.startMinute;
    final end = _parseTime(_end.text) ?? _template.endMinute;
    final nextName = _name.text.trim().isEmpty
        ? _template.name
        : _name.text.trim();
    final defaultAdjustments = <Adjustment>[];
    final allowance = double.tryParse(_allowance.text) ?? 0;
    final deduction = double.tryParse(_deduction.text) ?? 0;
    if (allowance > 0) {
      defaultAdjustments.add(Adjustment.allowance('默认补贴', allowance));
    }
    if (deduction > 0) {
      defaultAdjustments.add(Adjustment.deduction('默认扣款', deduction));
    }
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    widget.state.updateShiftTemplate(
      _template.copyWith(
        name: nextName,
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
    showLedgerSnackBar(rootContext, '已保存模板“$nextName”');
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
      _snack('至少保留一个班次模板');
      return;
    }
    final deletedName = _template.name;
    setState(() {
      _template = widget.state.templates.first;
      _load(_template);
    });
    _snack('已删除模板“$deletedName”');
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final minute = _parseTime(controller.text) ?? _template.startMinute;
    final picked = await showLedgerTimePicker(context, initialMinute: minute);
    if (picked == null || !mounted) return;
    setState(() {
      controller.text = _time(picked);
      _clearCopyLock();
    });
  }

  void _clearCopyLock() {
    if (_copyLockedTemplateId == null) return;
    _copyLockedTemplateId = null;
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

  void _snack(String message) {
    showLedgerSnackBar(context, message);
  }
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
    final compact = useDenseTwoColumnLayout(context);
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
                      second: LedgerPickerButtonField(
                        label: '生效日期',
                        value: _effective.text,
                        icon: Icons.calendar_month_outlined,
                        onTap: _pickEffectiveDate,
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
    final rootContext = Navigator.of(context, rootNavigator: true).context;
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
    showLedgerSnackBar(rootContext, '计薪规则已保存');
  }

  Future<void> _pickEffectiveDate() async {
    final current = DateTime.tryParse(_effective.text);
    final picked = await showLedgerDatePicker(
      context,
      initialDate: current ?? widget.initialRule.effectiveFrom,
    );
    if (picked == null || !mounted) return;
    setState(() => _effective.text = ymd(picked));
  }
}
