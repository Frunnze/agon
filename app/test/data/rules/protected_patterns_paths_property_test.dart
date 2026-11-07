import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/protected_patterns.dart';

import '../../support/random_inputs.dart';
import 'support/protected_pattern_inputs.dart';

const List<String> _emptySegments = <String>['', '.'];
const List<String> _nothingPrefixes = <String>['', '~/', '/'];
const Map<int, String> _namedEscapes = <int, String>{
  0x00: r'\0',
  0x09: r'\t',
  0x0A: r'\n',
  0x0D: r'\r',
};
const List<String> _caseDistinctLetters = <String>['é', 'É', 'ä', 'Ä', 'ß'];
const int _lastLowControl = 0x1F;
const int _firstHighControl = 0x7F;
const int _lastHighControl = 0x9F;
const int _largestSampledRune = 0x2FFF;

String _problemOf(String pattern) {
  return describeProtectedFilesProblem(<String>[pattern]) ?? '';
}

String _randomNothingPattern(Random random) {
  final int segmentCount = random.nextInt(4);
  final List<String> segments = <String>[
    for (int i = 0; i < segmentCount; i += 1) pickOne(random, _emptySegments),
  ];
  final String pattern =
      '${pickOne(random, _nothingPrefixes)}${segments.join('/')}';
  if (pattern.isEmpty) {
    return '~';
  }
  return pattern;
}

List<int> _listControlRunes() {
  return <int>[
    for (int rune = 0; rune <= _lastLowControl; rune += 1) rune,
    for (int rune = _firstHighControl; rune <= _lastHighControl; rune += 1)
      rune,
  ];
}

bool _isControlRune(int rune) {
  return rune <= _lastLowControl ||
      (rune >= _firstHighControl && rune <= _lastHighControl);
}

String _hexEscape(int rune) => '\\u{${rune.toRadixString(16)}}';

