import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes/fake_workflow_checks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/workflow_problems.dart';

import '../../support/random_inputs.dart';
import 'support/workflow_inputs.dart';

Workflow _randomWorkflow(Random random, int index) {
  return randomValidWorkflow(
    random,
    index: index,
    signature: random.nextBool() ? buildSampleSignature() : null,
  );
}

Workflow _withId(Workflow workflow, WorkflowId workflowId) {
  return Workflow(
    id: workflowId,
    name: workflow.name,
    availability: workflow.availability,
    agents: workflow.agents,
    connections: workflow.connections,
    signature: workflow.signature,
  );
}

WorkflowChange _randomChange(Random random, WorkflowId workflowId) {
  final WorkflowChange sample = buildSampleChange(workflowId);
  return WorkflowChange(
    workflowId: workflowId,
    changedBy: DeviceId(randomText(random)),
    changedAt: randomUtcMoment(random),
    summary: randomText(random),
    differences: sample.differences,
    signedDocument: randomText(random),
    changedDocument: randomText(random),
  );
}

Workflow _withoutSteps(Workflow workflow) {
  return workflow.withGraph(
    agents: const <WorkflowAgent>[],
    connections: const <AgentConnection>[],
  );
}

Matcher _throwsProblem(Workflow workflow, String problem) {
  return throwsA(
    isA<ArgumentError>()
        .having((ArgumentError error) => error.message, 'message', problem)
        .having((ArgumentError error) => error.name, 'name', 'workflow')
        .having(
          (ArgumentError error) => error.invalidValue,
          'invalidValue',
          workflow.name,
        ),
  );
}

void main() {
  test('test_identify_workflow_property_round_trips_the_id', () {
    final Random random = seededRandom(95161);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String identifier = randomText(random);
      final Workflow workflow = _withId(
        _randomWorkflow(random, i),
        WorkflowId(identifier),
      );

      expect(identifyWorkflow(workflow), identifier);
      expect(WorkflowId(identifyWorkflow(workflow)), workflow.id);
    }
  });

  test('test_identify_workflow_property_ignores_all_but_the_id', () {
    final Random random = seededRandom(95162);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow first = _randomWorkflow(random, i);
      final Workflow second = _withId(
        _withoutSteps(_randomWorkflow(random, i + 1)).withName('other'),
        first.id,
      );

      expect(identifyWorkflow(second), identifyWorkflow(first));
    }
  });

  test('test_identify_workflow_property_distinct_ids_stay_distinct', () {
    final Random random = seededRandom(95163);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow template = _randomWorkflow(random, i);
      final String firstIdentifier = randomText(random);
      final String secondIdentifier = '$firstIdentifier${randomText(random)}';
      final Workflow first = _withId(template, WorkflowId(firstIdentifier));
      final Workflow second = _withId(template, WorkflowId(secondIdentifier));

      expect(
        identifyWorkflow(first) == identifyWorkflow(second),
        firstIdentifier == secondIdentifier,
      );
    }
  });

  test('test_identify_changed_workflow_property_round_trips_the_id', () {
    final Random random = seededRandom(95164);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String identifier = randomText(random);
      final WorkflowChange change = _randomChange(
        random,
        WorkflowId(identifier),
      );

      expect(identifyChangedWorkflow(change), identifier);
    }
  });

  test('test_identify_changed_workflow_property_ignores_all_but_the_'
      'workflow', () {
    final Random random = seededRandom(95165);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowId workflowId = WorkflowId(randomText(random));

      expect(
        identifyChangedWorkflow(_randomChange(random, workflowId)),
        identifyChangedWorkflow(buildSampleChange(workflowId)),
      );
    }
  });

  test('test_identify_changed_workflow_property_matches_the_workflow_'
      'identity', () {
    final Random random = seededRandom(95166);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _withId(
        _randomWorkflow(random, i),
        WorkflowId(randomText(random)),
      );

      expect(
        identifyChangedWorkflow(_randomChange(random, workflow.id)),
        identifyWorkflow(workflow),
      );
    }
  });

  test('test_refuse_workflow_problem_property_no_problem_passes', () {
    final Random random = seededRandom(95167);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow valid = _randomWorkflow(random, i);
      final Workflow broken = breakWorkflow(random, valid);

      refuseWorkflowProblem(valid, null);
      refuseWorkflowProblem(broken, null);
    }
  });

  test('test_refuse_workflow_problem_property_says_problem_and_name', () {
    final Random random = seededRandom(95168);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _randomWorkflow(
        random,
        i,
      ).withName(randomText(random));
      final String problem = randomText(random);

      expect(
        () => refuseWorkflowProblem(workflow, problem),
        _throwsProblem(workflow, problem),
      );
    }
  });

  test('test_refuse_workflow_problem_property_any_given_problem_'
      'refuses', () {
    final Random random = seededRandom(95169);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow valid = _randomWorkflow(random, i);
      final String problem = pickOne(random, <String>['', ' ', '\n']);

      expect(
        () => refuseWorkflowProblem(valid, problem),
        _throwsProblem(valid, problem),
      );
    }
  });

  test('test_refuse_workflow_upload_problem_property_valid_ones_pass', () {
    final Random random = seededRandom(95170);

    for (int i = 0; i < propertyIterations; i += 1) {
      refuseWorkflowUploadProblem(_randomWorkflow(random, i));
    }
  });

  test('test_refuse_workflow_upload_problem_property_broken_ones_'
      'refused', () {
    final Random random = seededRandom(95171);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow broken = breakWorkflow(
        random,
        _randomWorkflow(random, i),
      );
      final String? nameProblem = describeNameProblem(broken.name);
      final String? graphProblem = describeWorkflowProblem(broken);
      final String? firstProblem = nameProblem ?? graphProblem;
      if (firstProblem == null) {
        fail('breakWorkflow left ${broken.name} without a problem');
      }

      expect(
        () => refuseWorkflowUploadProblem(broken),
        _throwsProblem(broken, firstProblem),
      );
    }
  });

  test('test_refuse_workflow_upload_problem_property_name_problem_'
      'comes_first', () {
    final Random random = seededRandom(95172);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String badName = pickOne(random, brokenWorkflowNames);
      final Workflow workflow = _withoutSteps(_randomWorkflow(random, i))
          .withName(badName);
      final Workflow wellNamed = _withoutSteps(_randomWorkflow(random, i));

      expect(
        () => refuseWorkflowUploadProblem(workflow),
        _throwsProblem(workflow, describeNameProblem(badName)!),
      );
      expect(
        () => refuseWorkflowUploadProblem(wellNamed),
        _throwsProblem(wellNamed, noAgentsProblem),
      );
    }
  });
}
