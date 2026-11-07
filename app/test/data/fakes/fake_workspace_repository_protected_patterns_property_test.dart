import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/rules/protected_patterns.dart';

import '../../support/random_inputs.dart';
import '../rules/support/protected_pattern_inputs.dart';
import 'support/notification_counter.dart';
import 'support/workspace_inputs.dart';

const List<String> _hostilePatterns = <String>[
  '',
  ' padded',
  'trailing ',
  'a/../b',
  '~',
  'it\'s',
  r'back\slash',
  '(bracket)',
  'bell\u0007',
];

List<String> _randomMixedPatterns(Random random) {
  final List<String> patterns = randomDistinctPatterns(random);
  final int hostileCount = random.nextInt(3);
  for (int i = 0; i < hostileCount; i += 1) {
    final String hostile = random.nextBool()
        ? pickOne(random, _hostilePatterns)
        : randomText(random);
    patterns.insert(random.nextInt(patterns.length + 1), hostile);
  }
  if (random.nextInt(4) == 0) {
    patterns.add(flipAsciiCase(pickOne(random, patterns)));
  }
  return patterns;
}

Matcher _throwsArgumentErrorWith(String problem) {
  return throwsA(
    isA<ArgumentError>().having(
      (ArgumentError error) => error.message,
      'message',
      problem,
    ),
  );
}

void main() {
  test(
    'test_save_protected_files_property_refuses_what_the_rule_refuses',
    () async {
      final Random random = seededRandom(52601);

      for (int i = 0; i < propertyIterations; i += 1) {
        final SeededWorkspaces seeded = seedRandomWorkspaces(random);
        final Workspace target = pickOne(random, seeded.workspaces);
        final List<String> patterns = _randomMixedPatterns(random);
        final String? problem = describeProtectedFilesProblem(patterns);

        final Future<Workspace> saving = seeded.repository.saveProtectedFiles(
          workspaceId: target.id,
          patterns: patterns,
        );

        if (problem == null) {
          expect((await saving).protectedFiles, orderedEquals(patterns));
        } else {
          await expectLater(saving, _throwsArgumentErrorWith(problem));
        }
      }
    },
  );

  test('test_save_protected_files_property_refusal_changes_nothing', () async {
    final Random random = seededRandom(52602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Workspace target = pickOne(random, seeded.workspaces);
      final List<String> patterns = <String>[
        ...randomDistinctPatterns(random),
        pickOne(random, _hostilePatterns),
      ];
      final NotificationCounter notifications = NotificationCounter();
      seeded.repository.addListener(notifications.record);

      await expectLater(
        seeded.repository.saveProtectedFiles(
          workspaceId: target.id,
          patterns: patterns,
        ),
        throwsArgumentError,
      );

      expect(notifications.count, 0);
      expect(
        seeded.repository.listWorkspaces(),
        orderedEquals(seeded.workspaces),
      );
    }
  });

  test('test_save_protected_files_property_judges_patterns_first', () async {
    final Random random = seededRandom(52603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final WorkspaceId unknown = WorkspaceId('unknown-${random.nextInt(99)}');
      final List<String> patterns = <String>[
        pickOne(random, _hostilePatterns),
      ];

      await expectLater(
        seeded.repository.saveProtectedFiles(
          workspaceId: unknown,
          patterns: patterns,
        ),
        _throwsArgumentErrorWith(describeProtectedFilesProblem(patterns)!),
      );
    }
  });
}
