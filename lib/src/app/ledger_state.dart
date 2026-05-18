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
    List<DeletedDayRecord>? recentDeletedDays,
  }) : now = dateOnly(now),
       entries = entries ?? [],
       payRules = _safePayRules(payRules),
       templates = _safeTemplates(templates, payRules),
       nightRule = nightRule ?? NightRule.defaults(),
       payPeriod = payPeriod ?? const PayPeriod(),
       webDavConfig = webDavConfig ?? const WebDavConfig(),
       autoBackupConfig = autoBackupConfig ?? const AutoBackupConfig(),
       recentDeletedDays = recentDeletedDays ?? [];

  static List<PayRule> _safePayRules(List<PayRule>? rules) {
    if (rules != null && rules.isNotEmpty) return rules;
    return [
      PayRule.defaultHourly(),
      PayRule.defaultDaily(),
      PayRule.defaultMonthly(),
    ];
  }

  static List<ShiftTemplate> _safeTemplates(
    List<ShiftTemplate>? templates,
    List<PayRule>? rules,
  ) {
    final fallbackRuleId = _safePayRules(rules).first.id;
    final existing = templates ?? const <ShiftTemplate>[];
    if (existing.isEmpty) {
      return ShiftTemplate.builtInTemplates(payRuleId: fallbackRuleId);
    }
    final existingIds = existing.map((template) => template.id).toSet();
    return [
      ...existing,
      for (final builtIn in ShiftTemplate.builtInTemplates(
        payRuleId: fallbackRuleId,
      ))
        if (!existingIds.contains(builtIn.id)) builtIn,
    ];
  }

  factory LedgerState.empty({DateTime? now}) {
    final rule = PayRule.defaultHourly();
    return LedgerState(
      now: now ?? DateTime.now(),
      payRules: [rule, PayRule.defaultDaily(), PayRule.defaultMonthly()],
      templates: ShiftTemplate.builtInTemplates(payRuleId: rule.id),
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
      templates: ShiftTemplate.builtInTemplates(payRuleId: rule.id),
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
        recentDeletedDays: snapshot.recentDeletedDays,
      );

  final DateTime now;
  List<WorkEntry> entries;
  List<ShiftTemplate> templates;
  List<PayRule> payRules;
  NightRule nightRule;
  PayPeriod payPeriod;
  WebDavConfig webDavConfig;
  AutoBackupConfig autoBackupConfig;
  List<DeletedDayRecord> recentDeletedDays;

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
    end = normalizeOvernightEnd(start, end);
    final rule = ruleForDate(targetDay, preferredRuleId: tpl.defaultPayRuleId);
    return WorkEntry.create(
      workDate: targetDay,
      startDateTime: start,
      endDateTime: end,
      breakMinutes: tpl.breakMinutes,
      type: type ?? tpl.type,
      templateId: tpl.id,
      locationName: tpl.defaultLocationName,
      jobTypeName: tpl.defaultJobTypeName,
      payRule: rule,
      adjustments: tpl.defaultAdjustments,
    );
  }

  void addEntry(WorkEntry entry) {
    entries = [...entries, entry]
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    notifyListeners();
  }

  void addEntries(Iterable<WorkEntry> additions) {
    final next = additions.toList();
    if (next.isEmpty) return;
    entries = [...entries, ...next]
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

  DeletedDayRecord? deleteDay(DateTime day) {
    final key = ymd(day);
    final removedEntries = entriesForDay(day);
    if (removedEntries.isEmpty) return null;
    final deleted = DeletedDayRecord(
      id: newId('deleted_day'),
      day: dateOnly(day),
      deletedAt: DateTime.now(),
      entries: removedEntries,
    );
    entries = entries.where((entry) => ymd(entry.workDate) != key).toList();
    recentDeletedDays = [
      deleted,
      for (final item in recentDeletedDays)
        if (ymd(item.day) != key) item,
    ].take(5).toList();
    notifyListeners();
    return deleted;
  }

  bool restoreDeletedDay(String id) {
    final index = recentDeletedDays.indexWhere((item) => item.id == id);
    if (index < 0) return false;
    final restorePoint = recentDeletedDays[index];
    final restoredIds = restorePoint.entries.map((entry) => entry.id).toSet();
    entries = [
      for (final entry in entries)
        if (!restoredIds.contains(entry.id)) entry,
      ...restorePoint.entries,
    ]..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    recentDeletedDays = [
      for (var i = 0; i < recentDeletedDays.length; i++)
        if (i != index) recentDeletedDays[i],
    ];
    notifyListeners();
    return true;
  }

  void replaceDayEntries(
    DateTime originalDay,
    DateTime targetDay,
    List<WorkEntry> replacements,
  ) {
    final originalKey = ymd(originalDay);
    final targetKey = ymd(targetDay);
    final replacementIds = replacements.map((entry) => entry.id).toSet();
    entries = [
      for (final entry in entries)
        if (originalKey == targetKey) ...[
          if (ymd(entry.workDate) != originalKey) entry,
        ] else ...[
          if (ymd(entry.workDate) != originalKey &&
              !(ymd(entry.workDate) == targetKey &&
                  replacementIds.contains(entry.id)))
            entry,
        ],
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

  bool deleteShiftTemplate(String id) {
    if (ShiftTemplate.builtInIds.contains(id)) return false;
    if (templates.length <= 1) return false;
    final next = templates.where((template) => template.id != id).toList();
    if (next.length == templates.length || next.isEmpty) return false;
    templates = next;
    notifyListeners();
    return true;
  }

  void setDefaultShiftTemplate(String id) {
    final index = templates.indexWhere((item) => item.id == id);
    if (index <= 0) return;
    final next = [...templates];
    final selected = next.removeAt(index);
    templates = [selected, ...next];
    notifyListeners();
  }

  bool restoreShiftTemplate(String id) {
    if (!ShiftTemplate.builtInIds.contains(id)) return false;
    final index = templates.indexWhere((item) => item.id == id);
    if (index < 0) return false;
    final restored = ShiftTemplate.builtInById(id, payRuleId: defaultRule.id);
    if (restored == null) return false;
    templates = [...templates]..[index] = restored;
    notifyListeners();
    return true;
  }

  void updateWebDavConfig(WebDavConfig config) {
    webDavConfig = config;
    autoBackupConfig = autoBackupConfig.copyWith(remotePath: config.remotePath);
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
    final nextPayRules = snapshot.payRules.isEmpty
        ? payRules
        : snapshot.payRules;
    entries = snapshot.entries;
    payRules = nextPayRules;
    templates = _safeTemplates(
      snapshot.templates.isEmpty ? templates : snapshot.templates,
      nextPayRules,
    );
    nightRule = snapshot.nightRule;
    payPeriod = snapshot.payPeriod;
    webDavConfig = snapshot.webDavConfig.sanitized();
    autoBackupConfig = snapshot.autoBackupConfig.copyWith(
      remotePath: snapshot.webDavConfig.remotePath,
    );
    recentDeletedDays = snapshot.recentDeletedDays;
    notifyListeners();
  }

  LedgerSnapshot toSnapshot() => LedgerSnapshot(
    entries: entries,
    templates: templates,
    payRules: payRules,
    nightRule: nightRule,
    payPeriod: payPeriod,
    webDavConfig: webDavConfig,
    autoBackupConfig: autoBackupConfig.copyWith(
      remotePath: webDavConfig.remotePath,
    ),
    recentDeletedDays: recentDeletedDays,
  );
}
