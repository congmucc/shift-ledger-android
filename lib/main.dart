import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/app/ledger_state.dart';
import 'src/services/auto_backup_service.dart';
import 'src/services/local_ledger_repository.dart';
import 'src/ui/scope.dart';
import 'src/ui/shell.dart';
import 'src/ui/theme.dart';
import 'src/ui/widgets.dart';

class AppStartupNotice {
  const AppStartupNotice({required this.title, required this.message});

  final String title;
  final String message;
}

class AppBootstrapResult {
  const AppBootstrapResult({
    required this.state,
    required this.repository,
    this.startupNotice,
  });

  final LedgerState state;
  final LocalLedgerRepository repository;
  final AppStartupNotice? startupNotice;
}

Future<AppBootstrapResult> bootstrapShiftLedgerApp({
  LocalLedgerRepository? repository,
  DateTime? now,
}) async {
  final resolvedRepository = repository ?? LocalLedgerRepository();
  try {
    final loaded = await resolvedRepository.loadDetailed();
    if (loaded == null) {
      return AppBootstrapResult(
        state: LedgerState.empty(now: now),
        repository: resolvedRepository,
      );
    }

    return AppBootstrapResult(
      state: LedgerState.fromSnapshot(loaded.snapshot, now: now),
      repository: resolvedRepository,
      startupNotice: loaded.diagnostics.hasWarnings
          ? AppStartupNotice(
              title: '已载入可读取数据',
              message:
                  '本地账本里有部分内容损坏，已自动忽略 ${loaded.diagnostics.summary}。建议尽快到“设置 > 本地备份/恢复”检查最近备份。',
            )
          : null,
    );
  } catch (_) {
    final latestBackupPath = await _safeLatestBackupPath(resolvedRepository);
    return AppBootstrapResult(
      state: LedgerState.empty(now: now),
      repository: resolvedRepository,
      startupNotice: AppStartupNotice(
        title: '本地账本读取失败',
        message: latestBackupPath == null
            ? '当前先以空账本打开，避免继续写入损坏数据。请先不要卸载应用，并尽快到“设置 > 本地备份/恢复”检查是否还能导出或恢复备份。'
            : '当前先以空账本打开，避免继续写入损坏数据。检测到最近本地备份，可到“设置 > 本地备份/恢复”尝试恢复。',
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await bootstrapShiftLedgerApp();
  runApp(
    ShiftLedgerApp(
      state: bootstrap.state,
      repository: bootstrap.repository,
      startupNotice: bootstrap.startupNotice,
    ),
  );
}

Future<String?> _safeLatestBackupPath(LocalLedgerRepository repository) async {
  try {
    return await repository.latestBackupPath();
  } catch (_) {
    return null;
  }
}

class ShiftLedgerApp extends StatefulWidget {
  const ShiftLedgerApp({
    super.key,
    required this.state,
    this.repository,
    this.autoBackupService = const AutoBackupService(),
    this.autoBackupStartupDelay = const Duration(seconds: 20),
    this.autoBackupChangeDebounce = const Duration(minutes: 10),
    this.startupNotice,
  });

  final LedgerState state;
  final LocalLedgerRepository? repository;
  final AutoBackupService autoBackupService;
  final Duration autoBackupStartupDelay;
  final Duration autoBackupChangeDebounce;
  final AppStartupNotice? startupNotice;

  @override
  State<ShiftLedgerApp> createState() => _ShiftLedgerAppState();
}

class _ShiftLedgerAppState extends State<ShiftLedgerApp> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  Timer? _saveDebounce;
  Timer? _autoBackupStartupTimer;
  Timer? _autoBackupChangeTimer;
  bool _runningAutoBackup = false;
  bool _didShowStartupNotice = false;
  bool _reportedSaveFailure = false;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_handleStateChanged);
    if (widget.repository != null && widget.state.autoBackupConfig.enabled) {
      _autoBackupStartupTimer = Timer(
        widget.autoBackupStartupDelay,
        _runAutoBackup,
      );
    }
    if (widget.startupNotice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showStartupNoticeIfNeeded();
      });
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_handleStateChanged);
    _saveDebounce?.cancel();
    _autoBackupStartupTimer?.cancel();
    _autoBackupChangeTimer?.cancel();
    super.dispose();
  }

  void _handleStateChanged() {
    _scheduleSave();
    if (!widget.state.autoBackupConfig.enabled) {
      _autoBackupStartupTimer?.cancel();
      _autoBackupStartupTimer = null;
      _autoBackupChangeTimer?.cancel();
      _autoBackupChangeTimer = null;
      return;
    }
    if (!_runningAutoBackup) {
      _scheduleAutoBackupAfterChange();
    }
  }

  void _scheduleSave() {
    final repository = widget.repository;
    if (repository == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        await repository.save(widget.state.toSnapshot());
        _reportedSaveFailure = false;
      } catch (_) {
        if (_reportedSaveFailure) return;
        _reportedSaveFailure = true;
        _showSaveFailureNotice();
      }
    });
  }

  void _scheduleAutoBackupAfterChange() {
    if (widget.repository == null) {
      return;
    }
    if (!widget.state.autoBackupConfig.enabled) {
      _autoBackupChangeTimer?.cancel();
      _autoBackupChangeTimer = null;
      return;
    }
    _autoBackupChangeTimer?.cancel();
    _autoBackupChangeTimer = Timer(
      widget.autoBackupChangeDebounce,
      _runAutoBackup,
    );
  }

  Future<void> _runAutoBackup() async {
    if (widget.repository == null ||
        _runningAutoBackup ||
        !widget.state.autoBackupConfig.enabled) {
      return;
    }
    _runningAutoBackup = true;
    try {
      await widget.autoBackupService.run(state: widget.state);
    } finally {
      _runningAutoBackup = false;
    }
  }

  void _showStartupNoticeIfNeeded() {
    final dialogContext = _navigatorKey.currentContext;
    if (!mounted ||
        _didShowStartupNotice ||
        widget.startupNotice == null ||
        dialogContext == null) {
      return;
    }
    _didShowStartupNotice = true;
    showLedgerInfoDialog(
      dialogContext,
      title: widget.startupNotice!.title,
      icon: Icons.warning_amber_rounded,
      content: Text(
        widget.startupNotice!.message,
        style: const TextStyle(
          color: LedgerColors.muted,
          fontSize: 14,
          height: 1.45,
        ),
      ),
    );
  }

  void _showSaveFailureNotice() {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;
    showLedgerSnackBarOn(
      messenger,
      '本地保存失败，请先不要卸载应用，并尽快到“设置 > 本地备份/恢复”导出或恢复一份备份。',
    );
  }

  @override
  Widget build(BuildContext context) {
    return LedgerScope(
      state: widget.state,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _messengerKey,
        title: 'Shift Ledger 工时账本',
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildLedgerTheme(),
        home: LedgerShell(repository: widget.repository),
      ),
    );
  }
}
