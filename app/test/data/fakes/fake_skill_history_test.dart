import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';

import '../../support/random_inputs.dart';

const String _currentInstructions = 'Current instructions.';
const SkillId _editedSkillId = SkillId('skill-edited');

SkillChangeOrigin _randomOrigin(Random random) {
  final RunId runId = RunId('run-${random.nextInt(1000)}');
  return pickOne(random, <SkillChangeOrigin>[
    const PersonEdit(),
    ApprovedAgentRun(runId),
    AutomaticAgentRun(runId),
  ]);
}

List<SkillChange> _randomHistory(Random random) {
  final int count = random.nextInt(4);
  return <SkillChange>[
    for (int i = 0; i < count; i += 1)
      SkillChange(
        origin: _randomOrigin(random),
        savedAt: galleryDaysAgo(count - i),
        replacedInstructions: 'Version $i\n${randomText(random)}',
      ),
  ];
}

Skill _buildSkill(List<SkillChange> history) {
  return Skill(
    id: _editedSkillId,
    name: 'edited',
    summary: 'Edited skill',
    instructions: _currentInstructions,
    scope: const Scope.everywhere(),
    usage: SkillUsage.automatic,
    source: SkillSource.created,
    improvement: SkillImprovement.auto,
    history: history,
  );
}

FakeSkillRepository _buildRepository(List<Skill> skills) {
  return FakeSkillRepository(skills: skills, clock: FixedClock(galleryNow));
}

SkillDraft _buildDraft(Skill skill, String instructions) {
  return SkillDraft(
    name: skill.name,
    summary: skill.summary,
    instructions: instructions,
    scope: skill.scope,
    usage: skill.usage,
    improvement: skill.improvement,
  );
}

void main() {
  test(
    'test_undo_latest_agent_change_property_restores_replaced_text',
    () async {
      final Random random = seededRandom(7121);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<SkillChange> history = _randomHistory(random);
        final FakeSkillRepository repository = _buildRepository(<Skill>[
          _buildSkill(history),
        ]);
        final bool isAgentChangeNewest =
            history.isNotEmpty && history.last.origin is AgentRunOrigin;

        if (!isAgentChangeNewest) {
          await expectLater(
            repository.undoLatestAgentChange(_editedSkillId),
            throwsStateError,
          );
          final Skill kept = repository.findSkill(_editedSkillId);
          expect(kept.instructions, _currentInstructions);
          expect(kept.history.length, history.length);
          continue;
        }

        final Skill restored = await repository.undoLatestAgentChange(
          _editedSkillId,
        );

        expect(restored.instructions, history.last.replacedInstructions);
        expect(restored.history, history.sublist(0, history.length - 1));
        expect(restored.improvement, SkillImprovement.auto);
        final Skill stored = repository.findSkill(_editedSkillId);
        expect(stored.instructions, restored.instructions);
      }
    },
  );

  test('test_update_skill_property_records_only_new_instructions', () async {
    final Random random = seededRandom(7122);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SkillChange> history = _randomHistory(random);
      final FakeSkillRepository repository = _buildRepository(<Skill>[
        _buildSkill(history),
      ]);
      final Skill original = repository.findSkill(_editedSkillId);
      final String instructions = random.nextBool()
          ? original.instructions
          : 'Edited ${randomText(random)}';

      final Skill updated = await repository.updateSkill(
        _editedSkillId,
        _buildDraft(original, instructions),
      );

      if (instructions == original.instructions) {
        expect(updated.history, history);
        continue;
      }
      expect(updated.history.length, history.length + 1);
      expect(updated.history.last.origin, isA<PersonEdit>());
      expect(updated.history.last.savedAt, galleryNow);
      expect(updated.history.last.replacedInstructions, _currentInstructions);
      await expectLater(
        repository.undoLatestAgentChange(_editedSkillId),
        throwsStateError,
      );
    }
  });

  test('the gallery release skill undoes its approved agent change', () async {
    final FakeSkillRepository repository = _buildRepository(gallerySkills);
    final Skill original = repository.findSkill(GallerySkillIds.iosRelease);

    final Skill restored = await repository.undoLatestAgentChange(
      GallerySkillIds.iosRelease,
    );

    expect(original.history.last.origin, isA<ApprovedAgentRun>());
    expect(restored.instructions, original.history.last.replacedInstructions);
    expect(restored.history.last.origin, isA<AutomaticAgentRun>());
  });
}
