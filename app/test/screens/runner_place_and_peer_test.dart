import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';
import '../support/runner_pages.dart';

String? _randomProblem(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return 'Docker is not running ${random.nextInt(1000)}';
}

void main() {
  testWidgets('test_settings_property_peer_problem_shows_a_banner', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10111);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String? problem = random.nextBool()
          ? 'the relay refused ${random.nextInt(1000)}'
          : null;
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpApp(
        tester,
        size: desktopSize,
        route: const SectionRoute(AppSection.settings),
        dependencies: replaceRepositories(
          buildGalleryDependencies(),
          deviceRepository: buildRunnerDevices(peerAddressProblem: problem),
        ),
      );

      final Matcher shown = problem == null ? findsNothing : findsOneWidget;
      expect(find.text(peerAddressProblemTitle), shown);
      if (problem != null) {
        expect(find.text(problem), findsOneWidget);
      }
    }
  });

  testWidgets('test_runners_tab_property_this_device_problem_is_explained', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10115);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String? problem = _randomProblem(random);
      final List<Runner> runners = random.nextBool()
          ? const <Runner>[]
          : galleryRunners;
      final bool offersLocal = random.nextBool();

      await openDevicesWithRunners(
        tester,
        runners: buildOfferingRunners(
          runners: runners,
          offers: <PlaceOffer>[
            PlaceOffer(place: AgentPlace.container, problem: problem),
            if (offersLocal)
              const PlaceOffer(place: AgentPlace.localProcess, problem: null),
          ],
          problem: problem,
        ),
      );

      final bool hasProblem = problem != null;
      expect(
        find.text(runnerProblemTitle),
        hasProblem ? findsOneWidget : findsNothing,
      );
      final bool canAddLocal = hasProblem && !offersLocal;
      expect(
        find.text(runLocallyLabel),
        canAddLocal ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_runners_tab_property_running_locally_clears_the_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10116);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String problem =
          'The runner image is missing ${random.nextInt(1000)}';
      final FakeRunnerRepository runners = buildOfferingRunners(
        runners: random.nextBool() ? const <Runner>[] : galleryRunners,
        offers: <PlaceOffer>[
          PlaceOffer(place: AgentPlace.container, problem: problem),
        ],
        problem: problem,
      );
      await openDevicesWithRunners(tester, runners: runners);

      await tapVisible(tester, find.text(runLocallyLabel));
      await pumpFrames(tester);

      expect(findOfferedPlaces(runners.findThisDeviceOffers()!), <AgentPlace>{
        AgentPlace.container,
        AgentPlace.localProcess,
      });
      expect(find.text(runnerProblemTitle), findsNothing);
    }
  });
}
