import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';

import '../../support/random_inputs.dart';
import 'support/workspace_inputs.dart';

const AppServerMember _activeOther = AppServerMember(
  deviceId: DeviceId('other-active-server'),
  standing: ServerStanding.active,
  copy: null,
);
const AppServerMember _backupOther = AppServerMember(
  deviceId: DeviceId('other-backup-server'),
  standing: ServerStanding.backup,
  copy: null,
);

Workspace _withId(Workspace workspace, String identifier) {
  return Workspace(
    id: WorkspaceId(identifier),
    name: workspace.name,
    appServerAddress: workspace.appServerAddress,
    protectedFiles: workspace.protectedFiles,
    approvalPolicy: workspace.approvalPolicy,
  );
}

FakeWorkspaceRepository _buildWithMembers(List<AppServerMember> members) {
  final Workspace only = Workspace(
    id: const WorkspaceId('only'),
    name: 'only',
    appServerAddress: 'peer://only',
    protectedFiles: const <String>[],
    approvalPolicy: ApprovalPolicy.neverAsk,
  );
  return buildWorkspaceRepository(
    workspaces: <Workspace>[only],
    currentWorkspaceId: only.id,
    appServerGroup: AppServerGroup(
      members: members,
      thisDeviceStanding: ThisDeviceStanding.none,
      canKeepBackup: true,
    ),
  );
}

