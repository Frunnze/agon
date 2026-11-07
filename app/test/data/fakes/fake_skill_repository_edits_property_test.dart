import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/refusals.dart';
import 'support/skill_inputs.dart';

const int _keptSkillChanges = 20;
const int _largestEditCount = 30;

bool _refusesTheName(Object error) {
  return error is ArgumentError || error is StateError;
}

bool _isNewestChangeByAgent(List<SkillChange> history) {
  return history.isNotEmpty && history.last.origin is AgentRunOrigin;
}

SkillDraft _draftKeepingName(Random random, Skill skill) {
  return randomSkillDraftNamed(random, skill.name);
}

void main() {
  test('test_update_skill_property_refuses_badly_formed_names', () async {
    final Random random = seededRandom(66601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Skill> seeded = randomSeededSkills(random);
      if (seeded.isEmpty) {
        continue;
      }
      final FakeSkillRepository repository = buildSkillRepository(seeded);
      final Skill edited = pickOne(random, seeded);
      final String name = randomInvalidSkillName(random);
      final NotificationCounter counter = NotificationCounter();
      repository.addListener(counter.record);

      final bool wasRefused = await isRefused(
        () => repository.updateSkill(
          edited.id,
          randomSkillDraftNamed(random, name),
        ),
        isRefusal: _refusesTheName,
      );

      expect(wasRefused, isTrue, reason: 'accepted "$name"');
      expect(describeSkills(repository.listSkills()), describeSkills(seeded));
      expect(counter.count, 0);
    }
  });

  test('test_update_skill_property_keeps_at_most_the_kept_changes', () async {
    final Random random = seededRandom(66602);

    for (int i = 0; i < propertyIterations ~/ 4; i += 1) {
      final Skill seeded = randomSeededSkill(random, 0);
      final FakeSkillRepository repository = buildSkillRepository(<Skill>[
        seeded,
      ]);
      final int editCount = random.nextInt(_largestEditCount);

      for (int edit = 0; edit < editCount; edit += 1) {
        final Skill before = repository.findSkill(seeded.id);
        final Skill after = await repository.updateSkill(
          seeded.id,
          _draftKeepingName(random, before),
        );

        expect(after.history.length, lessThanOrEqualTo(_keptSkillChanges));
        if (after.instructions != before.instructions) {
          expect(after.history.last.replacedInstructions, before.instructions);
        }
      }
    }
  });

  test('test_update_skill_property_unknown_ids_are_not_found', () async {
    final Random random = seededRandom(66603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeSkillRepository repository = buildSkillRepository(
        randomSeededSkills(random),
      );
      final Skill missing = randomSeededSkill(random, propertyIterations);

      final bool wasRefused = await isRefused(
        () => repository.updateSkill(
          missing.id,
          randomSkillDraftNamed(random, 'missing-$i'),
        ),
        isRefusal: (Object error) => error is RecordNotFound,
      );

      expect(wasRefused, isTrue);
    }
  });

  test(
    'test_undo_latest_agent_change_property_walks_back_agent_changes',
    () async {
      final Random random = seededRandom(66604);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Skill seeded = randomSeededSkill(random, 0);
        final FakeSkillRepository repository = buildSkillRepository(<Skill>[
          seeded,
        ]);
        List<SkillChange> remaining = seeded.history;

        while (_isNewestChangeByAgent(remaining)) {
          final SkillChange undone = remaining.last;
          final Skill restored = await repository.undoLatestAgentChange(
            seeded.id,
          );

          expect(restored.instructions, undone.replacedInstructions);
          expect(restored.history.length, remaining.length - 1);
          remaining = restored.history;
        }

        final bool wasRefused = await isRefused(
          () => repository.undoLatestAgentChange(seeded.id),
          isRefusal: refusesWithStateError,
        );
        expect(wasRefused, isTrue);
      }
    },
  );

  test(
    'test_undo_latest_agent_change_property_refusals_change_nothing',
    () async {
      final Random random = seededRandom(66605);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Skill seeded = randomSeededSkill(random, 0);
        if (_isNewestChangeByAgent(seeded.history)) {
          continue;
        }
        final FakeSkillRepository repository = buildSkillRepository(<Skill>[
          seeded,
        ]);
        final NotificationCounter counter = NotificationCounter();
        repository.addListener(counter.record);

        final bool wasRefused = await isRefused(
          () => repository.undoLatestAgentChange(seeded.id),
          isRefusal: refusesWithStateError,
        );

        expect(wasRefused, isTrue);
        expect(
          describeSkill(repository.findSkill(seeded.id)),
          describeSkill(seeded),
        );
        expect(counter.count, 0);
      }
    },
  );

  test(
    'test_undo_latest_agent_change_property_keeps_everything_else',
    () async {
      final Random random = seededRandom(66606);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Skill seeded = randomSeededSkill(random, 0);
        if (!_isNewestChangeByAgent(seeded.history)) {
          continue;
        }
        final FakeSkillRepository repository = buildSkillRepository(<Skill>[
          seeded,
        ]);

        final Skill restored = await repository.undoLatestAgentChange(
          seeded.id,
        );

        expect(restored.id, seeded.id);
        expect(restored.name, seeded.name);
        expect(restored.summary, seeded.summary);
        expect(restored.usage, seeded.usage);
        expect(restored.source, seeded.source);
        expect(restored.improvement, seeded.improvement);
        for (int index = 0; index < restored.history.length; index += 1) {
          expect(restored.history[index], same(seeded.history[index]));
        }
      }
    },
  );

  test('test_replace_skill_property_keeps_the_list_position', () async {
    final Random random = seededRandom(66607);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Skill> seeded = randomSeededSkills(random);
      if (seeded.isEmpty) {
        continue;
      }
      final FakeSkillRepository repository = buildSkillRepository(seeded);
      final int position = random.nextInt(seeded.length);
      final Skill edited = seeded[position];

      final Skill updated = await repository.updateSkill(
        edited.id,
        _draftKeepingName(random, edited),
      );

      final List<Skill> listed = repository.listSkills();
      expect(listed.length, seeded.length);
      expect(listed[position], same(updated));
    }
  });

  test('test_replace_skill_property_notifies_once_per_edit', () async {
    final Random random = seededRandom(66608);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Skill> seeded = randomSeededSkills(random);
      if (seeded.isEmpty) {
        continue;
      }
      final FakeSkillRepository repository = buildSkillRepository(seeded);
      final Skill edited = pickOne(random, seeded);
      final NotificationCounter counter = NotificationCounter();
      repository.addListener(counter.record);

      await repository.updateSkill(
        edited.id,
        _draftKeepingName(random, edited),
      );
      int expectedCount = 1;
      if (_isNewestChangeByAgent(repository.findSkill(edited.id).history)) {
        await repository.undoLatestAgentChange(edited.id);
        expectedCount += 1;
      }

      expect(counter.count, expectedCount);
    }
  });

  test('test_replace_skill_property_returns_what_is_stored', () async {
    final Random random = seededRandom(66609);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Skill> seeded = randomSeededSkills(random);
      if (seeded.isEmpty) {
        continue;
      }
      final FakeSkillRepository repository = buildSkillRepository(seeded);
      final Skill edited = pickOne(random, seeded);

      final Skill updated = await repository.updateSkill(
        edited.id,
        _draftKeepingName(random, edited),
      );

      expect(repository.findSkill(edited.id), same(updated));
      expect(updated.source, edited.source);
    }
  });
}
