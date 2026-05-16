import '../domain/models.dart';

class RecordUiSummary {
  const RecordUiSummary({
    required this.totalHours,
    required this.regularHours,
    required this.manualOvertimeHours,
    required this.nightHours,
    required this.segmentCount,
    required this.manualOvertimeDays,
    required this.nightDays,
    required this.noteDays,
  });

  final double totalHours;
  final double regularHours;
  final double manualOvertimeHours;
  final double nightHours;
  final int segmentCount;
  final int manualOvertimeDays;
  final int nightDays;
  final int noteDays;
}

RecordUiSummary summarizeRecordEntries(Iterable<WorkEntry> entries) {
  var totalHours = 0.0;
  var regularHours = 0.0;
  var manualOvertimeHours = 0.0;
  var nightHours = 0.0;
  var segmentCount = 0;
  final manualOvertimeDays = <String>{};
  final nightDays = <String>{};
  final noteDays = <String>{};

  for (final entry in entries) {
    final entryHours = entry.netHours;
    final dayKey = ymd(entry.workDate);
    totalHours += entryHours;
    segmentCount++;
    if (entry.hasNote) noteDays.add(dayKey);
    if (entry.type == EntryType.night) {
      nightHours += entryHours;
      nightDays.add(dayKey);
      continue;
    }
    if (entry.isManualOvertime) {
      manualOvertimeHours += entryHours;
      manualOvertimeDays.add(dayKey);
      continue;
    }
    regularHours += entryHours;
  }

  return RecordUiSummary(
    totalHours: totalHours,
    regularHours: regularHours,
    manualOvertimeHours: manualOvertimeHours,
    nightHours: nightHours,
    segmentCount: segmentCount,
    manualOvertimeDays: manualOvertimeDays.length,
    nightDays: nightDays.length,
    noteDays: noteDays.length,
  );
}
