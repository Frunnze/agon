import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/runner_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

import '../support/random_inputs.dart';
import '../support/sample_runners.dart';

void main() {
  test('test_find_runner_reach_property_offline_wins_relay_needs_server', () {
    final Random random = seededRandom(9407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = randomRunner(random);
      final AppServerState state = pickOne(random, AppServerState.values);
      final RunnerReach reach = findRunnerReach(runner, state);

      if (!runner.online) {
        expect(reach, RunnerReach.offline);
      } else if (state == AppServerState.unreachable &&
          runner.link == RunnerLink.relay) {
        expect(reach, RunnerReach.needsServer);
      } else {
        expect(reach, RunnerReach.reachable);
      }
    }
  });

  test('test_count_free_slots_property_bounded_by_reachable_totals', () {
    final Random random = seededRandom(9408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomRunners(random);
      final int freeSlots = countFreeSlots(runners);
      int onlineTotal = 0;
      for (final Runner runner in runners) {
        if (runner.online) {
          onlineTotal += runner.slotsTotal;
        }
      }

      expect(freeSlots, inInclusiveRange(0, onlineTotal));
    }
    expect(countFreeSlots(galleryRunners), 5);
  });

  test('test_describe_runner_fleet_property_counts_online_of_total', () {
    final Random random = seededRandom(9409);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomRunners(random);
      final int online = runners
          .where((Runner runner) => runner.online)
          .length;
      final String fleet = describeRunnerFleet(runners);

      expect(fleet, startsWith('$online of ${runners.length} online · '));
      expect(fleet, endsWith(countFreeSlots(runners) == 1 ? 'slot' : 'slots'));
    }
    expect(
      describeRunnerFleet(galleryRunners),
      '3 of 4 online · 5 free slots',
    );
  });

  test('test_describe_reachable_runners_property_counts_without_server', () {
    final Random random = seededRandom(9410);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomRunners(random);
      final int reachable = runners.where((Runner runner) {
        return findRunnerReach(runner, AppServerState.unreachable) ==
            RunnerReach.reachable;
      }).length;

      expect(
        describeReachableRunners(runners),
        '$reachable of ${runners.length} reachable',
      );
    }
    expect(describeReachableRunners(galleryRunners), '2 of 4 reachable');
  });

  test('test_describe_runner_link_property_server_down_names_the_path', () {
    for (final RunnerLink link in RunnerLink.values) {
      final String online = describeRunnerLink(link, AppServerState.online);
      final String down = describeRunnerLink(link, AppServerState.unreachable);

      expect(online, isNotEmpty);
      if (link == RunnerLink.relay) {
        expect(down, 'Needs the server');
      }
      if (link == RunnerLink.direct || link == RunnerLink.localNetwork) {
        expect(down, 'This network');
      }
    }
    expect(
      describeRunnerLink(RunnerLink.direct, AppServerState.online),
      'Direct',
    );
    expect(
      describeRunnerLink(RunnerLink.relay, AppServerState.online),
      'Relay',
    );
  });

  test('test_describe_sandbox_property_every_kind_has_distinct_text', () {
    final Set<String> sandboxTexts = <String>{
      for (final SandboxKind kind in SandboxKind.values) describeSandbox(kind),
    };
    final Set<String> fileTexts = <String>{
      for (final SandboxKind kind in SandboxKind.values)
        describeFileAccess(kind),
    };

    expect(sandboxTexts.length, SandboxKind.values.length);
    expect(fileTexts, isNotEmpty);
    expect(
      describeSandbox(SandboxKind.container),
      'In Docker, a new container per run, deleted when the run ends',
    );
    expect(
      describeSandbox(SandboxKind.localProcess),
      'On the computer itself, as local processes',
    );
    expect(
      describeFileAccess(SandboxKind.container),
      "Only the run's own workspace",
    );
  });

  test('test_describe_runner_summary_property_reach_leads_the_summary', () {
    final Random random = seededRandom(9411);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = randomRunner(random);
      final RunnerReach reach = pickOne(random, RunnerReach.values);
      final String summary = describeRunnerSummary(
        runner: runner,
        reach: reach,
        lastSeen: '3 days ago',
      );

      switch (reach) {
        case RunnerReach.reachable:
          final String state = runner.acceptingNewRuns ? 'Online' : 'Paused';
          expect(
            summary,
            '$state · ${runner.slotsBusy} of ${runner.slotsTotal} slots busy',
          );
        case RunnerReach.offline:
          expect(summary, 'Offline · last seen 3 days ago');
        case RunnerReach.needsServer:
          expect(summary, startsWith('Unreachable · '));
      }
    }
  });

  test('test_describe_server_down_notice_property_names_every_waiting', () {
    final Random random = seededRandom(9412);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> names = <String>[
        for (int index = 0; index < random.nextInt(4); index += 1)
          'runner-$index',
      ];
      final String notice = describeServerDownNotice(names);

      expect(notice, startsWith('Runners on this network still work.'));
      for (final String name in names) {
        expect(notice.contains(name), isTrue);
      }
      expect(
        notice.contains('wait until the server is back.'),
        names.isNotEmpty,
      );
    }
    expect(
      describeServerDownNotice(const <String>['gpu-box']),
      'Runners on this network still work. Runs for gpu-box wait until '
      'the server is back.',
    );
    expect(
      describeServerDownNotice(const <String>['a', 'b', 'c']),
      'Runners on this network still work. Runs for a, b and c wait until '
      'the server is back.',
    );
  });

  test('test_describe_server_retry_property_clock_and_interval', () {
    final Random random = seededRandom(9413);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime lastConnectedAt = randomLocalMoment(random);
      final int seconds = 1 + random.nextInt(120);
      final AppServerStatus status = AppServerStatus(
        address: 'relay.acme.dev',
        state: AppServerState.unreachable,
        lastConnectedAt: lastConnectedAt,
        retryInterval: Duration(seconds: seconds),
      );

      expect(
        describeServerRetry(status),
        'Last connected ${formatClockTime(lastConnectedAt)} · '
        'trying every $seconds seconds',
      );
    }
  });

  test('gallery runner reach pins the server-down runners list', () {
    final List<RunnerReach> reaches = <RunnerReach>[
      for (final Runner runner in galleryRunners)
        findRunnerReach(runner, AppServerState.unreachable),
    ];

    expect(reaches, <RunnerReach>[
      RunnerReach.reachable,
      RunnerReach.reachable,
      RunnerReach.needsServer,
      RunnerReach.offline,
    ]);
    expect(galleryRunners[2].deviceId, GalleryDeviceIds.gpuBox);
  });
}
