import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes/task_skill_removal.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'support/task_inputs.dart';

Set<SkillId> _randomRemovedSkills(Random random) {
  return <SkillId>{
    for (final SkillId skillId in sampleSkillIds)
      if (random.nextBool()) skillId,
    if (random.nextBool()) const SkillId('skill-never-used'),
  };
}

void main() {
  test('test_remove_skills_from_task_property_keeps_every_other_skill_in_'
      'order', () {
    final Random random = seededRandom(91401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = randomSeededTask(random, i);
      final Set<SkillId> removed = _randomRemovedSkills(random);

      final Task cleaned = removeSkillsFromTask(task, removed);

      expect(cleaned.skills, <SkillId>[
        for (final SkillId skillId in task.skills)
          if (!removed.contains(skillId)) skillId,
      ]);
    }
  });

  test('test_remove_skills_from_task_property_keeps_every_other_field', () {
    final Random random = seededRandom(91402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = randomSeededTask(random, i);

      final Task cleaned = removeSkillsFromTask(
        task,
        _randomRemovedSkills(random),
      );

      expect(cleaned.id, task.id);
      expect(cleaned.title, task.title);
      expect(cleaned.details, task.details);
      expect(cleaned.projectId, task.projectId);
      expect(cleaned.doer, task.doer);
      expect(cleaned.runsOn, task.runsOn);
      expect(cleaned.agentPlace, task.agentPlace);
      expect(cleaned.usesAutomaticSkills, task.usesAutomaticSkills);
      expect(cleaned.approvalPolicy, task.approvalPolicy);
      expect(cleaned.schedule, same(task.schedule));
      expect(cleaned.status, task.status);
      expect(cleaned.createdAt, task.createdAt);
    }
  });

  test('test_remove_skills_from_task_property_an_untouched_task_stays_'
      'identical_and_removal_is_idempotent', () {
    final Random random = seededRandom(91403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Task task = randomSeededTask(random, i);
      final Set<SkillId> removed = _randomRemovedSkills(random);

      final Task once = removeSkillsFromTask(task, removed);
      final Task twice = removeSkillsFromTask(once, removed);
      final Task untouched = removeSkillsFromTask(task, <SkillId>{});

      expect(untouched, same(task));
      expect(twice, same(once));
      if (!task.skills.any(removed.contains)) {
        expect(once, same(task));
      }
    }
  });
}
