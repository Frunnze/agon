import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/runner_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/runner_repository_rig.dart';

const String _typePrefix = 'test_node_backed_runner_repository';
const int _iterations = 40;

String _describeFinding(RunnerRepository repository, DeviceId deviceId) {
  try {
    return describeRunner(repository.findRunner(deviceId));
  } on RecordNotFound catch (missing) {
    return 'missing ${missing.kind} ${missing.identifier}';
  }
}

void main() {
  test('${_typePrefix}_constructor_property_starts_empty_and_'
      'silent', () {
    final Random random = seededRandom(81201);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);

      expect(rig.repository.listRunners(), isEmpty);
      expect(rig.repository.findThisDeviceOffers(), isNull);
      expect(rig.repository.findThisRunnerProblem(), isNull);
      expect(rig.node.device.receivedCommands, isEmpty);
      expect(rig.notifications.count, 0);
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_constructor_property_follows_workspace_switches_'
      'before_any_load', () async {
    final Random random = seededRandom(81202);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);

      await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
      await pumpEventQueue();

      expect(listShownRunnerIds(rig), listNodeRunnerIdsHere(rig));
      expect(rig.node.listedWorkspaceIds, <Object?>[
        rig.workspaces.currentWorkspace().id.value,
      ]);
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_constructor_property_reads_only_its_own_'
      'channel', () async {
    final Random random = seededRandom(81203);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig first = buildRunnerRig(random);
      final RunnerRig second = buildRunnerRig(random);

      await first.repository.load();
      await second.repository.load();

      expect(listShownRunnerIds(first), listNodeRunnerIdsHere(first));
      expect(listShownRunnerIds(second), listNodeRunnerIdsHere(second));
      expect(first.node.listedWorkspaceIds, hasLength(1));
      expect(second.node.listedWorkspaceIds, hasLength(1));
      closeRunnerRig(first);
      closeRunnerRig(second);
    }
  });

  test('${_typePrefix}_list_runners_property_mirrors_the_current_'
      'workspace_in_node_order', () async {
    final Random random = seededRandom(81204);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      await rig.repository.load();

      for (int step = 0; step < 4; step += 1) {
        rig.node.addRunnerIn(random, pickOne(random, rig.workspaceIds));
        await rig.workspaces.switchWorkspace(
          pickOne(random, rig.workspaceIds),
        );
        await pumpEventQueue();

        expect(listShownRunnerIds(rig), listNodeRunnerIdsHere(rig));
      }
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_list_runners_property_is_unmodifiable_and_'
      'stable', () async {
    final Random random = seededRandom(81205);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      rig.node.addRunnerIn(random, rig.workspaces.currentWorkspace().id);
      await rig.repository.load();
      final List<Runner> first = rig.repository.listRunners();

      expect(first.removeLast, throwsUnsupportedError);
      expect(() => first.add(first.first), throwsUnsupportedError);
      expect(identical(rig.repository.listRunners(), first), isTrue);
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_list_runners_property_empty_without_a_'
      'workspace', () async {
    final Random random = seededRandom(81206);

    for (int i = 0; i < _iterations; i += 1) {
      final ScopedRunnerNode simulated = ScopedRunnerNode();
      simulated.addRunnerIn(random, WorkspaceId(randomText(random)));
      simulated.seedThisDevice(random);
      final WorkspaceRepository workspaces =
          await openWorkspacelessRepository();
      final NodeBackedRunnerRepository repository = NodeBackedRunnerRepository(
        channel: buildSimulatedChannel(simulated.answer),
        workspaceRepository: workspaces,
      );

      await repository.load();

      expect(repository.listRunners(), isEmpty);
      expect(repository.findThisDeviceOffers(), isNull);
      expect(repository.findThisRunnerProblem(), isNull);
      expect(simulated.device.receivedCommands, isEmpty);
      repository.dispose();
    }
  });

  test('${_typePrefix}_find_runner_property_finds_every_listed_'
      'runner', () async {
    final Random random = seededRandom(81207);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      rig.node.addRunnerIn(random, rig.workspaces.currentWorkspace().id);
      await rig.repository.load();

      for (final Runner runner in rig.repository.listRunners()) {
        final Runner found = rig.repository.findRunner(runner.deviceId);
        expect(identical(found, runner), isTrue);
      }
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_find_runner_property_unknown_devices_are_not_'
      'found', () async {
    final Random random = seededRandom(81208);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      final WorkspaceId elsewhere = WorkspaceId('elsewhere-$i');
      final DeviceId outsider = DeviceId(
        rig.node.addRunnerIn(random, elsewhere),
      );
      await rig.repository.load();
      final DeviceId unknown = randomUnknownDeviceId(random);

      for (final DeviceId deviceId in <DeviceId>[outsider, unknown]) {
        expect(
          () => rig.repository.findRunner(deviceId),
          throwsA(
            isA<RecordNotFound>()
                .having((RecordNotFound error) => error.kind, 'kind', 'runner')
                .having(
                  (RecordNotFound error) => error.identifier,
                  'identifier',
                  deviceId.value,
                ),
          ),
        );
      }
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_find_runner_property_agrees_with_the_fake', () async {
    final Random random = seededRandom(81209);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      await rig.repository.load();
      final FakeRunnerRepository fake = buildRunnerRepository(
        runners: rig.repository.listRunners(),
        offers: rig.repository.findThisDeviceOffers(),
        problem: rig.repository.findThisRunnerProblem(),
      );
      final List<DeviceId> asked = <DeviceId>[
        for (final String deviceId in rig.node.device.runners.keys)
          DeviceId(deviceId),
        randomUnknownDeviceId(random),
      ];

      for (final DeviceId deviceId in asked) {
        expect(
          _describeFinding(rig.repository, deviceId),
          _describeFinding(fake, deviceId),
        );
      }
      closeRunnerRig(rig);
      fake.dispose();
    }
  });

  test('${_typePrefix}_load_property_an_older_reply_never_overwrites_a_'
      'newer_one', () async {
    final Random random = seededRandom(81210);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      rig.transport.holdNextReply(listRunnersCommand);
      final Future<void> olderLoad = rig.repository.load();
      await rig.transport.heldReplyArrival;
      rig.node.addRunnerIn(random, pickOne(random, rig.workspaceIds));

      await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
      await pumpEventQueue();
      final List<String> newer = listShownRunnerIds(rig);
      rig.transport.releaseHeldReply();
      await olderLoad;

      expect(newer, listNodeRunnerIdsHere(rig));
      expect(listShownRunnerIds(rig), newer);
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_load_property_notifies_once_per_accepted_'
      'reply', () async {
    final Random random = seededRandom(81211);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      final int loads = 1 + random.nextInt(4);

      for (int step = 0; step < loads; step += 1) {
        await rig.repository.load();
      }

      expect(rig.notifications.count, loads);
      expect(rig.node.listedWorkspaceIds, hasLength(loads));
      closeRunnerRig(rig);
    }
  });
}
