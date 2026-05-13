import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ledger/main.dart';
import 'package:shift_ledger/src/app/ledger_state.dart';
import 'package:shift_ledger/src/domain/models.dart';
import 'package:shift_ledger/src/services/auto_backup_service.dart';
import 'package:shift_ledger/src/services/local_ledger_repository.dart';

void main() {
  testWidgets('app schedules startup and debounced change auto backups', (
    tester,
  ) async {
    final state = LedgerState.empty(now: DateTime(2026, 5, 13))
      ..updateAutoBackupConfig(const AutoBackupConfig(enabled: true));
    final repository = _MemoryRepository();
    final service = _CountingAutoBackupService();

    await tester.pumpWidget(
      ShiftLedgerApp(
        state: state,
        repository: repository,
        autoBackupService: service,
        autoBackupStartupDelay: const Duration(milliseconds: 10),
        autoBackupChangeDebounce: const Duration(milliseconds: 20),
      ),
    );

    await tester.pump(const Duration(milliseconds: 11));
    expect(service.runs, 1);

    state.addEntry(state.createTemplateEntry());
    await tester.pump(const Duration(milliseconds: 19));
    expect(service.runs, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(service.runs, 2);
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.savedSnapshots, isNotEmpty);
  });
}

class _MemoryRepository extends LocalLedgerRepository {
  _MemoryRepository();

  final savedSnapshots = <LedgerSnapshot>[];

  @override
  Future<void> save(LedgerSnapshot snapshot) async {
    savedSnapshots.add(snapshot);
  }
}

class _CountingAutoBackupService extends AutoBackupService {
  int runs = 0;

  @override
  Future<AutoBackupConfig> run({required LedgerState state}) async {
    runs += 1;
    final next = state.autoBackupConfig.copyWith(
      lastStatus: AutoBackupStatus.skipped,
    );
    state.updateAutoBackupConfig(next);
    return next;
  }
}
