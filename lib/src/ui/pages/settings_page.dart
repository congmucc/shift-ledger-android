import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/ledger_state.dart';
import '../../domain/models.dart';
import '../../services/backup_service.dart';
import '../../services/csv_exporter.dart';
import '../../services/local_ledger_repository.dart';
import '../../services/webdav_client.dart';
import '../theme.dart';
import '../widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.state, this.repository});
  final LedgerState state;
  final LocalLedgerRepository? repository;

  @override
  Widget build(BuildContext context) {
    final rule = state.defaultRule;
    return PageFrame(
      title: '设置',
      children: [
        const Text('个人工时账本', style: TextStyle(color: LedgerColors.muted)),
        const SectionHeader(title: '常用规则'),
        LedgerCard(
          child: Column(
            children: [
              SettingTile(
                title: '早班模板',
                subtitle: '09:00-18:00 · 休 60 分钟',
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
                subtitle: state.webDavConfig.isConfigured
                    ? '${state.webDavConfig.username} · ${state.webDavConfig.remotePath}'
                    : '恢复后需重新授权',
                trailing: '连接',
                onTap: () => showWebDavSheet(context, state),
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
      backgroundColor: LedgerColors.paper,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('班次模板', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              for (final tpl in state.templates)
                SettingTile(
                  title: tpl.name,
                  subtitle:
                      '${_time(tpl.startMinute)}-${_time(tpl.endMinute)} · 休 ${tpl.breakMinutes} 分钟',
                  trailing: tpl.type.label,
                ),
            ],
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
      backgroundColor: LedgerColors.paper,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      startMinute: (int.tryParse(start.text) ?? 22) * 60,
                      endMinute: (int.tryParse(end.text) ?? 6) * 60,
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
    final startDay = TextEditingController(
      text: state.payPeriod.monthStartDay.toString(),
    );
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: LedgerColors.paper,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                TextField(
                  controller: startDay,
                  enabled: mode == PayPeriodMode.monthlyStartDay,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '每月起始日（1-28）'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    state.updatePayPeriod(
                      PayPeriod(
                        mode: mode,
                        monthStartDay: (int.tryParse(startDay.text) ?? 1).clamp(
                          1,
                          28,
                        ),
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
    startDay.dispose();
  }

  Future<void> _exportCsv(BuildContext context) async {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('CSV 已导出：$path')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV 已生成：${csv.length} 字符；当前预览环境不支持写入文件')),
        );
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
    try {
      final path = await repository!.writeBackup(state.toSnapshot());
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('本地备份已创建：$path')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前预览环境不支持写入本地备份')));
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
        ).showSnackBar(const SnackBar(content: Text('当前预览环境不支持读取本地备份')));
      }
    }
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
                decoration: const InputDecoration(labelText: '生效日期 YYYY-MM-DD'),
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
      hourlyRate: double.tryParse(_hourly.text) ?? initial.hourlyRate,
      dailyRate: double.tryParse(_daily.text) ?? initial.dailyRate,
      monthlyRate: double.tryParse(_monthly.text) ?? initial.monthlyRate,
      dailyPayMode: _dailyPayMode,
      effectiveFrom:
          DateTime.tryParse(_effective.text) ?? initial.effectiveFrom,
      standardHoursPerDay:
          double.tryParse(_standard.text) ?? initial.standardHoursPerDay,
      overtimeMultiplier:
          double.tryParse(_overtime.text) ?? initial.overtimeMultiplier,
      overtimeBaseHourlyRate: double.tryParse(_overtimeBase.text) ?? 0,
      restDayMultiplier:
          double.tryParse(_restDayMultiplier.text) ?? initial.restDayMultiplier,
      version: initial.version + 1,
      isDefault: true,
    );
    widget.state.savePayRule(rule);
    Navigator.pop(context);
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
              final configured = _config().isConfigured;
              setState(() {
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
    if (confirmed != true) return;
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

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
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
