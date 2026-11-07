import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes/fake_workflow_checks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';

import '../../support/random_inputs.dart';
import 'support/missing_record_matchers.dart';
import 'support/workflow_inputs.dart';

void main() {
  test('test_find_workflow_in_property_finds_every_listed_workflow', () {
    final Random random = seededRandom(78401);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> workflows = randomSeededWorkflows(random);
      for (final Workflow workflow in workflows) {
        expect(findWorkflowIn(workflows, workflow.id), same(workflow));
      }
    }
  });

  test('test_find_workflow_in_property_missing_names_the_workflow', () {
    final Random random = seededRandom(78402);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String missing = 'missing-${randomText(random)}';
      expect(
        () =>
            findWorkflowIn(randomSeededWorkflows(random), WorkflowId(missing)),
        throwsMissingRecord(workflowKind, missing),
      );
    }
  });

  test('test_find_workflow_in_property_first_match_wins', () {
    final Random random = seededRandom(78403);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow first = randomValidWorkflow(
        random,
        index: 0,
        signature: null,
      );
      final Workflow second = first.withName('second');

      expect(findWorkflowIn(<Workflow>[first, second], first.id), same(first));
    }
  });

  test('test_find_change_of_listed_property_hidden_workflows_have_no_'
      'change', () {
    final Random random = seededRandom(78404);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> workflows = randomSeededWorkflows(random);
      final List<WorkflowChange> changes = randomChangesFor(random, workflows);
      for (final WorkflowChange change in changes) {
        expect(
          findChangeOfListed(
            changes: changes,
            listedWorkflows: const <Workflow>[],
            workflowId: change.workflowId,
          ),
          isNull,
        );
      }
    }
  });

  test('test_find_change_of_listed_property_listed_workflows_keep_their_'
      'change', () {
    final Random random = seededRandom(78405);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> workflows = randomSeededWorkflows(random);
      final List<WorkflowChange> changes = randomChangesFor(random, workflows);
      for (final Workflow workflow in workflows) {
        expect(
          findChangeOfListed(
            changes: changes,
            listedWorkflows: workflows,
            workflowId: workflow.id,
          ),
          same(findChangeOf(changes, workflow.id)),
        );
      }
    }
  });

  test('test_find_change_of_listed_property_no_changes_means_none', () {
    final Random random = seededRandom(78406);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workflow> workflows = randomSeededWorkflows(random);
      for (final Workflow workflow in workflows) {
        expect(
          findChangeOfListed(
            changes: const <WorkflowChange>[],
            listedWorkflows: workflows,
            workflowId: workflow.id,
          ),
          isNull,
        );
      }
    }
  });

  test('test_refuse_missing_change_property_missing_change_is_not_found', () {
    final Random random = seededRandom(78407);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String identifier = randomText(random);
      expect(
        () => refuseMissingChange(null, WorkflowId(identifier)),
        throwsMissingRecord(workflowChangeKind, identifier),
      );
    }
  });

  test('test_refuse_missing_change_property_present_change_passes', () {
    final Random random = seededRandom(78408);
    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowId workflowId = WorkflowId(randomText(random));
      refuseMissingChange(buildSampleChange(workflowId), workflowId);
    }
  });

  test('test_refuse_missing_change_property_any_change_passes_for_any_'
      'id', () {
    final Random random = seededRandom(78409);
    for (int i = 0; i < propertyIterations; i += 1) {
      refuseMissingChange(
        buildSampleChange(WorkflowId(randomText(random))),
        WorkflowId(randomText(random)),
      );
    }
  });
}
