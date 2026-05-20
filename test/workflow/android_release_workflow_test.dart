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

  test('android release workflow supports rebuilding a chosen tag manually', () {
    final workflow = File(
      '.github/workflows/android-release.yml',
    ).readAsStringSync();

    expect(workflow, contains('workflow_dispatch:'));
    expect(workflow, contains('release_tag:'));
    expect(
      workflow,
      contains(
        "ref: \${{ github.event_name == 'workflow_dispatch' && inputs.release_tag || github.ref }}",
      ),
    );
    expect(
      workflow,
      contains(
        "TAG_NAME=\"\${{ github.event_name == 'workflow_dispatch' && inputs.release_tag || github.ref_name }}\"",
      ),
    );
    expect(
      workflow,
      contains(r'tag_name: ${{ steps.version.outputs.tag }}'),
    );
  });
}
