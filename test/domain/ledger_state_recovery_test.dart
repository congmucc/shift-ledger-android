import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ledger/src/app/ledger_state.dart';
import 'package:shift_ledger/src/domain/models.dart';

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

  test(
    'replacing copied day entries refreshes prior copies without touching manual entries',
    () {
      final rule = PayRule.defaultHourly(hourlyRate: 35);
      final state = LedgerState(
        now: DateTime(2026, 5, 13),
        payRules: [rule],
        entries: [
          WorkEntry.create(
            id: 'manual_target',
            workDate: DateTime(2026, 5, 14),
            startDateTime: DateTime(2026, 5, 14, 13),
            endDateTime: DateTime(2026, 5, 14, 18),
            payRule: rule,
          ),
          WorkEntry.create(
            id: 'copied_old_1',
            workDate: DateTime(2026, 5, 14),
            startDateTime: DateTime(2026, 5, 14, 9),
            endDateTime: DateTime(2026, 5, 14, 12),
            payRule: rule,
            copiedFromDayKey: '2026-05-13',
          ),
          WorkEntry.create(
            id: 'copied_old_2',
            workDate: DateTime(2026, 5, 14),
            startDateTime: DateTime(2026, 5, 14, 19),
            endDateTime: DateTime(2026, 5, 14, 21),
            payRule: rule,
            copiedFromDayKey: '2026-05-13',
          ),
        ],
      );

      state.replaceCopiedDayEntries(
        DateTime(2026, 5, 13),
        DateTime(2026, 5, 14),
        [
          WorkEntry.create(
            id: 'copied_new',
            workDate: DateTime(2026, 5, 14),
            startDateTime: DateTime(2026, 5, 14, 10),
            endDateTime: DateTime(2026, 5, 14, 16),
            payRule: rule,
            copiedFromDayKey: '2026-05-13',
          ),
        ],
      );

      final targetEntries = state.entriesForDay(DateTime(2026, 5, 14));
      expect(targetEntries.length, 2);
      expect(targetEntries.any((entry) => entry.id == 'manual_target'), isTrue);
      expect(targetEntries.any((entry) => entry.id == 'copied_new'), isTrue);
      expect(targetEntries.any((entry) => entry.id == 'copied_old_1'), isFalse);
      expect(targetEntries.any((entry) => entry.id == 'copied_old_2'), isFalse);
    },
  );
}
