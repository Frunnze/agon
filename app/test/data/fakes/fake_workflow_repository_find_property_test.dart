import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/workflow_views.dart' as node;
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/simulated_workflow_node.dart';
import 'support/workflow_inputs.dart';
import 'support/workspace_inputs.dart';
import 'support/workspace_scope_inputs.dart';
import 'support/workspace_work_checks.dart';
import 'support/workspace_workflow_inputs.dart';

const String _typePrefix = 'test_fake_workflow_repository';
const int _sequenceIterations = 30;
const int _longestSequence = 8;
const int _largestSeededCount = 5;
const List<String> _seededStates = <String>[
  signedState,
  unsignedState,
  changedState,
];

typedef _Pair = ({
  FakeWorkflowRepository fake,
  NodeBackedWorkflowRepository nodeBacked,
  FakeWorkspaceRepository workspaces,
  List<WorkspaceId> workspaceIds,
  List<WorkflowId> seededIds,
});

Object? _encodeWire(Object? json) => jsonDecode(jsonEncode(json));

node.WorkflowView _seedView(
  Random random,
  SimulatedWorkflowNode simulated,
  List<WorkspaceId> workspaceIds,
  int index,
) {
  final Map<String, Object?> view = simulated.addWorkflow(
    name: 'seeded-$index',
    state: pickOne(random, _seededStates),
  );
  final Map<String, Object?> workflow =
      view['workflow']! as Map<String, Object?>;
  workflow['availability'] = _encodeWire(
    mapWorkspaceScopeToNode(randomWorkspaceScopeOver(random, workspaceIds))
        .toJson(),
  );
  return node.WorkflowView.fromJson(_encodeWire(view));
}

Future<_Pair> _buildPair(Random random) async {
  final SeededWorkspaces seeded = seedRandomWorkspaces(random);
  final List<WorkspaceId> workspaceIds = listWorkspaceIds(seeded.workspaces);
  final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
    pollsBeforeDraftIsDone: 1,
  );
  final int count = random.nextInt(_largestSeededCount + 1);
  final List<node.WorkflowView> views = <node.WorkflowView>[
    for (int index = 0; index < count; index += 1)
      _seedView(random, simulated, workspaceIds, index),
  ];
  final NodeBackedWorkflowRepository nodeBacked = NodeBackedWorkflowRepository(
    channel: simulated.channel,
    workspaceRepository: seeded.repository,
    draftPollInterval: Duration.zero,
  );
  await nodeBacked.load();
  final FakeWorkflowRepository fake = buildWorkflowRepositoryIn(
    workflows: <Workflow>[
      for (final node.WorkflowView view in views) mapWorkflowFromNode(view),
    ],
    changes: <WorkflowChange>[
      for (final node.WorkflowView view in views)
        ?mapPendingChangeFromNode(view),
    ],
    workspaceRepository: seeded.repository,
  );
  return (
    fake: fake,
    nodeBacked: nodeBacked,
    workspaces: seeded.repository,
    workspaceIds: workspaceIds,
    seededIds: <WorkflowId>[
      for (final node.WorkflowView view in views) view.workflow.id,
    ],
  );
}

bool _isFound(WorkflowRepository repository, WorkflowId workflowId) {
  try {
    repository.findWorkflow(workflowId);
    return true;
  } on RecordNotFound {
    return false;
  }
}

void _expectSameLookups(_Pair pair) {
  for (final WorkflowId workflowId in pair.seededIds) {
    expect(
      _isFound(pair.fake, workflowId),
      _isFound(pair.nodeBacked, workflowId),
      reason: 'find ${workflowId.value}',
    );
    expect(
      pair.fake.findPendingChange(workflowId) == null,
      pair.nodeBacked.findPendingChange(workflowId) == null,
      reason: 'change ${workflowId.value}',
    );
  }
}

String _describeAvailability(Workflow workflow) {
  return jsonEncode(mapWorkspaceScopeToNode(workflow.availability).toJson());
}

