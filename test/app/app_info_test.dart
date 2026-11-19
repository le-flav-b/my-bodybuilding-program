import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_bodybuilding_program/app/app_info.dart';

void main() {
  test('AppInfo.version matches the pubspec version', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final version = line.split(':')[1].trim().split('+').first;
    expect(AppInfo.version, version);
  });
}
