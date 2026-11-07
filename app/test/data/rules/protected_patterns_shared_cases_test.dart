import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/protected_patterns.dart';

import '../../support/random_inputs.dart';
import 'support/protected_pattern_inputs.dart';

const String _sharedCasesPath =
    '../rust/crates/orchestration-core/tests/fixtures/'
    'protected_pattern_cases.json';

final class _SharedPatternCase {
  const _SharedPatternCase({
    required this.description,
    required this.patterns,
    required this.problem,
  });

  final String description;
  final List<String> patterns;
  final String? problem;
}

_SharedPatternCase _readSharedCase(Object? entry) {
  if (entry is! Map<String, Object?>) {
    throw FormatException('a shared pattern case is not an object: $entry');
  }
  final List<Object?> patternEntries = entry['patterns']! as List<Object?>;
  return _SharedPatternCase(
    description: entry['description']! as String,
    patterns: <String>[
      for (final Object? pattern in patternEntries) pattern! as String,
    ],
    problem: entry['problem'] as String?,
  );
}

List<_SharedPatternCase> _readSharedCases() {
  final String sharedCasesText = File(_sharedCasesPath).readAsStringSync();
  final Object? decoded = jsonDecode(sharedCasesText);
  if (decoded is! List<Object?>) {
    throw FormatException('the shared pattern table is not a list: $decoded');
  }
  return <_SharedPatternCase>[
    for (final Object? entry in decoded) _readSharedCase(entry),
  ];
}

void main() {
  final List<_SharedPatternCase> sharedCases = _readSharedCases();

  test('test_describe_protected_files_problem_property_agrees_with_table', () {
    for (final _SharedPatternCase sharedCase in sharedCases) {
      final String? problem = describeProtectedFilesProblem(
        sharedCase.patterns,
      );

      expect(problem, sharedCase.problem, reason: sharedCase.description);
    }
  });

  test(
    'test_describe_protected_files_problem_property_ascii_case_ignored',
    () {
      for (final _SharedPatternCase sharedCase in sharedCases) {
        final List<String> flipped = <String>[
          for (final String pattern in sharedCase.patterns)
            flipAsciiCase(pattern),
        ];

        final String? problem = describeProtectedFilesProblem(flipped);

        expect(
          problem == null,
          sharedCase.problem == null,
          reason: sharedCase.description,
        );
      }
    },
  );

  test('test_describe_protected_files_problem_property_too_many_first', () {
    final Random random = seededRandom(52301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = maximumProtectedPatternCount + 1 + random.nextInt(20);
      final List<String> patterns = <String>[
        for (int index = 0; index < count; index += 1) randomText(random),
      ];

      final String? problem = describeProtectedFilesProblem(patterns);

      expect(
        problem,
        'the list can have at most $maximumProtectedPatternCount patterns, '
        'this one has $count',
      );
    }
  });

  test(
    'test_describe_protected_files_problem_property_prefixes_stay_valid',
    () {
      final Random random = seededRandom(52302);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<String> patterns = randomDistinctPatterns(random);
        final int kept = random.nextInt(patterns.length + 1);

        final String? problem = describeProtectedFilesProblem(
          patterns.sublist(0, kept),
        );

        expect(describeProtectedFilesProblem(patterns), isNull);
        expect(problem, isNull);
      }
    },
  );
}
