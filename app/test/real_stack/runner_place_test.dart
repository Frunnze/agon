import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/commands/runner_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/runner_settings.dart' as node;
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/screens/devices/devices_screen.dart';
import 'package:agent_orchestration/widgets/forms/check_choice_list_field.dart';
import 'package:agent_orchestration/widgets/slots_indicator.dart';

import '../support/workspace_device_finders.dart';
import 'support/real_stack.dart';
import 'support/stack_navigation.dart';
import 'support/stack_node_reads.dart';
import 'support/stack_waiting.dart';

const String _missingImage = 'agents-orchestration-real-stack-missing:never';
const String _runnerLabel = 'mac';

node.RunnerSettings _blockedContainerRunner() {
  return node.RunnerSettings(
    labels: const <String>[_runnerLabel],
    slotCapacity: 1,
    sandbox: node.ContainerSandbox(
      engine: node.ContainerEngineChoice.docker,
      image: _missingImage,
      allowedHosts: const <String>[],
    ),
    cloneUrlTemplate: null,
  );
}

Finder _findOnDevicesPage(String text) {
  return find.descendant(
    of: find.byType(DevicesScreen),
    matching: find.text(text),
  );
}

Future<node.RunnersView> _listNodeRunners(RealStack stack) {
  return stack.channel.execute(
    node.ListRunnersCommand(workspaceId: stack.homeWorkspaceId),
  );
}

Set<node.AgentPlace> _offeredPlaces(node.RunnersView runners) {
  return <node.AgentPlace>{
    for (final node.PlaceOffer offer
        in runners.thisDeviceOffers ?? const <node.PlaceOffer>[])
      offer.place,
  };
}

Future<bool> _offersBothAndIsOnline(RealStack stack) async {
  final node.RunnerView? runner = await findNodeRunner(
    stack: stack,
    deviceName: appDeviceName,
  );
  final node.RunnersView runners = await _listNodeRunners(stack);
  final bool offersBoth = _offeredPlaces(runners).length == 2;
  return runner != null && runner.runner.online && offersBoth;
}

Future<bool> _isBlockedInDockerOnly(RealStack stack) async {
  final node.RunnersView runners = await _listNodeRunners(stack);
  final Set<node.AgentPlace> places = _offeredPlaces(runners);
  final bool isDockerOnly =
      places.length == 1 && places.contains(node.AgentPlace.container);
  return isDockerOnly && runners.thisDeviceProblem != null;
}

Future<String?> _readDockerProblem(RealStack stack) async {
  final node.RunnersView runners = await _listNodeRunners(stack);
  for (final node.PlaceOffer offer
      in runners.thisDeviceOffers ?? const <node.PlaceOffer>[]) {
    if (offer.place == node.AgentPlace.container) {
      return offer.problem;
    }
  }
  return null;
}

Future<void> _expectDockerProblemShown(
  WidgetTester tester,
  RealStack stack,
) async {
  final String? dockerProblem = await askNode(
    tester,
    () => _readDockerProblem(stack),
  );
  expect(dockerProblem, isNotNull);
  await waitUntilShown(tester, find.text(dockerProblem!));
}

Future<void> _waitUntilTicked(WidgetTester tester, Set<AgentPlace> expected) {
  return waitUntilTrue(
    tester,
    description: 'the page to tick $expected',
    isReached: () => setEquals(_tickedPlaces(tester), expected),
  );
}

Set<AgentPlace> _tickedPlaces(WidgetTester tester) {
  return tester
      .widget<CheckChoiceListField<AgentPlace>>(
        find.byType(CheckChoiceListField<AgentPlace>),
      )
      .selected;
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_runner_place_property_the_tab_and_page_follow_the_offers',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openAsRunner(
        tester,
        runner: _blockedContainerRunner(),
      );
      await openDevices(tester);
      await waitUntilShown(tester, _findOnDevicesPage(runnerProblemTitle));
      final node.RunnersView blocked = await askNode(
        tester,
        () => _listNodeRunners(stack),
      );
      final String? problem = blocked.thisDeviceProblem;
      expect(problem, isNotNull);
      expect(_findOnDevicesPage(problem!), findsOneWidget);

      await tapWhenShown(tester, _findOnDevicesPage(runLocallyLabel));
      await waitUntilNodeAgrees(
        tester,
        description: 'this computer offering both places',
        check: () => _offersBothAndIsOnline(stack),
      );
      await waitUntilShown(
        tester,
        find.descendant(
          of: find.byType(DevicesScreen),
          matching: find.byType(SlotsIndicator),
        ),
      );
      await waitUntilGone(tester, _findOnDevicesPage(runnerProblemTitle));

      await tapAndWait(
        tester,
        findWorkspaceDevice(
          workspaceName: homeWorkspaceName,
          deviceName: appDeviceName,
        ),
        expected: findPageTitle(appDeviceName),
      );
      await waitUntilGone(tester, find.byType(DevicesScreen));
      await _waitUntilTicked(tester, AgentPlace.values.toSet());
      await _expectDockerProblemShown(tester, stack);

      await tapWhenShown(
        tester,
        find.text(describeAgentPlaceTitle(AgentPlace.localProcess)),
      );
      await waitUntilNodeAgrees(
        tester,
        description: 'this computer blocked in Docker only',
        check: () => _isBlockedInDockerOnly(stack),
      );
      await _waitUntilTicked(tester, <AgentPlace>{AgentPlace.container});
      await _expectDockerProblemShown(tester, stack);

      await tapWhenShown(
        tester,
        find.text(describeAgentPlaceTitle(AgentPlace.localProcess)),
      );
      await waitUntilNodeAgrees(
        tester,
        description: 'this computer offering both places again',
        check: () => _offersBothAndIsOnline(stack),
      );
      await _waitUntilTicked(tester, AgentPlace.values.toSet());
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
