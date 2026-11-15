import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_bodybuilding_program/app/theme/app_tokens.dart';

/// The Dart theme constants must mirror `design/tokens.json` exactly.
void main() {
  final tokens = jsonDecode(
    File('design/tokens.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  Color parse(String hex) =>
      Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);

  for (final (name, map) in [
    ('light', AppTokens.light),
    ('dark', AppTokens.dark),
  ]) {
    test('colours ($name) match tokens.json', () {
      final json =
          (tokens['color'] as Map<String, dynamic>)[name]
              as Map<String, dynamic>;
      expect(map.keys.toSet(), json.keys.toSet());
      for (final entry in json.entries) {
        expect(
          map[entry.key],
          parse(entry.value as String),
          reason: '$name.${entry.key}',
        );
      }
    });
  }

  test('type scale matches tokens.json', () {
    final json = tokens['type'] as Map<String, dynamic>;
    final fonts = tokens['font'] as Map<String, dynamic>;
    expect(AppTokens.type.keys.toSet(), json.keys.toSet());
    for (final entry in json.entries) {
      final j = entry.value as Map<String, dynamic>;
      final t = AppTokens.type[entry.key]!;
      expect(t.size, j['size'], reason: entry.key);
      expect(t.lineHeight, j['lineHeight'], reason: entry.key);
      expect(t.weight, j['weight'], reason: entry.key);
      expect(t.letterSpacing, j['letterSpacing'], reason: entry.key);
      expect(t.tabular, j['tabular'] ?? false, reason: entry.key);
      expect(t.font, fonts[j['font'] ?? 'ui'], reason: entry.key);
    }
    expect(AppFonts.logo, fonts['logo']);
    expect(AppFonts.ui, fonts['ui']);
  });

  test('spacing, radius and sizes match tokens.json', () {
    expect(AppSpacing.values, tokens['spacing']);
    expect(AppRadius.values, tokens['radius']);
    expect(AppSizes.values, tokens['size']);
  });
}
