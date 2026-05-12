import 'dart:async';

import 'package:flutter/material.dart';

import 'src/app/ledger_state.dart';
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
    state = snapshot == null ? LedgerState.seeded() : LedgerState.fromSnapshot(snapshot);
  } catch (_) {
    state = LedgerState.seeded();
  }
  runApp(ShiftLedgerApp(state: state, repository: repository));
}

class ShiftLedgerApp extends StatefulWidget {
  const ShiftLedgerApp({super.key, required this.state, this.repository});
  final LedgerState state;
  final LocalLedgerRepository? repository;

  @override
  State<ShiftLedgerApp> createState() => _ShiftLedgerAppState();
}

class _ShiftLedgerAppState extends State<ShiftLedgerApp> {
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_scheduleSave);
  }

  @override
  void dispose() {
    widget.state.removeListener(_scheduleSave);
    _saveDebounce?.cancel();
    super.dispose();
  }

  void _scheduleSave() {
    final repository = widget.repository;
    if (repository == null) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(repository.save(widget.state.toSnapshot()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return LedgerScope(
      state: widget.state,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Shift Ledger 工时账本',
        theme: buildLedgerTheme(),
        home: LedgerShell(repository: widget.repository),
      ),
    );
  }
}
