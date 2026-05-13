import 'package:flutter/foundation.dart';

import '../domain/models.dart';
import '../services/pay_calculator.dart';

class LedgerState extends ChangeNotifier {
  LedgerState({
    required DateTime now,
    List<WorkEntry>? entries,
    List<ShiftTemplate>? templates,
    List<PayRule>? payRules,
    NightRule? nightRule,
    PayPeriod? payPeriod,
    WebDavConfig? webDavConfig,
    AutoBackupConfig? autoBackupConfig,
  }) : now = dateOnly(now),
       entries = entries ?? [],
       templates = templates ?? [],
       payRules = payRules ?? [PayRule.defaultHourly()],
       nightRule = nightRule ?? NightRule.defaults(),
       payPeriod = payPeriod ?? const PayPeriod(),
       webDavConfig = webDavConfig ?? const WebDavConfig(),
       autoBackupConfig = autoBackupConfig ?? const AutoBackupConfig();

  factory LedgerState.empty({DateTime? now}) {
    final rule = PayRule.defaultHourly();
    return LedgerState(
      now: now ?? DateTime.now(),
      payRules: [rule, PayRule.defaultDaily(), PayRule.defaultMonthly()],
      templates: [
        ShiftTemplate.standard(payRuleId: rule.id),
        ShiftTemplate.overtime(payRuleId: rule.id),
        ShiftTemplate.night(payRuleId: rule.id),
      ],
    );
  }

  factory LedgerState.seeded({DateTime? now}) {
    final anchor = dateOnly(now ?? DateTime.now());
    final rule = PayRule.defaultHourly(hourlyRate: 35);
    final daily = PayRule.defaultDaily(dailyRate: 280);
    final monthly = PayRule.defaultMonthly(monthlyRate: 8500);
    final entries = <WorkEntry>[
      WorkEntry.create(
        id: 'seed_1',
        workDate: anchor,
        startDateTime: DateTime(anchor.year, anchor.month, anchor.day, 9),
        endDateTime: DateTime(anchor.year, anchor.month, anchor.day, 12),
        type: EntryType.regular,
        payRule: rule,
        locationName: '门店 A',
        note: '替班',
      ),
      WorkEntry.create(
        id: 'seed_2',
        workDate: anchor,
        startDateTime: DateTime(anchor.year, anchor.month, anchor.day, 13),
        endDateTime: DateTime(anchor.year, anchor.month, anchor.day, 19),
        breakMinutes: 60,
        type: EntryType.regular,
        payRule: rule,
        locationName: '门店 A',
        adjustments: [Adjustment.allowance('餐补', 20, id: 'seed_meal')],
      ),
      WorkEntry.create(
        id: 'seed_night',
        workDate: anchor.subtract(const Duration(days: 5)),
        startDateTime: DateTime(anchor.year, anchor.month, anchor.day - 5, 22),
        endDateTime: DateTime(anchor.year, anchor.month, anchor.day - 4, 6),
        breakMinutes: 60,
        type: EntryType.night,
        payRule: rule,
        locationName: '门店 A',
        note: '替夜班',
      ),
    ];
    return LedgerState(
      now: anchor,
      entries: entries,
      payRules: [rule, daily, monthly],
      templates: [
        ShiftTemplate.standard(payRuleId: rule.id),
        ShiftTemplate.overtime(payRuleId: rule.id),
        ShiftTemplate.night(payRuleId: rule.id),
      ],
    );
  }

  factory LedgerState.fromSnapshot(LedgerSnapshot snapshot, {DateTime? now}) =>
      LedgerState(
        now: now ?? DateTime.now(),
        entries: snapshot.entries,
        templates: snapshot.templates,
        payRules: snapshot.payRules,
        nightRule: snapshot.nightRule,
        payPeriod: snapshot.payPeriod,
        webDavConfig: snapshot.webDavConfig,
        autoBackupConfig: snapshot.autoBackupConfig,
      );

  final DateTime now;
  List<WorkEntry> entries;
  List<ShiftTemplate> templates;
  List<PayRule> payRules;
  NightRule nightRule;
  PayPeriod payPeriod;
  WebDavConfig webDavConfig;
  AutoBackupConfig autoBackupConfig;

  DateRange get currentMonth => DateRange.month(now.year, now.month);
  DateRange get currentPayPeriod => payPeriod.rangeFor(now);
  PayRule get defaultRule => payRules.lastWhere(
    (rule) => rule.isDefault,
    orElse: () => payRules.first,
  );

  PayRule ruleForDate(DateTime day, {String? preferredRuleId}) {
    final activeRules = payRules.where((rule) => rule.activeOn(day)).toList();
    if (preferredRuleId != null) {
      final preferred = activeRules
          .where((rule) => rule.id == preferredRuleId)
          .toList();
      if (preferred.isNotEmpty) return preferred.last;
    }
    final activeDefaults = activeRules.where((rule) => rule.isDefault).toList();
    if (activeDefaults.isNotEmpty) return activeDefaults.last;
    if (activeRules.isNotEmpty) return activeRules.last;
    return defaultRule;
  }

