import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ledger/src/app/ledger_state.dart';
import 'package:shift_ledger/src/domain/models.dart';
import 'package:shift_ledger/src/services/pay_calculator.dart';

void main() {
  group('time boundary invariants', () {
    test(
      'equal start and end times are not normalized into cross-day records',
      () {
        final rule = PayRule.defaultHourly(hourlyRate: 35);
        final entry = WorkEntry.create(
          workDate: DateTime(2026, 5, 13),
          startDateTime: DateTime(2026, 5, 13, 9),
          endDateTime: DateTime(2026, 5, 13, 9),
          breakMinutes: 0,
          payRule: rule,
        );

        expect(entry.isCrossDay, isFalse);
        expect(entry.netHours, 0);
        expect(entry.timeRangeLabel, '09:00 — 09:00');
      },
    );

    test('equal-time templates do not create implicit 24-hour entries', () {
      final state = LedgerState.empty(now: DateTime(2026, 5, 13));
      final template = ShiftTemplate.standard(payRuleId: state.defaultRule.id)
          .copyWith(
            id: 'tpl_equal_time',
            name: '等时模板',
            startMinute: 9 * 60,
            endMinute: 9 * 60,
            breakMinutes: 0,
          );

      final entry = state.createTemplateEntry(
        day: DateTime(2026, 5, 13),
        template: template,
      );

      expect(entry.isCrossDay, isFalse);
      expect(entry.netHours, 0);
      expect(entry.timeRangeLabel, '09:00 — 09:00');
    });

    test(
      'equal night-rule boundaries do not turn the whole day into night',
      () {
        final rule = PayRule.defaultHourly(hourlyRate: 35);
        final entry = WorkEntry.create(
          workDate: DateTime(2026, 5, 13),
          startDateTime: DateTime(2026, 5, 13, 10),
          endDateTime: DateTime(2026, 5, 13, 12),
          breakMinutes: 0,
          payRule: rule,
        );

        final summary = PayCalculator().summarize(
          entries: [entry],
          rules: [rule],
          nightRule: NightRule.defaults().copyWith(
            startMinute: 9 * 60,
            endMinute: 9 * 60,
          ),
          range: DateRange.custom(DateTime(2026, 5, 13), DateTime(2026, 5, 13)),
        );

        expect(summary.nightHours, 0);
        expect(summary.nightShiftCount, 0);
      },
    );
  });
}
