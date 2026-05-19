import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android release workflow pins the verified Flutter version', () {
    final workflow = File(
      '.github/workflows/android-release.yml',
    ).readAsStringSync();

    expect(workflow, contains("flutter-version: '3.41.9'"));
    expect(workflow, isNot(contains('channel: stable')));
  });
}
