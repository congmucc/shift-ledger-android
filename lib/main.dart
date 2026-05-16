import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/app/ledger_state.dart';
import 'src/services/auto_backup_service.dart';
import 'src/services/local_ledger_repository.dart';
import 'src/ui/scope.dart';
import 'src/ui/shell.dart';
import 'src/ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = LocalLedgerRepository();
  LedgerState state;
  try {
    final snapshot = await repository.load();
    state = snapshot == null
        ? LedgerState.empty()
        : LedgerState.fromSnapshot(snapshot);
  } catch (_) {
    state = LedgerState.empty();
  }
  runApp(ShiftLedgerApp(state: state, repository: repository));
}

class ShiftLedgerApp extends StatefulWidget {
  const ShiftLedgerApp({
    super.key,
    required this.state,
    this.repository,
    this.autoBackupService = const AutoBackupService(),
    this.autoBackupStartupDelay = const Duration(seconds: 20),
    this.autoBackupChangeDebounce = const Duration(minutes: 10),
  });

  final LedgerState state;
  final LocalLedgerRepository? repository;
  final AutoBackupService autoBackupService;
  final Duration autoBackupStartupDelay;
  final Duration autoBackupChangeDebounce;

  @override
  State<ShiftLedgerApp> createState() => _ShiftLedgerAppState();
}

class _ShiftLedgerAppState extends State<ShiftLedgerApp> {
  Timer? _saveDebounce;
  Timer? _autoBackupStartupTimer;
  Timer? _autoBackupChangeTimer;
  bool _runningAutoBackup = false;

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
    _saveDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(repository.save(widget.state.toSnapshot()));
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

  @override
  Widget build(BuildContext context) {
    return LedgerScope(
      state: widget.state,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
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
