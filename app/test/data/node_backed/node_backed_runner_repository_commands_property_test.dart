import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';

import '../../bridge/support/node_json_primitives.dart';
import '../../bridge/support/random_account_json.dart';
import '../../support/random_inputs.dart';
import '../fakes/support/runner_inputs.dart';
import 'support/runner_repository_rig.dart';
import 'support/simulated_work_node.dart' show WireRecord;

const String _typePrefix = 'test_node_backed_runner_repository';
const int _iterations = 30;
const int _longestSequence = 6;

enum _Switch { pause, resume }

Future<RunnerRig> _openRigWithRunners(Random random) async {
  final RunnerRig rig = buildRunnerRig(random);
  for (int i = 0; i <= random.nextInt(3); i += 1) {
    rig.node.addRunnerIn(random, rig.workspaces.currentWorkspace().id);
  }
  await rig.repository.load();
  return rig;
}

Future<Runner> _flip(RunnerRepository repository, _Switch flip, DeviceId id) {
  return switch (flip) {
    _Switch.pause => repository.pauseRunner(id),
    _Switch.resume => repository.resumeRunner(id),
  };
}

FakeRunnerRepository _buildTwinFake(RunnerRig rig) {
  return buildRunnerRepository(
    runners: rig.repository.listRunners(),
    offers: rig.repository.findThisDeviceOffers(),
    problem: rig.repository.findThisRunnerProblem(),
  );
}

String _describeOffers(RunnerRepository repository) {
  final List<PlaceOffer>? offers = repository.findThisDeviceOffers();
  final String problem = '${repository.findThisRunnerProblem()}';
  if (offers == null) {
    return 'cannot run, problem $problem';
  }
  final List<String> shown = <String>[
    for (final PlaceOffer offer in offers)
      '${offer.place.name}:${offer.problem}',
  ];
  return '${shown.join(' | ')}, problem $problem';
}

void _seedEveryPlaceOffer(Random random, RunnerRig rig) {
  final List<WireRecord> offers = <WireRecord>[
    for (final String place in <String>['local_process', 'container'])
      <String, Object?>{'place': place, 'problem': randomOfferProblem(random)},
  ];
  rig.node.device.runnerSettings = randomRunnerSettingsJson(random);
  rig.node.device.runnerOffers = offers;
  rig.node.device.runnerProblem = findRustBlockingProblem(offers);
}

void _seedADeviceThatCannotRun(RunnerRig rig) {
  rig.node.device.runnerSettings = null;
  rig.node.device.runnerOffers = null;
  rig.node.device.runnerProblem = null;
}

Matcher _isRunnerNotFound(DeviceId deviceId) {
  return isA<RecordNotFound>()
      .having((RecordNotFound error) => error.kind, 'kind', 'runner')
      .having(
        (RecordNotFound error) => error.identifier,
        'identifier',
        deviceId.value,
      );
}

