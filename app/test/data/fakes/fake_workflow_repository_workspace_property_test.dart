import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/workflow_inputs.dart';
import 'support/workspace_inputs.dart';
import 'support/workspace_scope_inputs.dart';
import 'support/workspace_workflow_inputs.dart';

const String _typePrefix = 'test_fake_workflow_repository';

typedef _AvailableWorkflows = ({
  SeededWorkspaces workspaces,
  List<Workflow> seeded,
  FakeWorkflowRepository repository,
});

_AvailableWorkflows _buildAvailableWorkflows(Random random) {
  final SeededWorkspaces workspaces = seedRandomWorkspaces(random);
  final List<Workflow> seeded = randomWorkflowsAvailableOver(
    random,
    listWorkspaceIds(workspaces.workspaces),
  );
  return (
    workspaces: workspaces,
    seeded: seeded,
    repository: buildWorkflowRepositoryIn(
      workflows: seeded,
      changes: const <WorkflowChange>[],
      workspaceRepository: workspaces.repository,
    ),
  );
}

Future<WorkspaceId> _switchRandomly(
  Random random,
  _AvailableWorkflows available,
) async {
  final Workspace target = pickOne(random, available.workspaces.workspaces);
  final Workspace switched = await available.workspaces.repository
      .switchWorkspace(target.id);
  return switched.id;
}

void main() {
  test('${_typePrefix}_list_workflows_property_lists_only_workflows_'
      'available_in_the_current_workspace', () async {
    final Random random = seededRandom(91901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _AvailableWorkflows available = _buildAvailableWorkflows(random);
      final WorkspaceId current = await _switchRandomly(random, available);

      final List<Workflow> listed = available.repository.listWorkflows();

      expect(
        listWorkflowIds(listed),
        orderedEquals(predictWorkflowsListedIn(available.seeded, current)),
      );
      for (final Workflow workflow in listed) {
        expect(available.seeded, contains(same(workflow)));
      }
    }
  });

  test('${_typePrefix}_list_workflows_property_follows_every_switch_and_'
      'notifies_for_it', () async {
    final Random random = seededRandom(91902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _AvailableWorkflows available = _buildAvailableWorkflows(random);
      final NotificationCounter notifications = NotificationCounter();
      available.repository.addListener(notifications.record);
      final int switchCount = 1 + random.nextInt(4);

      for (int step = 0; step < switchCount; step += 1) {
        final WorkspaceId current = await _switchRandomly(random, available);
        expect(
          listWorkflowIds(available.repository.listWorkflows()),
          predictWorkflowsListedIn(available.seeded, current),
        );
      }

      expect(notifications.count, switchCount);
    }
  });

  test('${_typePrefix}_constructor_property_keeps_every_workflow_findable_'
      'whatever_the_current_workspace', () async {
    final Random random = seededRandom(91903);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _AvailableWorkflows available = _buildAvailableWorkflows(random);
      await _switchRandomly(random, available);

      for (final Workflow workflow in available.seeded) {
        expect(
          available.repository.findWorkflowInAnyWorkspace(workflow.id),
          same(workflow),
        );
      }
    }
  });

  test('${_typePrefix}_dispose_property_stops_following_the_workspace_'
      'repository', () async {
    final Random random = seededRandom(91904);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _AvailableWorkflows available = _buildAvailableWorkflows(random);
      final NotificationCounter notifications = NotificationCounter();
      available.repository.addListener(notifications.record);
      available.repository.removeListener(notifications.record);

      available.repository.dispose();
      await _switchRandomly(random, available);

      expect(notifications.count, 0);
    }
  });

  test('${_typePrefix}_dispose_property_leaves_the_workspace_repository_'
      'usable_for_other_listeners', () async {
    final Random random = seededRandom(91905);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _AvailableWorkflows available = _buildAvailableWorkflows(random);
      final NotificationCounter workspaceNotifications = NotificationCounter();
      available.workspaces.repository.addListener(
        workspaceNotifications.record,
      );

      available.repository.dispose();
      await _switchRandomly(random, available);

      expect(workspaceNotifications.count, 1);
    }
  });

  test('${_typePrefix}_list_workflows_property_created_workflow_is_listed_'
      'only_where_it_is_available', () async {
    final Random random = seededRandom(91906);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _AvailableWorkflows available = _buildAvailableWorkflows(random);
      final WorkspaceId current = await _switchRandomly(random, available);
      final Workflow template = randomValidWorkflow(
        random,
        index: i,
        signature: null,
      );
      final Workflow unsaved = withAvailability(
        template,
        randomWorkspaceScopeOver(
          random,
          listWorkspaceIds(available.workspaces.workspaces),
        ),
      );

      final Workflow created = await available.repository.createWorkflow(
        unsaved,
      );

      final bool isListed = available.repository.listWorkflows().any(
        (Workflow workflow) => workflow.id == created.id,
      );
      expect(
        isListed,
        isModelUsableInWorkspace(created.availability, current),
      );
    }
  });
}
