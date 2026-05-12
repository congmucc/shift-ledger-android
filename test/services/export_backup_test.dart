import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ledger/src/app/ledger_state.dart';
import 'package:shift_ledger/src/domain/models.dart';
import 'package:shift_ledger/src/services/backup_service.dart';
import 'package:shift_ledger/src/services/csv_exporter.dart';

void main() {
  test('CSV export contains required audit columns', () {
    final rule = PayRule.defaultHourly(hourlyRate: 35);
    final entry = WorkEntry.create(
      workDate: DateTime(2026, 5, 13),
      startDateTime: DateTime(2026, 5, 13, 9),
      endDateTime: DateTime(2026, 5, 13, 18),
      breakMinutes: 60,
      type: EntryType.regular,
      payRule: rule,
      note: '替班',
    );
    final csv = CsvExporter().exportEntries(
      entries: [entry],
      rules: [rule],
      nightRule: NightRule.defaults(),
      range: DateRange.month(2026, 5),
    );

    expect(csv, contains('归属日期,开始日期时间,结束日期时间,跨天标记'));
    expect(csv, contains('计薪规则名称,计薪类型,规则快照摘要'));
    expect(csv, contains('基础收入,加班收入,夜班收入,补贴,扣款,收入合计,备注'));
    expect(csv, contains('替班'));
  });

  test('backup excludes WebDAV app password but restores ledger data', () {
    final state = LedgerState.seeded(now: DateTime(2026, 5, 13));
    state.updateWebDavConfig(const WebDavConfig(
      url: 'https://dav.jianguoyun.com/dav/shift-ledger',
      username: 'user@example.com',
      appPassword: 'secret-app-password',
      remotePath: 'shift-ledger-backup.json',
    ));

    final payload = BackupService().encode(state.toSnapshot());
    expect(payload, isNot(contains('secret-app-password')));
    expect(payload, contains('user@example.com'));

    final decoded = BackupService().decode(jsonDecode(payload) as Map<String, Object?>);
    expect(decoded.entries, isNotEmpty);
    expect(decoded.webDavConfig.appPassword, isEmpty);
  });
}
