import 'dart:convert';

import 'package:flutter/material.dart';

import '../app/ledger_state.dart';
import '../domain/models.dart';
import '../services/backup_service.dart';
import '../services/webdav_client.dart';
import 'theme.dart';
import 'widgets.dart';

class BackupStatusDisplay {
  const BackupStatusDisplay({required this.summary, required this.detail});

  final String summary;
  final String detail;
}

BackupStatusDisplay buildBackupStatusDisplay({
  required WebDavConfig webDavConfig,
  required AutoBackupConfig autoConfig,
}) {
  if (!webDavConfig.isConfigured) {
    final hasPartialConfig =
        webDavConfig.url.isNotEmpty || webDavConfig.username.isNotEmpty;
    return BackupStatusDisplay(
      summary: hasPartialConfig ? '需重新授权或补全配置' : '未连接；可配置坚果云备份',
      detail: hasPartialConfig ? 'WebDAV 信息不完整，自动备份不会运行。' : '还没有连接坚果云。',
    );
  }
  if (!autoConfig.enabled) {
    return BackupStatusDisplay(
      summary: '已连接；未开启自动备份',
      detail: '${webDavConfig.username} · ${webDavConfig.remotePath}',
    );
  }
  return switch (autoConfig.lastStatus) {
    AutoBackupStatus.success => BackupStatusDisplay(
      summary: autoConfig.lastSuccessAt == null
          ? '自动备份正常'
          : '自动备份正常；最近成功 ${dateTimeText(autoConfig.lastSuccessAt!)}',
      detail: '云端文件 ${webDavConfig.remotePath}',
    ),
    AutoBackupStatus.skipped => BackupStatusDisplay(
      summary: '内容未变化，已跳过',
      detail: autoConfig.lastAttemptAt == null
          ? '自动备份已开启。'
          : '最近检查 ${dateTimeText(autoConfig.lastAttemptAt!)}',
    ),
    AutoBackupStatus.waiting => BackupStatusDisplay(
      summary: autoConfig.lastSuccessAt == null
          ? '自动备份等待中'
          : '等待下次自动备份；最近成功 ${dateTimeText(autoConfig.lastSuccessAt!)}',
      detail: '内容有变化且距离上次成功超过 1 小时才会自动上传。',
    ),
    AutoBackupStatus.configIncomplete => const BackupStatusDisplay(
      summary: '需重新授权或补全配置',
      detail: '自动备份已开启，但 WebDAV 配置不完整。',
    ),
    AutoBackupStatus.failed => BackupStatusDisplay(
      summary: autoConfig.lastError.isEmpty
          ? '最近自动备份失败'
          : '最近失败：${autoConfig.lastError}',
      detail: autoConfig.lastAttemptAt == null
          ? '请检查账号、应用授权密码和网络。'
          : '失败时间 ${dateTimeText(autoConfig.lastAttemptAt!)}',
    ),
    AutoBackupStatus.idle => const BackupStatusDisplay(
      summary: '自动备份已开；等待首次备份',
      detail: '打开 App 或账本变化后会自动检查。',
    ),
  };
}

String? decodeWarningMessage(BackupDecodeDiagnostics diagnostics) {
  if (!diagnostics.hasWarnings) return null;
  return '已忽略 ${diagnostics.summary}';
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
    _remotePath = TextEditingController(
      text: config.remotePath.isEmpty
          ? defaultWebDavRemotePath
          : config.remotePath,
    );
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
    final connectionStatus = buildBackupStatusDisplay(
      webDavConfig: _config(),
      autoConfig: widget.state.autoBackupConfig.copyWith(
        lastStatus: displayStatus,
      ),
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
                subtitle: '应用授权密码不会写入普通备份。',
                onClose: () => Navigator.pop(context),
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
                        hintText: 'https://dav.jianguoyun.com/dav/',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _username,
                      decoration: const InputDecoration(
                        labelText: '账号',
                        hintText: '登录邮箱或用户名',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _password,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: '应用授权密码',
                        hintText: '使用应用授权密码',
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
                        hintText: defaultWebDavRemotePath,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('保存配置'),
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
                    const SizedBox(height: 10),
                    Column(
                      children: [
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
        ? defaultWebDavRemotePath
        : _remotePath.text.trim(),
  );

  Widget _buildAutoBackupSection(BuildContext context) {
    final autoConfig = widget.state.autoBackupConfig;
    final displayStatus = _displayAutoBackupStatus();
    final backupStatus = buildBackupStatusDisplay(
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
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            value: autoConfig.enabled,
            title: const Text('自动云备份'),
            subtitle: const Text('打开 App 或账本变化后自动检查 · 1 小时内不重复上传'),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusLine(label: '当前状态', value: backupStatus.summary),
                _StatusLine(label: '云端文件', value: _config().remotePath),
                _StatusLine(
                  label: '上次自动备份',
                  value: autoConfig.lastSuccessAt == null
                      ? '尚未自动备份'
                      : dateTimeText(autoConfig.lastSuccessAt!),
                ),
                if (autoConfig.lastStatus == AutoBackupStatus.failed &&
                    autoConfig.lastError.isNotEmpty)
                  _StatusLine(label: '失败原因', value: autoConfig.lastError),
                if (backupStatus.detail.isNotEmpty)
                  _StatusLine(label: '状态说明', value: backupStatus.detail),
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
      final decodeResult = BackupService().decodeWithReport(
        jsonDecode(payload) as Map<String, Object?>,
      );
      widget.state.updateWebDavConfig(config);
      widget.state.restore(decodeResult.snapshot);
      final warning = decodeWarningMessage(decodeResult.diagnostics);
      _snack(
        warning == null
            ? '已从坚果云恢复，应用授权密码需重新输入'
            : '已从坚果云恢复，应用授权密码需重新输入；$warning',
      );
    });
  }

  Future<bool?> _confirmRestore() => showLedgerConfirmDialog(
    context,
    title: '从坚果云恢复？',
    message: '这会用远端备份覆盖当前记录、模板和规则；应用授权密码不会随备份恢复，需要重新输入。',
    confirmText: '确认恢复',
    icon: Icons.cloud_download_outlined,
  );

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
    showLedgerSnackBar(context, message);
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
