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

FakeRuleRepository buildGalleryRuleRepository() {
  return FakeRuleRepository(
    rules: galleryRules,
    clock: FixedClock(galleryNow),
  );
}

SkillDraft randomSkillDraft(Random random) {
  return SkillDraft(
    name: 'skill-${random.nextInt(100000)}',
    summary: randomText(random),
    instructions: randomText(random),
    scope: const Scope.everywhere(),
    usage: pickOne(random, SkillUsage.values),
    improvement: pickOne(random, SkillImprovement.values),
  );
}

void main() {
  test('test_list_skills_property_names_stay_unique', () async {
    final Random random = seededRandom(701);
    final FakeSkillRepository repository = FakeSkillRepository(
      skills: gallerySkills,
      clock: FixedClock(galleryNow),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final SkillDraft draft = randomSkillDraft(random);
      final bool isTaken = repository.listSkills().any(
        (Skill skill) => skill.name == draft.name,
      );
      if (isTaken) {
        await expectLater(
          repository.createSkill(draft),
          throwsA(isA<StateError>()),
        );
      } else {
        await repository.createSkill(draft);
      }
      final List<Skill> skills = repository.listSkills();
      expect(skills.map((Skill s) => s.name).toSet().length, skills.length);
    }
  });

  test('test_find_skill_property_finds_every_seeded_skill', () {
    final Random random = seededRandom(702);
    final FakeSkillRepository repository = FakeSkillRepository(
      skills: gallerySkills,
      clock: FixedClock(galleryNow),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final Skill skill = pickOne(random, gallerySkills);
      expect(repository.findSkill(skill.id).name, skill.name);
    }
    expect(
      () => repository.findSkill(const SkillId('missing')),
      throwsA(isA<RecordNotFound>()),
    );
  });

  test('test_create_skill_property_created_source', () async {
    final Random random = seededRandom(703);
    final FakeSkillRepository repository = FakeSkillRepository(
      skills: gallerySkills,
      clock: FixedClock(galleryNow),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final SkillDraft draft = randomSkillDraft(random);
      if (repository.listSkills().every((Skill s) => s.name != draft.name)) {
        final Skill skill = await repository.createSkill(draft);
        expect(skill.source, SkillSource.created);
        expect(skill.usage, draft.usage);
        expect(skill.improvement, draft.improvement);
        expect(skill.history, isEmpty);
      }
    }
  });

  test('test_list_rules_property_count_grows_only_by_creation', () async {
    final Random random = seededRandom(704);
    final FakeRuleRepository repository = buildGalleryRuleRepository();
    int expectedCount = galleryRules.length;

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rule rule = pickOne(random, repository.listRules());
      if (random.nextBool()) {
        await repository.turnRuleOn(rule.id);
      } else {
        await repository.turnRuleOff(rule.id);
      }
      expect(repository.listRules().length, expectedCount);
      await repository.createRule(
        const RuleDraft(
          title: 'Keep commits small',
          details: '',
          scope: Scope.everywhere(),
        ),
      );
      expectedCount += 1;
    }
  });

  test('test_create_rule_property_new_rules_start_on', () async {
    final Random random = seededRandom(705);
    final FakeRuleRepository repository = buildGalleryRuleRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = randomWordPhrase(random);
      final RuleDraft draft = RuleDraft(
        title: title,
        details: randomText(random),
        scope: const Scope.everywhere(),
      );
      if (title.trim().isEmpty) {
        await expectLater(
          repository.createRule(draft),
          throwsA(isA<ArgumentError>()),
        );
      } else {
        final Rule rule = await repository.createRule(draft);
        expect(rule.enabled, isTrue);
        expect(rule.title, title.trim());
      }
    }
  });

  test('test_turn_rule_on_property_rule_ends_enabled', () async {
    final Random random = seededRandom(706);
    final FakeRuleRepository repository = buildGalleryRuleRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rule rule = pickOne(random, galleryRules);
      expect((await repository.turnRuleOn(rule.id)).enabled, isTrue);
    }
  });

  test('test_turn_rule_off_property_rule_ends_disabled', () async {
    final Random random = seededRandom(707);
    final FakeRuleRepository repository = buildGalleryRuleRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rule rule = pickOne(random, galleryRules);
      expect((await repository.turnRuleOff(rule.id)).enabled, isFalse);
    }
    await expectLater(
      repository.turnRuleOff(const RuleId('missing')),
      throwsA(isA<RecordNotFound>()),
    );
  });
}
