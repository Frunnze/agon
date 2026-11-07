import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/notification_counter.dart';
import 'support/node_backed_harness.dart';
import 'support/runner_repository_rig.dart';

const String _typePrefix = 'test_node_backed_runner_repository';
const int _iterations = 30;
const List<node.ChangeArea> _watchedAreas = <node.ChangeArea>[
  node.ChangeArea.runners,
  node.ChangeArea.devices,
  node.ChangeArea.workspaces,
];
const List<int> _refusalStatuses = <int>[400, 403, 404, 409, 503];

void _ignoreChange() {}

Future<List<Object>> _switchCatchingEscapes(
  Random random,
  RunnerRig rig,
) async {
  final List<Object> escaped = <Object>[];
  runZonedGuarded(
    () => unawaited(
      rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds)),
    ),
    (Object problem, StackTrace _) => escaped.add(problem),
  );
  await pumpEventQueue();
  return escaped;
}

void main() {
  test('${_typePrefix}_apply_change_property_each_watched_area_reloads_'
      'once', () async {
    final Random random = seededRandom(81241);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      final node.ChangeArea area = pickOne(random, _watchedAreas);
      rig.node.addRunnerIn(random, rig.workspaces.currentWorkspace().id);

      await rig.repository.applyChange(node.AreaChanged(area: area));

      expect(countCommands(rig, listRunnersCommand), 1, reason: '$area');
      expect(listShownRunnerIds(rig), listNodeRunnerIdsHere(rig));
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_apply_change_property_run_changes_ask_'
      'nothing', () async {
    final Random random = seededRandom(81242);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);

      await rig.repository.applyChange(
        node.RunChanged(runId: RunId(randomText(random))),
      );

      expect(rig.node.device.receivedCommands, isEmpty);
      expect(rig.notifications.count, 0);
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_load_after_workspace_change_property_lists_the_new_'
      'workspace', () async {
    final Random random = seededRandom(81243);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      await rig.repository.load();
      final WorkspaceId target = pickOne(random, rig.workspaceIds);
      rig.node.addRunnerIn(random, target);

      await rig.workspaces.switchWorkspace(target);
      await pumpEventQueue();

      expect(listShownRunnerIds(rig), rig.node.listRunnerIdsIn(target));
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_load_after_workspace_change_property_settles_on_the_'
      'last_switch', () async {
    final Random random = seededRandom(81244);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      final int switches = 2 + random.nextInt(4);

      for (int step = 0; step < switches; step += 1) {
        rig.node.addRunnerIn(random, pickOne(random, rig.workspaceIds));
        unawaited(
          rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds)),
        );
      }
      await pumpEventQueue();

      expect(listShownRunnerIds(rig), listNodeRunnerIdsHere(rig));
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_load_after_workspace_change_property_swallows_node_'
      'failures', () async {
    final Random random = seededRandom(81245);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      rig.node.addRunnerIn(random, rig.workspaces.currentWorkspace().id);
      await rig.repository.load();
      final List<Runner> before = rig.repository.listRunners();
      rig.node.refusal = 'the node is down ${randomText(random)}';

      final List<Object> escaped = await _switchCatchingEscapes(random, rig);

      expect(escaped, isEmpty);
      expect(identical(rig.repository.listRunners(), before), isTrue);
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_fetch_runners_property_no_workspace_asks_'
      'nothing', () async {
    final Random random = seededRandom(81246);

    for (int i = 0; i < _iterations; i += 1) {
      final ScopedRunnerNode simulated = ScopedRunnerNode();
      simulated.seedThisDevice(random);
      final WorkspaceRepository workspaces =
          await openWorkspacelessRepository();
      final NodeBackedRunnerRepository repository = NodeBackedRunnerRepository(
        channel: buildSimulatedChannel(simulated.answer),
        workspaceRepository: workspaces,
      );

      for (final node.ChangeArea area in _watchedAreas) {
        await repository.applyChange(node.AreaChanged(area: area));
      }

      expect(simulated.device.receivedCommands, isEmpty);
      expect(repository.listRunners(), isEmpty);
      repository.dispose();
    }
  });

  test('${_typePrefix}_fetch_runners_property_asks_for_the_current_'
      'workspace_every_time', () async {
    final Random random = seededRandom(81247);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      final List<Object?> expected = <Object?>[];

      for (int step = 0; step < 4; step += 1) {
        await rig.workspaces.switchWorkspace(
          pickOne(random, rig.workspaceIds),
        );
        await pumpEventQueue();
        expected.add(rig.workspaces.currentWorkspace().id.value);
      }

      expect(rig.node.listedWorkspaceIds, expected);
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_fetch_runners_property_app_server_refusals_are_'
      'typed_and_keep_the_listing', () async {
    final Random random = seededRandom(81248);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      rig.node.addRunnerIn(random, rig.workspaces.currentWorkspace().id);
      await rig.repository.load();
      final List<Runner> before = rig.repository.listRunners();
      final int notified = rig.notifications.count;
      final int status = pickOne(random, _refusalStatuses);
      final String reason = 'refused ${randomText(random)}';
      rig.node.refusal = 'the app server answered $status: $reason';

      await expectLater(
        rig.repository.load(),
        throwsA(
          isA<AppServerRefusal>()
              .having(
                (AppServerRefusal error) => error.status,
                'status',
                status,
              )
              .having(
                (AppServerRefusal error) => error.message,
                'message',
                reason,
              ),
        ),
      );

      expect(identical(rig.repository.listRunners(), before), isTrue);
      expect(rig.notifications.count, notified);
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_dispose_property_stops_reloading_on_'
      'switches', () async {
    final Random random = seededRandom(81249);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      rig.repository.removeListener(rig.notifications.record);
      rig.repository.dispose();

      await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
      await pumpEventQueue();

      expect(rig.node.device.receivedCommands, isEmpty);
      rig.workspaces.dispose();
    }
  });

  test('${_typePrefix}_dispose_property_keeps_other_listeners', () async {
    final Random random = seededRandom(81250);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      final NotificationCounter counter = NotificationCounter();
      rig.workspaces.addListener(counter.record);
      rig.repository.removeListener(rig.notifications.record);
      rig.repository.dispose();

      await rig.workspaces.switchWorkspace(pickOne(random, rig.workspaceIds));
      await pumpEventQueue();

      expect(counter.count, 1);
      rig.workspaces.dispose();
    }
  });

  test('${_typePrefix}_dispose_property_refuses_new_listeners', () {
    final Random random = seededRandom(81251);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      rig.repository.removeListener(rig.notifications.record);
      rig.repository.dispose();

      expect(
        () => rig.repository.addListener(_ignoreChange),
        throwsFlutterError,
      );
      expect(rig.node.device.receivedCommands, isEmpty);
      rig.workspaces.dispose();
    }
  });
}
