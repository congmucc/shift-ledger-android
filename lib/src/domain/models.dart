import 'dart:math';

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
String ymd(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String hm(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String dateTimeText(DateTime value) => '${ymd(value)} ${hm(value)}';
String cnDateText(DateTime value) =>
    '${value.year}年 ${value.month}月 ${value.day}日';
bool isOvernightDateTimeRange(DateTime start, DateTime end) =>
    end.isBefore(start);
DateTime normalizeOvernightEnd(DateTime start, DateTime end) =>
    isOvernightDateTimeRange(start, end)
    ? end.add(const Duration(days: 1))
    : end;
DateTime parseDate(Object? value) => DateTime.parse(value as String);
DateTime? parseOptionalDate(Object? value) =>
    value == null || value == '' ? null : DateTime.parse(value as String);
double asDouble(Object? value, [double fallback = 0]) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;
int asInt(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
double asNonNegativeDouble(Object? value, [double fallback = 0]) {
  final parsed = asDouble(value, fallback);
  return parsed < 0 ? 0 : parsed;
}

int asNonNegativeInt(Object? value, [int fallback = 0]) {
  final parsed = asInt(value, fallback);
  return parsed < 0 ? 0 : parsed;
}

int clampInt(int value, int minValue, int maxValue) =>
    value.clamp(minValue, maxValue).toInt();

String newId(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(99999)}';

enum EntryType { regular, overtime, night, temporary }

enum PayBaseType { hourly, daily, monthly }

enum DailyPayMode { attendanceDay, shiftCount }

enum NightAllowanceMode { fixed, hourly, multiplier }

enum AdjustmentType { allowance, deduction }

enum PayPeriodMode { naturalMonth, monthlyStartDay, customRange }

enum AutoBackupStatus {
  idle,
  success,
  skipped,
  waiting,
  configIncomplete,
  failed,
}

extension EntryTypeX on EntryType {
  String get label => switch (this) {
    EntryType.regular => '普通',
    EntryType.overtime => '加班',
    EntryType.night => '夜班',
    EntryType.temporary => '临时班',
  };

  static EntryType fromName(String? value) => EntryType.values.firstWhere(
    (item) => item.name == value,
    orElse: () => EntryType.regular,
  );
}

extension PayBaseTypeX on PayBaseType {
  String get label => switch (this) {
    PayBaseType.hourly => '按小时',
    PayBaseType.daily => '按天',
    PayBaseType.monthly => '按月',
  };

  static PayBaseType fromName(String? value) => PayBaseType.values.firstWhere(
    (item) => item.name == value,
    orElse: () => PayBaseType.hourly,
  );
}

extension DailyPayModeX on DailyPayMode {
  String get label => switch (this) {
    DailyPayMode.attendanceDay => '按出勤日',
    DailyPayMode.shiftCount => '按班次数',
  };

  static DailyPayMode fromName(String? value) => DailyPayMode.values.firstWhere(
    (item) => item.name == value,
    orElse: () => DailyPayMode.attendanceDay,
  );
}

extension NightAllowanceModeX on NightAllowanceMode {
  String get label => switch (this) {
    NightAllowanceMode.fixed => '每次固定补贴',
    NightAllowanceMode.hourly => '按夜班小时补贴',
    NightAllowanceMode.multiplier => '夜班倍率',
  };

  static NightAllowanceMode fromName(String? value) =>
      NightAllowanceMode.values.firstWhere(
        (item) => item.name == value,
        orElse: () => NightAllowanceMode.fixed,
      );
}

extension AdjustmentTypeX on AdjustmentType {
  String get label => switch (this) {
    AdjustmentType.allowance => '补贴',
    AdjustmentType.deduction => '扣款',
  };

  static AdjustmentType fromName(String? value) =>
      AdjustmentType.values.firstWhere(
        (item) => item.name == value,
        orElse: () => AdjustmentType.allowance,
      );
}

extension PayPeriodModeX on PayPeriodMode {
  static PayPeriodMode fromName(String? value) =>
      PayPeriodMode.values.firstWhere(
        (item) => item.name == value,
        orElse: () => PayPeriodMode.naturalMonth,
      );
}

extension AutoBackupStatusX on AutoBackupStatus {
  String get label => switch (this) {
    AutoBackupStatus.idle => '尚未自动备份',
    AutoBackupStatus.success => '自动备份成功',
    AutoBackupStatus.skipped => '内容未变化，已跳过',
    AutoBackupStatus.waiting => '等待下次自动备份',
    AutoBackupStatus.configIncomplete => '需重新授权或配置不完整',
    AutoBackupStatus.failed => '自动备份失败',
  };

  static AutoBackupStatus fromName(String? value) =>
      AutoBackupStatus.values.firstWhere(
        (item) => item.name == value,
        orElse: () => AutoBackupStatus.idle,
      );
}

class DateRange {
  const DateRange({
    required this.start,
    required this.endExclusive,
    this.label,
  });

  final DateTime start;
  final DateTime endExclusive;
  final String? label;

  factory DateRange.month(int year, int month) {
    final start = DateTime(year, month);
    return DateRange(
      start: start,
      endExclusive: DateTime(year, month + 1),
      label: '$year年$month月',
    );
  }

  factory DateRange.year(int year) => DateRange(
    start: DateTime(year),
    endExclusive: DateTime(year + 1),
    label: '$year年',
  );

  factory DateRange.week(DateTime day) {
    final base = dateOnly(day);
    final start = base.subtract(Duration(days: base.weekday - 1));
    return DateRange(
      start: start,
      endExclusive: start.add(const Duration(days: 7)),
      label: '${ymd(start)} — ${ymd(start.add(const Duration(days: 6)))}',
    );
  }

  factory DateRange.custom(
    DateTime start,
    DateTime endInclusive, {
    String? label,
  }) => DateRange(
    start: dateOnly(start),
    endExclusive: dateOnly(endInclusive).add(const Duration(days: 1)),
    label: label ?? '${ymd(start)} — ${ymd(endInclusive)}',
  );

  int get dayCount => endExclusive.difference(start).inDays;
  DateTime get endInclusive => endExclusive.subtract(const Duration(days: 1));

  bool containsDate(DateTime date) {
    final d = dateOnly(date);
    return !d.isBefore(start) && d.isBefore(endExclusive);
  }

  bool overlaps(DateTime startDateTime, DateTime endDateTime) =>
      startDateTime.isBefore(endExclusive) && endDateTime.isAfter(start);
}

class Adjustment {
  const Adjustment({
    required this.id,
    required this.name,
    required this.amount,
    required this.type,
  });

  factory Adjustment.allowance(String name, double amount, {String? id}) =>
      Adjustment(
        id: id ?? newId('adj'),
        name: name,
        amount: amount.abs(),
        type: AdjustmentType.allowance,
      );

  factory Adjustment.deduction(String name, double amount, {String? id}) =>
      Adjustment(
        id: id ?? newId('adj'),
        name: name,
        amount: amount.abs(),
        type: AdjustmentType.deduction,
      );

  final String id;
  final String name;
  final double amount;
  final AdjustmentType type;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'type': type.name,
  };

  factory Adjustment.fromJson(Map<String, Object?> json) => Adjustment(
    id: json['id'] as String? ?? newId('adj'),
    name: json['name'] as String? ?? '补贴',
    amount: asNonNegativeDouble(json['amount']),
    type: AdjustmentTypeX.fromName(json['type'] as String?),
  );
}

class PayRule {
  const PayRule({
    required this.id,
    required this.name,
    required this.baseType,
    this.hourlyRate = 0,
    this.dailyRate = 0,
    this.monthlyRate = 0,
    this.dailyPayMode = DailyPayMode.attendanceDay,
    required this.effectiveFrom,
    this.effectiveTo,
    this.version = 1,
    this.standardHoursPerDay = 8,
    this.overtimeBaseHourlyRate = 0,
    this.overtimeThresholdHours = 8,
    this.overtimeMultiplier = 1.5,
    this.restDayMultiplier = 2,
    this.isDefault = false,
  });

  factory PayRule.defaultHourly({double hourlyRate = 35}) => PayRule(
    id: 'rule_hourly_default',
    name: '默认按小时',
    baseType: PayBaseType.hourly,
    hourlyRate: hourlyRate,
    effectiveFrom: DateTime(2026, 5, 1),
    isDefault: true,
  );

  factory PayRule.defaultDaily({double dailyRate = 280}) => PayRule(
    id: 'rule_daily_default',
    name: '按天规则',
    baseType: PayBaseType.daily,
    dailyRate: dailyRate,
    effectiveFrom: DateTime(2026, 5, 1),
  );

  factory PayRule.defaultMonthly({double monthlyRate = 8500}) => PayRule(
    id: 'rule_monthly_default',
    name: '月薪规则',
    baseType: PayBaseType.monthly,
    monthlyRate: monthlyRate,
    effectiveFrom: DateTime(2026, 5, 1),
  );

  final String id;
  final String name;
  final PayBaseType baseType;
  final double hourlyRate;
  final double dailyRate;
  final double monthlyRate;
  final DailyPayMode dailyPayMode;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final int version;
  final double standardHoursPerDay;
  final double overtimeBaseHourlyRate;
  final double overtimeThresholdHours;
  final double overtimeMultiplier;
  final double restDayMultiplier;
  final bool isDefault;

  bool activeOn(DateTime date) {
    final d = dateOnly(date);
    return !d.isBefore(dateOnly(effectiveFrom)) &&
        (effectiveTo == null || !d.isAfter(dateOnly(effectiveTo!)));
  }

  double overtimeHourlyBase({DateRange? range}) {
    if (overtimeBaseHourlyRate > 0) return overtimeBaseHourlyRate;
    return switch (baseType) {
      PayBaseType.hourly => hourlyRate,
      PayBaseType.daily =>
        standardHoursPerDay <= 0 ? 0 : dailyRate / standardHoursPerDay,
      PayBaseType.monthly => _monthlyHourlyBase(range),
    };
  }

  double _monthlyHourlyBase(DateRange? range) {
    final monthRange =
        range ?? DateRange.month(effectiveFrom.year, effectiveFrom.month);
    final hours = max(1, monthRange.dayCount * standardHoursPerDay);
    return monthlyRate / hours;
  }

  String get amountLabel => switch (baseType) {
    PayBaseType.hourly => '¥${hourlyRate.toStringAsFixed(0)}/h',
    PayBaseType.daily => '¥${dailyRate.toStringAsFixed(0)}/天',
    PayBaseType.monthly => '¥${monthlyRate.toStringAsFixed(0)}/月',
  };

  String get snapshotSummary =>
      '$name · ${baseType.label} · $amountLabel · v$version · ${ymd(effectiveFrom)}起';

  PayRule copyWith({
    String? id,
    String? name,
    PayBaseType? baseType,
    double? hourlyRate,
    double? dailyRate,
    double? monthlyRate,
    DailyPayMode? dailyPayMode,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    int? version,
    double? standardHoursPerDay,
    double? overtimeBaseHourlyRate,
    double? overtimeThresholdHours,
    double? overtimeMultiplier,
    double? restDayMultiplier,
    bool? isDefault,
  }) => PayRule(
    id: id ?? this.id,
    name: name ?? this.name,
    baseType: baseType ?? this.baseType,
    hourlyRate: hourlyRate ?? this.hourlyRate,
    dailyRate: dailyRate ?? this.dailyRate,
    monthlyRate: monthlyRate ?? this.monthlyRate,
    dailyPayMode: dailyPayMode ?? this.dailyPayMode,
    effectiveFrom: effectiveFrom ?? this.effectiveFrom,
    effectiveTo: effectiveTo ?? this.effectiveTo,
    version: version ?? this.version,
    standardHoursPerDay: standardHoursPerDay ?? this.standardHoursPerDay,
    overtimeBaseHourlyRate:
        overtimeBaseHourlyRate ?? this.overtimeBaseHourlyRate,
    overtimeThresholdHours:
        overtimeThresholdHours ?? this.overtimeThresholdHours,
    overtimeMultiplier: overtimeMultiplier ?? this.overtimeMultiplier,
    restDayMultiplier: restDayMultiplier ?? this.restDayMultiplier,
    isDefault: isDefault ?? this.isDefault,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'baseType': baseType.name,
    'hourlyRate': hourlyRate,
    'dailyRate': dailyRate,
    'monthlyRate': monthlyRate,
    'dailyPayMode': dailyPayMode.name,
    'effectiveFrom': ymd(effectiveFrom),
    'effectiveTo': effectiveTo == null ? null : ymd(effectiveTo!),
    'version': version,
    'standardHoursPerDay': standardHoursPerDay,
    'overtimeBaseHourlyRate': overtimeBaseHourlyRate,
    'overtimeThresholdHours': overtimeThresholdHours,
    'overtimeMultiplier': overtimeMultiplier,
    'restDayMultiplier': restDayMultiplier,
    'isDefault': isDefault,
  };

  factory PayRule.fromJson(Map<String, Object?> json) => PayRule(
    id: json['id'] as String? ?? newId('rule'),
    name: json['name'] as String? ?? '计薪规则',
    baseType: PayBaseTypeX.fromName(json['baseType'] as String?),
    hourlyRate: asNonNegativeDouble(json['hourlyRate']),
    dailyRate: asNonNegativeDouble(json['dailyRate']),
    monthlyRate: asNonNegativeDouble(json['monthlyRate']),
    dailyPayMode: DailyPayModeX.fromName(json['dailyPayMode'] as String?),
    effectiveFrom: parseDate(json['effectiveFrom'] ?? ymd(DateTime.now())),
    effectiveTo: parseOptionalDate(json['effectiveTo']),
    version: asNonNegativeInt(json['version'], 1),
    standardHoursPerDay: asNonNegativeDouble(json['standardHoursPerDay'], 8),
    overtimeBaseHourlyRate: asNonNegativeDouble(json['overtimeBaseHourlyRate']),
    overtimeThresholdHours: asNonNegativeDouble(
      json['overtimeThresholdHours'],
      8,
    ),
    overtimeMultiplier: asNonNegativeDouble(json['overtimeMultiplier'], 1.5),
    restDayMultiplier: asNonNegativeDouble(json['restDayMultiplier'], 2),
    isDefault: json['isDefault'] == true,
  );
}

class NightRule {
  const NightRule({
    this.startMinute = 22 * 60,
    this.endMinute = 6 * 60,
    this.mode = NightAllowanceMode.fixed,
    this.fixedAmount = 30,
    this.hourlyAmount = 5,
    this.multiplier = 1.2,
  });

  factory NightRule.defaults() => const NightRule();

  final int startMinute;
  final int endMinute;
  final NightAllowanceMode mode;
  final double fixedAmount;
  final double hourlyAmount;
  final double multiplier;

  NightRule copyWith({
    int? startMinute,
    int? endMinute,
    NightAllowanceMode? mode,
    double? fixedAmount,
    double? hourlyAmount,
    double? multiplier,
  }) => NightRule(
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
    mode: mode ?? this.mode,
    fixedAmount: fixedAmount ?? this.fixedAmount,
    hourlyAmount: hourlyAmount ?? this.hourlyAmount,
    multiplier: multiplier ?? this.multiplier,
  );

  String get label =>
      '${(startMinute ~/ 60).toString().padLeft(2, '0')}:00-${(endMinute ~/ 60).toString().padLeft(2, '0')}:00';

  Map<String, Object?> toJson() => {
    'startMinute': startMinute,
    'endMinute': endMinute,
    'mode': mode.name,
    'fixedAmount': fixedAmount,
    'hourlyAmount': hourlyAmount,
    'multiplier': multiplier,
  };

  factory NightRule.fromJson(Map<String, Object?> json) => NightRule(
    startMinute: clampInt(asInt(json['startMinute'], 22 * 60), 0, 23 * 60 + 59),
    endMinute: clampInt(asInt(json['endMinute'], 6 * 60), 0, 23 * 60 + 59),
    mode: NightAllowanceModeX.fromName(json['mode'] as String?),
    fixedAmount: asNonNegativeDouble(json['fixedAmount'], 30),
    hourlyAmount: asNonNegativeDouble(json['hourlyAmount'], 5),
    multiplier: asNonNegativeDouble(json['multiplier'], 1.2),
  );
}

class ShiftTemplate {
  static const standardId = 'tpl_standard';
  static const overtimeId = 'tpl_overtime';
  static const nightId = 'tpl_night';
  static const builtInIds = <String>[standardId, overtimeId, nightId];

  const ShiftTemplate({
    required this.id,
    required this.name,
    required this.startMinute,
    required this.endMinute,
    this.breakMinutes = 0,
    this.type = EntryType.regular,
    this.colorToken = 'work-amber',
    this.defaultPayRuleId,
    this.defaultLocationName = '',
    this.defaultJobTypeName = '',
    this.defaultAdjustments = const [],
  });

  static List<ShiftTemplate> builtInTemplates({String? payRuleId}) => [
    ShiftTemplate.standard(payRuleId: payRuleId),
    ShiftTemplate.overtime(payRuleId: payRuleId),
    ShiftTemplate.night(payRuleId: payRuleId),
  ];

  static ShiftTemplate? builtInById(String id, {String? payRuleId}) {
    switch (id) {
      case standardId:
        return ShiftTemplate.standard(payRuleId: payRuleId);
      case overtimeId:
        return ShiftTemplate.overtime(payRuleId: payRuleId);
      case nightId:
        return ShiftTemplate.night(payRuleId: payRuleId);
    }
    return null;
  }

  factory ShiftTemplate.standard({String? payRuleId}) => ShiftTemplate(
    id: standardId,
    name: '标准班次',
    startMinute: 9 * 60,
    endMinute: 18 * 60,
    breakMinutes: 60,
    defaultPayRuleId: payRuleId,
  );

  factory ShiftTemplate.night({String? payRuleId}) => ShiftTemplate(
    id: nightId,
    name: '夜班',
    startMinute: 22 * 60,
    endMinute: 6 * 60,
    breakMinutes: 0,
    type: EntryType.night,
    colorToken: 'night-slate',
    defaultPayRuleId: payRuleId,
  );

  factory ShiftTemplate.overtime({String? payRuleId}) => ShiftTemplate(
    id: overtimeId,
    name: '加班',
    startMinute: 18 * 60,
    endMinute: 21 * 60,
    breakMinutes: 0,
    type: EntryType.overtime,
    colorToken: 'overtime-moss',
    defaultPayRuleId: payRuleId,
  );

  final String id;
  final String name;
  final int startMinute;
  final int endMinute;
  final int breakMinutes;
  final EntryType type;
  final String colorToken;
  final String? defaultPayRuleId;
  final String defaultLocationName;
  final String defaultJobTypeName;
  final List<Adjustment> defaultAdjustments;

  bool get isBuiltIn => builtInIds.contains(id);

  ShiftTemplate copyWith({
    String? id,
    String? name,
    int? startMinute,
    int? endMinute,
    int? breakMinutes,
    EntryType? type,
    String? colorToken,
    String? defaultPayRuleId,
    String? defaultLocationName,
    String? defaultJobTypeName,
    List<Adjustment>? defaultAdjustments,
  }) => ShiftTemplate(
    id: id ?? this.id,
    name: name ?? this.name,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
    breakMinutes: breakMinutes ?? this.breakMinutes,
    type: type ?? this.type,
    colorToken: colorToken ?? this.colorToken,
    defaultPayRuleId: defaultPayRuleId ?? this.defaultPayRuleId,
    defaultLocationName: defaultLocationName ?? this.defaultLocationName,
    defaultJobTypeName: defaultJobTypeName ?? this.defaultJobTypeName,
    defaultAdjustments: defaultAdjustments ?? this.defaultAdjustments,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'startMinute': startMinute,
    'endMinute': endMinute,
    'breakMinutes': breakMinutes,
    'type': type.name,
    'colorToken': colorToken,
    'defaultPayRuleId': defaultPayRuleId,
    'defaultLocationName': defaultLocationName,
    'defaultJobTypeName': defaultJobTypeName,
    'defaultAdjustments': defaultAdjustments.map((a) => a.toJson()).toList(),
  };

  factory ShiftTemplate.fromJson(Map<String, Object?> json) => ShiftTemplate(
    id: json['id'] as String? ?? newId('tpl'),
    name: json['name'] as String? ?? '模板',
    startMinute: clampInt(asInt(json['startMinute'], 9 * 60), 0, 23 * 60 + 59),
    endMinute: clampInt(asInt(json['endMinute'], 18 * 60), 0, 23 * 60 + 59),
    breakMinutes: asNonNegativeInt(json['breakMinutes'], 0),
    type: EntryTypeX.fromName(json['type'] as String?),
    colorToken: json['colorToken'] as String? ?? 'work-amber',
    defaultPayRuleId: json['defaultPayRuleId'] as String?,
    defaultLocationName: json['defaultLocationName'] as String? ?? '',
    defaultJobTypeName: json['defaultJobTypeName'] as String? ?? '',
    defaultAdjustments: ((json['defaultAdjustments'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Adjustment.fromJson(Map<String, Object?>.from(item)))
        .toList(),
  );
}

class WorkEntry {
  const WorkEntry({
    required this.id,
    required this.workDate,
    required this.startDateTime,
    required this.endDateTime,
    this.breakMinutes = 0,
    this.type = EntryType.regular,
    this.templateId,
    this.locationName = '',
    this.jobTypeName = '',
    required this.payRuleId,
    required this.payRuleSnapshot,
    this.copiedFromDayKey,
    this.note = '',
    this.adjustments = const [],
    this.isRestDayOvertime = false,
  });

  factory WorkEntry.create({
    String? id,
    required DateTime workDate,
    required DateTime startDateTime,
    required DateTime endDateTime,
    int breakMinutes = 0,
    EntryType type = EntryType.regular,
    String? templateId,
    String locationName = '',
    String jobTypeName = '',
    required PayRule payRule,
    String? copiedFromDayKey,
    String note = '',
    List<Adjustment> adjustments = const [],
    bool isRestDayOvertime = false,
  }) {
    final normalizedEnd = normalizeOvernightEnd(startDateTime, endDateTime);
    return WorkEntry(
      id: id ?? newId('entry'),
      workDate: dateOnly(workDate),
      startDateTime: startDateTime,
      endDateTime: normalizedEnd,
      breakMinutes: breakMinutes,
      type: type,
      templateId: templateId,
      locationName: locationName,
      jobTypeName: jobTypeName,
      payRuleId: payRule.id,
      payRuleSnapshot: payRule,
      copiedFromDayKey: copiedFromDayKey,
      note: note,
      adjustments: adjustments,
      isRestDayOvertime: isRestDayOvertime,
    );
  }

  final String id;
  final DateTime workDate;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final int breakMinutes;
  final EntryType type;
  final String? templateId;
  final String locationName;
  final String jobTypeName;
  final String payRuleId;
  final PayRule payRuleSnapshot;
  final String? copiedFromDayKey;
  final String note;
  final List<Adjustment> adjustments;
  final bool isRestDayOvertime;

  bool get isCrossDay => dateOnly(startDateTime) != dateOnly(endDateTime);
  double get grossHours => endDateTime.difference(startDateTime).inMinutes / 60;
  int get effectiveBreakMinutes {
    final grossMinutes = max(
      0,
      endDateTime.difference(startDateTime).inMinutes,
    );
    return clampInt(breakMinutes, 0, grossMinutes);
  }

  double get netHours => max(0, grossHours - effectiveBreakMinutes / 60);
  bool get isManualOvertime => type == EntryType.overtime || isRestDayOvertime;
  bool get hasNote => note.trim().isNotEmpty;
  double get allowanceTotal => adjustments
      .where((item) => item.type == AdjustmentType.allowance)
      .fold(0.0, (sum, item) => sum + item.amount);
  double get deductionTotal => adjustments
      .where((item) => item.type == AdjustmentType.deduction)
      .fold(0.0, (sum, item) => sum + item.amount);

  String get timeRangeLabel => isCrossDay
      ? '${hm(startDateTime)} — 次日 ${hm(endDateTime)}'
      : '${hm(startDateTime)} — ${hm(endDateTime)}';

  WorkEntry copyWith({
    String? id,
    DateTime? workDate,
    DateTime? startDateTime,
    DateTime? endDateTime,
    int? breakMinutes,
    EntryType? type,
    String? templateId,
    String? locationName,
    String? jobTypeName,
    String? payRuleId,
    PayRule? payRuleSnapshot,
    String? copiedFromDayKey,
    String? note,
    List<Adjustment>? adjustments,
    bool? isRestDayOvertime,
  }) => WorkEntry(
    id: id ?? this.id,
    workDate: workDate ?? this.workDate,
    startDateTime: startDateTime ?? this.startDateTime,
    endDateTime: endDateTime ?? this.endDateTime,
    breakMinutes: breakMinutes ?? this.breakMinutes,
    type: type ?? this.type,
    templateId: templateId ?? this.templateId,
    locationName: locationName ?? this.locationName,
    jobTypeName: jobTypeName ?? this.jobTypeName,
    payRuleId: payRuleId ?? this.payRuleId,
    payRuleSnapshot: payRuleSnapshot ?? this.payRuleSnapshot,
    copiedFromDayKey: copiedFromDayKey ?? this.copiedFromDayKey,
    note: note ?? this.note,
    adjustments: adjustments ?? this.adjustments,
    isRestDayOvertime: isRestDayOvertime ?? this.isRestDayOvertime,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'workDate': ymd(workDate),
    'startDateTime': startDateTime.toIso8601String(),
    'endDateTime': endDateTime.toIso8601String(),
    'breakMinutes': breakMinutes,
    'type': type.name,
    'templateId': templateId,
    'locationName': locationName,
    'jobTypeName': jobTypeName,
    'payRuleId': payRuleId,
    'payRuleSnapshot': payRuleSnapshot.toJson(),
    'copiedFromDayKey': copiedFromDayKey,
    'note': note,
    'adjustments': adjustments.map((a) => a.toJson()).toList(),
    'isRestDayOvertime': isRestDayOvertime,
  };

  factory WorkEntry.fromJson(Map<String, Object?> json) => WorkEntry(
    id: json['id'] as String? ?? newId('entry'),
    workDate: parseDate(json['workDate'] ?? ymd(DateTime.now())),
    startDateTime: DateTime.parse(json['startDateTime'] as String),
    endDateTime: DateTime.parse(json['endDateTime'] as String),
    breakMinutes: asNonNegativeInt(json['breakMinutes']),
    type: EntryTypeX.fromName(json['type'] as String?),
    templateId: json['templateId'] as String?,
    locationName: json['locationName'] as String? ?? '',
    jobTypeName: json['jobTypeName'] as String? ?? '',
    payRuleId: json['payRuleId'] as String? ?? '',
    payRuleSnapshot: PayRule.fromJson(
      Map<String, Object?>.from(json['payRuleSnapshot'] as Map? ?? {}),
    ),
    copiedFromDayKey: json['copiedFromDayKey'] as String?,
    note: json['note'] as String? ?? '',
    adjustments: ((json['adjustments'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Adjustment.fromJson(Map<String, Object?>.from(item)))
        .toList(),
    isRestDayOvertime: json['isRestDayOvertime'] == true,
  );
}

class PayPeriod {
  const PayPeriod({
    this.mode = PayPeriodMode.naturalMonth,
    this.monthStartDay = 1,
    this.customStartDate,
    this.customEndDate,
  });

  final PayPeriodMode mode;
  final int monthStartDay;
  final DateTime? customStartDate;
  final DateTime? customEndDate;

  DateRange rangeFor(DateTime anchor) {
    return switch (mode) {
      PayPeriodMode.naturalMonth => DateRange.month(anchor.year, anchor.month),
      PayPeriodMode.monthlyStartDay => _monthlyStartRange(anchor),
      PayPeriodMode.customRange => DateRange.custom(
        customStartDate ?? DateTime(anchor.year, anchor.month),
        customEndDate ?? DateTime(anchor.year, anchor.month + 1, 0),
        label: '自定义',
      ),
    };
  }

  DateRange _monthlyStartRange(DateTime anchor) {
    final preferredDay = clampInt(monthStartDay, 1, 31);
    var start = _dayInMonth(anchor.year, anchor.month, preferredDay);
    if (dateOnly(anchor).isBefore(start)) {
      start = _dayInMonth(anchor.year, anchor.month - 1, preferredDay);
    }
    return DateRange(
      start: start,
      endExclusive: _dayInMonth(start.year, start.month + 1, preferredDay),
      label: '每月$preferredDay日起',
    );
  }

  DateTime _dayInMonth(int year, int month, int preferredDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, clampInt(preferredDay, 1, lastDay));
  }

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'monthStartDay': monthStartDay,
    'customStartDate': customStartDate == null ? null : ymd(customStartDate!),
    'customEndDate': customEndDate == null ? null : ymd(customEndDate!),
  };

  factory PayPeriod.fromJson(Map<String, Object?> json) => PayPeriod(
    mode: PayPeriodModeX.fromName(json['mode'] as String?),
    monthStartDay: clampInt(asInt(json['monthStartDay'], 1), 1, 31),
    customStartDate: parseOptionalDate(json['customStartDate']),
    customEndDate: parseOptionalDate(json['customEndDate']),
  );
}

class WebDavConfig {
  const WebDavConfig({
    this.url = '',
    this.username = '',
    this.appPassword = '',
    this.remotePath = 'shift-ledger-backup.json',
    this.lastBackupAt,
  });

  final String url;
  final String username;
  final String appPassword;
  final String remotePath;
  final DateTime? lastBackupAt;

  bool get isConfigured =>
      url.isNotEmpty && username.isNotEmpty && appPassword.isNotEmpty;

  WebDavConfig sanitized() => copyWith(appPassword: '');

  WebDavConfig copyWith({
    String? url,
    String? username,
    String? appPassword,
    String? remotePath,
    DateTime? lastBackupAt,
  }) => WebDavConfig(
    url: url ?? this.url,
    username: username ?? this.username,
    appPassword: appPassword ?? this.appPassword,
    remotePath: remotePath ?? this.remotePath,
    lastBackupAt: lastBackupAt ?? this.lastBackupAt,
  );

  Map<String, Object?> toJson({bool includeSecret = false}) => {
    'url': url,
    'username': username,
    'appPassword': includeSecret ? appPassword : '',
    'remotePath': remotePath,
    'lastBackupAt': lastBackupAt?.toIso8601String(),
  };

  factory WebDavConfig.fromJson(Map<String, Object?> json) => WebDavConfig(
    url: json['url'] as String? ?? '',
    username: json['username'] as String? ?? '',
    appPassword: json['appPassword'] as String? ?? '',
    remotePath: json['remotePath'] as String? ?? 'shift-ledger-backup.json',
    lastBackupAt: parseOptionalDate(json['lastBackupAt']),
  );
}

class AutoBackupConfig {
  const AutoBackupConfig({
    this.enabled = false,
    this.remotePath = 'shift-ledger-backup.json',
    this.lastTargetSignature = '',
    this.lastSuccessAt,
    this.lastAttemptAt,
    this.lastContentHash = '',
    this.dailyCountDate,
    this.dailySuccessCount = 0,
    this.lastStatus = AutoBackupStatus.idle,
    this.lastError = '',
  });

  final bool enabled;
  final String remotePath;
  final String lastTargetSignature;
  final DateTime? lastSuccessAt;
  final DateTime? lastAttemptAt;
  final String lastContentHash;
  final DateTime? dailyCountDate;
  final int dailySuccessCount;
  final AutoBackupStatus lastStatus;
  final String lastError;

  AutoBackupConfig copyWith({
    bool? enabled,
    String? remotePath,
    String? lastTargetSignature,
    DateTime? lastSuccessAt,
    DateTime? lastAttemptAt,
    String? lastContentHash,
    DateTime? dailyCountDate,
    int? dailySuccessCount,
    AutoBackupStatus? lastStatus,
    String? lastError,
  }) => AutoBackupConfig(
    enabled: enabled ?? this.enabled,
    remotePath: remotePath ?? this.remotePath,
    lastTargetSignature: lastTargetSignature ?? this.lastTargetSignature,
    lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    lastContentHash: lastContentHash ?? this.lastContentHash,
    dailyCountDate: dailyCountDate ?? this.dailyCountDate,
    dailySuccessCount: dailySuccessCount ?? this.dailySuccessCount,
    lastStatus: lastStatus ?? this.lastStatus,
    lastError: lastError ?? this.lastError,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'remotePath': remotePath,
    'lastTargetSignature': lastTargetSignature,
    'lastSuccessAt': lastSuccessAt?.toIso8601String(),
    'lastAttemptAt': lastAttemptAt?.toIso8601String(),
    'lastContentHash': lastContentHash,
    'dailyCountDate': dailyCountDate == null ? null : ymd(dailyCountDate!),
    'dailySuccessCount': dailySuccessCount,
    'lastStatus': lastStatus.name,
    'lastError': lastError,
  };

  factory AutoBackupConfig.fromJson(Map<String, Object?> json) =>
      AutoBackupConfig(
        enabled: json['enabled'] == true,
        remotePath: json['remotePath'] as String? ?? 'shift-ledger-backup.json',
        lastTargetSignature: json['lastTargetSignature'] as String? ?? '',
        lastSuccessAt: parseOptionalDate(json['lastSuccessAt']),
        lastAttemptAt: parseOptionalDate(json['lastAttemptAt']),
        lastContentHash: json['lastContentHash'] as String? ?? '',
        dailyCountDate: parseOptionalDate(json['dailyCountDate']),
        dailySuccessCount: asNonNegativeInt(json['dailySuccessCount']),
        lastStatus: AutoBackupStatusX.fromName(json['lastStatus'] as String?),
        lastError: json['lastError'] as String? ?? '',
      );
}

class DeletedDayRecord {
  const DeletedDayRecord({
    required this.id,
    required this.day,
    required this.deletedAt,
    required this.entries,
  });

  final String id;
  final DateTime day;
  final DateTime deletedAt;
  final List<WorkEntry> entries;

  int get segmentCount => entries.length;
  double get totalHours =>
      entries.fold(0, (total, entry) => total + entry.netHours);

  Map<String, Object?> toJson() => {
    'id': id,
    'day': ymd(day),
    'deletedAt': deletedAt.toIso8601String(),
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };

  factory DeletedDayRecord.fromJson(Map<String, Object?> json) =>
      DeletedDayRecord(
        id: json['id'] as String? ?? newId('deleted_day'),
        day: parseDate(json['day']),
        deletedAt: parseOptionalDate(json['deletedAt']) ?? DateTime.now(),
        entries: _decodeList(json['entries'], WorkEntry.fromJson),
      );
}

class LedgerSnapshot {
  const LedgerSnapshot({
    required this.entries,
    required this.templates,
    required this.payRules,
    required this.nightRule,
    required this.payPeriod,
    required this.webDavConfig,
    this.autoBackupConfig = const AutoBackupConfig(),
    this.recentDeletedDays = const [],
  });

  final List<WorkEntry> entries;
  final List<ShiftTemplate> templates;
  final List<PayRule> payRules;
  final NightRule nightRule;
  final PayPeriod payPeriod;
  final WebDavConfig webDavConfig;
  final AutoBackupConfig autoBackupConfig;
  final List<DeletedDayRecord> recentDeletedDays;

  LedgerSnapshot sanitizedForBackup() => LedgerSnapshot(
    entries: entries,
    templates: templates,
    payRules: payRules,
    nightRule: nightRule,
    payPeriod: payPeriod,
    webDavConfig: webDavConfig.sanitized(),
    autoBackupConfig: autoBackupConfig,
    recentDeletedDays: recentDeletedDays,
  );

  Map<String, Object?> toJson({bool includeSecrets = false}) => {
    'schemaVersion': 1,
    'entries': entries.map((entry) => entry.toJson()).toList(),
    'templates': templates.map((tpl) => tpl.toJson()).toList(),
    'payRules': payRules.map((rule) => rule.toJson()).toList(),
    'nightRule': nightRule.toJson(),
    'payPeriod': payPeriod.toJson(),
    'webDavConfig': webDavConfig.toJson(includeSecret: includeSecrets),
    'autoBackupConfig': autoBackupConfig.toJson(),
    'recentDeletedDays': recentDeletedDays.map((day) => day.toJson()).toList(),
  };

  factory LedgerSnapshot.fromJson(Map<String, Object?> json) => LedgerSnapshot(
    entries: _decodeList(json['entries'], WorkEntry.fromJson),
    templates: _decodeList(json['templates'], ShiftTemplate.fromJson),
    payRules: _decodeList(json['payRules'], PayRule.fromJson),
    nightRule: _decodeObject(
      json['nightRule'],
      NightRule.fromJson,
      NightRule.defaults(),
    ),
    payPeriod: _decodeObject(
      json['payPeriod'],
      PayPeriod.fromJson,
      const PayPeriod(),
    ),
    webDavConfig: _decodeObject(
      json['webDavConfig'],
      WebDavConfig.fromJson,
      const WebDavConfig(),
    ),
    autoBackupConfig: _decodeObject(
      json['autoBackupConfig'],
      AutoBackupConfig.fromJson,
      const AutoBackupConfig(),
    ),
    recentDeletedDays: _decodeList(
      json['recentDeletedDays'],
      DeletedDayRecord.fromJson,
    ),
  );
}

List<T> _decodeList<T>(
  Object? value,
  T Function(Map<String, Object?> json) decode,
) => [
  for (final item in value is List ? value : const [])
    if (item is Map)
      ..._decodeItem(() => decode(Map<String, Object?>.from(item))),
];

List<T> _decodeItem<T>(T Function() decode) {
  try {
    return [decode()];
  } catch (_) {
    return const [];
  }
}

T _decodeObject<T>(
  Object? value,
  T Function(Map<String, Object?> json) decode,
  T fallback,
) {
  try {
    return decode(Map<String, Object?>.from(value as Map? ?? {}));
  } catch (_) {
    return fallback;
  }
}

class EntryCalculation {
  const EntryCalculation({
    required this.entry,
    required this.regularHours,
    required this.overtimeHours,
    required this.nightHours,
    required this.baseIncome,
    required this.overtimeIncome,
    required this.nightIncome,
  });

  final WorkEntry entry;
  final double regularHours;
  final double overtimeHours;
  final double nightHours;
  final double baseIncome;
  final double overtimeIncome;
  final double nightIncome;

  double get income =>
      baseIncome +
      overtimeIncome +
      nightIncome +
      entry.allowanceTotal -
      entry.deductionTotal;
}

class LedgerSummary {
  const LedgerSummary({
    required this.range,
    required this.totalHours,
    required this.regularHours,
    required this.overtimeHours,
    required this.nightHours,
    required this.attendanceDays,
    required this.overtimeDays,
    required this.nightShiftCount,
    required this.noteDays,
    required this.longDurationDays,
    required this.allowance,
    required this.deduction,
    required this.baseIncome,
    required this.overtimeIncome,
    required this.nightIncome,
    required this.calculations,
  });

  final DateRange range;
  final double totalHours;
  final double regularHours;
  final double overtimeHours;
  final double nightHours;
  final int attendanceDays;
  final int overtimeDays;
  final int nightShiftCount;
  final int noteDays;
  final int longDurationDays;
  final double allowance;
  final double deduction;
  final double baseIncome;
  final double overtimeIncome;
  final double nightIncome;
  final List<EntryCalculation> calculations;

  double get income =>
      baseIncome + overtimeIncome + nightIncome + allowance - deduction;
}