void main() {
  test('test_identify_workspace_property_case_keeps_ids_apart', () {
    final Random random = seededRandom(68501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace seed = buildSampleWorkspace(random, i);
      final Workspace upper = _withId(seed, 'TEAM-$i');
      final Workspace lower = _withId(seed, 'team-$i');

      final FakeWorkspaceRepository repository = buildWorkspaceRepository(
        workspaces: <Workspace>[upper, lower],
        currentWorkspaceId: lower.id,
        appServerGroup: randomAppServerGroup(random),
      );

      expect(repository.listWorkspaces(), hasLength(2));
    }
  });

  test('test_identify_workspace_property_names_may_repeat', () {
    final Random random = seededRandom(68502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace seed = buildSampleWorkspace(random, i);

      final FakeWorkspaceRepository repository = buildWorkspaceRepository(
        workspaces: <Workspace>[_withId(seed, 'one'), _withId(seed, 'two')],
        currentWorkspaceId: const WorkspaceId('two'),
        appServerGroup: randomAppServerGroup(random),
      );

      expect(repository.currentWorkspace().name, seed.name);
    }
  });

  test('test_identify_workspace_property_refusal_names_the_id', () {
    final Random random = seededRandom(68503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace seed = buildSampleWorkspace(random, i);
      final String identifier = 'repeated ${randomText(random)}';

      expect(
        () => buildWorkspaceRepository(
          workspaces: <Workspace>[
            _withId(seed, identifier),
            _withId(seed, identifier),
          ],
          currentWorkspaceId: WorkspaceId(identifier),
          appServerGroup: randomAppServerGroup(random),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError error) => error.invalidValue,
            'invalidValue',
            identifier,
          ),
        ),
      );
    }
  });

  test('test_has_active_server_property_backups_alone_are_not', () async {
    final Random random = seededRandom(68504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int backupCount = random.nextInt(3);
      final List<AppServerMember> backups = <AppServerMember>[
        for (int count = 0; count < backupCount; count += 1) _backupOther,
      ];

      await expectLater(
        _buildWithMembers(backups).startServerBackup(),
        throwsStateError,
      );
    }
  });

  test('test_has_active_server_property_any_active_is_enough', () async {
    final Random random = seededRandom(68505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int backupCount = random.nextInt(3);
      final List<AppServerMember> members = <AppServerMember>[
        for (int count = 0; count < backupCount; count += 1) _backupOther,
        _activeOther,
      ];
      members.shuffle(random);

      final AppServerGroup started = await _buildWithMembers(members)
          .startServerBackup();

      expect(started.thisDeviceStanding, ThisDeviceStanding.backup);
    }
  });

  test('test_has_active_server_property_order_does_not_matter', () async {
    final Random random = seededRandom(68506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AppServerMember> members = <AppServerMember>[
        _activeOther,
        _backupOther,
        _backupOther,
      ];
      members.shuffle(random);
      final AppServerGroup group = AppServerGroup(
        members: members,
        thisDeviceStanding: ThisDeviceStanding.none,
        canKeepBackup: true,
      );

      final AppServerGroup started = await _buildWithMembers(members)
          .startServerBackup();

      expect(describeServerMembers(started), <String>[
        ...describeServerMembers(group),
        '${thisWorkspaceDeviceId.value} ${ServerStanding.backup.name}',
      ]);
    }
  });

  test('test_claim_created_workspace_id_property_skips_seeded', () async {
    final Random random = seededRandom(68507);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workspace seed = buildSampleWorkspace(random, i);
      final Workspace taken = _withId(seed, 'created-workspace-1');
      final FakeWorkspaceRepository repository = buildWorkspaceRepository(
        workspaces: <Workspace>[taken],
        currentWorkspaceId: taken.id,
        appServerGroup: randomAppServerGroup(random),
      );

      final Workspace created = await repository.createWorkspace(
        name: 'team-$i',
      );

      expect(created.id, isNot(taken.id));
    }
  });

  test('test_claim_created_workspace_id_property_never_reused', () async {
    final Random random = seededRandom(68508);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Set<WorkspaceId> seenIds = <WorkspaceId>{};

      final int createCount = 1 + random.nextInt(4);
      for (int create = 0; create < createCount; create += 1) {
        final Workspace created = await seeded.repository.createWorkspace(
          name: 'team-$create',
        );
        expect(seenIds.add(created.id), isTrue);
        await seeded.repository.deleteWorkspace(created.id);
      }
    }
  });

  test(
    'test_claim_created_workspace_id_property_refusal_claims_none',
    () async {
      final Random random = seededRandom(68509);

      for (int i = 0; i < propertyIterations; i += 1) {
        final SeededWorkspaces seeded = seedRandomWorkspaces(random);
        await expectLater(
          seeded.repository.createWorkspace(name: 'Not Valid'),
          throwsArgumentError,
        );

        final Workspace created = await seeded.repository.createWorkspace(
          name: 'team-$i',
        );

        expect(created.id.value, 'created-workspace-1');
      }
    },
  );

  test('test_is_listed_property_created_ids_were_free', () async {
    final Random random = seededRandom(68510);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Set<WorkspaceId> before = <WorkspaceId>{
        for (final Workspace workspace in seeded.workspaces) workspace.id,
      };

      final Workspace created = await seeded.repository.createWorkspace(
        name: 'team-$i',
      );

      expect(before, isNot(contains(created.id)));
    }
  });

  test('test_is_listed_property_many_taken_ids_skipped', () async {
    final Random random = seededRandom(68511);

    for (int i = 0; i < 40; i += 1) {
      final Workspace seed = buildSampleWorkspace(random, i);
      final int takenCount = 1 + random.nextInt(5);
      final List<Workspace> taken = <Workspace>[
        for (int number = 1; number <= takenCount; number += 1)
          _withId(seed, 'created-workspace-$number'),
      ];
      final FakeWorkspaceRepository repository = buildWorkspaceRepository(
        workspaces: taken,
        currentWorkspaceId: taken.first.id,
        appServerGroup: randomAppServerGroup(random),
      );

      final Workspace created = await repository.createWorkspace(name: 'x');

      expect(created.id.value, 'created-workspace-${takenCount + 1}');
    }
  });

  test('test_is_listed_property_deleted_ids_stay_retired', () async {
    final Random random = seededRandom(68512);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Workspace first = await seeded.repository.createWorkspace(
        name: 'first',
      );
      await seeded.repository.deleteWorkspace(first.id);

      final Workspace second = await seeded.repository.createWorkspace(
        name: 'second',
      );

      expect(second.id, isNot(first.id));
    }
  });
}
