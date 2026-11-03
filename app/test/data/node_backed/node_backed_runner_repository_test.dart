import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../bridge/support/random_account_json.dart';
import '../../bridge/support/scripted_node_transport.dart';
import '../../support/random_inputs.dart';
import 'support/node_backed_harness.dart';
import 'support/simulated_device_node.dart';
import 'support/simulated_node_replies.dart' show simulatedOutageMessage;

const int _sequenceIterations = 25;
const int _stepsPerSequence = 10;
const String _localPlaceWireName = 'local_process';
const String _containerPlaceWireName = 'container';

typedef _Fixture = ({
  SimulatedDeviceNode node,
  NodeBackedRunnerRepository repository,
});

_Fixture _buildFixture() {
  final SimulatedDeviceNode simulated = SimulatedDeviceNode(
    thisDeviceId: 'me',
  );
  final NodeBackedRunnerRepository repository = NodeBackedRunnerRepository(
    channel: buildSimulatedChannel(simulated.answer),
    workspaceRepository: buildSingleWorkspaceRepository(),
  );
  return (node: simulated, repository: repository);
}

final class _OutageSwitch {
  _OutageSwitch({required this.node});

  final SimulatedDeviceNode node;
  bool isServerDown = false;

  String answer(String inputJson) {
    if (isServerDown) {
      return encodeErrorReply(simulatedOutageMessage);
    }
    return node.answer(inputJson);
  }
}

void _expectMirrorsNode(_Fixture fixture) {
  final List<Runner> runners = fixture.repository.listRunners();
  expect(
    runners.map((Runner runner) => runner.deviceId.value),
    fixture.node.runners.keys,
  );
  for (final Runner runner in runners) {
    final Map<String, Object?> wire =
        fixture.node.runners[runner.deviceId.value]!;
    expect(runner.acceptingNewRuns, wire['accepting_new_runs']);
  }
}

List<Map<String, Object?>>? _randomOffersJson(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return <Map<String, Object?>>[
    for (int index = 0; index < 1 + random.nextInt(2); index += 1)
      <String, Object?>{
        'place': pickOne(random, AgentPlace.values) == AgentPlace.container
            ? _containerPlaceWireName
            : _localPlaceWireName,
        'problem': random.nextBool() ? null : 'blocked ${randomText(random)}',
      },
  ];
}

AgentPlace _placeOfWireName(Object? wireName) {
  if (wireName == _localPlaceWireName) {
    return AgentPlace.localProcess;
  }
  return AgentPlace.container;
}

List<AgentPlace> _randomChosenPlaces(Random random) {
  final List<AgentPlace> places = <AgentPlace>[
    for (final AgentPlace place in AgentPlace.values)
      if (random.nextBool()) place,
  ];
  if (places.isEmpty) {
    return <AgentPlace>[pickOne(random, AgentPlace.values)];
  }
  return places;
}

