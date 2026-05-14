import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ledger/src/app/ledger_state.dart';

void main() {
  test('delete day stores a restore point and snapshots roundtrip it', () {
    final state = LedgerState.seeded(now: DateTime(2026, 5, 13));

    final deleted = state.deleteDay(DateTime(2026, 5, 13));

    expect(deleted, isNotNull);
    expect(state.entriesForDay(DateTime(2026, 5, 13)), isEmpty);
    expect(state.recentDeletedDays.length, 1);
    expect(state.recentDeletedDays.first.segmentCount, 2);
    expect(state.recentDeletedDays.first.totalHours, 8);

    final reloaded = LedgerState.fromSnapshot(
      state.toSnapshot(),
      now: DateTime(2026, 5, 13),
    );
    expect(reloaded.recentDeletedDays.length, 1);

    final restored = reloaded.restoreDeletedDay(
      reloaded.recentDeletedDays.first.id,
    );
    expect(restored, isTrue);
    expect(reloaded.entriesForDay(DateTime(2026, 5, 13)).length, 2);
    expect(reloaded.recentDeletedDays, isEmpty);
  });

  test('restoring a deleted day merges with new same-day entries', () {
    final state = LedgerState.seeded(now: DateTime(2026, 5, 13));
    final deleted = state.deleteDay(DateTime(2026, 5, 13))!;
    state.addEntry(state.createTemplateEntry(day: DateTime(2026, 5, 13)));

    final restored = state.restoreDeletedDay(deleted.id);

    expect(restored, isTrue);
    expect(state.entriesForDay(DateTime(2026, 5, 13)).length, 3);
  });
}
