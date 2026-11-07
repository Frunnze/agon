import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/protected_patterns.dart';

import '../../support/random_inputs.dart';
import 'support/protected_pattern_inputs.dart';

const String _emoji = '😀';
const String _forbiddenRule =
    'quotes, backslashes and brackets are not allowed';
const Map<String, String> _quotedForbiddenCharacters = <String, String>{
  '"': "'\"'",
  "'": r"'\''",
  r'\': r"'\\'",
  '(': "'('",
  ')': "')'",
};
const String _allowedPunctuation = '*?[]{}!@#\$%^&+=,;:<>|`~-_';

String _problemOf(String pattern) {
  return describeProtectedFilesProblem(<String>[pattern]) ?? '';
}

String _insertAt(Random random, String text, String inserted) {
  final int position = random.nextInt(text.length + 1);
  return text.replaceRange(position, position, inserted);
}

void main() {
  test('test_describe_pattern_problem_property_valid_patterns_pass', () {
    final Random random = seededRandom(52401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String pattern = randomValidPattern(random);

      expect(describeProtectedFilesProblem(<String>[pattern]), isNull);
    }
  });

  test('test_describe_pattern_problem_property_edge_white_space_refused', () {
    final Random random = seededRandom(52402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String pattern = randomValidPattern(random);
      final String space = String.fromCharCode(
        pickOne(random, <int>[0x20, ...unicodeWhiteSpaceOtherThanSpace]),
      );
      final String padded = random.nextBool()
          ? '$space$pattern'
          : '$pattern$space';

      expect(_problemOf(padded), endsWith('starts or ends with a space'));
    }
  });

  test('test_describe_pattern_problem_property_judged_one_at_a_time', () {
    final Random random = seededRandom(52403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> earlier = randomDistinctPatterns(random);
      final String pattern = randomText(random);
      final String? alone = describeProtectedFilesProblem(<String>[pattern]);
      if (alone == null) {
        continue;
      }

      final String? afterOthers = describeProtectedFilesProblem(<String>[
        ...earlier,
        pattern,
      ]);

      expect(afterOthers, alone);
    }
  });

  test('test_describe_pattern_problem_property_length_counts_characters', () {
    final Random random = seededRandom(52404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int length = 1 + random.nextInt(maximumProtectedPatternLength * 2);
      final String pattern = _emoji * length;

      final String? problem = describeProtectedFilesProblem(<String>[pattern]);

      if (length <= maximumProtectedPatternLength) {
        expect(problem, isNull);
      } else {
        expect(
          problem,
          'a pattern can have at most $maximumProtectedPatternLength '
          'characters, this one has $length',
        );
      }
    }
  });

  test(
    'test_describe_repeated_pattern_problem_property_case_copy_refused',
    () {
      final Random random = seededRandom(52405);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<String> patterns = randomDistinctPatterns(random);
        final String earlier = pickOne(random, patterns);
        final String copy = flipAsciiCase(earlier);

        final String? problem = describeProtectedFilesProblem(<String>[
          ...patterns,
          copy,
        ]);

        expect(
          problem,
          'the pattern ${quotePrintableText(copy)} is listed twice: it '
          'protects the same files as ${quotePrintableText(earlier)}',
        );
      }
    },
  );

  test('test_describe_repeated_pattern_problem_property_extra_slashes', () {
    final Random random = seededRandom(52406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> patterns = randomDistinctPatterns(random);
      final String earlier = pickOne(random, patterns);
      final String copy = '${earlier.replaceAll('/', '//./')}/';

      final String? problem = describeProtectedFilesProblem(<String>[
        ...patterns,
        copy,
      ]);

      expect(problem, startsWith('the pattern "$copy" is listed twice'));
    }
  });

  test('test_describe_repeated_pattern_problem_property_distinct_pass', () {
    final Random random = seededRandom(52407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> patterns = randomDistinctPatterns(random);
      patterns.shuffle(random);

      expect(describeProtectedFilesProblem(patterns), isNull);
    }
  });

  test('test_find_quoted_forbidden_character_property_names_the_first', () {
    final Random random = seededRandom(52408);
    final List<String> forbidden = _quotedForbiddenCharacters.keys.toList();

    for (int i = 0; i < propertyIterations; i += 1) {
      String pattern = randomValidPattern(random);
      for (int added = 0; added < 1 + random.nextInt(3); added += 1) {
        pattern = _insertAt(random, pattern, pickOne(random, forbidden));
      }
      final String firstCharacter = pattern
          .split('')
          .firstWhere(_quotedForbiddenCharacters.containsKey);

      final String problem = _problemOf(pattern);

      expect(
        problem,
        'the pattern ${quotePrintableText(pattern)} cannot contain '
        '${_quotedForbiddenCharacters[firstCharacter]}: $_forbiddenRule',
      );
    }
  });

  test('test_find_quoted_forbidden_character_property_each_one_refused', () {
    final Random random = seededRandom(52409);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String character = pickOne(
        random,
        _quotedForbiddenCharacters.keys.toList(),
      );
      final String pattern = _insertAt(
        random,
        randomPatternName(random),
        character,
      );

      expect(
        _problemOf(pattern),
        contains('cannot contain ${_quotedForbiddenCharacters[character]}'),
      );
    }
  });

  test('test_find_quoted_forbidden_character_property_punctuation_passes', () {
    final Random random = seededRandom(52410);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String punctuation =
          _allowedPunctuation[random.nextInt(_allowedPunctuation.length)];
      final String pattern = _insertAt(
        random,
        randomPatternName(random),
        punctuation,
      );

      expect(describeProtectedFilesProblem(<String>[pattern]), isNull);
    }
  });

  test('test_split_path_segments_property_order_of_names_matters', () {
    final Random random = seededRandom(52411);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String first = randomPatternName(random);
      final String second = '${randomPatternName(random)}-$first';

      final String? problem = describeProtectedFilesProblem(<String>[
        '$first/$second',
        '$second/$first',
      ]);

      expect(problem, isNull);
    }
  });

  test('test_split_path_segments_property_deeper_paths_are_new', () {
    final Random random = seededRandom(52412);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String pattern = randomValidPattern(random);
      final String deeper = '$pattern/${randomPatternName(random)}';

      final String? problem = describeProtectedFilesProblem(<String>[
        pattern,
        deeper,
      ]);

      expect(problem, isNull);
    }
  });

  test('test_split_path_segments_property_dot_names_are_kept', () {
    final Random random = seededRandom(52413);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomPatternName(random);
      final String dotted = pickOne(random, <String>[
        '.$name',
        '$name.',
        '...',
      ]);

      final String? problem = describeProtectedFilesProblem(<String>[
        name,
        dotted,
      ]);

      expect(problem, isNull);
    }
  });
}
