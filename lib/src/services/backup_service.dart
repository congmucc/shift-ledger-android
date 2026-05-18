import 'dart:convert';
import 'dart:math';

import '../domain/models.dart';

class BackupDecodeDiagnostics {
  const BackupDecodeDiagnostics({
    this.malformedEntries = 0,
    this.malformedTemplates = 0,
    this.malformedPayRules = 0,
    this.malformedDeletedDays = 0,
  });

  final int malformedEntries;
  final int malformedTemplates;
  final int malformedPayRules;
  final int malformedDeletedDays;

  int get totalMalformedCount =>
      malformedEntries +
      malformedTemplates +
      malformedPayRules +
      malformedDeletedDays;

  bool get hasWarnings => totalMalformedCount > 0;

  String get summary {
    final parts = <String>[
      if (malformedEntries > 0) '$malformedEntries条工时记录',
      if (malformedTemplates > 0) '$malformedTemplates条班次模板',
      if (malformedPayRules > 0) '$malformedPayRules条计薪规则',
      if (malformedDeletedDays > 0) '$malformedDeletedDays条最近删除记录',
    ];
    return parts.join('、');
  }
}

class BackupDecodeResult {
  const BackupDecodeResult({
    required this.snapshot,
    this.diagnostics = const BackupDecodeDiagnostics(),
  });

  final LedgerSnapshot snapshot;
  final BackupDecodeDiagnostics diagnostics;
}

class BackupService {
  const BackupService();

  String encode(LedgerSnapshot snapshot) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(snapshot.sanitizedForBackup().toJson());
  }

  BackupDecodeResult decodeWithReport(Map<String, Object?> json) {
    final snapshot = LedgerSnapshot.fromJson(json);
    final diagnostics = BackupDecodeDiagnostics(
      malformedEntries: _malformedCount(
        json['entries'],
        snapshot.entries.length,
      ),
      malformedTemplates: _malformedCount(
        json['templates'],
        snapshot.templates.length,
      ),
      malformedPayRules: _malformedCount(
        json['payRules'],
        snapshot.payRules.length,
      ),
      malformedDeletedDays: _malformedCount(
        json['recentDeletedDays'],
        snapshot.recentDeletedDays.length,
      ),
    );
    return BackupDecodeResult(snapshot: snapshot, diagnostics: diagnostics);
  }

  LedgerSnapshot decode(Map<String, Object?> json) => decodeWithReport(json).snapshot;

  int _malformedCount(Object? rawList, int decodedCount) {
    if (rawList is! List) return 0;
    final sourceCount = rawList.whereType<Map>().length;
    return max(0, sourceCount - decodedCount);
  }
}
