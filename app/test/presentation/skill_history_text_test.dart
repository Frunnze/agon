import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/presentation/skill_history_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

import '../support/random_inputs.dart';

const int _shownChangeCount = 5;

SkillChangeOrigin _randomOrigin(Random random) {
  final RunId runId = RunId('run-${random.nextInt(1000)}');
  return pickOne(random, <SkillChangeOrigin>[
    const PersonEdit(),
    ApprovedAgentRun(runId),
    AutomaticAgentRun(runId),
  ]);
}

List<SkillChange> _randomHistory(Random random) {
  final int count = random.nextInt(12);
  return <SkillChange>[
    for (int i = 0; i < count; i += 1)
      SkillChange(
        origin: _randomOrigin(random),
        savedAt: galleryDaysAgo(count - i),
        replacedInstructions: randomText(random),
      ),
  ];
}

void main() {
  test(
    'test_list_recent_skill_changes_property_newest_first_at_most_five',
    () {
      final Random random = seededRandom(9251);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<SkillChange> history = _randomHistory(random);

        final List<SkillChange> recent = listRecentSkillChanges(history);

        expect(recent.length, min(history.length, _shownChangeCount));
        for (int j = 0; j < recent.length; j += 1) {
          expect(recent[j], same(history[history.length - 1 - j]));
        }
      }
    },
  );

  test('test_describe_skill_change_title_property_one_title_per_origin', () {
    const RunId runId = RunId('run-release-41');

    expect(describeSkillChangeTitle(const PersonEdit()), 'Changed by you');
    expect(
      describeSkillChangeTitle(const ApprovedAgentRun(runId)),
      'Improved by an agent, approved by you',
    );
    expect(
      describeSkillChangeTitle(const AutomaticAgentRun(runId)),
      'Improved by an agent automatically',
    );
  });

  test('test_describe_skill_change_moment_property_run_then_time', () {
    final Random random = seededRandom(9252);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime savedAt = galleryDaysAgo(random.nextInt(9));
      final String? runLabel = random.nextBool()
          ? 'release #${random.nextInt(500)}'
          : null;
      final String since = describeTimeSince(savedAt, galleryNow);

      final String moment = describeSkillChangeMoment(
        runLabel: runLabel,
        savedAt: savedAt,
        now: galleryNow,
      );

      expect(moment, runLabel == null ? since : '$runLabel · $since');
    }
  });

  test('test_skill_improvement_property_every_choice_explained', () {
    final Set<String> labels = <String>{
      for (final SkillImprovement improvement in SkillImprovement.values)
        improvement.label,
    };
    final Set<String> explanations = <String>{
      for (final SkillImprovement improvement in SkillImprovement.values)
        improvement.explanation,
    };

    expect(labels, <String>{'Never', 'Ask me', 'Auto'});
    expect(explanations.length, SkillImprovement.values.length);
  });
}
