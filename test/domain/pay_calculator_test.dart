import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ledger/src/app/ledger_state.dart';
import 'package:shift_ledger/src/domain/models.dart';
import 'package:shift_ledger/src/services/pay_calculator.dart';

void main() {
  group('PayCalculator', () {
    test(
      'hourly rule splits regular and overtime across multiple segments',
      () {
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
      },
    );

    test('manual overtime does not double count daily threshold overtime', () {
      final rule = PayRule.defaultHourly(
        hourlyRate: 40,
      ).copyWith(overtimeThresholdHours: 8, overtimeMultiplier: 1.5);
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

    test(
      'cross-day night shift counts night hours and fixed night allowance',
      () {
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
      },
    );

    test(
      'daily pay defaults to one unit per attendance day even with multiple segments',
      () {
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
      },
    );

    test(
      'monthly pay prorates by effective date coverage and keeps overtime separate',
      () {
        final rule = PayRule.defaultMonthly(
          monthlyRate: 3100,
        ).copyWith(effectiveFrom: DateTime(2026, 5, 16));
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
      },
    );

    test('monthly pay sums calendar months correctly across year ranges', () {
      final rule = PayRule.defaultMonthly(
        monthlyRate: 3100,
      ).copyWith(effectiveFrom: DateTime(2026, 5, 1));
      final entry = WorkEntry.create(
        workDate: DateTime(2026, 5, 20),
        startDateTime: DateTime(2026, 5, 20, 9),
        endDateTime: DateTime(2026, 5, 20, 18),
        breakMinutes: 60,
        type: EntryType.regular,
        payRule: rule,
      );

      final summary = PayCalculator().summarize(
        entries: [entry],
        rules: [rule],
        nightRule: NightRule.defaults(),
        range: DateRange.year(2026),
      );

      expect(summary.baseIncome, 3100 * 8);
    });

    test('negative break minutes never inflate payable hours', () {
      final rule = PayRule.defaultHourly(hourlyRate: 50);
      final entry = WorkEntry.create(
        workDate: DateTime(2026, 5, 20),
        startDateTime: DateTime(2026, 5, 20, 9),
        endDateTime: DateTime(2026, 5, 20, 17),
        breakMinutes: -60,
        type: EntryType.regular,
        payRule: rule,
      );

      final summary = PayCalculator().summarize(
        entries: [entry],
        rules: [rule],
        nightRule: NightRule.defaults(),
        range: DateRange.month(2026, 5),
      );

      expect(entry.netHours, 8);
      expect(summary.totalHours, 8);
      expect(summary.baseIncome, 400);
    });

    test('restored malformed numeric fields are clamped to safe ranges', () {
      final rule = PayRule.fromJson({
        'id': 'bad_rule',
        'name': '异常规则',
        'baseType': 'hourly',
        'hourlyRate': -50,
        'effectiveFrom': '2026-05-01',
        'standardHoursPerDay': -8,
        'overtimeMultiplier': -1,
      });
      final template = ShiftTemplate.fromJson({
        'id': 'bad_tpl',
        'name': '异常模板',
        'startMinute': -10,
        'endMinute': 2000,
        'breakMinutes': -30,
      });
      final nightRule = NightRule.fromJson({
        'startMinute': -60,
        'endMinute': 2000,
        'fixedAmount': -30,
      });

      expect(rule.hourlyRate, 0);
      expect(rule.standardHoursPerDay, 0);
      expect(rule.overtimeMultiplier, 0);
      expect(template.startMinute, 0);
      expect(template.endMinute, 23 * 60 + 59);
      expect(template.breakMinutes, 0);
      expect(nightRule.startMinute, 0);
      expect(nightRule.endMinute, 23 * 60 + 59);
      expect(nightRule.fixedAmount, 0);
    });

    test(
      'pay period preserves 29/30/31 start days and falls back per month',
      () {
        const period = PayPeriod(
          mode: PayPeriodMode.monthlyStartDay,
          monthStartDay: 31,
        );

        final febPeriod = period.rangeFor(DateTime(2026, 2, 28));
        final marBeforeStart = period.rangeFor(DateTime(2026, 3, 30));
        final restored = PayPeriod.fromJson({
          'mode': 'monthlyStartDay',
          'monthStartDay': 31,
        });

        expect(febPeriod.start, DateTime(2026, 2, 28));
        expect(febPeriod.endExclusive, DateTime(2026, 3, 31));
        expect(marBeforeStart.start, DateTime(2026, 2, 28));
        expect(marBeforeStart.endExclusive, DateTime(2026, 3, 31));
        expect(restored.monthStartDay, 31);
      },
    );

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

    test(
      'ledger state chooses active default rule by work date and versions edited rules',
      () {
        final oldRule = PayRule.defaultHourly(
          hourlyRate: 30,
        ).copyWith(effectiveFrom: DateTime(2026, 5, 1), isDefault: true);
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
      },
    );

    test(
      'default shift template creates neutral entries without allowance',
      () {
        final state = LedgerState.empty(now: DateTime(2026, 5, 20));

        final entry = state.createTemplateEntry(day: DateTime(2026, 5, 20));

        expect(state.templates.first.defaultAdjustments, isEmpty);
        expect(entry.allowanceTotal, 0);
        expect(entry.deductionTotal, 0);
      },
    );

    test('built-in shift templates keep standard lunch break defaults', () {
      final state = LedgerState.empty(now: DateTime(2026, 5, 20));

      expect(
        ShiftTemplate.standard(payRuleId: state.defaultRule.id).breakMinutes,
        60,
      );
      expect(
        ShiftTemplate.overtime(payRuleId: state.defaultRule.id).breakMinutes,
        0,
      );
      expect(
        ShiftTemplate.night(payRuleId: state.defaultRule.id).breakMinutes,
        0,
      );
      expect(
        state.templates
            .firstWhere((template) => template.id == ShiftTemplate.standardId)
            .breakMinutes,
        60,
      );
      expect(
        state.templates
            .where((template) => template.id != ShiftTemplate.standardId)
            .map((template) => template.breakMinutes),
        everyElement(0),
      );
    });

    test(
      'restoreShiftTemplate resets one built-in template without touching custom templates',
      () {
        final state = LedgerState.empty(now: DateTime(2026, 5, 20));
        state.updateShiftTemplate(
          state.templates.first.copyWith(
            name: '白班',
            breakMinutes: 45,
            defaultLocationName: '南山店',
          ),
        );
        state.updateShiftTemplate(
          ShiftTemplate.standard(
            payRuleId: state.defaultRule.id,
          ).copyWith(id: 'tpl_custom', name: '周末店班'),
        );

        final restored = state.restoreShiftTemplate(ShiftTemplate.standardId);

        expect(restored, isTrue);
        expect(
          state.templates.firstWhere(
            (template) => template.id == ShiftTemplate.standardId,
          ),
          isA<ShiftTemplate>()
              .having((template) => template.name, 'name', '标准班次')
              .having((template) => template.breakMinutes, 'breakMinutes', 60)
              .having(
                (template) => template.defaultLocationName,
                'location',
                '',
              ),
        );
        expect(
          state.templates
              .firstWhere((template) => template.id == 'tpl_custom')
              .name,
          '周末店班',
        );
      },
    );

    test('deleteShiftTemplate rejects built-in templates', () {
      final state = LedgerState.empty(now: DateTime(2026, 5, 20));

      final deleted = state.deleteShiftTemplate(ShiftTemplate.nightId);

      expect(deleted, isFalse);
      expect(
        state.templates.any((template) => template.id == ShiftTemplate.nightId),
        isTrue,
      );
    });

    test('ledger state auto-heals missing built-in templates on load', () {
      final rule = PayRule.defaultHourly(hourlyRate: 35);
      final custom = ShiftTemplate.standard(
        payRuleId: rule.id,
      ).copyWith(id: 'tpl_custom', name: '周末店班');
      final state = LedgerState(
        now: DateTime(2026, 5, 20),
        payRules: [rule],
        templates: [custom],
      );

      expect(state.templates.first.id, 'tpl_custom');
      expect(
        state.templates.any(
          (template) => template.id == ShiftTemplate.standardId,
        ),
        isTrue,
      );
      expect(
        state.templates.any(
          (template) => template.id == ShiftTemplate.overtimeId,
        ),
        isTrue,
      );
      expect(
        state.templates.any((template) => template.id == ShiftTemplate.nightId),
        isTrue,
      );
    });

    test('ledger state recovers safe defaults from sparse snapshots', () {
      final state = LedgerState.fromSnapshot(
        LedgerSnapshot(
          entries: const [],
          templates: const [],
          payRules: const [],
          nightRule: NightRule.defaults(),
          payPeriod: const PayPeriod(),
          webDavConfig: const WebDavConfig(),
        ),
        now: DateTime(2026, 5, 20),
      );

      expect(state.payRules, isNotEmpty);
      expect(state.templates, isNotEmpty);
      expect(state.defaultRule.id, isNotEmpty);
      expect(state.createTemplateEntry().payRuleSnapshot.id, isNotEmpty);
    });
  });
}
