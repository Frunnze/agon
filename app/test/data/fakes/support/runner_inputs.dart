import 'dart:math';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../../support/random_inputs.dart';
import '../../../support/sample_runners.dart';

const int _largestRunnerCount = 6;
const int _largestChoiceLength = 5;
const String _seededRunnerPrefix = 'seeded-runner-';
const String _unknownDevicePrefix = 'unknown-device-';
const String _blockedPrefix = 'blocked ';

List<Runner> randomDistinctRunners(Random random) {
  final List<Runner> runners = <Runner>[];
  final int count = random.nextInt(_largestRunnerCount);

  for (int i = 0; i < count; i += 1) {
    final Runner shape = randomRunner(random);
    runners.add(
      Runner(
        deviceId: DeviceId('$_seededRunnerPrefix$i'),
        labels: shape.labels,
        slotsTotal: shape.slotsTotal,
        slotsBusy: shape.slotsBusy,
        link: shape.link,
        online: shape.online,
        acceptingNewRuns: shape.acceptingNewRuns,
        offers: shape.offers,
        allowedHosts: shape.allowedHosts,
      ),
    );
  }

  return runners;
}

DeviceId randomUnknownDeviceId(Random random) {
  return DeviceId('$_unknownDevicePrefix${randomText(random)}');
}

String? randomOfferProblem(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return '$_blockedPrefix${randomText(random)}';
}

List<PlaceOffer> randomPlaceOffers(Random random) {
  final List<PlaceOffer> offers = <PlaceOffer>[];

  for (final AgentPlace place in AgentPlace.values) {
    if (random.nextBool()) {
      offers.add(
        PlaceOffer(place: place, problem: randomOfferProblem(random)),
      );
    }
  }

  return offers;
}

List<AgentPlace> randomPlaceChoice(Random random) {
  final List<AgentPlace> choice = <AgentPlace>[
    pickOne(random, AgentPlace.values),
  ];
  final int extraCount = random.nextInt(_largestChoiceLength);

  for (int i = 0; i < extraCount; i += 1) {
    choice.add(pickOne(random, AgentPlace.values));
  }

  return choice;
}

FakeRunnerRepository buildRunnerRepository({
  required List<Runner> runners,
  required List<PlaceOffer>? offers,
  required String? problem,
}) {
  return FakeRunnerRepository(
    runners: runners,
    thisDeviceOffers: offers,
    thisRunnerProblem: problem,
  );
}

FakeRunnerRepository buildRandomRunnerRepository(Random random) {
  final List<PlaceOffer>? offers = random.nextBool()
      ? null
      : randomPlaceOffers(random);
  return buildRunnerRepository(
    runners: randomDistinctRunners(random),
    offers: offers,
    problem: randomOfferProblem(random),
  );
}

List<String> describeRunners(List<Runner> runners) {
  final List<String> descriptions = <String>[];

  for (final Runner runner in runners) {
    descriptions.add(describeRunner(runner));
  }

  return descriptions;
}

String describeRunner(Runner runner) {
  final List<String> fields = <String>[
    runner.deviceId.value,
    runner.labels.join(','),
    '${runner.slotsTotal}/${runner.slotsBusy}',
    runner.link.name,
    '${runner.online}',
    '${runner.acceptingNewRuns}',
    runner.offers.map((AgentPlace place) => place.name).join(','),
    runner.allowedHosts.join(','),
  ];
  return fields.join('|');
}

Future<Runner> pauseOrResumeRunner(
  Random random,
  FakeRunnerRepository repository,
  DeviceId deviceId,
) {
  if (random.nextBool()) {
    return repository.pauseRunner(deviceId);
  }
  return repository.resumeRunner(deviceId);
}
