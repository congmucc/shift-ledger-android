import 'dart:convert';

import '../domain/models.dart';

class BackupService {
  const BackupService();

  String encode(LedgerSnapshot snapshot) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(snapshot.sanitizedForBackup().toJson());
  }

  LedgerSnapshot decode(Map<String, Object?> json) => LedgerSnapshot.fromJson(json);
}