Future<void> _switchBoth(Random random, _Pair pair) async {
  await pair.workspaces.switchWorkspace(pickOne(random, pair.workspaceIds));
  await pair.nodeBacked.load();
}

Future<void> _moveInBoth(Random random, _Pair pair) async {
  final List<Workflow> listed = pair.nodeBacked.listWorkflows();
  if (listed.isEmpty) {
    return;
  }
  final Workflow chosen = pickOne(random, listed);
  final Workflow moved = withAvailability(
    chosen,
    randomWorkspaceScopeOver(random, pair.workspaceIds),
  );
  if (_describeAvailability(moved) == _describeAvailability(chosen)) {
    return;
  }

  await expectSameRefusal(
    fakeStep: () => pair.fake.saveWorkflow(moved),
    nodeStep: () => pair.nodeBacked.saveWorkflow(moved),
    reason: 'save ${moved.id.value}',
  );
}

Future<void> _deleteInBoth(Random random, _Pair pair) async {
  if (pair.seededIds.isEmpty) {
    return;
  }
  final WorkflowId workflowId = pickOne(random, pair.seededIds);

  await expectSameRefusal(
    fakeStep: () => pair.fake.deleteWorkflow(workflowId),
    nodeStep: () => pair.nodeBacked.deleteWorkflow(workflowId),
    reason: 'delete ${workflowId.value}',
  );
}

typedef _PairStep = Future<void> Function(Random random, _Pair pair);

Future<void> _checkAgreement(_PairStep focus, int seed) async {
  final Random random = seededRandom(seed);

  for (int i = 0; i < _sequenceIterations; i += 1) {
    final _Pair pair = await _buildPair(random);
    _expectSameLookups(pair);
    final int stepCount = 1 + random.nextInt(_longestSequence);

    for (int step = 0; step < stepCount; step += 1) {
      final _PairStep chosen = random.nextInt(3) == 0
          ? pickOne(random, <_PairStep>[_switchBoth, _moveInBoth])
          : focus;
      await chosen(random, pair);
      _expectSameLookups(pair);
    }
    await pumpEventQueue();
    pair.nodeBacked.dispose();
    pair.fake.dispose();
  }
}

void main() {
  test('${_typePrefix}_find_workflow_property_finds_what_the_node_lists', () {
    return _checkAgreement(_switchBoth, 77601);
  });

  test('${_typePrefix}_find_workflow_property_moved_workflows_leave_like_'
      'the_node', () {
    return _checkAgreement(_moveInBoth, 77602);
  });

  test('${_typePrefix}_find_pending_change_property_sees_what_the_node_'
      'lists', () {
    return _checkAgreement(_switchBoth, 77603);
  });

  test('${_typePrefix}_delete_workflow_property_deletes_any_workspace_'
      'workflow_like_the_node', () {
    return _checkAgreement(_deleteInBoth, 77604);
  });

  test('test_node_backed_workflow_repository_store_view_property_drops_'
      'workflows_moved_out_of_the_workspace', () {
    return _checkAgreement(_moveInBoth, 77605);
  });

  test('test_node_backed_workflow_repository_store_view_property_keeps_'
      'changes_only_for_listed_workflows', () {
    return _checkAgreement(_moveInBoth, 77606);
  });

  test('${_typePrefix}_find_workflow_property_unlisted_workflows_are_record_'
      'not_found', () async {
    final Random random = seededRandom(77607);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Pair pair = await _buildPair(random);
      await _switchBoth(random, pair);
      final Set<WorkflowId> listed = <WorkflowId>{
        for (final Workflow workflow in pair.fake.listWorkflows()) workflow.id,
      };

      for (final WorkflowId workflowId in pair.seededIds) {
        final bool isFound = _isFound(pair.fake, workflowId);
        expect(isFound, listed.contains(workflowId));
        expect(
          pair.fake.findWorkflowInAnyWorkspace(workflowId).id,
          workflowId,
        );
      }
      await pumpEventQueue();
      pair.nodeBacked.dispose();
    }
  });
}
