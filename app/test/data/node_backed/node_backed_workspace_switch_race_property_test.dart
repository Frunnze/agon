import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../support/random_inputs.dart';
import 'support/slow_listing_race.dart';

const int _sequenceIterations = 60;
const int _longestSequence = 14;

enum _RaceStep {
  switchWorkspace,
  createSkill,
  deleteSkill,
  createRule,
  deleteRule,
  releaseOneReply,
}

Scope _randomScope(Random random, SlowListingRace race) {
  if (random.nextInt(3) == 0) {
    return const Scope.everywhere();
  }
  final List<WorkspaceId> chosen = <WorkspaceId>[
    for (final Workspace workspace in race.workspaces.listWorkspaces())
      if (random.nextBool()) workspace.id,
  ];
  return Scope(
    workspaces: OnlyWorkspaces(chosen),
    projects: const AllProjects(),
  );
}

Scope _scopeOfTheCurrentWorkspace(SlowListingRace race) {
  final WorkspaceId currentWorkspaceId = race.workspaces.currentWorkspace().id;
  return Scope(
    workspaces: OnlyWorkspaces(<WorkspaceId>[currentWorkspaceId]),
    projects: const AllProjects(),
  );
}

SkillDraft _buildSkillDraft({required int step, required Scope scope}) {
  return SkillDraft(
    name: 'made-$step',
    summary: 'Summary $step',
    instructions: 'Instructions $step',
    scope: scope,
    usage: SkillUsage.whenChosen,
    improvement: SkillImprovement.never,
  );
}

RuleDraft _buildRuleDraft({required int step, required Scope scope}) {
  return RuleDraft(
    title: 'Made rule $step',
    details: 'Details $step',
    scope: scope,
  );
}

Future<void> _deleteAnyListedSkill(Random random, SlowListingRace race) async {
  final List<Skill> listed = race.skills.listSkills();
  if (listed.isEmpty) {
    return;
  }
  await race.skills.deleteSkill(pickOne(random, listed).id);
}

Future<void> _deleteAnyListedRule(Random random, SlowListingRace race) async {
  final List<Rule> listed = race.rules.listRules();
  if (listed.isEmpty) {
    return;
  }
  await race.rules.deleteRule(pickOne(random, listed).id);
}

Future<void> _switchToAnotherWorkspace(
  Random random,
  SlowListingRace race,
) async {
  final WorkspaceId currentWorkspaceId = race.workspaces.currentWorkspace().id;
  final List<Workspace> others = <Workspace>[
    for (final Workspace workspace in race.workspaces.listWorkspaces())
      if (workspace.id != currentWorkspaceId) workspace,
  ];
  await race.workspaces.switchWorkspace(pickOne(random, others).id);
}

Future<void> _takeStep(Random random, SlowListingRace race, int step) async {
  switch (pickOne(random, _RaceStep.values)) {
    case _RaceStep.switchWorkspace:
      await _switchToAnotherWorkspace(random, race);
    case _RaceStep.createSkill:
      await race.skills.createSkill(
        _buildSkillDraft(step: step, scope: _randomScope(random, race)),
      );
    case _RaceStep.deleteSkill:
      await _deleteAnyListedSkill(random, race);
    case _RaceStep.createRule:
      await race.rules.createRule(
        _buildRuleDraft(step: step, scope: _randomScope(random, race)),
      );
    case _RaceStep.deleteRule:
      await _deleteAnyListedRule(random, race);
    case _RaceStep.releaseOneReply:
      releaseOneHeldReply(random, race.transport);
  }
  await pumpEventQueue();
}

void main() {
  test(
    'test_record_local_change_property_listings_end_in_the_current_workspace',
    () async {
      final Random random = seededRandom(76401);
      for (int i = 0; i < _sequenceIterations; i += 1) {
        final SlowListingRace race = await openSlowListingRace();
        final int stepCount = 1 + random.nextInt(_longestSequence);

        for (int step = 0; step < stepCount; step += 1) {
          await _takeStep(random, race, step);
        }
        await releaseEveryHeldReply(race.transport);

        expectListingsMatchTheCurrentWorkspace(race);
        closeSlowListingRace(race);
      }
    },
  );

  test(
    'test_record_local_change_property_slow_switch_reload_keeps_the_change',
    () async {
      final Random random = seededRandom(76402);
      for (int i = 0; i < _sequenceIterations; i += 1) {
        final SlowListingRace race = await openSlowListingRace();

        await _switchToAnotherWorkspace(random, race);
        await pumpEventQueue();
        final Skill created = await race.skills.createSkill(
          _buildSkillDraft(step: i, scope: _scopeOfTheCurrentWorkspace(race)),
        );
        await _deleteAnyListedRule(random, race);
        while (race.transport.heldReplyCount > 0) {
          releaseOneHeldReply(random, race.transport);
          await pumpEventQueue();
        }

        expectListingsMatchTheCurrentWorkspace(race);
        expect(race.skills.findSkill(created.id).name, created.name);
        closeSlowListingRace(race);
      }
    },
  );
}
