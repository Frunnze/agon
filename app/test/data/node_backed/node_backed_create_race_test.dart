import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../support/random_inputs.dart';
import 'support/held_reply_race.dart';
import 'support/simulated_catalog_node.dart';

const int _mostEarlierRecords = 4;

int _countMatches<Listed>(
  List<Listed> records,
  bool Function(Listed record) matches,
) {
  int count = 0;
  for (final Listed record in records) {
    if (matches(record)) {
      count += 1;
    }
  }
  return count;
}

void main() {
  test(
    'test_create_project_property_listed_once_after_a_seen_fetch',
    () async {
      final Random random = seededRandom(13101);
      for (int i = 0; i < propertyIterations; i += 1) {
        final SimulatedCatalogNode simulated = buildSimulatedHomeNode();
        final WorkspaceId workspaceId = WorkspaceId(
          readHomeWorkspaceId(simulated),
        );
        final int earlierCount = random.nextInt(_mostEarlierRecords);
        for (int index = 0; index < earlierCount; index += 1) {
          simulated.projects.add(<String, Object?>{
            'id': simulated.nextIdentifier('project'),
            'workspace_id': workspaceId.value,
            'name': 'earlier-$index',
            'repositories': <Object?>[],
          });
        }
        final HeldReplyRace race = await openHeldReplyRace(
          simulated: simulated,
          heldCommandName: 'create_project',
        );

        final Project created = await createWhileAFetchSeesIt(
          race: race,
          create: () => race.repositories.projects.createProject(
            ProjectDraft(
              workspaceId: workspaceId,
              name: 'site-$i',
              repositories: const <Repository>[],
            ),
          ),
          fetchedArea: node.ChangeArea.projects,
        );
        final List<Project> listed = race.repositories.projects.listProjects(
          workspaceId,
        );

        expect(
          _countMatches(listed, (Project project) => project.id == created.id),
          1,
        );
        expect(listed.length, earlierCount + 1);
        await closeHeldReplyRace(race);
      }
    },
  );

  test('test_create_rule_property_listed_once_after_a_seen_fetch', () async {
    final Random random = seededRandom(13102);
    for (int i = 0; i < propertyIterations; i += 1) {
      final SimulatedCatalogNode simulated = buildSimulatedHomeNode();
      final int earlierCount = random.nextInt(_mostEarlierRecords);
      for (int index = 0; index < earlierCount; index += 1) {
        simulated.addRule(
          workspaceId: readHomeWorkspaceId(simulated),
          title: 'Earlier rule $index',
        );
      }
      final HeldReplyRace race = await openHeldReplyRace(
        simulated: simulated,
        heldCommandName: 'create_rule',
      );

      final Rule created = await createWhileAFetchSeesIt(
        race: race,
        create: () => race.repositories.rules.createRule(
          RuleDraft(
            title: 'Rule $i',
            details: 'Details $i',
            scope: const Scope.everywhere(),
          ),
        ),
        fetchedArea: node.ChangeArea.rules,
      );
      final List<Rule> listed = race.repositories.rules.listRules();

      expect(_countMatches(listed, (Rule rule) => rule.id == created.id), 1);
      expect(listed.length, earlierCount + 1);
      await closeHeldReplyRace(race);
    }
  });

  test('test_create_skill_property_listed_once_after_a_seen_fetch', () async {
    final Random random = seededRandom(13103);
    for (int i = 0; i < propertyIterations; i += 1) {
      final SimulatedCatalogNode simulated = buildSimulatedHomeNode();
      final int earlierCount = random.nextInt(_mostEarlierRecords);
      for (int index = 0; index < earlierCount; index += 1) {
        simulated.addSkill(
          workspaceId: readHomeWorkspaceId(simulated),
          name: 'earlier-$index',
        );
      }
      final HeldReplyRace race = await openHeldReplyRace(
        simulated: simulated,
        heldCommandName: 'create_skill',
      );

      final Skill created = await createWhileAFetchSeesIt(
        race: race,
        create: () => race.repositories.skills.createSkill(
          SkillDraft(
            name: 'skill-$i',
            summary: 'Summary $i',
            instructions: 'Instructions $i',
            scope: const Scope.everywhere(),
            usage: SkillUsage.automatic,
            improvement: SkillImprovement.never,
          ),
        ),
        fetchedArea: node.ChangeArea.skills,
      );
      final List<Skill> listed = race.repositories.skills.listSkills();

      expect(
        _countMatches(listed, (Skill skill) => skill.id == created.id),
        1,
      );
      expect(listed.length, earlierCount + 1);
      await closeHeldReplyRace(race);
    }
  });

  test(
    'test_create_workspace_property_listed_once_after_a_seen_fetch',
    () async {
      final Random random = seededRandom(13104);
      for (int i = 0; i < propertyIterations; i += 1) {
        final SimulatedCatalogNode simulated = buildSimulatedHomeNode();
        final int earlierCount = random.nextInt(_mostEarlierRecords);
        for (int index = 0; index < earlierCount; index += 1) {
          simulated.addWorkspace('earlier-$index');
        }
        final HeldReplyRace race = await openHeldReplyRace(
          simulated: simulated,
          heldCommandName: 'create_workspace',
        );

        final Workspace created = await createWhileAFetchSeesIt(
          race: race,
          create: () =>
              race.repositories.workspaces.createWorkspace(name: 'labs-$i'),
          fetchedArea: node.ChangeArea.workspaces,
        );
        final List<Workspace> listed = race.repositories.workspaces
            .listWorkspaces();

        expect(
          _countMatches(
            listed,
            (Workspace workspace) => workspace.id == created.id,
          ),
          1,
        );
        expect(listed.length, earlierCount + 2);
        await closeHeldReplyRace(race);
      }
    },
  );
}
