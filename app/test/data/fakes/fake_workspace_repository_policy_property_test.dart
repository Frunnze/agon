import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/notification_counter.dart';
import 'support/workspace_inputs.dart';

void main() {
  test('test_change_approval_policy_property_only_that_policy', () async {
    final Random random = seededRandom(68013);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Workspace target = pickOne(random, seeded.workspaces);
      final ApprovalPolicy policy = pickOne(random, ApprovalPolicy.values);

      final Workspace changed = await seeded.repository.changeApprovalPolicy(
        workspaceId: target.id,
        approvalPolicy: policy,
      );

      expect(changed.approvalPolicy, policy);
      expect(changed.protectedFiles, orderedEquals(target.protectedFiles));
      expect(changed.name, target.name);
      expectOtherWorkspacesUntouched(
        seeded.repository,
        seeded.workspaces,
        changed,
      );
    }
  });

  test('test_change_approval_policy_property_last_change_wins', () async {
    final Random random = seededRandom(68014);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Workspace target = pickOne(random, seeded.workspaces);
      final int changeCount = 1 + random.nextInt(4);
      ApprovalPolicy last = target.approvalPolicy;

      for (int change = 0; change < changeCount; change += 1) {
        last = pickOne(random, ApprovalPolicy.values);
        await seeded.repository.changeApprovalPolicy(
          workspaceId: target.id,
          approvalPolicy: last,
        );
      }

      final Workspace stored = seeded.repository.listWorkspaces().firstWhere(
        (Workspace workspace) => workspace.id == target.id,
      );
      expect(stored.approvalPolicy, last);
    }
  });

  test('test_change_approval_policy_property_unknown_ids_refused', () async {
    final Random random = seededRandom(68015);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);

      await expectLater(
        seeded.repository.changeApprovalPolicy(
          workspaceId: WorkspaceId('missing ${randomText(random)}'),
          approvalPolicy: pickOne(random, ApprovalPolicy.values),
        ),
        throwsA(isA<RecordNotFound>()),
      );
      expect(
        seeded.repository.listWorkspaces(),
        orderedEquals(seeded.workspaces),
      );
    }
  });

  test('test_store_changed_workspace_property_returns_the_stored', () async {
    final Random random = seededRandom(68016);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Workspace target = pickOne(random, seeded.workspaces);

      final Workspace changed = await seeded.repository.changeApprovalPolicy(
        workspaceId: target.id,
        approvalPolicy: pickOne(random, ApprovalPolicy.values),
      );

      expect(seeded.repository.listWorkspaces(), contains(same(changed)));
    }
  });

  test('test_store_changed_workspace_property_notifies_once', () async {
    final Random random = seededRandom(68017);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final NotificationCounter notifications = NotificationCounter();
      seeded.repository.addListener(notifications.record);
      final int changeCount = 1 + random.nextInt(4);

      for (int change = 0; change < changeCount; change += 1) {
        await seeded.repository.changeApprovalPolicy(
          workspaceId: pickOne(random, seeded.workspaces).id,
          approvalPolicy: pickOne(random, ApprovalPolicy.values),
        );
      }

      expect(notifications.count, changeCount);
    }
  });

  test('test_store_changed_workspace_property_keeps_the_order', () async {
    final Random random = seededRandom(68018);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final List<WorkspaceId> before = <WorkspaceId>[
        for (final Workspace workspace in seeded.workspaces) workspace.id,
      ];

      await seeded.repository.changeApprovalPolicy(
        workspaceId: pickOne(random, seeded.workspaces).id,
        approvalPolicy: pickOne(random, ApprovalPolicy.values),
      );

      final List<WorkspaceId> after = <WorkspaceId>[
        for (final Workspace workspace in seeded.repository.listWorkspaces())
          workspace.id,
      ];
      expect(after, orderedEquals(before));
    }
  });

  test('test_delete_workspace_property_never_the_last_one', () async {
    final Random random = seededRandom(68019);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace only = buildSampleWorkspace(random, i);
      final FakeWorkspaceRepository repository = buildWorkspaceRepository(
        workspaces: <Workspace>[only],
        currentWorkspaceId: only.id,
        appServerGroup: randomAppServerGroup(random),
      );

      await expectLater(repository.deleteWorkspace(only.id), throwsStateError);
      expect(repository.listWorkspaces().single, same(only));
      expect(repository.currentWorkspace(), same(only));
    }
  });

  test('test_delete_workspace_property_removes_exactly_one', () async {
    final Random random = seededRandom(68020);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      if (seeded.workspaces.length < 2) {
        continue;
      }
      final Workspace current = seeded.repository.currentWorkspace();
      final Workspace deleted = pickOne(random, seeded.workspaces);

      await seeded.repository.deleteWorkspace(deleted.id);

      final List<Workspace> expected = <Workspace>[
        for (final Workspace workspace in seeded.workspaces)
          if (workspace.id != deleted.id) workspace,
      ];
      expect(seeded.repository.listWorkspaces(), orderedEquals(expected));
      final Workspace expectedCurrent = deleted.id == current.id
          ? expected.first
          : current;
      expect(seeded.repository.currentWorkspace(), same(expectedCurrent));
    }
  });

  test('test_delete_workspace_property_unknown_ids_refused', () async {
    final Random random = seededRandom(68021);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final NotificationCounter notifications = NotificationCounter();
      seeded.repository.addListener(notifications.record);

      await expectLater(
        seeded.repository.deleteWorkspace(
          WorkspaceId('missing ${randomText(random)}'),
        ),
        throwsA(isA<RecordNotFound>()),
      );
      expect(
        seeded.repository.listWorkspaces(),
        orderedEquals(seeded.workspaces),
      );
      expect(notifications.count, 0);
    }
  });
}
