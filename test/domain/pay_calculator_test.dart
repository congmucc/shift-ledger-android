import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ledger/src/app/ledger_state.dart';
import 'package:shift_ledger/src/domain/models.dart';
import 'package:shift_ledger/src/services/pay_calculator.dart';

void main() {
  group('PayCalculator', () {
    test('hourly rule splits regular and overtime across multiple segments', () {
      final rule = PayRule.defaultHourly(hourlyRate: 35);
      final entries = [
        WorkEntry.create(
          workDate: DateTime(2026, 5, 13),
          startDateTime: DateTime(2026, 5, 13, 9),
          endDateTime: DateTime(2026, 5, 13, 12),
          breakMinutes: 0,
          type: EntryType.regular,
          payRule: rule,
        ),
        WorkEntry.create(
          workDate: DateTime(2026, 5, 13),
          startDateTime: DateTime(2026, 5, 13, 13),
          endDateTime: DateTime(2026, 5, 13, 19),
          breakMinutes: 60,
          type: EntryType.regular,
          payRule: rule,
          adjustments: [Adjustment.allowance('餐补', 20)],
        ),
      ];

      final summary = PayCalculator().summarize(
        entries: entries,
        rules: [rule],
        nightRule: NightRule.defaults(),
        range: DateRange.month(2026, 5),
      );

      expect(summary.totalHours, 8);
      expect(summary.regularHours, 8);
      expect(summary.overtimeHours, 0);
      expect(summary.allowance, 20);
      expect(summary.income, 300);
    });

    test('manual overtime does not double count daily threshold overtime', () {
      final rule = PayRule.defaultHourly(hourlyRate: 40).copyWith(
        overtimeThresholdHours: 8,
        overtimeMultiplier: 1.5,
      );
      final entries = [
        WorkEntry.create(
          workDate: DateTime(2026, 5, 14),
          startDateTime: DateTime(2026, 5, 14, 9),
          endDateTime: DateTime(2026, 5, 14, 18),
          breakMinutes: 60,
          type: EntryType.regular,
          payRule: rule,
        ),
        WorkEntry.create(
          workDate: DateTime(2026, 5, 14),
          startDateTime: DateTime(2026, 5, 14, 19),
          endDateTime: DateTime(2026, 5, 14, 21),
          breakMinutes: 0,
          type: EntryType.overtime,
          payRule: rule,
        ),
      ];

      final summary = PayCalculator().summarize(
        entries: entries,
        rules: [rule],
        nightRule: NightRule.defaults(),
        range: DateRange.month(2026, 5),
      );

      expect(summary.totalHours, 10);
      expect(summary.regularHours, 8);
      expect(summary.overtimeHours, 2);
      expect(summary.baseIncome, 320);
      expect(summary.overtimeIncome, 120);
      expect(summary.income, 440);
    });

    test('cross-day night shift counts night hours and fixed night allowance', () {
      final rule = PayRule.defaultHourly(hourlyRate: 30);
      final entry = WorkEntry.create(
        workDate: DateTime(2026, 5, 8),
        startDateTime: DateTime(2026, 5, 8, 22),
        endDateTime: DateTime(2026, 5, 9, 6),
        breakMinutes: 60,
        type: EntryType.night,
        payRule: rule,
      );

      final summary = PayCalculator().summarize(
        entries: [entry],
        rules: [rule],
        nightRule: NightRule.defaults().copyWith(
          mode: NightAllowanceMode.fixed,
          fixedAmount: 50,
        ),
        range: DateRange.month(2026, 5),
      );

      expect(entry.isCrossDay, isTrue);
      expect(summary.totalHours, 7);
      expect(summary.nightShiftCount, 1);
      expect(summary.nightHours, 7);
      expect(summary.nightIncome, 50);
    });

    test('daily pay defaults to one unit per attendance day even with multiple segments', () {
      final rule = PayRule.defaultDaily(dailyRate: 280);
      final day = DateTime(2026, 5, 15);
      final entries = [
        WorkEntry.create(
          workDate: day,
          startDateTime: DateTime(2026, 5, 15, 9),
          endDateTime: DateTime(2026, 5, 15, 12),
          type: EntryType.regular,
          payRule: rule,
        ),
        WorkEntry.create(
          workDate: day,
          startDateTime: DateTime(2026, 5, 15, 14),
          endDateTime: DateTime(2026, 5, 15, 18),
          type: EntryType.regular,
          payRule: rule,
        ),
      ];

      final summary = PayCalculator().summarize(
        entries: entries,
        rules: [rule],
        nightRule: NightRule.defaults(),
        range: DateRange.month(2026, 5),
      );

      expect(summary.attendanceDays, 1);
      expect(summary.baseIncome, 280);
    });

    test('monthly pay prorates by effective date coverage and keeps overtime separate', () {
      final rule = PayRule.defaultMonthly(monthlyRate: 3100).copyWith(
        effectiveFrom: DateTime(2026, 5, 16),
      );
      final entries = [
        WorkEntry.create(
          workDate: DateTime(2026, 5, 20),
          startDateTime: DateTime(2026, 5, 20, 9),
          endDateTime: DateTime(2026, 5, 20, 19),
          breakMinutes: 60,
          type: EntryType.regular,
          payRule: rule,
        ),
      ];

      final summary = PayCalculator().summarize(
        entries: entries,
        rules: [rule],
        nightRule: NightRule.defaults(),
        range: DateRange.month(2026, 5),
      );

      expect(summary.baseIncome, closeTo(1600, 0.01));
      expect(summary.overtimeHours, 1);
      expect(summary.overtimeIncome, greaterThan(0));
    });

    test('record keeps pay rule snapshot stable after rule changes', () {
      final oldRule = PayRule.defaultHourly(hourlyRate: 35);
      final entry = WorkEntry.create(
        workDate: DateTime(2026, 5, 13),
        startDateTime: DateTime(2026, 5, 13, 9),
        endDateTime: DateTime(2026, 5, 13, 18),
        breakMinutes: 60,
        type: EntryType.regular,
        payRule: oldRule,
      );
      final changedRule = oldRule.copyWith(hourlyRate: 50, version: 2);

      final summary = PayCalculator().summarize(
        entries: [entry],
        rules: [changedRule],
        nightRule: NightRule.defaults(),
        range: DateRange.month(2026, 5),
      );

      expect(entry.payRuleSnapshot.hourlyRate, 35);
      expect(summary.baseIncome, 280);
    });


    test('ledger state chooses active default rule by work date and versions edited rules', () {
      final oldRule = PayRule.defaultHourly(hourlyRate: 30).copyWith(
        effectiveFrom: DateTime(2026, 5, 1),
        isDefault: true,
      );
      final state = LedgerState.empty(now: DateTime(2026, 5, 20));
      state.payRules = [oldRule];
      final newRule = oldRule.copyWith(
        hourlyRate: 50,
        effectiveFrom: DateTime(2026, 5, 16),
        version: 2,
      );

      state.savePayRule(newRule);

      final before = state.createTemplateEntry(day: DateTime(2026, 5, 15));
      final after = state.createTemplateEntry(day: DateTime(2026, 5, 20));
      expect(before.payRuleSnapshot.hourlyRate, 30);
      expect(after.payRuleSnapshot.hourlyRate, 50);
      expect(state.payRules.length, 2);
    });
  });
}