import 'dart:math';

import '../domain/models.dart';

class PayCalculator {
  LedgerSummary summarize({
    required List<WorkEntry> entries,
    required List<PayRule> rules,
    required NightRule nightRule,
    required DateRange range,
  }) {
    final visible =
        entries
            .where(
              (entry) => range.overlaps(entry.startDateTime, entry.endDateTime),
            )
            .toList()
          ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

    final byDay = <String, List<WorkEntry>>{};
    for (final entry in visible) {
      byDay.putIfAbsent(ymd(entry.workDate), () => []).add(entry);
    }

    final attendance = <String>{};
    final overtimeDays = <String>{};
    final noteDays = <String>{};
    final longDays = <String>{};
    final calculations = <EntryCalculation>[];
    var totalHours = 0.0;
    var regularHours = 0.0;
    var overtimeHours = 0.0;
    var nightHours = 0.0;
    var nightShiftCount = 0;
    var allowance = 0.0;
    var deduction = 0.0;
    var baseIncome = 0.0;
    var overtimeIncome = 0.0;
    var nightIncome = 0.0;

    final dailyBaseKeys = <String>{};
    final monthlyRuleIds = <String>{};

    for (final dayEntries in byDay.values) {
      dayEntries.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
      final dayKey = ymd(dayEntries.first.workDate);
      attendance.add(dayKey);
      if (dayEntries.any((entry) => entry.hasNote)) noteDays.add(dayKey);

      final thresholdByRule = <String, double>{};
      for (final entry in dayEntries) {
        final rule = _ruleFor(entry, rules);
        thresholdByRule.putIfAbsent(rule.id, () => rule.overtimeThresholdHours);
      }
      final consumedRegularByRule = <String, double>{};

      for (final entry in dayEntries) {
        final rule = _ruleFor(entry, rules);
        final net = _entryHoursInRange(entry, range);
        final manualOvertime = entry.isManualOvertime;
        var entryRegular = 0.0;
        var entryOvertime = 0.0;

        if (manualOvertime) {
          entryOvertime = net;
        } else {
          final consumed = consumedRegularByRule[rule.id] ?? 0;
          final threshold = thresholdByRule[rule.id] ?? 8;
          final regularCapacity = max(0.0, threshold - consumed);
          entryRegular = min(net, regularCapacity);
          entryOvertime = max(0.0, net - entryRegular);
          consumedRegularByRule[rule.id] = consumed + entryRegular;
        }

        final entryNightHours = _nightHours(entry, nightRule, range);
        final entryAllowance = entry.allowanceTotal;
        final entryDeduction = entry.deductionTotal;
        final entryOvertimeIncome =
            entryOvertime *
            rule.overtimeHourlyBase(range: range) *
            (entry.isRestDayOvertime
                ? rule.restDayMultiplier
                : rule.overtimeMultiplier);
        final entryNightIncome = _nightIncome(
          entryNightHours,
          entry,
          rule,
          nightRule,
          range,
        );
        var entryBaseIncome = 0.0;
        switch (rule.baseType) {
          case PayBaseType.hourly:
            entryBaseIncome = entryRegular * rule.hourlyRate;
          case PayBaseType.daily:
            if (rule.dailyPayMode == DailyPayMode.shiftCount) {
              entryBaseIncome = rule.dailyRate;
            } else {
              final key = '$dayKey/${rule.id}';
              if (!dailyBaseKeys.contains(key)) {
                dailyBaseKeys.add(key);
                entryBaseIncome = rule.dailyRate;
              }
            }
          case PayBaseType.monthly:
            monthlyRuleIds.add(rule.id);
        }

        totalHours += net;
        regularHours += entryRegular;
        overtimeHours += entryOvertime;
        nightHours += entryNightHours;
        allowance += entryAllowance;
        deduction += entryDeduction;
        baseIncome += entryBaseIncome;
        overtimeIncome += entryOvertimeIncome;
        nightIncome += entryNightIncome;
        if (entryOvertime > 0) overtimeDays.add(dayKey);
        if (entryNightHours > 0) nightShiftCount++;

        calculations.add(
          EntryCalculation(
            entry: entry,
            regularHours: _round2(entryRegular),
            overtimeHours: _round2(entryOvertime),
            nightHours: _round2(entryNightHours),
            baseIncome: _round2(entryBaseIncome),
            overtimeIncome: _round2(entryOvertimeIncome),
            nightIncome: _round2(entryNightIncome),
          ),
        );
      }

      final dayTotal = dayEntries.fold(
        0.0,
        (sum, entry) => sum + _entryHoursInRange(entry, range),
      );
      if (dayTotal > 12) longDays.add(dayKey);
    }

    for (final ruleId in monthlyRuleIds) {
      final rule = rules.firstWhere(
        (item) => item.id == ruleId,
        orElse: () => visible
            .firstWhere((e) => e.payRuleSnapshot.id == ruleId)
            .payRuleSnapshot,
      );
      baseIncome += _monthlyBaseIncome(rule, range);
    }

    return LedgerSummary(
      range: range,
      totalHours: _round2(totalHours),
      regularHours: _round2(regularHours),
      overtimeHours: _round2(overtimeHours),
      nightHours: _round2(nightHours),
      attendanceDays: attendance.length,
      overtimeDays: overtimeDays.length,
      nightShiftCount: nightShiftCount,
      noteDays: noteDays.length,
      longDurationDays: longDays.length,
      allowance: _round2(allowance),
      deduction: _round2(deduction),
      baseIncome: _round2(baseIncome),
      overtimeIncome: _round2(overtimeIncome),
      nightIncome: _round2(nightIncome),
      calculations: calculations,
    );
  }

