import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/simulated_workflow_node.dart';
import 'support/workflow_repository_harness.dart';

const int _draftIterations = 30;
const List<String> _states = <String>[
  signedState,
  changedState,
  unsignedState,
];

List<String> _listNodeWorkflowIds(SimulatedWorkflowNode simulated) {
  return <String>[
    for (final Map<String, Object?> view in simulated.views)
      (view['workflow'] as Map<String, Object?>)['id'] as String,
  ];
}

void _expectMirrorsNode(
  NodeBackedWorkflowRepository repository,
  SimulatedWorkflowNode simulated,
) {
  expect(<String>[
    for (final Workflow workflow in repository.listWorkflows())
      workflow.id.value,
  ], _listNodeWorkflowIds(simulated));
  for (final Map<String, Object?> view in simulated.views) {
    final String workflowId =
        (view['workflow'] as Map<String, Object?>)['id'] as String;
    final WorkflowChange? change = repository.findPendingChange(
      WorkflowId(workflowId),
    );
    expect(change != null, view['signature_state'] == changedState);
  }
}

const Map<AgentKind, String> _agentWireNames = <AgentKind, String>{
  AgentKind.claudeCode: 'claude_code',
  AgentKind.codex: 'codex',
  AgentKind.geminiCli: 'gemini_cli',
};

