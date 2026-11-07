import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../bridge/support/node_json_primitives.dart';
import '../../support/random_inputs.dart';
import 'support/device_repository_rig.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_device_node.dart';

const int _largestLoadCount = 5;
const int _notFoundStatus = 404;
const String _memberMissingReason = 'the workspace member was not found';

final class _DeviceDroppingNode {
  _DeviceDroppingNode({required this.node, required this.droppedDeviceId});

  final SimulatedDeviceNode node;
  final String droppedDeviceId;

  String answer(String inputJson) {
    final String reply = node.answer(inputJson);
    final Map<String, Object?> command =
        jsonDecode(inputJson) as Map<String, Object?>;
    if (command['command'] == 'revoke_device') {
      node.devices.remove(droppedDeviceId);
    }
    return reply;
  }
}

List<Object?> _thisDeviceKeys(DeviceRig rig) {
  return rig.node.devices[rigThisDeviceId]!['workspaces']! as List<Object?>;
}

WorkspaceId _grantWorkspaceKey(Random random, DeviceRig rig) {
  final WorkspaceId workspaceId = WorkspaceId(randomUuidText(random));
  _thisDeviceKeys(rig).add(workspaceId.value);
  return workspaceId;
}

Future<DeviceId> _loadWithJoiner(Random random, DeviceRig rig) async {
  final String joinerId = addUnrevokedDeviceFromElsewhere(random, rig.node);
  await rig.repository.load();
  return DeviceId(joinerId);
}

