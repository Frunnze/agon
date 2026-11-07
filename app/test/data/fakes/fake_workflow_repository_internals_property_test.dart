import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_problems.dart';

import '../../support/random_inputs.dart';
import 'support/workflow_inputs.dart';

Workflow _withId(Workflow workflow, String identifier) {
  return Workflow(
    id: WorkflowId(identifier),
    name: workflow.name,
    availability: workflow.availability,
    agents: workflow.agents,
    connections: workflow.connections,
    signature: workflow.signature,
  );
}

Matcher _isRefusalNaming(Workflow workflow, String problem) {
  return isA<ArgumentError>()
      .having((ArgumentError error) => error.message, 'message', problem)
      .having(
        (ArgumentError error) => error.invalidValue,
        'invalidValue',
        workflow.name,
      );
}

void main() {
  test('test_identify_workflow_property_distinct_ids_are_accepted', () {
    final Random random = seededRandom(68401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);

      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: seeded,
        changes: const <WorkflowChange>[],
      );

      expect(repository.listWorkflows(), hasLength(seeded.length));
    }
  });

  test('test_identify_workflow_property_case_makes_ids_distinct', () {
    final Random random = seededRandom(68402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomValidWorkflow(
        random,
        index: i,
        signature: null,
      );
      final Workflow upper = _withId(workflow, 'FLOW-$i');
      final Workflow lower = _withId(workflow, 'flow-$i');

      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: <Workflow>[upper, lower],
        changes: const <WorkflowChange>[],
      );

      expect(repository.findWorkflow(upper.id), same(upper));
      expect(repository.findWorkflow(lower.id), same(lower));
    }
  });

  test('test_identify_workflow_property_names_may_repeat', () {
    final Random random = seededRandom(68403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomValidWorkflow(
        random,
        index: i,
        signature: null,
      );

      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: <Workflow>[
          _withId(workflow, 'first-$i'),
          _withId(workflow, 'second-$i'),
        ],
        changes: const <WorkflowChange>[],
      );

      expect(repository.listWorkflows(), hasLength(2));
    }
  });

  test('test_identify_changed_workflow_property_one_per_workflow', () {
    final Random random = seededRandom(68404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      final List<WorkflowChange> changes = randomChangesFor(random, seeded);

      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: seeded,
        changes: changes,
      );

      for (final WorkflowChange change in changes) {
        expect(repository.findPendingChange(change.workflowId), same(change));
      }
    }
  });

  test('test_identify_changed_workflow_property_repeats_refused', () {
    final Random random = seededRandom(68405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> seeded = randomSeededWorkflows(random);
      final List<WorkflowChange> changes = randomChangesFor(random, seeded);
      if (changes.isEmpty) {
        continue;
      }
      final WorkflowChange repeated = pickOne(random, changes);

      expect(
        () => buildWorkflowRepository(
          workflows: seeded,
          changes: <WorkflowChange>[...changes, repeated],
        ),
        throwsArgumentError,
      );
    }
  });

  test('test_identify_changed_workflow_property_message_names_it', () {
    final Random random = seededRandom(68406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowId workflowId = WorkflowId(
        'changed-${randomText(random)}',
      );

      expect(
        () => buildWorkflowRepository(
          workflows: const <Workflow>[],
          changes: <WorkflowChange>[
            buildSampleChange(workflowId),
            buildSampleChange(workflowId),
          ],
        ),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError error) => error.invalidValue,
            'invalidValue',
            workflowId.value,
          ),
        ),
      );
    }
  });

  test('test_refuse_workflow_problem_property_says_the_problem', () async {
    final Random random = seededRandom(68407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: const <Workflow>[],
        changes: const <WorkflowChange>[],
      );
      final Workflow broken = breakWorkflow(
        random,
        randomValidWorkflow(random, index: i, signature: null),
      );
      final String? problem = describeUploadProblem(broken);
      expect(problem, isNotNull);

      await expectLater(
        repository.createWorkflow(broken),
        throwsA(_isRefusalNaming(broken, problem ?? '')),
      );
    }
  });

  test(
    'test_refuse_workflow_problem_property_sign_says_graph_problem',
    () async {
      final Random random = seededRandom(68408);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Workflow broken = breakWorkflow(
          random,
          randomValidWorkflow(random, index: i, signature: null),
        );
        final String? problem = describeWorkflowProblem(broken);
        if (problem == null) {
          continue;
        }
        final FakeWorkflowRepository repository = buildWorkflowRepository(
          workflows: <Workflow>[broken],
          changes: const <WorkflowChange>[],
        );

        await expectLater(
          repository.signWorkflow(broken.id),
          throwsA(_isRefusalNaming(broken, problem)),
        );
      }
    },
  );

  test('test_refuse_workflow_problem_property_valid_ones_pass', () async {
    final Random random = seededRandom(68409);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow valid = randomValidWorkflow(
        random,
        index: i,
        signature: null,
      );
      final FakeWorkflowRepository repository = buildWorkflowRepository(
        workflows: <Workflow>[valid],
        changes: const <WorkflowChange>[],
      );

      await repository.saveWorkflow(valid);
      await repository.signWorkflow(valid.id);
      await repository.createWorkflow(valid);

      expect(repository.listWorkflows(), hasLength(2));
    }
  });
}
