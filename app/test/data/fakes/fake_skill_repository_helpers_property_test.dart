import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';

import '../../support/random_inputs.dart';
import 'support/skill_inputs.dart';

const int _largestTakenIdCount = 4;
const int _keptSkillChanges = 20;
const int _largestCreationCount = 12;
const int _largestEditCount = 30;

Skill _seedWithId(Random random, String identifier) {
  final Skill shape = randomSeededSkill(random, 0);
  return Skill(
    id: SkillId(identifier),
    name: 'taken-$identifier',
    summary: shape.summary,
    instructions: shape.instructions,
    scope: const Scope.everywhere(),
    usage: shape.usage,
    source: shape.source,
    improvement: shape.improvement,
    history: shape.history,
  );
}

Future<List<String>> _editRepeatedly(
  Random random,
  FakeSkillRepository repository,
  Skill skill,
  int editCount,
) async {
  final List<String> replaced = <String>[];
  for (int edit = 0; edit < editCount; edit += 1) {
    final Skill before = repository.findSkill(skill.id);
    final SkillDraft draft = randomSkillDraftNamed(random, skill.name);
    if (draft.instructions != before.instructions) {
      replaced.add(before.instructions);
    }
    await repository.updateSkill(skill.id, draft);
  }
  return replaced;
}

void main() {
  test('test_next_free_skill_id_property_never_reuses_a_listed_id', () async {
    final Random random = seededRandom(67501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int takenCount = random.nextInt(_largestTakenIdCount);
      final List<Skill> seeded = <Skill>[
        for (int index = 1; index <= takenCount; index += 1)
          _seedWithId(random, '$createdSkillIdPrefix$index'),
      ];
      final FakeSkillRepository repository = buildSkillRepository(seeded);

      await repository.createSkill(randomSkillDraftNamed(random, 'new-$i'));

      final List<Skill> skills = repository.listSkills();
      final Set<SkillId> ids = <SkillId>{
        for (final Skill skill in skills) skill.id,
      };
      expect(ids.length, skills.length);
    }
  });

  test(
    'test_next_free_skill_id_property_distinct_over_many_creations',
    () async {
      final Random random = seededRandom(67502);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakeSkillRepository repository = buildSkillRepository(
          randomSeededSkills(random),
        );
        final int creationCount = 1 + random.nextInt(_largestCreationCount);
        final Set<SkillId> created = <SkillId>{};

        for (int index = 0; index < creationCount; index += 1) {
          final Skill skill = await repository.createSkill(
            randomSkillDraftNamed(random, 'many-$index'),
          );
          created.add(skill.id);
        }

        expect(created.length, creationCount);
      }
    },
  );

  test(
    'test_next_free_skill_id_property_ids_differ_from_deleted_ones',
    () async {
      final Random random = seededRandom(67503);

      for (int i = 0; i < propertyIterations; i += 1) {
        final FakeSkillRepository repository = buildSkillRepository(
          const <Skill>[],
        );
        final Skill first = await repository.createSkill(
          randomSkillDraftNamed(random, 'first'),
        );
        await repository.deleteSkill(first.id);

        final Skill second = await repository.createSkill(
          randomSkillDraftNamed(random, 'second'),
        );

        expect(second.id, isNot(first.id));
        expect(repository.findSkill(second.id), same(second));
      }
    },
  );

  test('test_keep_latest_changes_property_never_more_than_kept', () async {
    final Random random = seededRandom(67504);

    for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
      final Skill seeded = randomSeededSkill(random, 0);
      final FakeSkillRepository repository = buildSkillRepository(<Skill>[
        seeded,
      ]);
      final int editCount = random.nextInt(_largestEditCount);

      await _editRepeatedly(random, repository, seeded, editCount);

      final int length = repository.findSkill(seeded.id).history.length;
      expect(length, lessThanOrEqualTo(_keptSkillChanges));
    }
  });

  test(
    'test_keep_latest_changes_property_keeps_the_newest_in_order',
    () async {
      final Random random = seededRandom(67505);

      for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
        final Skill seeded = randomSeededSkill(random, 0);
        final FakeSkillRepository repository = buildSkillRepository(<Skill>[
          seeded,
        ]);
        final int editCount = random.nextInt(_largestEditCount);

        final List<String> replaced = await _editRepeatedly(
          random,
          repository,
          seeded,
          editCount,
        );

        final List<String> everyReplaced = <String>[
          for (final SkillChange change in seeded.history)
            change.replacedInstructions,
          ...replaced,
        ];
        final int keptCount = min(everyReplaced.length, _keptSkillChanges);
        final List<String> expected = everyReplaced.sublist(
          everyReplaced.length - keptCount,
        );
        final List<String> kept = <String>[
          for (final SkillChange change
              in repository.findSkill(seeded.id).history)
            change.replacedInstructions,
        ];
        expect(kept, expected);
      }
    },
  );

  test(
    'test_keep_latest_changes_property_short_histories_stay_whole',
    () async {
      final Random random = seededRandom(67506);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Skill seeded = randomSeededSkill(random, 0);
        final FakeSkillRepository repository = buildSkillRepository(<Skill>[
          seeded,
        ]);
        final SkillDraft draft = randomSkillDraftNamed(random, seeded.name);
        if (draft.instructions == seeded.instructions) {
          continue;
        }

        final Skill updated = await repository.updateSkill(seeded.id, draft);

        expect(updated.history.length, seeded.history.length + 1);
        for (int index = 0; index < seeded.history.length; index += 1) {
          expect(updated.history[index], same(seeded.history[index]));
        }
      }
    },
  );
}
