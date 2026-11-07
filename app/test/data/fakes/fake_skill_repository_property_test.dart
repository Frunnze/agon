import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/refusals.dart';
import 'support/skill_inputs.dart';

const String _typePrefix = 'test_fake_skill_repository';
const String _unknownSkillPrefix = 'unknown-skill-';

bool _refusesAsNotFound(Object error) => error is RecordNotFound;

SkillId _randomUnknownSkillId(Random random) {
  return SkillId('$_unknownSkillPrefix${randomText(random)}');
}

void main() {
  test('${_typePrefix}_new_property_keeps_every_seeded_skill', () {
    final Random random = seededRandom(66401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Skill> seeded = randomSeededSkills(random);

      final FakeSkillRepository repository = buildSkillRepository(seeded);

      expect(describeSkills(repository.listSkills()), describeSkills(seeded));
    }
  });

  test('${_typePrefix}_new_property_later_seed_edits_do_not_leak', () {
    final Random random = seededRandom(66402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Skill> seeded = randomSeededSkills(random);
      final List<String> before = describeSkills(seeded);
      final FakeSkillRepository repository = buildSkillRepository(seeded);

      seeded.add(randomSeededSkill(random, seeded.length));

      expect(describeSkills(repository.listSkills()), before);
    }
  });

  test('${_typePrefix}_new_property_shown_list_cannot_be_edited', () {
    final Random random = seededRandom(66403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeSkillRepository repository = buildSkillRepository(
        randomSeededSkills(random),
      );
      final Skill extra = randomSeededSkill(random, propertyIterations + i);

      expect(() => repository.listSkills().add(extra), throwsUnsupportedError);
    }
  });

  test('test_list_skills_property_ids_and_names_stay_unique', () async {
    final Random random = seededRandom(66404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeSkillRepository repository = buildSkillRepository(
        randomSeededSkills(random),
      );
      final String name = randomValidSkillName(random);
      final bool isTaken = isSkillNameListed(repository.listSkills(), name);

      await isRefused(
        () => repository.createSkill(randomSkillDraftNamed(random, name)),
        isRefusal: refusesWithStateError,
      );

      final List<Skill> skills = repository.listSkills();
      final Set<SkillId> ids = <SkillId>{
        for (final Skill skill in skills) skill.id,
      };
      final Set<String> names = <String>{
        for (final Skill skill in skills) skill.name,
      };
      expect(ids.length, skills.length);
      expect(names.length, skills.length);
      expect(isSkillNameListed(skills, name), isTrue);
      expect(isTaken || skills.last.name == name, isTrue);
    }
  });

  test('test_list_skills_property_creation_appends_at_the_end', () async {
    final Random random = seededRandom(66405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Skill> seeded = randomSeededSkills(random);
      final FakeSkillRepository repository = buildSkillRepository(seeded);
      final String name = 'created-$i';

      final Skill created = await repository.createSkill(
        randomSkillDraftNamed(random, name),
      );

      final List<String> expected = <String>[
        ...describeSkills(seeded),
        describeSkill(created),
      ];
      expect(describeSkills(repository.listSkills()), expected);
    }
  });

  test(
    'test_list_skills_property_deletion_keeps_the_others_in_order',
    () async {
      final Random random = seededRandom(66406);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<Skill> seeded = randomSeededSkills(random);
        if (seeded.isEmpty) {
          continue;
        }
        final FakeSkillRepository repository = buildSkillRepository(seeded);
        final Skill deleted = pickOne(random, seeded);

        await repository.deleteSkill(deleted.id);

        final List<String> expected = <String>[
          for (final Skill skill in seeded)
            if (skill.id != deleted.id) describeSkill(skill),
        ];
        expect(describeSkills(repository.listSkills()), expected);
      }
    },
  );

  test('test_find_skill_property_finds_exactly_the_listed_skills', () {
    final Random random = seededRandom(66407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeSkillRepository repository = buildSkillRepository(
        randomSeededSkills(random),
      );

      for (final Skill listed in repository.listSkills()) {
        expect(repository.findSkill(listed.id), same(listed));
      }
    }
  });

  test('test_find_skill_property_unknown_ids_name_the_missing_id', () {
    final Random random = seededRandom(66408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeSkillRepository repository = buildSkillRepository(
        randomSeededSkills(random),
      );
      final SkillId unknown = _randomUnknownSkillId(random);

      expect(
        () => repository.findSkill(unknown),
        throwsA(
          isA<RecordNotFound>().having(
            (RecordNotFound error) => error.identifier,
            'identifier',
            unknown.value,
          ),
        ),
      );
    }
  });

  test('test_find_skill_property_created_skills_are_found', () async {
    final Random random = seededRandom(66409);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeSkillRepository repository = buildSkillRepository(
        randomSeededSkills(random),
      );

      final Skill created = await repository.createSkill(
        randomSkillDraftNamed(random, 'found-$i'),
      );

      expect(repository.findSkill(created.id), same(created));
    }
  });

  test('test_delete_skill_property_deleted_skills_are_gone', () async {
    final Random random = seededRandom(66410);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Skill> seeded = randomSeededSkills(random);
      if (seeded.isEmpty) {
        continue;
      }
      final FakeSkillRepository repository = buildSkillRepository(seeded);
      final Skill deleted = pickOne(random, seeded);

      await repository.deleteSkill(deleted.id);

      expect(
        () => repository.findSkill(deleted.id),
        throwsA(isA<RecordNotFound>()),
      );
      final bool wasRefused = await isRefused(
        () => repository.deleteSkill(deleted.id),
        isRefusal: _refusesAsNotFound,
      );
      expect(wasRefused, isTrue);
    }
  });

  test('test_delete_skill_property_unknown_ids_change_nothing', () async {
    final Random random = seededRandom(66411);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeSkillRepository repository = buildSkillRepository(
        randomSeededSkills(random),
      );
      final List<String> before = describeSkills(repository.listSkills());
      final NotificationCounter counter = NotificationCounter();
      repository.addListener(counter.record);

      final bool wasRefused = await isRefused(
        () => repository.deleteSkill(_randomUnknownSkillId(random)),
        isRefusal: _refusesAsNotFound,
      );

      expect(wasRefused, isTrue);
      expect(describeSkills(repository.listSkills()), before);
      expect(counter.count, 0);
    }
  });

  test('test_delete_skill_property_frees_the_name_for_reuse', () async {
    final Random random = seededRandom(66412);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Skill> seeded = randomSeededSkills(random);
      if (seeded.isEmpty) {
        continue;
      }
      final FakeSkillRepository repository = buildSkillRepository(seeded);
      final Skill deleted = pickOne(random, seeded);
      final NotificationCounter counter = NotificationCounter();
      repository.addListener(counter.record);

      await repository.deleteSkill(deleted.id);
      final Skill reused = await repository.createSkill(
        randomSkillDraftNamed(random, deleted.name),
      );

      expect(reused.name, deleted.name);
      expect(reused.id, isNot(deleted.id));
      expect(counter.count, 2);
    }
  });
}