  LedgerSummary summaryFor(DateRange range) => PayCalculator().summarize(
    entries: entries,
    rules: payRules,
    nightRule: nightRule,
    range: range,
  );

  List<WorkEntry> entriesForDay(DateTime day) {
    final key = ymd(day);
    final result = entries.where((entry) => ymd(entry.workDate) == key).toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    return result;
  }

  WorkEntry createTemplateEntry({
    DateTime? day,
    ShiftTemplate? template,
    EntryType? type,
  }) {
    final targetDay = dateOnly(day ?? now);
    final tpl = template ?? templates.first;
    final start = DateTime(
      targetDay.year,
      targetDay.month,
      targetDay.day,
      tpl.startMinute ~/ 60,
      tpl.startMinute % 60,
    );
    var end = DateTime(
      targetDay.year,
      targetDay.month,
      targetDay.day,
      tpl.endMinute ~/ 60,
      tpl.endMinute % 60,
    );
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    final rule = ruleForDate(targetDay, preferredRuleId: tpl.defaultPayRuleId);
    return WorkEntry.create(
      workDate: targetDay,
      startDateTime: start,
      endDateTime: end,
      breakMinutes: tpl.breakMinutes,
      type: type ?? tpl.type,
      templateId: tpl.id,
      locationName: '门店 A',
      payRule: rule,
      adjustments: tpl.defaultAdjustments,
    );
  }

  void addEntry(WorkEntry entry) {
    entries = [...entries, entry]
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    notifyListeners();
  }

  void upsertEntry(WorkEntry entry) {
    final index = entries.indexWhere((item) => item.id == entry.id);
    if (index >= 0) {
      entries = [...entries]..[index] = entry;
    } else {
      entries = [...entries, entry];
    }
    entries.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    notifyListeners();
  }

  void deleteEntry(String id) {
    entries = entries.where((entry) => entry.id != id).toList();
    notifyListeners();
  }

  void deleteDay(DateTime day) {
    final key = ymd(day);
    entries = entries.where((entry) => ymd(entry.workDate) != key).toList();
    notifyListeners();
  }

  void replaceDayEntries(
    DateTime originalDay,
    DateTime targetDay,
    List<WorkEntry> replacements,
  ) {
    final originalKey = ymd(originalDay);
    final targetKey = ymd(targetDay);
    entries = [
      for (final entry in entries)
        if (ymd(entry.workDate) != originalKey &&
            ymd(entry.workDate) != targetKey)
          entry,
      ...replacements,
    ]..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    notifyListeners();
  }

  void savePayRule(PayRule rule) {
    final index = payRules.indexWhere((item) => item.id == rule.id);
    if (index >= 0) {
      final existing = payRules[index];
      final previousVersion = existing.copyWith(
        isDefault: false,
        effectiveTo: rule.effectiveFrom.subtract(const Duration(days: 1)),
      );
      final newVersion = rule.copyWith(id: newId('rule'), isDefault: true);
      payRules = [
        for (var i = 0; i < payRules.length; i++)
          if (i == index)
            previousVersion
          else
            payRules[i].isDefault
                ? payRules[i].copyWith(isDefault: false)
                : payRules[i],
        newVersion,
      ];
    } else {
      payRules = [
        for (final item in payRules)
          rule.isDefault ? item.copyWith(isDefault: false) : item,
        rule,
      ];
    }
    notifyListeners();
  }

  void updateNightRule(NightRule rule) {
    nightRule = rule;
    notifyListeners();
  }

  void updateShiftTemplate(ShiftTemplate template) {
    final index = templates.indexWhere((item) => item.id == template.id);
    if (index >= 0) {
      templates = [...templates]..[index] = template;
    } else {
      templates = [...templates, template];
    }
    notifyListeners();
  }

  void setDefaultShiftTemplate(String id) {
    final index = templates.indexWhere((item) => item.id == id);
    if (index <= 0) return;
    final next = [...templates];
    final selected = next.removeAt(index);
    templates = [selected, ...next];
    notifyListeners();
  }

  void updateWebDavConfig(WebDavConfig config) {
    webDavConfig = config;
    notifyListeners();
  }

  void updateAutoBackupConfig(AutoBackupConfig config) {
    autoBackupConfig = config;
    notifyListeners();
  }

  void updatePayPeriod(PayPeriod period) {
    payPeriod = period;
    notifyListeners();
  }

  void restore(LedgerSnapshot snapshot) {
    entries = snapshot.entries;
    templates = snapshot.templates.isEmpty ? templates : snapshot.templates;
    payRules = snapshot.payRules.isEmpty ? payRules : snapshot.payRules;
    nightRule = snapshot.nightRule;
    payPeriod = snapshot.payPeriod;
    webDavConfig = snapshot.webDavConfig.sanitized();
    autoBackupConfig = snapshot.autoBackupConfig;
    notifyListeners();
  }

  LedgerSnapshot toSnapshot() => LedgerSnapshot(
    entries: entries,
    templates: templates,
    payRules: payRules,
    nightRule: nightRule,
    payPeriod: payPeriod,
    webDavConfig: webDavConfig,
    autoBackupConfig: autoBackupConfig,
  );
}
