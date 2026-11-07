import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/skill_inputs.dart';
import 'support/scoped_library_listing.dart';
import 'support/skill_repository_rig.dart';

const String _typePrefix = 'test_node_backed_skill_repository';
const int _iterations = 30;
const int _longestSequence = 8;
const String _acceptedOutcome = 'accepted';

bool _isSkillRefusal(Object error) {
  return error is ArgumentError ||
      error is StateError ||
      error is RecordNotFound;
}

String _describeRefusal(Object error) {
  return switch (error) {
    ArgumentError() => 'bad name',
    StateError(:final String message) => message,
    _ => 'not found',
  };
}

String _reportAccepted(Object? outcome) => _acceptedOutcome;

Future<String> _attempt(Future<Object?> Function() step) {
  final Future<String> accepted = step().then(_reportAccepted);
  return accepted.catchError(_describeRefusal, test: _isSkillRefusal);
}

List<String> _describeListing(SkillRepository repository) {
  return <String>[
    for (final Skill skill in repository.listSkills())
      <String>[
        skill.name,
        skill.summary,
        skill.instructions,
        '${skill.history.length}',
      ].join('|'),
  ];
}

String _pickDraftName(Random random, SkillRig rig) {
  final List<Skill> listed = rig.skills.listSkills();
  return switch (random.nextInt(3)) {
    0 when listed.isNotEmpty => pickOne(random, listed).name,
    1 => randomInvalidSkillName(random),
    _ => randomValidSkillName(random),
  };
}

SkillDraft _randomDraft(Random random, SkillRig rig, String name) {
  return SkillDraft(
    name: name,
    summary: randomText(random),
    instructions: randomText(random),
    scope: randomListingScope(random, rig.workspaceIds),
    usage: pickOne(random, SkillUsage.values),
    improvement: pickOne(random, SkillImprovement.values),
  );
}

Future<SkillRig> _openLoadedRig(Random random) async {
  final SkillRig rig = await openSkillRig(random);
  await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
  await rig.skills.load();
  return rig;
}

void main() {
  test('${_typePrefix}_create_skill_property_bad_names_send_'
      'nothing', () async {
    final Random random = seededRandom(81341);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await _openLoadedRig(random);
      final List<Skill> before = rig.skills.listSkills();
      final int notified = rig.notifications.count;
      final String name = randomInvalidSkillName(random);

      await expectLater(
        rig.skills.createSkill(_randomDraft(random, rig, name)),
        throwsArgumentError,
      );

      expect(rig.node.countCommands(createSkillCommand), 0);
      expect(identical(rig.skills.listSkills(), before), isTrue);
      expect(rig.notifications.count, notified);
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_create_skill_property_a_listed_name_sends_'
      'nothing', () async {
    final Random random = seededRandom(81342);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await _openLoadedRig(random);
      final Skill taken = await rig.skills.createSkill(
        randomSkillDraftNamed(random, randomValidSkillName(random)),
      );
      final List<Skill> before = rig.skills.listSkills();

      await expectLater(
        rig.skills.createSkill(_randomDraft(random, rig, taken.name)),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            'A skill named ${taken.name} already exists',
          ),
        ),
      );

      expect(rig.node.countCommands(createSkillCommand), 1);
      expect(identical(rig.skills.listSkills(), before), isTrue);
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_create_skill_property_agrees_with_the_fake_over_'
      'random_drafts', () async {
    final Random random = seededRandom(81343);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await _openLoadedRig(random);
      final FakeSkillRepository fake = buildTwinFakeSkills(rig);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        final String name = _pickDraftName(random, rig);
        final SkillDraft draft = _randomDraft(random, rig, name);

        final String shown = await _attempt(
          () => rig.skills.createSkill(draft),
        );
        final String modelled = await _attempt(() => fake.createSkill(draft));

        expect(shown, modelled, reason: 'creating $name');
        expect(_describeListing(rig.skills), _describeListing(fake));
      }
      fake.dispose();
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_delete_skill_property_unknown_skills_are_not_found_'
      'and_change_nothing', () async {
    final Random random = seededRandom(81344);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await _openLoadedRig(random);
      final List<Skill> before = rig.skills.listSkills();
      final int notified = rig.notifications.count;
      final SkillId unknown = SkillId('skill-gone-${random.nextInt(1 << 20)}');

      await expectLater(
        rig.skills.deleteSkill(unknown),
        throwsA(
          isA<RecordNotFound>()
              .having((RecordNotFound error) => error.kind, 'kind', 'skill')
              .having(
                (RecordNotFound error) => error.identifier,
                'identifier',
                unknown.value,
              ),
        ),
      );

      expect(identical(rig.skills.listSkills(), before), isTrue);
      expect(rig.notifications.count, notified);
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_delete_skill_property_agrees_with_the_fake_until_'
      'nothing_is_left', () async {
    final Random random = seededRandom(81345);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await _openLoadedRig(random);
      final FakeSkillRepository fake = buildTwinFakeSkills(rig);

      while (rig.skills.listSkills().isNotEmpty) {
        final Skill target = pickOne(random, rig.skills.listSkills());
        await rig.skills.deleteSkill(target.id);
        await fake.deleteSkill(target.id);

        expect(_describeListing(rig.skills), _describeListing(fake));
        expect(listShownSkillIds(rig), listNodeSkillIdsHere(rig));
      }
      fake.dispose();
      closeSkillRig(rig);
    }
  });
}
