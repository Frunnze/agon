import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/data/rules/skill_undo.dart';

import '../../support/random_inputs.dart';

SkillChangeOrigin _randomOrigin(Random random) {
  final RunId runId = RunId('run-${random.nextInt(1000)}');
  return pickOne(random, <SkillChangeOrigin>[
    const PersonEdit(),
    ApprovedAgentRun(runId),
    AutomaticAgentRun(runId),
  ]);
}

void main() {
  test('test_find_undoable_agent_change_property_only_the_newest_agent', () {
    final Random random = seededRandom(9781);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = random.nextInt(5);
      final List<SkillChange> history = <SkillChange>[
        for (int j = 0; j < count; j += 1)
          SkillChange(
            origin: _randomOrigin(random),
            savedAt: galleryDaysAgo(count - j),
            replacedInstructions: randomText(random),
          ),
      ];

      final SkillChange? undoable = findUndoableAgentChange(history);

      if (history.isEmpty || history.last.origin is PersonEdit) {
        expect(undoable, isNull);
      } else {
        expect(undoable, same(history.last));
      }
    }
  });
}
