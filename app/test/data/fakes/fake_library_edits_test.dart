import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';

FakeRuleRepository _buildRuleRepository() {
  return FakeRuleRepository(
    rules: galleryRules,
    clock: FixedClock(galleryNow),
  );
}

SkillDraft _randomSkillDraft(Random random, String name) {
  return SkillDraft(
    name: name,
    summary: randomText(random),
    instructions: randomText(random),
    scope: const Scope.everywhere(),
    usage: pickOne(random, SkillUsage.values),
    improvement: pickOne(random, SkillImprovement.values),
  );
}

RuleDraft _randomRuleDraft(Random random) {
  return RuleDraft(
    title: pickOne(random, <String>['', '  ', randomWordPhrase(random)]),
    details: randomText(random),
    scope: const Scope.everywhere(),
  );
}

void main() {
  test('test_update_skill_property_keeps_the_id_and_the_source', () async {
    final Random random = seededRandom(7101);
    final FakeSkillRepository repository = FakeSkillRepository(
      skills: gallerySkills,
      clock: FixedClock(galleryNow),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final Skill original = pickOne(random, repository.listSkills());
      final String name = random.nextBool()
          ? original.name
          : 'edited-${random.nextInt(100000)}';
      final SkillDraft draft = _randomSkillDraft(random, name);
      final bool isTakenByAnother = repository.listSkills().any(
        (Skill skill) => skill.name == name && skill.id != original.id,
      );
      if (isTakenByAnother) {
        continue;
      }

      final Skill updated = await repository.updateSkill(original.id, draft);

      expect(updated.id, original.id);
      expect(updated.source, original.source);
      expect(repository.findSkill(original.id).name, name);
      expect(repository.findSkill(original.id).summary, draft.summary);
      expect(repository.findSkill(original.id).usage, draft.usage);
      expect(repository.findSkill(original.id).improvement, draft.improvement);
      expect(repository.listSkills().length, gallerySkills.length);
    }
  });

  test('test_update_skill_property_refuses_another_skills_name', () async {
    final Random random = seededRandom(7102);
    final FakeSkillRepository repository = FakeSkillRepository(
      skills: gallerySkills,
      clock: FixedClock(galleryNow),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final Skill edited = pickOne(random, gallerySkills);
      final Skill other = pickOne(random, <Skill>[
        for (final Skill skill in gallerySkills)
          if (skill.id != edited.id) skill,
      ]);

      await expectLater(
        repository.updateSkill(
          edited.id,
          _randomSkillDraft(random, other.name),
        ),
        throwsStateError,
      );
      expect(repository.findSkill(edited.id).name, edited.name);
    }
  });

  test('test_delete_skill_property_removes_only_that_skill', () async {
    final Random random = seededRandom(7103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeSkillRepository repository = FakeSkillRepository(
        skills: gallerySkills,
        clock: FixedClock(galleryNow),
      );
      final Skill deleted = pickOne(random, gallerySkills);

      await repository.deleteSkill(deleted.id);

      expect(repository.listSkills().length, gallerySkills.length - 1);
      expect(
        () => repository.findSkill(deleted.id),
        throwsA(isA<RecordNotFound>()),
      );
      await expectLater(
        repository.deleteSkill(deleted.id),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('test_find_rule_property_finds_every_seeded_rule', () {
    final Random random = seededRandom(7104);
    final FakeRuleRepository repository = _buildRuleRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rule rule = pickOne(random, galleryRules);
      expect(repository.findRule(rule.id).title, rule.title);
    }
    expect(
      () => repository.findRule(const RuleId('missing')),
      throwsA(isA<RecordNotFound>()),
    );
  });

  test('test_update_rule_property_keeps_the_switch_and_the_time', () async {
    final Random random = seededRandom(7105);
    final FakeRuleRepository repository = _buildRuleRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rule original = pickOne(random, repository.listRules());
      final RuleDraft draft = _randomRuleDraft(random);
      if (draft.title.trim().isEmpty) {
        await expectLater(
          repository.updateRule(original.id, draft),
          throwsArgumentError,
        );
        expect(repository.findRule(original.id).title, original.title);
        continue;
      }

      final Rule updated = await repository.updateRule(original.id, draft);

      expect(updated.id, original.id);
      expect(updated.enabled, original.enabled);
      expect(updated.addedAt, original.addedAt);
      expect(repository.findRule(original.id).title, draft.title.trim());
      expect(repository.findRule(original.id).details, draft.details);
      expect(repository.listRules().length, galleryRules.length);
    }
  });

  test('test_delete_rule_property_removes_only_that_rule', () async {
    final Random random = seededRandom(7106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeRuleRepository repository = _buildRuleRepository();
      final Rule deleted = pickOne(random, galleryRules);

      await repository.deleteRule(deleted.id);

      expect(repository.listRules().length, galleryRules.length - 1);
      expect(
        () => repository.findRule(deleted.id),
        throwsA(isA<RecordNotFound>()),
      );
      await expectLater(
        repository.deleteRule(deleted.id),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });
}