void main() {
  test('test_load_property_reads_what_this_device_offers', () async {
    final Random random = seededRandom(9955);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _Fixture fixture = _buildFixture();
      final List<Map<String, Object?>>? offers = _randomOffersJson(random);
      final String? problem = random.nextBool()
          ? 'blocked ${randomText(random)}'
          : null;
      fixture.node.runnerSettings = offers == null
          ? null
          : randomRunnerSettingsJson(random);
      fixture.node.runnerOffers = offers;
      fixture.node.runnerProblem = problem;

      await fixture.repository.load();

      expect(fixture.repository.findThisRunnerProblem(), problem);
      final List<PlaceOffer>? expectedOffers = offers == null
          ? null
          : <PlaceOffer>[
              for (final Map<String, Object?> offer in offers)
                PlaceOffer(
                  place: _placeOfWireName(offer['place']),
                  problem: offer['problem'] as String?,
                ),
            ];
      expect(fixture.repository.findThisDeviceOffers(), expectedOffers);
    }
  });

  test('test_choose_agent_offers_property_shows_the_chosen_offers', () async {
    final Random random = seededRandom(9956);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _Fixture fixture = _buildFixture();
      fixture.node.runnerSettings = randomRunnerSettingsJson(random);
      fixture.node.runnerOffers = _randomOffersJson(random);
      fixture.node.runnerProblem = 'blocked ${randomText(random)}';
      await fixture.repository.load();
      int notifications = 0;
      fixture.repository.addListener(() => notifications += 1);
      final List<AgentPlace> chosen = _randomChosenPlaces(random);

      await fixture.repository.chooseAgentOffers(chosen);

      final List<PlaceOffer>? shown = fixture.repository
          .findThisDeviceOffers();
      expect(<AgentPlace>[
        for (final PlaceOffer offer in shown!) offer.place,
      ], chosen);
      expect(fixture.node.receivedCommands, contains('choose_agent_offers'));
      expect(notifications, greaterThan(0));
      if (chosen.contains(AgentPlace.localProcess)) {
        expect(fixture.repository.findThisRunnerProblem(), isNull);
      }
    }
  });

  test(
    'test_choose_agent_offers_property_a_device_without_agents_refuses',
    () {
      final Random random = seededRandom(9957);
      for (int i = 0; i < _sequenceIterations; i += 1) {
        final _Fixture fixture = _buildFixture();
        final List<AgentPlace> chosen = _randomChosenPlaces(random);

        expect(
          fixture.repository.chooseAgentOffers(chosen),
          throwsA(isA<StateError>()),
        );
      }
    },
  );

  test('test_apply_change_property_runners_mirror_the_node', () async {
    final Random random = seededRandom(9951);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _Fixture fixture = _buildFixture();
      fixture.node.addRunnerFromElsewhere(random);
      await fixture.repository.load();

      for (int step = 0; step < _stepsPerSequence; step += 1) {
        final Runner runner = pickOne(
          random,
          fixture.repository.listRunners(),
        );
        switch (random.nextInt(3)) {
          case 0:
            await fixture.repository.pauseRunner(runner.deviceId);
          case 1:
            await fixture.repository.resumeRunner(runner.deviceId);
          case _:
            fixture.node.addRunnerFromElsewhere(random);
            await fixture.repository.applyChange(
              const node.AreaChanged(area: node.ChangeArea.runners),
            );
        }
        _expectMirrorsNode(fixture);
      }
    }
  });

  test('test_pause_runner_property_stops_new_runs_until_resumed', () async {
    final Random random = seededRandom(9952);
    final _Fixture fixture = _buildFixture();
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final DeviceId deviceId = DeviceId(
        fixture.node.addRunnerFromElsewhere(random),
      );
      await fixture.repository.load();

      final Runner paused = await fixture.repository.pauseRunner(deviceId);
      expect(paused.acceptingNewRuns, isFalse);
      final Runner resumed = await fixture.repository.resumeRunner(deviceId);
      expect(resumed.acceptingNewRuns, isTrue);
    }
  });

  test('test_pause_runner_property_unknown_runner_is_not_found', () async {
    final Random random = seededRandom(9953);
    final _Fixture fixture = _buildFixture();
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final DeviceId deviceId = DeviceId('missing${random.nextInt(1000)}');
      await expectLater(
        fixture.repository.pauseRunner(deviceId),
        throwsA(isA<RecordNotFound>()),
      );
      expect(
        () => fixture.repository.findRunner(deviceId),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('test_apply_change_property_unwatched_areas_send_nothing', () async {
    final _Fixture fixture = _buildFixture();
    const Set<node.ChangeArea> watched = <node.ChangeArea>{
      node.ChangeArea.runners,
      node.ChangeArea.devices,
      node.ChangeArea.workspaces,
    };
    for (final node.ChangeArea area in node.ChangeArea.values) {
      if (!watched.contains(area)) {
        await fixture.repository.applyChange(node.AreaChanged(area: area));
      }
    }
    expect(fixture.node.receivedCommands, isEmpty);
  });

  test('test_load_property_background_reload_outage_keeps_runners', () async {
    final Random random = seededRandom(9954);
    for (int i = 0; i < _sequenceIterations; i += 1) {
      final _OutageSwitch outage = _OutageSwitch(
        node: SimulatedDeviceNode(thisDeviceId: 'me'),
      );
      outage.node.addRunnerFromElsewhere(random);
      final WorkspaceRepository workspaces = buildSingleWorkspaceRepository();
      final NodeBackedRunnerRepository repository = NodeBackedRunnerRepository(
        channel: buildSimulatedChannel(outage.answer),
        workspaceRepository: workspaces,
      );
      await repository.load();
      final List<Runner> before = repository.listRunners();
      outage.isServerDown = true;
      final List<Object> escaped = <Object>[];

      runZonedGuarded(
        () => unawaited(workspaces.retryAppServer()),
        (Object problem, StackTrace _) => escaped.add(problem),
      );
      for (int turn = 0; turn < _stepsPerSequence; turn += 1) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(escaped, isEmpty);
      expect(repository.listRunners(), before);
      repository.dispose();
    }
  });
}
