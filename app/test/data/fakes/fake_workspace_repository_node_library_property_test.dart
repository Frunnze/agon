import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/fake_workspace_contents.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';

import '../../support/fake_task_work_links.dart';
import '../../support/memory_workspace_choice_store.dart';
import '../../support/random_inputs.dart';
import '../node_backed/support/simulated_catalog_node.dart';
import 'support/rule_inputs.dart';
import 'support/skill_inputs.dart';
import 'support/workflow_inputs.dart';

const int _iterations = 30;
const int _workspaceCount = 3;
const int _largestRuleCount = 6;
const Duration _retryInterval = Duration(seconds: 30);

typedef _World = ({
  FakeWorkspaceRepository fakeWorkspaces,
  FakeRuleRepository fakeRules,
  NodeBackedWorkspaceRepository nodeWorkspaces,
  NodeBackedRuleRepository nodeRules,
});

WorkspaceScope _randomWorkspaceScope(Random random, List<String> ids) {
  if (random.nextInt(3) == 0) {
    return const AllWorkspaces();
  }
  final List<WorkspaceId> listed = <WorkspaceId>[
    for (final String id in ids)
      if (random.nextBool()) WorkspaceId(id),
  ];
  return OnlyWorkspaces(listed);
}

Object? _encodeScope(Scope scope) {
  return jsonDecode(jsonEncode(mapScopeToNode(scope).toJson()));
}

FakeWorkspaceContents _buildContents(FakeRuleRepository ruleRepository) {
  final FakeWorkflowRepository workflowRepository = buildWorkflowRepository(
    workflows: const <Workflow>[],
    changes: const <WorkflowChange>[],
  );
  workflowRepository.linkWork(
    taskWork: buildEmptyTaskWork(),
    approvalRepository: FakeApprovalRepository(
      approvals: const <ApprovalRequest>[],
      clock: FixedClock(galleryNow),
      currentDeviceId: GalleryDeviceIds.airLaptop,
    ),
  );
  return FakeWorkspaceContents(
    projectRepository: FakeProjectRepository(
      projects: const [],
      taskWork: buildEmptyTaskWork(),
    ),
    taskWork: buildEmptyTaskWork(),
    skillRepository: buildSkillRepository(const <Skill>[]),
    ruleRepository: ruleRepository,
    workflowRepository: workflowRepository,
  );
}

Future<_World> _buildWorld(Random random) async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  final List<String> workspaceIds = <String>[
    for (int i = 0; i < _workspaceCount; i += 1)
      simulated.addWorkspace('team-$i')['id']! as String,
  ];
  final List<Rule> rules = <Rule>[];
  final int ruleCount = random.nextInt(_largestRuleCount + 1);
  for (int i = 0; i < ruleCount; i += 1) {
    final Map<String, Object?> wire = simulated.addRule(
      workspaceId: pickOne(random, workspaceIds),
      title: 'Rule $i',
    );
    final Scope scope = Scope(
      workspaces: _randomWorkspaceScope(random, workspaceIds),
      projects: const AllProjects(),
    );
    wire['scope'] = _encodeScope(scope);
    rules.add(
      Rule(
        id: RuleId(wire['id']! as String),
        title: 'Rule $i',
        details: wire['details']! as String,
        scope: scope,
        enabled: true,
        addedAt: galleryNow,
      ),
    );
  }

  final NodeBackedWorkspaceRepository nodeWorkspaces =
      NodeBackedWorkspaceRepository(
        channel: simulated.channel,
        clock: FixedClock(galleryNow),
        retryInterval: _retryInterval,
        choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
      );
  await nodeWorkspaces.load();
  final NodeBackedRuleRepository nodeRules = NodeBackedRuleRepository(
    channel: simulated.channel,
    workspaceRepository: nodeWorkspaces,
  );
  final FakeWorkspaceRepository fakeWorkspaces = FakeWorkspaceRepository(
    workspaces: nodeWorkspaces.listWorkspaces(),
    currentWorkspaceId: nodeWorkspaces.currentWorkspace().id,
    appServerStatus: nodeWorkspaces.findAppServerStatus(),
    appServerGroup: nodeWorkspaces.findAppServerGroup(),
    currentDeviceId: const DeviceId(simulatedDeviceId),
    clock: FixedClock(galleryNow),
  );
  final FakeRuleRepository fakeRules = FakeRuleRepository(
    rules: rules,
    clock: FixedClock(galleryNow),
    workspaceRepository: fakeWorkspaces,
  );
  fakeWorkspaces.linkContents(_buildContents(fakeRules));
  return (
    fakeWorkspaces: fakeWorkspaces,
    fakeRules: fakeRules,
    nodeWorkspaces: nodeWorkspaces,
    nodeRules: nodeRules,
  );
}

List<String> _describeRules(RuleRepository repository) {
  return <String>[
    for (final Rule rule in repository.listRules())
      '${rule.title} ${describeScope(rule.scope)}',
  ];
}

Future<void> _expectSameRulesEverywhere(_World world) async {
  for (final Workspace workspace in world.nodeWorkspaces.listWorkspaces()) {
    await world.nodeWorkspaces.switchWorkspace(workspace.id);
    await world.fakeWorkspaces.switchWorkspace(workspace.id);
    await world.nodeRules.load();

    expect(
      _describeRules(world.fakeRules),
      orderedEquals(_describeRules(world.nodeRules)),
    );
  }
}

void main() {
  test('test_fake_workspace_repository_delete_workspace_property_leaves_'
      'the_same_rules_as_the_node', () async {
    final Random random = seededRandom(72701);

    for (int i = 0; i < _iterations; i += 1) {
      final _World world = await _buildWorld(random);
      await _expectSameRulesEverywhere(world);
      final Workspace doomed = pickOne(
        random,
        world.nodeWorkspaces.listWorkspaces(),
      );

      await world.nodeWorkspaces.deleteWorkspace(doomed.id);
      await world.fakeWorkspaces.deleteWorkspace(doomed.id);

      expect(
        world.fakeWorkspaces.listWorkspaces().length,
        world.nodeWorkspaces.listWorkspaces().length,
      );
      await _expectSameRulesEverywhere(world);
      world.nodeRules.dispose();
    }
  });
}