  PayRule _ruleFor(WorkEntry entry, List<PayRule> rules) =>
      entry.payRuleSnapshot;

  double _entryHoursInRange(WorkEntry entry, DateRange range) {
    final start = entry.startDateTime.isBefore(range.start)
        ? range.start
        : entry.startDateTime;
    final end = entry.endDateTime.isAfter(range.endExclusive)
        ? range.endExclusive
        : entry.endDateTime;
    if (!end.isAfter(start)) return 0;
    final grossTotalMinutes = entry.endDateTime
        .difference(entry.startDateTime)
        .inMinutes;
    if (grossTotalMinutes <= 0) return 0;
    final overlapMinutes = end.difference(start).inMinutes;
    final breakInOverlap =
        _effectiveBreakMinutes(entry) * overlapMinutes / grossTotalMinutes;
    return max(0, overlapMinutes / 60 - breakInOverlap / 60);
  }

  double _nightHours(WorkEntry entry, NightRule rule, DateRange range) {
    final net = _entryHoursInRange(entry, range);
    if (entry.type == EntryType.night) return net;
    final grossMinutes = entry.endDateTime
        .difference(entry.startDateTime)
        .inMinutes;
    if (grossMinutes <= 0) return 0;
    var overlap = 0;
    var cursor = dateOnly(
      entry.startDateTime,
    ).subtract(const Duration(days: 1));
    final limit = dateOnly(entry.endDateTime).add(const Duration(days: 2));
    while (cursor.isBefore(limit)) {
      final windowStart = cursor.add(Duration(minutes: rule.startMinute));
      final windowEnd = rule.endMinute <= rule.startMinute
          ? cursor
                .add(const Duration(days: 1, minutes: 0))
                .add(Duration(minutes: rule.endMinute))
          : cursor.add(Duration(minutes: rule.endMinute));
      final start = _latest([entry.startDateTime, range.start, windowStart]);
      final end = _earliest([entry.endDateTime, range.endExclusive, windowEnd]);
      if (end.isAfter(start)) overlap += end.difference(start).inMinutes;
      cursor = cursor.add(const Duration(days: 1));
    }
    final breakShare = _effectiveBreakMinutes(entry) * overlap / grossMinutes;
    return _round2(max(0, overlap / 60 - breakShare / 60));
  }

  double _nightIncome(
    double nightHours,
    WorkEntry entry,
    PayRule rule,
    NightRule nightRule,
    DateRange range,
  ) {
    if (nightHours <= 0) return 0;
    return switch (nightRule.mode) {
      NightAllowanceMode.fixed => nightRule.fixedAmount,
      NightAllowanceMode.hourly => nightHours * nightRule.hourlyAmount,
      NightAllowanceMode.multiplier =>
        nightHours *
            rule.overtimeHourlyBase(range: range) *
            max(0, nightRule.multiplier - 1),
    };
  }

  double _monthlyBaseIncome(PayRule rule, DateRange range) {
    final ruleStart = dateOnly(rule.effectiveFrom);
    final ruleEndExclusive = rule.effectiveTo == null
        ? range.endExclusive
        : dateOnly(rule.effectiveTo!).add(const Duration(days: 1));
    var total = 0.0;
    var monthStart = DateTime(range.start.year, range.start.month);
    while (monthStart.isBefore(range.endExclusive)) {
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1);
      final coveredStart = _latest([range.start, ruleStart, monthStart]);
      final coveredEnd = _earliest([
        range.endExclusive,
        ruleEndExclusive,
        monthEnd,
      ]);
      if (coveredEnd.isAfter(coveredStart)) {
        final monthDays = monthEnd.difference(monthStart).inDays;
        final coveredDays = coveredEnd.difference(coveredStart).inDays;
        total += rule.monthlyRate * coveredDays / monthDays;
      }
      monthStart = monthEnd;
    }
    return total;
  }

  int _effectiveBreakMinutes(WorkEntry entry) {
    final grossMinutes = max(
      0,
      entry.endDateTime.difference(entry.startDateTime).inMinutes,
    );
    return clampInt(entry.breakMinutes, 0, grossMinutes);
  }

  DateTime _latest(List<DateTime> values) =>
      values.reduce((a, b) => a.isAfter(b) ? a : b);
  DateTime _earliest(List<DateTime> values) =>
      values.reduce((a, b) => a.isBefore(b) ? a : b);
  double _round2(double value) => (value * 100).roundToDouble() / 100;
}
