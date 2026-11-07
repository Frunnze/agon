import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/workflow_problems.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import '../../support/random_workflows.dart';

const int _requestNumberSpan = 1000;
const int _workflowNumberSpan = 50;

const List<String> _blankTasks = <String>[
  '',
  ' ',
  '\t\n',
  '\u00A0',
  '\u3000 ',
];

String _randomRequest(Random random) {
  final String phrase = randomWordPhrase(random);
  final int number = random.nextInt(_requestNumberSpan);
  return 'Request $phrase $number';
}

WorkflowAgent _withTask(WorkflowAgent agent, String task) {
  return WorkflowAgent(
    id: agent.id,
    name: agent.name,
    stepKind: agent.stepKind,
    kind: agent.kind,
    task: task,
    runsOn: agent.runsOn,
    skills: agent.skills,
    usesAutomaticSkills: agent.usesAutomaticSkills,
    approvalPolicy: agent.approvalPolicy,
    position: agent.position,
  );
}

void main() {
  test('test_append_requested_agent_property_adds_one_fresh_agent_for_'
      'the_request', () {
    final Random random = seededRandom(68601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final String request = _randomRequest(random);
      final Workflow changed = appendRequestedAgent(workflow, request);
      final WorkflowAgent requested = changed.agents.last;
      final Set<WorkflowAgentId> oldIds = <WorkflowAgentId>{
        for (final WorkflowAgent agent in workflow.agents) agent.id,
      };
      final Set<String> oldNames = <String>{
        for (final WorkflowAgent agent in workflow.agents) agent.name,
      };

      expect(
        changed.agents.sublist(0, workflow.agents.length),
        workflow.agents,
      );
      expect(oldIds.contains(requested.id), isFalse);
      expect(oldNames.contains(requested.name), isFalse);
      expect(describeNameProblem(requested.name), isNull);
      expect(requested.task, request);
      expect(requested.kind, fakeDrafterKind);
      expect(requested.stepKind, StepKind.agent);
    }
  });

  test('test_append_requested_agent_property_keeps_valid_workflows_'
      'valid', () {
    final Random random = seededRandom(68602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      if (describeWorkflowProblem(workflow) != null) {
        continue;
      }
      final Workflow changed = appendRequestedAgent(
        workflow,
        _randomRequest(random),
      );

      expect(describeWorkflowProblem(changed), isNull);
      expect(
        changed.connections.sublist(0, workflow.connections.length),
        workflow.connections,
      );
    }
  });

  test('test_append_requested_agent_property_every_step_leads_to_the_'
      'request', () {
    final Random random = seededRandom(68603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomBranchingWorkflow(random);
      final Workflow changed = appendRequestedAgent(
        workflow,
        _randomRequest(random),
      );
      final WorkflowAgentId requestedId = changed.agents.last.id;

      for (final WorkflowAgent agent in workflow.agents) {
        final bool leadsToRequest = hasForwardPath(
          changed,
          from: agent.id,
          to: requestedId,
        );
        expect(leadsToRequest, isTrue, reason: agent.name);
      }
    }
  });

  test('test_fill_in_agent_property_keeps_a_written_task', () {
    final Random random = seededRandom(68604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgent agent = randomAgent(random, i);
      final String task = _randomRequest(random);
      final WorkflowAgent filled = fillInAgent(_withTask(agent, task), 'flow');

      expect(filled.task, task);
    }
  });

  test('test_fill_in_agent_property_blank_task_names_the_step_and_'
      'workflow', () {
    final Random random = seededRandom(68605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgent agent = _withTask(
        randomAgent(random, i),
        pickOne(random, _blankTasks),
      );
      final String workflowName =
          'flow-${random.nextInt(_workflowNumberSpan)}';
      final WorkflowAgent filled = fillInAgent(agent, workflowName);

      expect(filled.task.trim(), isNotEmpty);
      expect(filled.task, contains(agent.name));
      expect(filled.task, contains(workflowName));
    }
  });

  test('test_fill_in_agent_property_is_idempotent_and_keeps_the_rest', () {
    final Random random = seededRandom(68606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowAgent agent = randomAgent(random, i);
      final WorkflowAgent filled = fillInAgent(agent, 'flow');

      expect(fillInAgent(filled, 'flow'), filled);
      expect(filled.kind, agent.kind ?? fakeDrafterKind);
      expect(filled.id, agent.id);
      expect(filled.name, agent.name);
      expect(filled.position, agent.position);
      expect(filled.runsOn, agent.runsOn);
      expect(filled.skills, agent.skills);
      expect(filled.stepKind, agent.stepKind);
    }
  });
}
