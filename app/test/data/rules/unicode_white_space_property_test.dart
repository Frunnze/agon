import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';

const int _firstSurrogate = 0xD800;
const int _lastSurrogate = 0xDFFF;
const int _lastBasicPlaneCodeUnit = 0xFFFF;

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  test('test_trim_unicode_white_space_property_trims_only_shared_white', () {
    for (int code = 0; code <= _lastBasicPlaneCodeUnit; code += 1) {
      final bool isSurrogate =
          code >= _firstSurrogate && code <= _lastSurrogate;
      if (isSurrogate) {
        continue;
      }
      final String character = String.fromCharCode(code);

      final String trimmed = trimUnicodeWhiteSpace(character);

      final String expected = table.isWhiteSpace(character) ? '' : character;
      expect(trimmed, expected, reason: 'U+${code.toRadixString(16)}');
    }
  });

  test('test_trim_unicode_white_space_property_matches_the_model', () {
    final Random random = seededRandom(60817);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = table.randomExoticTitle(random);

      final String trimmed = trimUnicodeWhiteSpace(text);

      expect(trimmed, table.trimByModel(text), reason: text.runes.toString());
    }
  });

  test('test_trim_unicode_white_space_property_is_idempotent_and_inner', () {
    final Random random = seededRandom(60818);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = table.randomExoticTitle(random);
      final String leading = table.randomWhiteSpaceRun(random);
      final String trailing = table.randomWhiteSpaceRun(random);

      final String trimmed = trimUnicodeWhiteSpace(text);
      final String padded = trimUnicodeWhiteSpace('$leading$text$trailing');

      expect(trimUnicodeWhiteSpace(trimmed), trimmed);
      expect(padded, trimmed);
      expect(text.contains(trimmed), isTrue);
    }
  });

  test('test_collapse_unicode_white_space_property_matches_the_model', () {
    final Random random = seededRandom(60819);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = table.randomExoticTitle(random);

      final String collapsed = collapseUnicodeWhiteSpace(text);

      expect(
        collapsed,
        table.collapseByModel(text),
        reason: text.runes.toString(),
      );
    }
  });

  test('test_collapse_unicode_white_space_property_is_idempotent', () {
    final Random random = seededRandom(60820);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = table.randomExoticTitle(random);

      final String collapsed = collapseUnicodeWhiteSpace(text);

      expect(collapseUnicodeWhiteSpace(collapsed), collapsed);
      expect(trimUnicodeWhiteSpace(collapsed), collapsed);
    }
  });

  test('test_collapse_unicode_white_space_property_keeps_other_text', () {
    final Random random = seededRandom(60821);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = table.randomExoticTitle(random);

      final String collapsed = collapseUnicodeWhiteSpace(text);

      final List<String> keptFromText = <String>[
        for (final String character in text.split(''))
          if (!table.isWhiteSpace(character)) character,
      ];
      final List<String> keptFromCollapsed = <String>[
        for (final String character in collapsed.split(''))
          if (character != ' ') character,
      ];
      expect(keptFromCollapsed, keptFromText);
      expect(collapsed.contains('  '), isFalse);
      for (final String character in collapsed.split('')) {
        final bool isOtherWhiteSpace =
            character != ' ' && table.isWhiteSpace(character);
        expect(isOtherWhiteSpace, isFalse, reason: collapsed);
      }
    }
  });
}