void main() {
  test(
    'test_node_backed_device_repository_load_property_stale_reply_never_wins',
    () async {
      final Random random = seededRandom(76801);
      for (int i = 0; i < propertyIterations; i += 1) {
        final DeviceRig rig = buildDeviceRig(random);
        rig.transport.holdNextReply('list_devices');
        final Future<void> staleLoad = rig.repository.load();
        await rig.transport.heldReplyArrival;
        addUnrevokedDeviceFromElsewhere(random, rig.node);

        await rig.repository.load();
        rig.transport.releaseHeldReply();
        await staleLoad;

        expectRepositoryMirrorsNode(rig);
      }
    },
  );

  test(
    'test_node_backed_device_repository_load_property_notifies_once_per_load',
    () async {
      final Random random = seededRandom(76802);
      for (int i = 0; i < propertyIterations; i += 1) {
        final DeviceRig rig = buildDeviceRig(random);
        final int loadCount = 1 + random.nextInt(_largestLoadCount);
        int heard = 0;
        rig.repository.addListener(() => heard += 1);

        for (int load = 0; load < loadCount; load += 1) {
          await rig.repository.load();
        }

        expect(heard, loadCount);
      }
    },
  );

  test(
    'test_node_backed_device_repository_apply_change_property_watched_topics',
    () async {
      final Random random = seededRandom(76803);
      for (int i = 0; i < propertyIterations; i += 1) {
        final DeviceRig rig = buildDeviceRig(random);
        await rig.repository.load();
        addUnrevokedDeviceFromElsewhere(random, rig.node);
        final int commandsBefore = rig.node.receivedCommands.length;

        await rig.repository.applyChange(
          node.RunChanged(runId: RunId(randomText(random))),
        );
        expect(rig.node.receivedCommands.length, commandsBefore);
        await rig.repository.applyChange(
          const node.AreaChanged(area: node.ChangeArea.workspaces),
        );

        expectRepositoryMirrorsNode(rig);
      }
    },
  );

  test('test_revoke_device_property_only_that_device_changes', () async {
    final Random random = seededRandom(76804);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceRig rig = buildDeviceRig(random);
      final DeviceId revokedId = await _loadWithJoiner(random, rig);
      final List<Device> before = rig.repository.listDevices();

      final Device revoked = await rig.repository.revokeDevice(revokedId);

      expect(revoked.revoked, isTrue);
      final List<Device> after = rig.repository.listDevices();
      for (int position = 0; position < before.length; position += 1) {
        if (before[position].id != revokedId) {
          expect(after[position].revoked, before[position].revoked);
        }
      }
      expectRepositoryMirrorsNode(rig);
    }
  });

  test(
    'test_add_device_to_workspace_property_second_join_is_refused',
    () async {
      final Random random = seededRandom(76805);
      for (int i = 0; i < propertyIterations; i += 1) {
        final DeviceRig rig = buildDeviceRig(random);
        final WorkspaceId workspaceId = _grantWorkspaceKey(random, rig);
        final DeviceId joinerId = await _loadWithJoiner(random, rig);
        await rig.repository.addDeviceToWorkspace(joinerId, workspaceId);
        final List<Object?> joined = describeListedDevices(
          rig.repository.listDevices(),
        );

        await expectLater(
          rig.repository.addDeviceToWorkspace(joinerId, workspaceId),
          throwsStateError,
        );

        expect(describeListedDevices(rig.repository.listDevices()), joined);
        expectRepositoryMirrorsNode(rig);
      }
    },
  );

  test(
    'test_remove_device_from_workspace_property_non_member_refusal_is_plain',
    () async {
      final Random random = seededRandom(76806);
      for (int i = 0; i < propertyIterations; i += 1) {
        final DeviceRig rig = buildDeviceRig(random);
        final DeviceId deviceId = await _loadWithJoiner(random, rig);
        final WorkspaceId absent = WorkspaceId(randomUuidText(random));

        await expectLater(
          rig.repository.removeDeviceFromWorkspace(deviceId, absent),
          throwsA(
            isA<AppServerRefusal>()
                .having(
                  (AppServerRefusal refusal) => refusal.status,
                  'status',
                  _notFoundStatus,
                )
                .having(
                  (AppServerRefusal refusal) => refusal.message,
                  'reason',
                  _memberMissingReason,
                ),
          ),
        );
        expectRepositoryMirrorsNode(rig);
      }
    },
  );

  test(
    'test_remove_device_from_workspace_property_keeps_the_other_workspaces',
    () async {
      final Random random = seededRandom(76807);
      for (int i = 0; i < propertyIterations; i += 1) {
        final DeviceRig rig = buildDeviceRig(random);
        final DeviceId joinerId = await _loadWithJoiner(random, rig);
        final List<WorkspaceId> joined = <WorkspaceId>[
          for (int j = 0; j < 1 + random.nextInt(4); j += 1)
            _grantWorkspaceKey(random, rig),
        ];
        for (final WorkspaceId workspaceId in joined) {
          await rig.repository.addDeviceToWorkspace(joinerId, workspaceId);
        }
        final WorkspaceId leaving = pickOne(random, joined);
        final List<WorkspaceId> before = rig.repository
            .findDevice(joinerId)
            .workspaces;

        final Device left = await rig.repository.removeDeviceFromWorkspace(
          joinerId,
          leaving,
        );

        expect(left.workspaces, <WorkspaceId>[
          for (final WorkspaceId workspaceId in before)
            if (workspaceId != leaving) workspaceId,
        ]);
        expect(before.sublist(before.length - joined.length), joined);
      }
    },
  );

  test('test_reload_device_property_returns_the_listed_device', () async {
    final Random random = seededRandom(76808);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceRig rig = buildDeviceRig(random);
      final WorkspaceId workspaceId = _grantWorkspaceKey(random, rig);
      final DeviceId joinerId = await _loadWithJoiner(random, rig);
      int heard = 0;
      rig.repository.addListener(() => heard += 1);

      final Device joined = await rig.repository.addDeviceToWorkspace(
        joinerId,
        workspaceId,
      );

      expect(joined, same(rig.repository.findDevice(joinerId)));
      expect(heard, 1);
    }
  });

  test('test_reload_device_property_sees_changes_made_elsewhere', () async {
    final Random random = seededRandom(76809);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceRig rig = buildDeviceRig(random);
      final DeviceId revokedId = await _loadWithJoiner(random, rig);
      addUnrevokedDeviceFromElsewhere(random, rig.node);

      await rig.repository.revokeDevice(revokedId);

      expectRepositoryMirrorsNode(rig);
    }
  });

  test('test_reload_device_property_a_device_gone_is_not_found', () async {
    final Random random = seededRandom(76810);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceRig rig = buildDeviceRig(random);
      final String goneId = addUnrevokedDeviceFromElsewhere(random, rig.node);
      final _DeviceDroppingNode dropping = _DeviceDroppingNode(
        node: rig.node,
        droppedDeviceId: goneId,
      );
      final NodeBackedDeviceRepository repository = NodeBackedDeviceRepository(
        channel: buildSimulatedChannel(dropping.answer),
      );
      await repository.load();

      await expectLater(
        repository.revokeDevice(DeviceId(goneId)),
        throwsA(isA<RecordNotFound>()),
      );
      expect(
        repository.listDevices().map((Device device) => device.id.value),
        isNot(contains(goneId)),
      );
    }
  });
}
