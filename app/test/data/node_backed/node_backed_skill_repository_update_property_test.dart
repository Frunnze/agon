import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/skill_change.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/skill_inputs.dart';
import 'support/skill_repository_rig.dart';

const String _typePrefix = 'test_node_backed_skill_repository';
const int _iterations = 25;
const int _largestUpdateCount = 30;
const int _largestAgentChangeCount = 4;

SkillDraft _draftOf(Skill skill, {required String name}) {
  return SkillDraft(
    name: name,
    summary: skill.summary,
    instructions: skill.instructions,
    scope: const Scope.everywhere(),
    usage: skill.usage,
    improvement: skill.improvement,
  );
}

SkillDraft _rewordedDraft(Random random, Skill skill, {required int step}) {
  final bool isReworded = random.nextInt(4) != 0;
  return SkillDraft(
    name: skill.name,
    summary: randomText(random),
    instructions: isReworded ? 'Version $step' : skill.instructions,
    scope: const Scope.everywhere(),
    usage: pickOne(random, SkillUsage.values),
    improvement: pickOne(random, SkillImprovement.values),
  );
}

List<String> _describeHistory(Skill skill) {
  return <String>[
    for (final SkillChange change in skill.history)
      <String>[
        '${change.origin.runtimeType}',
        change.replacedInstructions,
        '${change.savedAt.toUtc()}',
      ].join('|'),
  ];
}

Future<Skill> _createListedSkill(Random random, SkillRig rig) async {
  await rig.skills.load();
  return rig.skills.createSkill(
    randomSkillDraftNamed(random, 'own-${random.nextInt(1 << 20)}'),
  );
}

void _seedAgentHistory(
  Random random,
  SkillRig rig,
  Skill skill, {
  required bool endsWithAgent,
}) {
  final List<Object?> history = <Object?>[
    for (int i = 0; i <= random.nextInt(_largestAgentChangeCount); i += 1)
      <String, Object?>{
        'origin': i.isEven
            ? <String, Object?>{'kind': 'person_edit'}
            : <String, Object?>{'kind': 'approved_agent_run', 'run_id': 'r$i'},
        'saved_at': skillClockMoment.toUtc().toIso8601String(),
        'replaced_instructions': 'Before change $i',
      },
  ];
  history.add(<String, Object?>{
    'origin': endsWithAgent
        ? <String, Object?>{'kind': 'automatic_agent_run', 'run_id': 'last'}
        : <String, Object?>{'kind': 'person_edit'},
    'saved_at': skillClockMoment.toUtc().toIso8601String(),
    'replaced_instructions': 'Before the latest change',
  });
  for (final Map<String, Object?> wire in rig.node.catalog.skills) {
    if (wire['id'] == skill.id.value) {
      wire['history'] = history;
    }
  }
}

void main() {
  test('${_typePrefix}_update_skill_property_bad_names_send_'
      'nothing', () async {
    final Random random = seededRandom(81361);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      final Skill skill = await _createListedSkill(random, rig);
      final List<Skill> before = rig.skills.listSkills();
      final String name = randomInvalidSkillName(random);

      await expectLater(
        rig.skills.updateSkill(skill.id, _draftOf(skill, name: name)),
        throwsArgumentError,
      );

      expect(rig.node.countCommands(updateSkillCommand), 0);
      expect(identical(rig.skills.listSkills(), before), isTrue);
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_update_skill_property_another_listed_name_is_'
      'refused_but_its_own_is_kept', () async {
    final Random random = seededRandom(81362);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      final Skill first = await _createListedSkill(random, rig);
      final Skill second = await _createListedSkill(random, rig);

      await expectLater(
        rig.skills.updateSkill(first.id, _draftOf(first, name: second.name)),
        throwsStateError,
      );
      expect(rig.node.countCommands(updateSkillCommand), 0);

      final Skill kept = await rig.skills.updateSkill(
        first.id,
        _draftOf(first, name: first.name),
      );
      expect(kept.name, first.name);
      expect(rig.skills.findSkill(first.id).name, first.name);
      expect(rig.skills.findSkill(second.id).name, second.name);
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_update_skill_property_history_keeps_the_newest_'
      'twenty_like_the_fake', () async {
    final Random random = seededRandom(81363);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      final Skill created = await _createListedSkill(random, rig);
      final FakeSkillRepository fake = buildTwinFakeSkills(rig);
      final int updates = random.nextInt(_largestUpdateCount);

      for (int step = 0; step < updates; step += 1) {
        final Skill current = rig.skills.findSkill(created.id);
        final SkillDraft draft = _rewordedDraft(random, current, step: step);
        final Skill shown = await rig.skills.updateSkill(created.id, draft);
        final Skill modelled = await fake.updateSkill(created.id, draft);

        expect(shown.history.length, lessThanOrEqualTo(rustKeptSkillChanges));
        expect(_describeHistory(shown), _describeHistory(modelled));
        expect(describeSkill(shown), describeSkill(modelled));
      }
      fake.dispose();
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_undo_latest_agent_change_property_restores_the_'
      'replaced_instructions_like_the_fake', () async {
    final Random random = seededRandom(81364);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      final Skill created = await _createListedSkill(random, rig);
      _seedAgentHistory(random, rig, created, endsWithAgent: true);
      await rig.skills.load();
      final Skill before = rig.skills.findSkill(created.id);
      final FakeSkillRepository fake = buildTwinFakeSkills(rig);

      final Skill restored = await rig.skills.undoLatestAgentChange(
        created.id,
      );
      final Skill modelled = await fake.undoLatestAgentChange(created.id);

      expect(restored.instructions, before.history.last.replacedInstructions);
      expect(
        _describeHistory(restored),
        _describeHistory(before).sublist(0, before.history.length - 1),
      );
      expect(describeSkill(restored), describeSkill(modelled));
      expect(identical(rig.skills.findSkill(created.id), restored), isTrue);
      fake.dispose();
      closeSkillRig(rig);
    }
  });

  test('${_typePrefix}_undo_latest_agent_change_property_person_edits_and_'
      'empty_histories_are_refused', () async {
    final Random random = seededRandom(81365);

    for (int i = 0; i < _iterations; i += 1) {
      final SkillRig rig = await openSkillRig(random);
      final Skill created = await _createListedSkill(random, rig);
      if (random.nextBool()) {
        _seedAgentHistory(random, rig, created, endsWithAgent: false);
      }
      await rig.skills.load();
      final List<Skill> before = rig.skills.listSkills();
      final int notified = rig.notifications.count;

      await expectLater(
        rig.skills.undoLatestAgentChange(created.id),
        throwsStateError,
      );

      expect(identical(rig.skills.listSkills(), before), isTrue);
      expect(rig.notifications.count, notified);
      closeSkillRig(rig);
    }
  });
}
