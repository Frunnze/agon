import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/skill_inputs.dart';
import 'support/skill_repository_rig.dart';

const String _typePrefix = 'test_node_backed_skill_repository';
const int _iterations = 30;

String _describeFinding(SkillRepository repository, SkillId skillId) {
  try {
    return describeSkill(repository.findSkill(skillId));
  } on RecordNotFound catch (missing) {
    return 'missing ${missing.kind} ${missing.identifier}';
  }
}

Future<void> _switchRandomly(Random random, SkillRig rig) async {
  await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
  await pumpEventQueue();
}

void main() {
  test('${_typePrefix}_constructor_property_starts_empty_and_'
      'silent', () async {
    final Random random = seededRandom(81301);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);

      expect(rig.skills.listSkills(), isEmpty);
      expect(rig.node.countCommands(listSkillsCommand), 0);
      expect(rig.notifications.count, 0);
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_constructor_property_follows_workspace_switches_'
      'before_any_load', () async {
    final Random random = seededRandom(81302);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);

      await _switchRandomly(random, rig);

      expect(listShownSkillIds(rig), listNodeSkillIdsHere(rig));
      expect(rig.node.countCommands(listSkillsCommand), 1);
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_constructor_property_reads_only_its_own_'
      'channel', () async {
    final Random random = seededRandom(81303);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig first = await openSkillRig(random);
      final SkillRig second = await openSkillRig(random);

      await first.skills.load();
      await second.skills.load();

      expect(listShownSkillIds(first), listNodeSkillIdsHere(first));
      expect(listShownSkillIds(second), listNodeSkillIdsHere(second));
      expect(first.node.countCommands(listSkillsCommand), 1);
      expect(second.node.countCommands(listSkillsCommand), 1);
      closeSkillRig(first);
      closeSkillRig(second);
    }
  });

  test('${_typePrefix}_load_property_lists_exactly_the_current_workspace_'
      'skills', () async {
    final Random random = seededRandom(81304);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);

      for (int step = 0; step < 3; step += 1) {
        rig.node.catalog.addSkill(
          workspaceId: pickOne(random, rig.workspaceIds).value,
          name: 'outside-$step',
        );
        await rig.skills.load();

        expect(listShownSkillIds(rig), listNodeSkillIdsHere(rig));
        await _switchRandomly(random, rig);
      }
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_load_property_a_local_change_during_the_latest_'
      'fetch_fetches_again', () async {
    final Random random = seededRandom(81305);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      rig.transport.holdNextReply(listSkillsCommand);
      final Future<void> loading = rig.skills.load();
      await rig.transport.heldReplyArrival;
      final SkillDraft draft = randomSkillDraftNamed(random, 'made-$i');

      final Skill created = await rig.skills.createSkill(draft);
      rig.transport.releaseHeldReply();
      await loading;

      expect(rig.node.countCommands(listSkillsCommand), 2);
      expect(listShownSkillIds(rig), listNodeSkillIdsHere(rig));
      expect(rig.skills.findSkill(created.id).name, draft.name);
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_load_property_notifies_once_per_accepted_'
      'listing', () async {
    final Random random = seededRandom(81306);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      final int loads = 1 + random.nextInt(4);

      for (int step = 0; step < loads; step += 1) {
        await rig.skills.load();
      }

      expect(rig.notifications.count, loads);
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_apply_change_property_only_the_skills_area_asks_'
      'the_node', () async {
    final Random random = seededRandom(81307);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      final node.ChangeArea area = pickOne(random, node.ChangeArea.values);

      await rig.skills.applyChange(node.AreaChanged(area: area));

      final int expected = area == node.ChangeArea.skills ? 1 : 0;
      expect(rig.node.countCommands(listSkillsCommand), expected);
      expect(rig.notifications.count, expected);
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_apply_change_property_run_changes_ask_'
      'nothing', () async {
    final Random random = seededRandom(81308);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);

      await rig.skills.applyChange(
        node.RunChanged(runId: RunId(randomText(random))),
      );

      expect(rig.node.countCommands(listSkillsCommand), 0);
      expect(rig.notifications.count, 0);
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_list_skills_property_is_unmodifiable_and_'
      'stable', () async {
    final Random random = seededRandom(81309);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      await rig.skills.load();
      final List<Skill> first = rig.skills.listSkills();

      expect(first.clear, throwsUnsupportedError);
      expect(identical(rig.skills.listSkills(), first), isTrue);
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_list_skills_property_agrees_with_the_fake_on_the_'
      'workspace_rule', () async {
    final Random random = seededRandom(81310);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      await _switchRandomly(random, rig);
      final FakeSkillRepository fake = buildTwinFakeSkills(rig);

      expect(
        rig.skills.listSkills().map(describeSkill),
        fake.listSkills().map(describeSkill),
      );
      fake.dispose();
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_find_skill_property_finds_every_listed_'
      'skill', () async {
    final Random random = seededRandom(81311);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      await rig.skills.load();

      for (final Skill skill in rig.skills.listSkills()) {
        expect(identical(rig.skills.findSkill(skill.id), skill), isTrue);
      }
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_find_skill_property_unlisted_skills_are_not_'
      'found', () async {
    final Random random = seededRandom(81312);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      await rig.skills.load();
      final Set<String> shown = listShownSkillIds(rig).toSet();
      final List<SkillId> unlisted = <SkillId>[
        SkillId('skill-${randomText(random)}'),
        for (final Skill skill in readNodeSkills(rig))
          if (!shown.contains(skill.id.value)) skill.id,
      ];

      for (final SkillId skillId in unlisted) {
        expect(
          () => rig.skills.findSkill(skillId),
          throwsA(
            isA<RecordNotFound>()
                .having((RecordNotFound error) => error.kind, 'kind', 'skill')
                .having(
                  (RecordNotFound error) => error.identifier,
                  'identifier',
                  skillId.value,
                ),
          ),
        );
      }
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_find_skill_property_agrees_with_the_fake', () async {
    final Random random = seededRandom(81313);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      await _switchRandomly(random, rig);
      final FakeSkillRepository fake = buildTwinFakeSkills(rig);
      final List<SkillId> asked = <SkillId>[
        for (final Skill skill in readNodeSkills(rig)) skill.id,
        SkillId('skill-${randomText(random)}'),
      ];

      for (final SkillId skillId in asked) {
        expect(
          _describeFinding(rig.skills, skillId),
          _describeFinding(fake, skillId),
        );
      }
      fake.dispose();
      closeSkillRig(rig);
    }
  });
}
