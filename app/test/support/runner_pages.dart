import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/forms/check_choice_list_field.dart';

import 'app_harness.dart';
import 'form_finders.dart';

const DeviceId thisRunnerDeviceId = GalleryDeviceIds.airLaptop;

FakeDeviceRepository buildRunnerDevices({
  required String? peerAddressProblem,
}) {
  return FakeDeviceRepository(
    devices: galleryDevices,
    currentDeviceId: thisRunnerDeviceId,
    peerAddressProblem: peerAddressProblem,
  );
}

FakeRunnerRepository buildOfferingRunners({
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

List<PlaceOffer> randomPlaceOffers(Random random) {
  final List<PlaceOffer> offers = <PlaceOffer>[
    for (final AgentPlace place in AgentPlace.values)
      if (random.nextBool())
        PlaceOffer(
          place: place,
          problem: place == AgentPlace.container && random.nextBool()
              ? 'Docker is not running ${random.nextInt(1000)}'
              : null,
        ),
  ];
  if (offers.isEmpty) {
    offers.add(
      const PlaceOffer(place: AgentPlace.localProcess, problem: null),
    );
  }
  return offers;
}

Set<AgentPlace> findOfferedPlaces(List<PlaceOffer> offers) {
  return <AgentPlace>{for (final PlaceOffer offer in offers) offer.place};
}

Set<AgentPlace>? findTickedPlaces(WidgetTester tester) {
  final Finder field = find.byType(CheckChoiceListField<AgentPlace>);
  if (field.evaluate().isEmpty) {
    return null;
  }
  return tester.widget<CheckChoiceListField<AgentPlace>>(field).selected;
}

Future<void> openRunnerPage(
  WidgetTester tester, {
  required DeviceId runnerId,
  required FakeRunnerRepository runners,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    size: desktopSize,
    route: RunnerDetailRoute(runnerId),
    dependencies: replaceRepositories(
      buildGalleryDependencies(),
      deviceRepository: buildRunnerDevices(peerAddressProblem: null),
      runnerRepository: runners,
    ),
  );
}

Future<void> openRunnersTab(
  WidgetTester tester, {
  required FakeRunnerRepository runners,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    size: desktopSize,
    route: const SectionRoute(AppSection.settings),
    dependencies: replaceRepositories(
      buildGalleryDependencies(),
      deviceRepository: buildRunnerDevices(peerAddressProblem: null),
      runnerRepository: runners,
    ),
  );
  await tapVisible(tester, find.text('Runners'));
  await pumpFrames(tester);
}
