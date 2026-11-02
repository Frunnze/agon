import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/presentation/runner_text.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';
import 'package:agent_orchestration/widgets/route_line.dart';

import '../support/app_harness.dart';
import '../support/form_finders.dart';
import '../support/random_inputs.dart';

const DeviceId _thisDeviceId = GalleryDeviceIds.airLaptop;
const String _emptyRunnersTitle = 'No runners yet';

Runner _runnerOnThisDevice() {
  final Runner base = galleryRunners.first;
  return Runner(
    deviceId: _thisDeviceId,
    labels: base.labels,
    slotsTotal: base.slotsTotal,
    slotsBusy: 0,
    link: RunnerLink.direct,
    online: true,
    acceptingNewRuns: true,
    sandbox: base.sandbox,
    allowedHosts: base.allowedHosts,
  );
}

FakeDeviceRepository _buildDevices({required String? peerAddressProblem}) {
  return FakeDeviceRepository(
    devices: galleryDevices,
    currentDeviceId: _thisDeviceId,
    peerAddressProblem: peerAddressProblem,
  );
}

FakeRunnerRepository _buildRunners({
  required List<Runner> runners,
  required AgentPlace? place,
  required String? problem,
}) {
  return FakeRunnerRepository(
    runners: runners,
    thisAgentPlace: place,
    thisRunnerProblem: problem,
  );
}

String? _randomProblem(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return 'Docker is not running ${random.nextInt(1000)}';
}

Future<void> _openRunnerPage(
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
      deviceRepository: _buildDevices(peerAddressProblem: null),
      runnerRepository: runners,
    ),
  );
}

Future<void> _openRunnersTab(
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
      deviceRepository: _buildDevices(peerAddressProblem: null),
      runnerRepository: runners,
    ),
  );
  await tapVisible(tester, find.text('Runners'));
  await pumpFrames(tester);
}

AgentPlace? _shownPlace(WidgetTester tester) {
  final Finder choice = find.byType(ChoiceListField<AgentPlace>);
  if (choice.evaluate().isEmpty) {
    return null;
  }
  return tester.widget<ChoiceListField<AgentPlace>>(choice).selected;
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
          deviceRepository: _buildDevices(peerAddressProblem: problem),
        ),
      );

      final Matcher shown = problem == null ? findsNothing : findsOneWidget;
      expect(find.text(peerAddressProblemTitle), shown);
      if (problem != null) {
        expect(find.text(problem), findsOneWidget);
      }
    }
  });

  testWidgets('test_runner_detail_property_this_device_offers_the_choice', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10112);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final bool isThisDevice = random.nextBool();
      final Runner otherRunner = galleryRunners.first;
      final DeviceId runnerId = isThisDevice
          ? _thisDeviceId
          : otherRunner.deviceId;

      await _openRunnerPage(
        tester,
        runnerId: runnerId,
        runners: _buildRunners(
          runners: <Runner>[...galleryRunners, _runnerOnThisDevice()],
          place: place,
          problem: null,
        ),
      );

      expect(_shownPlace(tester), isThisDevice ? place : null);
      final Matcher readOnly = isThisDevice ? findsNothing : findsOneWidget;
      expect(find.text(describeSandbox(otherRunner.sandbox)), readOnly);
      expect(find.byType(RouteLine), readOnly);
      expect(find.text(agentPlaceTitle), findsOneWidget);
    }
  });

  testWidgets('test_runner_detail_property_a_chosen_place_is_kept', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10113);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AgentPlace chosen = pickOne(random, AgentPlace.values);
      final FakeRunnerRepository runners = _buildRunners(
        runners: <Runner>[...galleryRunners, _runnerOnThisDevice()],
        place: place,
        problem: null,
      );
      await _openRunnerPage(tester, runnerId: _thisDeviceId, runners: runners);

      await tapVisible(tester, find.text(describeAgentPlaceTitle(chosen)));
      await pumpFrames(tester);

      expect(runners.findThisAgentPlace(), chosen);
      expect(_shownPlace(tester), chosen);
    }
  });

  testWidgets('test_runner_detail_property_this_device_problem_is_shown', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10114);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final String? problem = _randomProblem(random);
      final bool isThisDevice = random.nextBool();
      final DeviceId runnerId = isThisDevice
          ? _thisDeviceId
          : galleryRunners.first.deviceId;

      await _openRunnerPage(
        tester,
        runnerId: runnerId,
        runners: _buildRunners(
          runners: <Runner>[...galleryRunners, _runnerOnThisDevice()],
          place: place,
          problem: problem,
        ),
      );

      final bool isShown = isThisDevice && problem != null;
      final Matcher shown = isShown ? findsOneWidget : findsNothing;
      expect(find.text(runnerProblemTitle), shown);
      if (problem != null) {
        expect(find.text(problem), shown);
      }
      final bool offersLocal = isShown && place == AgentPlace.container;
      expect(
        find.text(runLocallyLabel),
        offersLocal ? findsOneWidget : findsNothing,
      );
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

      await _openRunnersTab(
        tester,
        runners: _buildRunners(
          runners: runners,
          place: AgentPlace.container,
          problem: problem,
        ),
      );

      final bool hasProblem = problem != null;
      expect(
        find.text(runnerProblemTitle),
        hasProblem ? findsOneWidget : findsNothing,
      );
      final bool isEmptyState = runners.isEmpty && !hasProblem;
      expect(
        find.text(_emptyRunnersTitle),
        isEmptyState ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_runners_tab_property_running_locally_clears_the_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(10116);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeRunnerRepository runners = _buildRunners(
        runners: random.nextBool() ? const <Runner>[] : galleryRunners,
        place: AgentPlace.container,
        problem: 'The runner image is missing ${random.nextInt(1000)}',
      );
      await _openRunnersTab(tester, runners: runners);

      await tapVisible(tester, find.text(runLocallyLabel));
      await pumpFrames(tester);

      expect(runners.findThisAgentPlace(), AgentPlace.localProcess);
      expect(find.text(runnerProblemTitle), findsNothing);
    }
  });
}