void main() {
  for (final _Switch flip in _Switch.values) {
    final String member = '${flip.name}_runner';

    test('${_typePrefix}_${member}_property_agrees_with_the_fake', () async {
      final Random random = seededRandom(81261 + flip.index);

      for (int i = 0; i < _iterations; i += 1) {
        final RunnerRig rig = await _openRigWithRunners(random);
        final FakeRunnerRepository fake = _buildTwinFake(rig);

        for (int step = 0; step < _longestSequence; step += 1) {
          final Runner target = pickOne(random, rig.repository.listRunners());
          final Runner shown = await _flip(
            rig.repository,
            flip,
            target.deviceId,
          );
          final Runner modelled = await _flip(fake, flip, target.deviceId);

          expect(describeRunner(shown), describeRunner(modelled));
          expect(
            describeRunners(rig.repository.listRunners()),
            describeRunners(fake.listRunners()),
          );
        }
        closeRunnerRig(rig);
        fake.dispose();
      }
    });

    test('${_typePrefix}_${member}_property_refusals_are_typed_and_'
        'change_nothing', () async {
      final Random random = seededRandom(81263 + flip.index);

      for (int i = 0; i < _iterations; i += 1) {
        final RunnerRig rig = await _openRigWithRunners(random);
        final List<Runner> before = rig.repository.listRunners();
        final int notified = rig.notifications.count;
        final DeviceId unknown = DeviceId(randomDeviceIdText(random));
        final DeviceId listed = pickOne(random, before).deviceId;

        await expectLater(
          _flip(rig.repository, flip, unknown),
          throwsA(_isRunnerNotFound(unknown)),
        );
        rig.node.refusal = 'the app server answered 403: not yours';
        await expectLater(
          _flip(rig.repository, flip, listed),
          throwsA(
            isA<AppServerRefusal>().having(
              (AppServerRefusal error) => error.status,
              'status',
              403,
            ),
          ),
        );

        expect(identical(rig.repository.listRunners(), before), isTrue);
        expect(rig.notifications.count, notified);
        closeRunnerRig(rig);
      }
    });
  }

  test('${_typePrefix}_resume_runner_property_undoes_a_pause_and_touches_'
      'nothing_else', () async {
    final Random random = seededRandom(81265);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = await _openRigWithRunners(random);
      final Runner target = pickOne(random, rig.repository.listRunners());
      final List<String> others = <String>[
        for (final Runner runner in rig.repository.listRunners())
          if (runner.deviceId != target.deviceId) describeRunner(runner),
      ];

      await rig.repository.pauseRunner(target.deviceId);
      final Runner resumed = await rig.repository.resumeRunner(
        target.deviceId,
      );

      expect(resumed.acceptingNewRuns, isTrue);
      expect(
        describeRunner(resumed),
        describeRunner(target.asAcceptingNewRuns()),
      );
      expect(<String>[
        for (final Runner runner in rig.repository.listRunners())
          if (runner.deviceId != target.deviceId) describeRunner(runner),
      ], others);
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_choose_agent_offers_property_agrees_with_the_fake_'
      'over_random_choices', () async {
    final Random random = seededRandom(81266);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      _seedEveryPlaceOffer(random, rig);
      await rig.repository.load();
      final FakeRunnerRepository fake = _buildTwinFake(rig);

      for (int step = 0; step < _longestSequence; step += 1) {
        final List<AgentPlace> choice = randomPlaceChoice(random);
        await rig.repository.chooseAgentOffers(choice);
        await fake.chooseAgentOffers(choice);

        expect(
          _describeOffers(rig.repository),
          _describeOffers(fake),
          reason: '$choice',
        );
      }
      closeRunnerRig(rig);
      fake.dispose();
    }
  });

  test('${_typePrefix}_choose_agent_offers_property_lists_local_process_'
      'before_container_once_each', () async {
    final Random random = seededRandom(81267);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      _seedEveryPlaceOffer(random, rig);
      final List<AgentPlace> choice = randomPlaceChoice(random);

      await rig.repository.chooseAgentOffers(choice);

      final List<AgentPlace> shown = <AgentPlace>[
        for (final PlaceOffer offer in rig.repository.findThisDeviceOffers()!)
          offer.place,
      ];
      expect(shown, <AgentPlace>[
        for (final AgentPlace place in <AgentPlace>[
          AgentPlace.localProcess,
          AgentPlace.container,
        ])
          if (choice.contains(place)) place,
      ]);
      closeRunnerRig(rig);
    }
  });

  test('${_typePrefix}_choose_agent_offers_property_refusals_match_the_'
      'fake_and_change_nothing', () async {
    final Random random = seededRandom(81268);

    for (int i = 0; i < _iterations; i += 1) {
      final RunnerRig rig = buildRunnerRig(random);
      final bool canRun = random.nextBool();
      if (canRun) {
        _seedEveryPlaceOffer(random, rig);
      } else {
        _seedADeviceThatCannotRun(rig);
      }
      await rig.repository.load();
      final FakeRunnerRepository fake = _buildTwinFake(rig);
      final List<AgentPlace> choice = canRun || random.nextBool()
          ? const <AgentPlace>[]
          : randomPlaceChoice(random);
      final String before = _describeOffers(rig.repository);

      final String nodeRefusal = await _describeRefusal(
        () => rig.repository.chooseAgentOffers(choice),
      );
      final String fakeRefusal = await _describeRefusal(
        () => fake.chooseAgentOffers(choice),
      );

      expect(nodeRefusal, fakeRefusal, reason: '$choice');
      expect(nodeRefusal, isNot('not refused'));
      expect(_describeOffers(rig.repository), before);
      closeRunnerRig(rig);
      fake.dispose();
    }
  });
}

String _reportNotRefused(Object? outcome) => 'not refused';

bool _isStateError(Object error) => error is StateError;

String _describeStateError(Object error) => (error as StateError).message;

Future<String> _describeRefusal(Future<void> Function() attempt) {
  final Future<String> notRefused = attempt().then(_reportNotRefused);
  return notRefused.catchError(_describeStateError, test: _isStateError);
}