void main() {
  test('test_read_pattern_property_home_root_and_dots_name_nothing', () {
    final Random random = seededRandom(52501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String pattern = _randomNothingPattern(random);

      expect(
        _problemOf(pattern),
        'the pattern "$pattern" names no file or folder',
      );
    }
  });

  test('test_read_pattern_property_places_keep_patterns_apart', () {
    final Random random = seededRandom(52502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomPatternName(random);
      final List<String> patterns = <String>['/$name', name, '~/$name'];
      patterns.shuffle(random);

      expect(describeProtectedFilesProblem(patterns), isNull);
    }
  });

  test('test_read_pattern_property_a_tilde_inside_a_name_is_a_name', () {
    final Random random = seededRandom(52503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomPatternName(random);
      final List<String> patterns = <String>['~$name', name, '~/$name'];
      patterns.shuffle(random);

      expect(describeProtectedFilesProblem(patterns), isNull);
    }
  });

  test('test_normalise_pattern_property_ascii_case_folds', () {
    final Random random = seededRandom(52504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String pattern = randomValidPattern(random);
      final String copy = flipAsciiCase(pattern);

      final String? problem = describeProtectedFilesProblem(<String>[
        pattern,
        copy,
      ]);

      expect(problem, contains('is listed twice'));
    }
  });

  test('test_normalise_pattern_property_other_case_does_not_fold', () {
    final Random random = seededRandom(52505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomPatternName(random);
      final String first = pickOne(random, _caseDistinctLetters);
      final String second = pickOne(
        random,
        _caseDistinctLetters
            .where((String letter) => letter != first)
            .toList(),
      );

      final String? problem = describeProtectedFilesProblem(<String>[
        '$name$first',
        '$name$second',
      ]);

      expect(problem, isNull);
    }
  });

  test('test_normalise_pattern_property_empty_and_dot_segments_vanish', () {
    final Random random = seededRandom(52506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String pattern = randomValidPattern(random);
      final String padding = pickOne(random, <String>['/', '/./', '//']);
      final String copy = pattern.replaceAll('/', padding);

      final String? problem = describeProtectedFilesProblem(<String>[
        pattern,
        copy,
      ]);

      expect(problem, contains('is listed twice'));
    }
  });

  test('test_quote_text_property_printable_text_matches_json', () {
    final Random random = seededRandom(52507);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomText(random).replaceAll(RegExp(r'\s'), 'x');
      final String pattern = '$name/..';
      final String problem = _problemOf(pattern);
      if (!problem.endsWith('cannot use .. to leave a folder')) {
        continue;
      }

      expect(problem, startsWith('the pattern ${jsonEncode(pattern)} '));
    }
  });

  test('test_quote_text_property_quotes_and_backslashes_are_escaped', () {
    final Random random = seededRandom(52508);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomPatternName(random);
      final String inserted = pickOne(random, <String>['"', r'\']);
      final String pattern = ' $name$inserted';

      expect(
        _problemOf(pattern),
        'the pattern ${quotePrintableText(pattern)} starts or ends with a '
        'space',
      );
    }
  });

  test('test_quote_text_property_quoted_text_has_no_bare_quotes', () {
    final Random random = seededRandom(52509);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String pattern = '${randomText(random)} ';
      final String problem = _problemOf(pattern);
      final String quoted = problem
          .substring('the pattern '.length)
          .replaceFirst(RegExp(r' starts or ends with a space$'), '');
      final String inside = quoted.substring(1, quoted.length - 1);

      expect(quoted, startsWith('"'));
      expect(quoted, endsWith('"'));
      expect(
        inside.replaceAll(r'\\', '').replaceAll(r'\"', ''),
        isNot(contains('"')),
      );
    }
  });

  test('test_escape_character_property_controls_use_braced_hex', () {
    for (final int rune in _listControlRunes()) {
      final String pattern = 'a${String.fromCharCode(rune)}b';
      final String expected = _namedEscapes[rune] ?? _hexEscape(rune);

      expect(
        _problemOf(pattern),
        'the pattern "a${expected}b" cannot contain control characters',
      );
    }
  });

  test('test_escape_character_property_hidden_spaces_use_braced_hex', () {
    for (final int rune in unicodeWhiteSpaceOtherThanSpace) {
      final String pattern = 'a${String.fromCharCode(rune)}';
      final String expected = _namedEscapes[rune] ?? _hexEscape(rune);

      expect(
        _problemOf(pattern),
        'the pattern "a$expected" starts or ends with a space',
      );
    }
  });

  test('test_escape_character_property_inner_spaces_stay_plain', () {
    final Random random = seededRandom(52510);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomPatternName(random);
      final String pattern = '$name ${randomPatternName(random)}/..';

      expect(_problemOf(pattern), startsWith('the pattern "$pattern" '));
    }
  });

  test('test_is_control_character_property_every_control_is_refused', () {
    for (final int rune in _listControlRunes()) {
      final String pattern = 'x${String.fromCharCode(rune)}y';

      expect(
        _problemOf(pattern),
        endsWith('cannot contain control characters'),
      );
    }
  });

  test('test_is_control_character_property_other_runes_pass', () {
    final Random random = seededRandom(52511);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int rune = 0x20 + random.nextInt(_largestSampledRune);
      final String character = String.fromCharCode(rune);
      final String pattern = 'x${character}y';
      if (_isControlRune(rune)) {
        continue;
      }

      expect(_problemOf(pattern), isNot(contains('control characters')));
    }
  });

  test('test_is_control_character_property_range_edges', () {
    final Map<int, bool> isRefusedByRune = <int, bool>{
      _lastLowControl: true,
      0x20: false,
      0x7E: false,
      _firstHighControl: true,
      _lastHighControl: true,
      0xA0: false,
    };

    for (final MapEntry<int, bool> entry in isRefusedByRune.entries) {
      final String pattern = 'x${String.fromCharCode(entry.key)}y';

      final String? problem = describeProtectedFilesProblem(<String>[pattern]);

      expect(problem != null, entry.value, reason: '${entry.key}');
    }
  });
}
