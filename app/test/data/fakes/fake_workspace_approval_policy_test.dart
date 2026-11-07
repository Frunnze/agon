import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/fake_task_work_links.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';

FakeWorkspaceRepository _buildWorkspaceRepository() {
  return FakeWorkspaceRepository(
    workspaces: galleryWorkspaces,
    currentWorkspaceId: GalleryWorkspaceIds.acme,
    appServerStatus: galleryAppServerStatus,
    appServerGroup: galleryAppServerGroup,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    clock: FixedClock(galleryNow),
  );
}

void main() {
  test('test_change_approval_policy_property_only_that_workspace', () async {
    final Random random = seededRandom(9801);
    final FakeWorkspaceRepository repository = _buildWorkspaceRepository();
    int notificationCount = 0;
    repository.addListener(() => notificationCount += 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace target = pickOne(random, repository.listWorkspaces());
      final ApprovalPolicy chosen = pickOne(random, ApprovalPolicy.values);
      final List<Workspace> before = repository.listWorkspaces();

      final Workspace changed = await repository.changeApprovalPolicy(
        workspaceId: target.id,
        approvalPolicy: chosen,
      );

      expect(changed.id, target.id);
      expect(changed.name, target.name);
      expect(changed.approvalPolicy, chosen);
      expect(notificationCount, i + 1);
      for (final Workspace workspace in repository.listWorkspaces()) {
        final Workspace earlier = before.firstWhere(
          (Workspace candidate) => candidate.id == workspace.id,
        );
        final ApprovalPolicy expected = workspace.id == target.id
            ? chosen
            : earlier.approvalPolicy;
        expect(workspace.approvalPolicy, expected);
      }
    }
  });

  test('test_change_approval_policy_property_unknown_ids_rejected', () async {
    final Random random = seededRandom(9802);
    final FakeWorkspaceRepository repository = _buildWorkspaceRepository();

    for (int i = 0; i < propertyIterations; i += 1) {
      await expectLater(
        repository.changeApprovalPolicy(
          workspaceId: WorkspaceId('unknown-${randomText(random)}'),
          approvalPolicy: pickOne(random, ApprovalPolicy.values),
        ),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('test_create_project_property_keeps_the_chosen_policy', () async {
    final Random random = seededRandom(9803);
    final FakeProjectRepository repository = FakeProjectRepository(
      projects: galleryProjects,
      taskWork: buildEmptyTaskWork(),
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalPolicy? chosen = randomInheritableApprovalPolicy(random);

      final Project created = await repository.createProject(
        ProjectDraft(
          workspaceId: GalleryWorkspaceIds.acme,
          name: 'project-$i',
          repositories: const <Repository>[],
          approvalPolicy: chosen,
        ),
      );

      expect(created.approvalPolicy, chosen);
      expect(repository.findProject(created.id).approvalPolicy, chosen);
    }
  });
}
