import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/simulated_catalog_node.dart';
import 'support/simulated_scoped_rules.dart';
import 'support/workspace_inputs.dart';
import 'support/workspace_scope_inputs.dart';

const String _typePrefix = 'test_fake_rule_repository';
const int _sequenceIterations = 60;
const int _smallestWorkspaceCount = 2;
const int _extraWorkspaceSpan = 3;
const int _largestSeededCount = 7;

typedef _Mirror = ({
  SimulatedCatalogNode simulated,
  FakeWorkspaceRepository workspaces,
  FakeRuleRepository fake,
  NodeBackedRuleRepository nodeBacked,
});

Workspace _mirrorWorkspace(Map<String, Object?> record) {
  return Workspace(
    id: WorkspaceId(record['id']! as String),
    name: record['name']! as String,
    appServerAddress: simulatedServerAddress,
    protectedFiles: const <String>[],
    approvalPolicy: ApprovalPolicy.neverAsk,
  );
}

Future<_Mirror> _buildMirror(Random random) async {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  final int workspaceCount =
      _smallestWorkspaceCount + random.nextInt(_extraWorkspaceSpan);
  final List<Workspace> workspaces = <Workspace>[
    for (int index = 0; index < workspaceCount; index += 1)
      _mirrorWorkspace(simulated.addWorkspace('team-$index')),
  ];
  final FakeWorkspaceRepository workspaceRepository = buildWorkspaceRepository(
    workspaces: workspaces,
    currentWorkspaceId: pickOne(random, workspaces).id,
    appServerGroup: randomAppServerGroup(random),
  );
  final List<Rule> modelRules = seedSimulatedRules(
    random: random,
    simulated: simulated,
    workspaceIds: listWorkspaceIds(workspaces),
    count: random.nextInt(_largestSeededCount + 1),
  );
  final NodeBackedRuleRepository nodeBacked = NodeBackedRuleRepository(
    channel: simulated.channel,
    workspaceRepository: workspaceRepository,
  );
  await nodeBacked.load();
  return (
    simulated: simulated,
    workspaces: workspaceRepository,
    fake: FakeRuleRepository(
      rules: modelRules,
      clock: FixedClock(randomUtcMoment(random)),
      workspaceRepository: workspaceRepository,
    ),
    nodeBacked: nodeBacked,
  );
}

Future<void> _deleteWorkspaceInBoth(
  _Mirror mirror,
  WorkspaceId deletedWorkspaceId,
) async {
  final String command = jsonEncode(<String, Object?>{
    'command': 'delete_workspace',
    'workspace_id': deletedWorkspaceId.value,
  });
  mirror.simulated.answer(command);
  await mirror.workspaces.deleteWorkspace(deletedWorkspaceId);
  final List<WorkspaceId> remaining = listWorkspaceIds(
    mirror.workspaces.listWorkspaces(),
  );
  final List<Object?> simulatedRemaining = <Object?>[
    for (final Map<String, Object?> record in mirror.simulated.workspaces)
      record['id'],
  ];
  expect(
    simulatedRemaining,
    orderedEquals(<Object?>[
      for (final WorkspaceId workspaceId in remaining) workspaceId.value,
    ]),
  );
  mirror.fake.forgetWorkspace(
    deletedWorkspaceId: deletedWorkspaceId,
    remainingWorkspaceIds: remaining.toSet(),
  );
}

Future<void> _expectSameListingsEverywhere(_Mirror mirror) async {
  final List<WorkspaceId> remaining = listWorkspaceIds(
    mirror.workspaces.listWorkspaces(),
  );
  for (final WorkspaceId workspaceId in remaining) {
    await mirror.workspaces.switchWorkspace(workspaceId);
    await mirror.nodeBacked.load();

    expect(
      describeRuleListing(mirror.fake),
      orderedEquals(describeRuleListing(mirror.nodeBacked)),
      reason: 'listing in ${workspaceId.value}',
    );
  }
}

void _closeMirror(_Mirror mirror) {
  mirror.nodeBacked.dispose();
  mirror.fake.dispose();
}

void main() {
  test('${_typePrefix}_forget_workspace_property_agrees_with_the_node_'
      'deleting_a_workspace', () async {
    final Random random = seededRandom(77101);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Mirror mirror = await _buildMirror(random);
      final WorkspaceId deleted = pickOne(
        random,
        listWorkspaceIds(mirror.workspaces.listWorkspaces()),
      );

      await _deleteWorkspaceInBoth(mirror, deleted);

      await _expectSameListingsEverywhere(mirror);
      _closeMirror(mirror);
    }
  });

  test('${_typePrefix}_forget_workspace_property_agrees_with_the_node_'
      'deleting_workspaces_in_a_row', () async {
    final Random random = seededRandom(77102);

    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Mirror mirror = await _buildMirror(random);

      while (mirror.workspaces.listWorkspaces().length > 1) {
        final WorkspaceId deleted = pickOne(
          random,
          listWorkspaceIds(mirror.workspaces.listWorkspaces()),
        );
        await _deleteWorkspaceInBoth(mirror, deleted);

        await _expectSameListingsEverywhere(mirror);
      }
      _closeMirror(mirror);
    }
  });
}