void main() {
  test('test_load_property_mirrors_node_workflows_and_changes', () async {
    final Random random = seededRandom(9901);
    for (int i = 0; i < _draftIterations; i += 1) {
      final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
        pollsBeforeDraftIsDone: 0,
      );
      final int count = random.nextInt(5);
      for (int j = 0; j < count; j += 1) {
        simulated.addWorkflow(
          name: 'flow-$j',
          state: pickOne(random, _states),
        );
      }
      final NodeBackedWorkflowRepository repository =
          buildSimulatedWorkflowRepository(simulated);
      await repository.load();
      _expectMirrorsNode(repository, simulated);
      repository.dispose();
    }
  });

  test('test_sign_workflow_property_change_waits_until_signed', () async {
    final Random random = seededRandom(9902);
    final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
      pollsBeforeDraftIsDone: 0,
    );
    for (int j = 0; j < 3; j += 1) {
      simulated.addWorkflow(name: 'flow-$j', state: pickOne(random, _states));
    }
    final NodeBackedWorkflowRepository repository =
        buildSimulatedWorkflowRepository(simulated);
    await repository.load();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = pickOne(random, repository.listWorkflows());
      switch (random.nextInt(4)) {
        case 0:
          final Workflow saved = await repository.saveWorkflow(workflow);
          expect(saved.id, workflow.id);
        case 1:
          final Workflow signed = await repository.signWorkflow(workflow.id);
          expect(signed.signature?.signedBy.value, simulatedSignerId);
          expect(repository.findPendingChange(workflow.id), isNull);
        case 2:
          if (repository.findPendingChange(workflow.id) == null) {
            await expectLater(
              repository.discardChange(workflow.id),
              throwsA(isA<RecordNotFound>()),
            );
          } else {
            await repository.discardChange(workflow.id);
            expect(repository.findPendingChange(workflow.id), isNull);
          }
        case 3:
          simulated.addWorkflow(name: 'remote-$i', state: changedState);
          await repository.applyChange(
            const node.AreaChanged(area: node.ChangeArea.workflows),
          );
      }
      _expectMirrorsNode(repository, simulated);
    }
    await expectLater(
      repository.signWorkflow(const WorkflowId('missing')),
      throwsA(isA<RecordNotFound>()),
    );
    repository.dispose();
  });

  test('test_draft_workflow_property_ends_with_a_listed_workflow', () async {
    final Random random = seededRandom(9903);
    for (int i = 0; i < _draftIterations; i += 1) {
      final int polls = random.nextInt(4);
      final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
        pollsBeforeDraftIsDone: polls,
      );
      final NodeBackedWorkflowRepository repository =
          buildSimulatedWorkflowRepository(simulated);
      await repository.load();

      final List<WorkflowDraftProgress> progress = await repository
          .draftWorkflow(const WorkflowDraft(description: 'Ship the site'))
          .toList();

      expect(progress.length, polls + 1);
      expect(progress.last.isFinished, isTrue);
      for (final WorkflowDraftProgress step in progress) {
        expect(step.drafterDeviceId.value, simulatedDrafterId);
        expect(step.drafterKind, AgentKind.claudeCode);
      }
      for (final WorkflowDraftProgress step in progress.sublist(0, polls)) {
        expect(step.isFinished, isFalse);
        expect(step.workflow.agents, isEmpty);
      }
      final Workflow drafted = progress.last.workflow;
      expect(drafted.name, isNotEmpty);
      expect(repository.findWorkflow(drafted.id).name, drafted.name);
      expect(simulated.draftStatusPollCount, polls + 1);
      _expectMirrorsNode(repository, simulated);
      repository.dispose();
    }
  });

  test('test_change_workflow_property_returns_the_redrafted_graph', () async {
    final Random random = seededRandom(9905);
    final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
      pollsBeforeDraftIsDone: 1,
    );
    simulated.addWorkflow(name: 'flow', state: signedState);
    final NodeBackedWorkflowRepository repository =
        buildSimulatedWorkflowRepository(simulated);
    await repository.load();
    final WorkflowId workflowId = repository.listWorkflows().single.id;

    for (int i = 0; i < _draftIterations; i += 1) {
      final Workflow before = repository.findWorkflow(workflowId);
      if (random.nextBool()) {
        final AgentKind agent = pickOne(random, AgentKind.values);
        final Workflow changed = await repository.changeWorkflow(
          workflowId,
          'Add a review step $i',
          agent,
        );
        expect(changed.agents.length, before.agents.length + 1);
        expect(simulated.changeAgents.last, _agentWireNames[agent]);
      } else {
        final WorkflowAgent agent = pickOne(random, before.agents);
        final Workflow filled = await repository.fillAgentSettings(
          workflowId,
          agent.id,
        );
        expect(filled.findAgent(agent.id).kind, AgentKind.codex);
      }
      expect(repository.findPendingChange(workflowId), isNotNull);
      _expectMirrorsNode(repository, simulated);
    }
    await expectLater(
      repository.changeWorkflow(workflowId, '   ', AgentKind.codex),
      throwsArgumentError,
    );
    repository.dispose();
  });

  test('test_change_workflow_property_blank_never_reaches_node', () async {
    final Random random = seededRandom(9906);
    final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
      pollsBeforeDraftIsDone: 1,
    );
    simulated.addWorkflow(name: 'flow', state: signedState);
    final NodeBackedWorkflowRepository repository =
        buildSimulatedWorkflowRepository(simulated);
    await repository.load();
    final WorkflowId workflowId = repository.listWorkflows().single.id;

    for (int i = 0; i < _draftIterations; i += 1) {
      final String blank = ' ' * random.nextInt(5);

      await expectLater(
        repository.changeWorkflow(
          workflowId,
          blank,
          pickOne(random, AgentKind.values),
        ),
        throwsArgumentError,
      );

      expect(simulated.changeAgents, isEmpty);
    }
    repository.dispose();
  });

  test('test_change_workflow_property_a_refusal_leaves_the_workflow', () async {
    final Random random = seededRandom(9907);
    final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
      pollsBeforeDraftIsDone: 1,
    );
    simulated.addWorkflow(name: 'flow', state: signedState);
    simulated.failingCommands.add('change_workflow');
    final NodeBackedWorkflowRepository repository =
        buildSimulatedWorkflowRepository(simulated);
    await repository.load();
    final WorkflowId workflowId = repository.listWorkflows().single.id;

    for (int i = 0; i < _draftIterations; i += 1) {
      final Workflow before = repository.findWorkflow(workflowId);

      await expectLater(
        repository.changeWorkflow(
          workflowId,
          'Add a review step $i',
          pickOne(random, AgentKind.values),
        ),
        throwsStateError,
      );

      final Workflow after = repository.findWorkflow(workflowId);
      expect(after.agents.length, before.agents.length);
      expect(repository.findPendingChange(workflowId), isNull);
    }
    repository.dispose();
  });
}
