import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/widgets/route_line.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';
import '../support/runner_pages.dart';
import '../support/sample_runners.dart';

void main() {
  testWidgets('test_runner_detail_property_this_device_shows_its_offers', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10112);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<PlaceOffer> offers = randomPlaceOffers(random);
      final bool isThisDevice = random.nextBool();
      final Runner otherRunner = galleryRunners.first;
      final DeviceId runnerId = isThisDevice
          ? thisRunnerDeviceId
          : otherRunner.deviceId;

      await openRunnerPage(
        tester,
        runnerId: runnerId,
        runners: buildOfferingRunners(
          runners: <Runner>[
            ...galleryRunners,
            buildOnlineRunnerOn(thisRunnerDeviceId),
          ],
          offers: offers,
          problem: null,
        ),
      );

      final Set<AgentPlace>? expectedTicks = isThisDevice
          ? findOfferedPlaces(offers)
          : null;
      expect(findTickedPlaces(tester), expectedTicks);
      final Matcher onThisDevice = isThisDevice
          ? findsOneWidget
          : findsNothing;
      final Matcher readOnly = isThisDevice ? findsNothing : findsOneWidget;
      expect(find.text(agentOffersTitle), onThisDevice);
      expect(find.text(agentPlaceTitle), readOnly);
      expect(find.byType(RouteLine), readOnly);
      if (!isThisDevice) {
        final String offersText = describeRunnerOffers(otherRunner.offers);
        expect(find.text(offersText), findsOneWidget);
      }
      for (final PlaceOffer offer in offers) {
        final String? problem = offer.problem;
        if (problem != null) {
          expect(find.text(problem), onThisDevice);
        }
        final Matcher loginShown = isThisDevice
            ? findsOneWidget
            : findsNothing;
        expect(find.text(describeAgentLoginTitle(offer.place)), loginShown);
      }
    }
  });

  testWidgets('test_runner_detail_property_ticking_changes_the_offers', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10113);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<PlaceOffer> offers = randomPlaceOffers(random);
      final AgentPlace toggled = pickOne(random, AgentPlace.values);
      final FakeRunnerRepository runners = buildOfferingRunners(
        runners: <Runner>[
          ...galleryRunners,
          buildOnlineRunnerOn(thisRunnerDeviceId),
        ],
        offers: offers,
        problem: null,
      );
      await openRunnerPage(
        tester,
        runnerId: thisRunnerDeviceId,
        runners: runners,
      );

      await tapVisible(tester, find.text(describeAgentPlaceTitle(toggled)));
      await pumpFrames(tester);

      final Set<AgentPlace> before = findOfferedPlaces(offers);
      final Set<AgentPlace> toggledSet = before.contains(toggled)
          ? before.difference(<AgentPlace>{toggled})
          : before.union(<AgentPlace>{toggled});
      final Set<AgentPlace> expected = toggledSet.isEmpty
          ? before
          : toggledSet;
      expect(findOfferedPlaces(runners.findThisDeviceOffers()!), expected);
      expect(findTickedPlaces(tester), expected);
    }
  });
}
