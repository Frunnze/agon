import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/workspace_inputs.dart';
import '../fakes/support/workspace_workflow_inputs.dart';
import 'support/simulated_workflow_node.dart';

const String _typePrefix = 'test_node_backed_workflow_repository';
const int _iterations = 40;
const int _largestSeededCount = 4;

typedef _Rig = ({
  SimulatedWorkflowNode simulated,
  NodeBackedWorkflowRepository repository,
  SeededWorkspaces workspaces,
});

Future<_Rig> _buildRig(Random random) async {
  final SeededWorkspaces workspaces = seedRandomWorkspaces(random);
  final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
    pollsBeforeDraftIsDone: 1,
  );
  final int count = 1 + random.nextInt(_largestSeededCount);
  for (int index = 0; index < count; index += 1) {
    simulated.addWorkflow(
      name: 'seeded-$index',
      state: pickOne(random, <String>[signedState, changedState]),
    );
  }
  final NodeBackedWorkflowRepository repository = NodeBackedWorkflowRepository(
    channel: simulated.channel,
    workspaceRepository: workspaces.repository,
    draftPollInterval: Duration.zero,
  );
  await repository.load();
  return (
    simulated: simulated,
    repository: repository,
    workspaces: workspaces,
  );
}

void _markInUse(SimulatedWorkflowNode simulated, WorkflowId workflowId) {
  simulated.tasks['task-using-${workflowId.value}'] = <String, Object?>{
    'id': 'task-using-${workflowId.value}',
    'doer': <String, Object?>{
      'kind': 'workflow',
      'workflow_id': workflowId.value,
    },
  };
}

Future<void> _close(_Rig rig) async {
  await pumpEventQueue();
  rig.repository.dispose();
}

void main() {
  test('${_typePrefix}_delete_workflow_property_drops_its_pending_'
      'change', () async {
    final Random random = seededRandom(78501);
    for (int i = 0; i < _iterations; i += 1) {
      final _Rig rig = await _buildRig(random);
      final Workflow doomed = pickOne(random, rig.repository.listWorkflows());

      await rig.repository.deleteWorkflow(doomed.id);

      expect(rig.repository.findPendingChange(doomed.id), isNull);
      expect(
        rig.repository.listWorkflows().map((Workflow listed) => listed.id),
        isNot(contains(doomed.id)),
      );
      await _close(rig);
    }
  });

  test('${_typePrefix}_delete_workflow_property_refusal_keeps_workflow_and_'
      'change', () async {
    final Random random = seededRandom(78502);
    for (int i = 0; i < _iterations; i += 1) {
      final _Rig rig = await _buildRig(random);
      final Workflow kept = pickOne(random, rig.repository.listWorkflows());
      final WorkflowChange? change = rig.repository.findPendingChange(kept.id);
      _markInUse(rig.simulated, kept.id);

      await expectLater(
        rig.repository.deleteWorkflow(kept.id),
        throwsStateError,
      );

      expect(rig.repository.findWorkflow(kept.id), same(kept));
      expect(rig.repository.findPendingChange(kept.id), same(change));
      await _close(rig);
    }
  });

  test('${_typePrefix}_delete_workflow_property_unlisted_workflow_leaves_the_'
      'listing', () async {
    final Random random = seededRandom(78503);
    for (int i = 0; i < _iterations; i += 1) {
      final _Rig rig = await _buildRig(random);
      final List<Workflow> before = rig.repository.listWorkflows();
      final WorkflowId unlisted = WorkflowId('unlisted-${randomText(random)}');

      await expectLater(
        rig.repository.deleteWorkflow(unlisted),
        throwsA(isA<RecordNotFound>()),
      );

      expect(rig.repository.listWorkflows(), orderedEquals(before));
      await _close(rig);
    }
  });

  test('${_typePrefix}_store_view_property_saved_workflow_that_stays_keeps_'
      'its_place', () async {
    final Random random = seededRandom(78504);
    for (int i = 0; i < _iterations; i += 1) {
      final _Rig rig = await _buildRig(random);
      final List<Workflow> before = rig.repository.listWorkflows();
      final int at = random.nextInt(before.length);

      final Workflow saved = await rig.repository.saveWorkflow(
        withAvailability(before[at], const AllWorkspaces()),
      );

      final List<Workflow> after = rig.repository.listWorkflows();
      expect(after.length, before.length);
      expect(after[at], same(saved));
      expect(rig.repository.findPendingChange(saved.id), isNotNull);
      await _close(rig);
    }
  });
}
