import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/memory_workspace_choice_store.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'support/simulated_catalog_node.dart';

const int _workspaceCount = 3;

NodeBackedWorkspaceRepository _buildWorkspaces(
  SimulatedCatalogNode simulated,
) {
  return NodeBackedWorkspaceRepository(
    channel: simulated.channel,
    clock: FixedClock(DateTime.utc(2026, 11, 4)),
    retryInterval: const Duration(seconds: 30),
    choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
  );
}

SimulatedCatalogNode _buildNodeWithWorkspaces() {
  final SimulatedCatalogNode simulated = SimulatedCatalogNode(
    hasAccount: true,
  );
  for (int i = 0; i < _workspaceCount; i += 1) {
    simulated.addWorkspace('workspace-$i');
  }
  return simulated;
}

String? _readNodePolicyName(Map<String, Object?> record) {
  return record['approval_policy'] as String?;
}

void main() {
  test('test_load_property_workspace_without_policy_reads_auto', () async {
    final SimulatedCatalogNode simulated = _buildNodeWithWorkspaces();
    final NodeBackedWorkspaceRepository repository = _buildWorkspaces(
      simulated,
    );

    await repository.load();

    for (final Workspace workspace in repository.listWorkspaces()) {
      expect(workspace.approvalPolicy, ApprovalPolicy.neverAsk);
    }
    repository.dispose();
  });

  test('test_change_approval_policy_property_node_and_list_agree', () async {
    final Random random = seededRandom(9851);
    final SimulatedCatalogNode simulated = _buildNodeWithWorkspaces();
    final NodeBackedWorkspaceRepository repository = _buildWorkspaces(
      simulated,
    );
    await repository.load();
    int notificationCount = 0;
    repository.addListener(() => notificationCount += 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int index = random.nextInt(_workspaceCount);
      final Workspace target = repository.listWorkspaces()[index];
      final ApprovalPolicy chosen = pickOne(random, ApprovalPolicy.values);

      final Workspace changed = await repository.changeApprovalPolicy(
        workspaceId: target.id,
        approvalPolicy: chosen,
      );

      expect(changed.id, target.id);
      expect(changed.approvalPolicy, chosen);
      expect(repository.listWorkspaces()[index].approvalPolicy, chosen);
      expect(
        _readNodePolicyName(simulated.workspaces[index]),
        mapApprovalPolicyToNode(chosen).wireName,
      );
      expect(notificationCount, i + 1);
    }
    repository.dispose();
  });

  test('test_change_approval_policy_property_unknown_ids_rejected', () async {
    final Random random = seededRandom(9852);
    final SimulatedCatalogNode simulated = _buildNodeWithWorkspaces();
    final NodeBackedWorkspaceRepository repository = _buildWorkspaces(
      simulated,
    );
    await repository.load();

    for (int i = 0; i < propertyIterations; i += 1) {
      await expectLater(
        repository.changeApprovalPolicy(
          workspaceId: WorkspaceId('missing-$i'),
          approvalPolicy: pickOne(random, ApprovalPolicy.values),
        ),
        throwsA(isA<RecordNotFound>()),
      );
    }
    repository.dispose();
  });

  test('test_create_project_property_sends_the_chosen_policy', () async {
    final Random random = seededRandom(9853);
    final SimulatedCatalogNode simulated = _buildNodeWithWorkspaces();
    final NodeBackedWorkspaceRepository workspaces = _buildWorkspaces(
      simulated,
    );
    final NodeBackedProjectRepository projects = NodeBackedProjectRepository(
      channel: simulated.channel,
      workspaceRepository: workspaces,
    );
    await workspaces.load();
    await projects.load();

    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalPolicy? chosen = randomInheritableApprovalPolicy(random);

      final Project created = await projects.createProject(
        ProjectDraft(
          workspaceId: workspaces.currentWorkspace().id,
          name: 'project-$i',
          repositories: const <Repository>[],
          approvalPolicy: chosen,
        ),
      );

      expect(created.approvalPolicy, chosen);
      expect(
        _readNodePolicyName(simulated.projects.last),
        mapOptionalApprovalPolicyToNode(chosen)?.wireName,
      );
    }
    projects.dispose();
    workspaces.dispose();
  });
}
