import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/fakes/fake_workflow_checks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/missing_record_matchers.dart';
import 'support/workflow_inputs.dart';
import 'support/workspace_inputs.dart';
import 'support/workspace_scope_inputs.dart';
import 'support/workspace_workflow_inputs.dart';

const String _typePrefix = 'test_fake_workflow_repository';

typedef _Seeded = ({
  FakeWorkflowRepository repository,
  FakeWorkspaceRepository workspaces,
  List<WorkspaceId> workspaceIds,
  List<Workflow> workflows,
  List<WorkflowChange> changes,
});

_Seeded _seed(Random random) {
  final SeededWorkspaces workspaces = seedRandomWorkspaces(random);
  final List<WorkspaceId> workspaceIds = listWorkspaceIds(
    workspaces.workspaces,
  );
  final List<Workflow> workflows = randomWorkflowsAvailableOver(
    random,
    workspaceIds,
  );
  final List<WorkflowChange> changes = randomChangesFor(random, workflows);
  return (
    repository: buildWorkflowRepositoryIn(
      workflows: workflows,
      changes: changes,
      workspaceRepository: workspaces.repository,
    ),
    workspaces: workspaces.repository,
    workspaceIds: workspaceIds,
    workflows: workflows,
    changes: changes,
  );
}

bool _isListed(_Seeded seeded, WorkflowId workflowId) {
  return seeded.repository.listWorkflows().any(
    (Workflow workflow) => workflow.id == workflowId,
  );
}

void main() {
  test('${_typePrefix}_find_workflow_in_any_workspace_property_finds_every_'
      'seed_anywhere', () async {
    final Random random = seededRandom(78410);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _Seeded seeded = _seed(random);
      await seeded.workspaces.switchWorkspace(
        pickOne(random, seeded.workspaceIds),
      );
      for (final Workflow workflow in seeded.workflows) {
        expect(
          seeded.repository.findWorkflowInAnyWorkspace(workflow.id),
          same(workflow),
        );
      }
    }
  });

  test('${_typePrefix}_find_workflow_in_any_workspace_property_missing_is_'
      'not_found', () {
    final Random random = seededRandom(78411);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String missing = 'missing-${randomText(random)}';
      expect(
        () =>
            _seed(random).repository
                .findWorkflowInAnyWorkspace(WorkflowId(missing)),
        throwsMissingRecord(workflowKind, missing),
      );
    }
  });

  test('${_typePrefix}_find_workflow_in_any_workspace_property_deleted_'
      'workflows_leave', () async {
    final Random random = seededRandom(78412);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _Seeded seeded = _seed(random);
      if (seeded.workflows.isEmpty) {
        continue;
      }
      final Workflow doomed = pickOne(random, seeded.workflows);

      await seeded.repository.deleteWorkflow(doomed.id);

      expect(
        () => seeded.repository.findWorkflowInAnyWorkspace(doomed.id),
        throwsA(isA<RecordNotFound>()),
      );
      expect(
        seeded.repository.findPendingChangeInAnyWorkspace(doomed.id),
        isNull,
      );
    }
  });

  test('${_typePrefix}_find_pending_change_in_any_workspace_property_keeps_'
      'every_seeded_change', () async {
    final Random random = seededRandom(78413);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _Seeded seeded = _seed(random);
      await seeded.workspaces.switchWorkspace(
        pickOne(random, seeded.workspaceIds),
      );
      for (final WorkflowChange change in seeded.changes) {
        expect(
          seeded.repository.findPendingChangeInAnyWorkspace(change.workflowId),
          same(change),
        );
      }
    }
  });

  test('${_typePrefix}_find_pending_change_in_any_workspace_property_'
      'unchanged_workflows_have_none', () {
    final Random random = seededRandom(78414);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _Seeded seeded = _seed(random);
      final Set<WorkflowId> changed = <WorkflowId>{
        for (final WorkflowChange change in seeded.changes) change.workflowId,
      };
      for (final Workflow workflow in seeded.workflows) {
        if (!changed.contains(workflow.id)) {
          expect(
            seeded.repository.findPendingChangeInAnyWorkspace(workflow.id),
            isNull,
          );
        }
      }
    }
  });

  test('${_typePrefix}_find_pending_change_in_any_workspace_property_is_a_'
      'superset_of_the_listed_view', () async {
    final Random random = seededRandom(78415);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _Seeded seeded = _seed(random);
      await seeded.workspaces.switchWorkspace(
        pickOne(random, seeded.workspaceIds),
      );
      for (final Workflow workflow in seeded.workflows) {
        final WorkflowChange? listed = seeded.repository.findPendingChange(
          workflow.id,
        );
        if (listed != null) {
          expect(
            seeded.repository.findPendingChangeInAnyWorkspace(workflow.id),
            same(listed),
          );
        }
      }
    }
  });

  test('${_typePrefix}_find_pending_change_property_only_listed_workflows_'
      'show_a_change', () async {
    final Random random = seededRandom(78416);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _Seeded seeded = _seed(random);
      await seeded.workspaces.switchWorkspace(
        pickOne(random, seeded.workspaceIds),
      );
      for (final WorkflowChange change in seeded.changes) {
        expect(
          seeded.repository.findPendingChange(change.workflowId),
          _isListed(seeded, change.workflowId) ? same(change) : isNull,
        );
      }
    }
  });

  test('${_typePrefix}_find_pending_change_property_follows_the_current_'
      'workspace', () async {
    final Random random = seededRandom(78417);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _Seeded seeded = _seed(random);
      for (final WorkspaceId workspaceId in seeded.workspaceIds) {
        await seeded.workspaces.switchWorkspace(workspaceId);
        for (final WorkflowChange change in seeded.changes) {
          final Workflow workflow = seeded.repository
              .findWorkflowInAnyWorkspace(change.workflowId);
          final bool isUsable = isModelUsableInWorkspace(
            workflow.availability,
            workspaceId,
          );
          expect(
            seeded.repository.findPendingChange(change.workflowId) != null,
            isUsable,
          );
        }
      }
    }
  });

  test('${_typePrefix}_delete_workflow_property_deletes_hidden_'
      'workflows', () async {
    final Random random = seededRandom(78418);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _Seeded seeded = _seed(random);
      final List<Workflow> hidden = <Workflow>[
        for (final Workflow workflow in seeded.workflows)
          if (!_isListed(seeded, workflow.id)) workflow,
      ];
      if (hidden.isEmpty) {
        continue;
      }
      final Workflow doomed = pickOne(random, hidden);
      final List<Workflow> listedBefore = seeded.repository.listWorkflows();

      await seeded.repository.deleteWorkflow(doomed.id);

      expect(seeded.repository.listWorkflows(), orderedEquals(listedBefore));
      expect(
        () => seeded.repository.findWorkflowInAnyWorkspace(doomed.id),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('${_typePrefix}_delete_workflow_property_unknown_is_not_found', () {
    final Random random = seededRandom(78419);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String missing = 'missing-${randomText(random)}';
      expect(
        _seed(random).repository.deleteWorkflow(WorkflowId(missing)),
        throwsMissingRecord(workflowKind, missing),
      );
    }
  });
}
