import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/screens/workflows/workflow_text.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/simulated_workflow_node.dart';
import '../node_backed/support/workflow_repository_harness.dart';
import 'support/refusals.dart';
import 'support/workflow_inputs.dart';

const int _sequenceIterations = 30;
const int _longestSequence = 8;
const int _largestSeededCount = 3;
const WorkflowId _missingWorkflowId = WorkflowId('workflow-missing');

typedef _Pair = ({
  FakeWorkflowRepository fake,
  NodeBackedWorkflowRepository nodeBacked,
});

enum _Operation { save, sign, discard, delete, change, fill }

typedef _PlannedStep = ({_Operation operation, int at, int agentAt});

bool _isWorkflowRefusal(Object error) {
  return error is StateError ||
      error is ArgumentError ||
      error is RecordNotFound;
}

String _describeWorkflow(WorkflowRepository repository, Workflow workflow) {
  final WorkflowChange? change = repository.findPendingChange(workflow.id);
  final SignatureState state = findSignatureState(workflow, change);
  return '${workflow.id.value} ${workflow.agents.length} $state';
}

List<String> _describeListing(WorkflowRepository repository) {
  return <String>[
    for (final Workflow workflow in repository.listWorkflows())
      _describeWorkflow(repository, workflow),
  ];
}

Future<_Pair> _buildPair(Random random) async {
  final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
    pollsBeforeDraftIsDone: 1,
  );
  final int seededCount = random.nextInt(_largestSeededCount + 1);
  for (int i = 0; i < seededCount; i += 1) {
    simulated.addWorkflow(
      name: 'seeded-$i',
      state: pickOne(random, <String>[signedState, unsignedState]),
    );
  }
  final NodeBackedWorkflowRepository nodeBacked =
      buildSimulatedWorkflowRepository(simulated);
  await nodeBacked.load();
  final List<Workflow> loaded = nodeBacked.listWorkflows();
  final FakeWorkflowRepository fake = buildWorkflowRepository(
    workflows: loaded,
    changes: const <WorkflowChange>[],
  );
  return (fake: fake, nodeBacked: nodeBacked);
}

WorkflowId _pickWorkflowId(WorkflowRepository repository, int at) {
  final List<Workflow> listed = repository.listWorkflows();
  if (at >= listed.length) {
    return _missingWorkflowId;
  }
  return listed[at].id;
}

int _pickUnfilledAgent(Random random, FakeWorkflowRepository fake, int at) {
  final WorkflowId workflowId = _pickWorkflowId(fake, at);
  if (workflowId == _missingWorkflowId) {
    return 0;
  }
  final List<WorkflowAgent> agents = fake.findWorkflow(workflowId).agents;
  final List<int> unfilled = <int>[
    for (int index = 0; index < agents.length; index += 1)
      if (agents[index].kind == null || agents[index].task.trim().isEmpty)
        index,
  ];
  if (unfilled.isEmpty) {
    return agents.length;
  }
  return pickOne(random, unfilled);
}

_PlannedStep _planStep(Random random, _Pair pair, _Operation focus) {
  final int at = random.nextInt(pair.fake.listWorkflows().length + 1);
  final _Operation operation = random.nextInt(3) == 0
      ? pickOne(random, _Operation.values)
      : focus;
  return (
    operation: operation,
    at: at,
    agentAt: _pickUnfilledAgent(random, pair.fake, at),
  );
}

WorkflowAgentId _pickAgentId(
  WorkflowRepository target,
  WorkflowId workflowId,
  int agentAt,
) {
  final List<WorkflowAgent> agents = target.findWorkflow(workflowId).agents;
  if (agentAt >= agents.length) {
    return const WorkflowAgentId('agent-missing');
  }
  return agents[agentAt].id;
}

Future<Object?> _applyStep(WorkflowRepository target, _PlannedStep step) {
  final WorkflowId workflowId = _pickWorkflowId(target, step.at);
  return switch (step.operation) {
    _Operation.save => target.saveWorkflow(
      addBlankStep(target.findWorkflow(workflowId)),
    ),
    _Operation.sign => target.signWorkflow(workflowId),
    _Operation.discard => target.discardChange(workflowId),
    _Operation.delete => target.deleteWorkflow(workflowId),
    _Operation.change => target.changeWorkflow(
      workflowId,
      'Add a review step',
      AgentKind.codex,
    ),
    _Operation.fill => target.fillAgentSettings(
      workflowId,
      _pickAgentId(target, workflowId, step.agentAt),
    ),
  };
}

Future<void> _checkAgreement({
  required _Operation focus,
  required int seed,
}) async {
  final Random random = seededRandom(seed);

  for (int i = 0; i < _sequenceIterations; i += 1) {
    final _Pair pair = await _buildPair(random);
    final int stepCount = 1 + random.nextInt(_longestSequence);

    for (int stepIndex = 0; stepIndex < stepCount; stepIndex += 1) {
      final _PlannedStep step = _planStep(random, pair, focus);
      final bool isFakeRefused = await isRefused(
        () async => _applyStep(pair.fake, step),
        isRefusal: _isWorkflowRefusal,
      );
      final bool isNodeRefused = await isRefused(
        () async => _applyStep(pair.nodeBacked, step),
        isRefusal: _isWorkflowRefusal,
      );

      expect(isFakeRefused, isNodeRefused, reason: '$step');
      expect(
        _describeListing(pair.fake),
        orderedEquals(_describeListing(pair.nodeBacked)),
        reason: '$step',
      );
    }
    pair.nodeBacked.dispose();
  }
}

void main() {
  test('test_save_workflow_property_agrees_with_the_node', () async {
    await _checkAgreement(focus: _Operation.save, seed: 67601);
  });

  test('test_sign_workflow_property_agrees_with_the_node', () async {
    await _checkAgreement(focus: _Operation.sign, seed: 67602);
  });

  test('test_discard_change_property_agrees_with_the_node', () async {
    await _checkAgreement(focus: _Operation.discard, seed: 67603);
  });

  test('test_delete_workflow_property_agrees_with_the_node', () async {
    await _checkAgreement(focus: _Operation.delete, seed: 67604);
  });

  test('test_change_workflow_property_agrees_with_the_node', () async {
    await _checkAgreement(focus: _Operation.change, seed: 67605);
  });

  test('test_fill_agent_settings_property_agrees_with_the_node', () async {
    await _checkAgreement(focus: _Operation.fill, seed: 67606);
  });
}
