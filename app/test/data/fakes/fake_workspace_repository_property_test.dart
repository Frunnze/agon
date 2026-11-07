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

const String _typePrefix = 'test_fake_workspace_repository';
const int _sequenceLength = 8;

List<WorkspaceId> _listIds(FakeWorkspaceRepository repository) {
  return <WorkspaceId>[
    for (final Workspace workspace in repository.listWorkspaces())
      workspace.id,
  ];
}

WorkspaceId _randomUnknownId(Random random) {
  return WorkspaceId('unknown ${randomText(random)}');
}

Future<void> _changeRandomly(
  Random random,
  FakeWorkspaceRepository repository,
) async {
  final List<Workspace> listed = repository.listWorkspaces();
  final int choice = random.nextInt(3);

  if (choice == 0) {
    await repository.createWorkspace(name: 'team-${random.nextInt(99)}');
  } else if (choice == 1 && listed.length > 1) {
    await repository.deleteWorkspace(pickOne(random, listed).id);
  } else {
    await repository.switchWorkspace(pickOne(random, listed).id);
  }
}

void main() {
  test('${_typePrefix}_new_property_refuses_repeated_seed_ids', () {
    final Random random = seededRandom(67901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workspace> seeded = randomWorkspaces(random);
      final Workspace repeated = pickOne(random, seeded);

      expect(
        () => buildWorkspaceRepository(
          workspaces: <Workspace>[...seeded, repeated],
          currentWorkspaceId: seeded.first.id,
          appServerGroup: randomAppServerGroup(random),
        ),
        throwsArgumentError,
      );
    }
  });

  test('${_typePrefix}_new_property_refuses_unknown_current', () {
    final Random random = seededRandom(67902);

    for (int i = 0; i < propertyIterations; i += 1) {
      expect(
        () => buildWorkspaceRepository(
          workspaces: randomWorkspaces(random),
          currentWorkspaceId: _randomUnknownId(random),
          appServerGroup: randomAppServerGroup(random),
        ),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('${_typePrefix}_new_property_keeps_a_frozen_copy', () {
    final Random random = seededRandom(67903);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workspace> seeded = randomWorkspaces(random);
      final List<WorkspaceId> seededIds = <WorkspaceId>[
        for (final Workspace workspace in seeded) workspace.id,
      ];
      final FakeWorkspaceRepository repository = buildWorkspaceRepository(
        workspaces: seeded,
        currentWorkspaceId: pickOne(random, seeded).id,
        appServerGroup: randomAppServerGroup(random),
      );

      seeded.add(buildSampleWorkspace(random, 99));

      expect(_listIds(repository), orderedEquals(seededIds));
    }
  });

  test('test_list_workspaces_property_listing_cannot_be_edited', () {
    final Random random = seededRandom(67904);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);

      expect(
        () => seeded.repository.listWorkspaces().removeLast(),
        throwsUnsupportedError,
      );
      expect(
        seeded.repository.listWorkspaces(),
        orderedEquals(seeded.workspaces),
      );
    }
  });

  test('test_list_workspaces_property_follows_creates_and_deletes', () async {
    final Random random = seededRandom(67905);

    for (int i = 0; i < 60; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final List<WorkspaceId> model = _listIds(seeded.repository);

      for (int step = 0; step < _sequenceLength; step += 1) {
        if (model.length > 1 && random.nextBool()) {
          final WorkspaceId removed = pickOne(random, model);
          await seeded.repository.deleteWorkspace(removed);
          model.remove(removed);
        } else {
          final Workspace created = await seeded.repository.createWorkspace(
            name: 'team-$step',
          );
          model.add(created.id);
        }

        expect(_listIds(seeded.repository), orderedEquals(model));
      }
    }
  });

  test('test_list_workspaces_property_created_ids_never_collide', () async {
    final Random random = seededRandom(67906);

    for (int i = 0; i < 60; i += 1) {
      final List<Workspace> seeded = <Workspace>[
        for (int index = 1; index <= 3; index += 1)
          Workspace(
            id: WorkspaceId('created-workspace-$index'),
            name: 'seeded-$index',
            appServerAddress: 'peer://seeded',
            protectedFiles: randomPatterns(random),
            approvalPolicy: ApprovalPolicy.neverAsk,
          ),
      ];
      final FakeWorkspaceRepository repository = buildWorkspaceRepository(
        workspaces: seeded,
        currentWorkspaceId: seeded.first.id,
        appServerGroup: randomAppServerGroup(random),
      );

      for (int step = 0; step < 4; step += 1) {
        await repository.createWorkspace(name: 'team-$step');
      }

      final List<WorkspaceId> ids = _listIds(repository);
      expect(ids.toSet(), hasLength(ids.length));
    }
  });

  test('test_current_workspace_property_always_a_listed_one', () async {
    final Random random = seededRandom(67907);

    for (int i = 0; i < 60; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);

      for (int step = 0; step < _sequenceLength; step += 1) {
        await _changeRandomly(random, seeded.repository);

        final Workspace current = seeded.repository.currentWorkspace();
        expect(seeded.repository.listWorkspaces(), contains(same(current)));
      }
    }
  });

  test('test_current_workspace_property_follows_switches', () async {
    final Random random = seededRandom(67908);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Workspace target = pickOne(random, seeded.workspaces);

      await seeded.repository.switchWorkspace(target.id);

      expect(seeded.repository.currentWorkspace(), same(target));
    }
  });

  test('test_current_workspace_property_moves_off_a_deleted_one', () async {
    final Random random = seededRandom(67909);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      if (seeded.workspaces.length < 2) {
        continue;
      }
      final Workspace current = seeded.repository.currentWorkspace();

      await seeded.repository.deleteWorkspace(current.id);

      expect(
        seeded.repository.currentWorkspace(),
        same(seeded.repository.listWorkspaces().first),
      );
    }
  });

  test('test_switch_workspace_property_unknown_ids_change_nothing', () async {
    final Random random = seededRandom(67910);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Workspace before = seeded.repository.currentWorkspace();
      final NotificationCounter notifications = NotificationCounter();
      seeded.repository.addListener(notifications.record);

      await expectLater(
        seeded.repository.switchWorkspace(_randomUnknownId(random)),
        throwsA(isA<RecordNotFound>()),
      );

      expect(seeded.repository.currentWorkspace(), same(before));
      expect(notifications.count, 0);
    }
  });

  test('test_switch_workspace_property_returns_it_and_notifies', () async {
    final Random random = seededRandom(67911);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final NotificationCounter notifications = NotificationCounter();
      seeded.repository.addListener(notifications.record);
      final Workspace target = pickOne(random, seeded.workspaces);

      final Workspace switched = await seeded.repository.switchWorkspace(
        target.id,
      );

      expect(switched, same(target));
      expect(notifications.count, 1);
    }
  });

  test('test_switch_workspace_property_switching_twice_is_once', () async {
    final Random random = seededRandom(67912);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SeededWorkspaces seeded = seedRandomWorkspaces(random);
      final Workspace target = pickOne(random, seeded.workspaces);

      await seeded.repository.switchWorkspace(target.id);
      await seeded.repository.switchWorkspace(target.id);

      expect(seeded.repository.currentWorkspace(), same(target));
      expect(
        seeded.repository.listWorkspaces(),
        orderedEquals(seeded.workspaces),
      );
    }
  });
}
