import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/catalog_views.dart' as node;
import 'package:agent_orchestration/bridge/commands/runner_commands.dart'
    as node;
import 'package:agent_orchestration/bridge/node/runner_settings.dart' as node;
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';

import 'support/real_stack.dart';
import 'support/stack_navigation.dart';
import 'support/stack_node_reads.dart';
import 'support/stack_settings.dart';
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

Finder _findInRunnersTab(String text) {
  return find.descendant(
    of: find.byType(RunnersSettingsTab),
    matching: find.text(text),
  );
}

Future<node.RunnersView> _listNodeRunners(RealStack stack) {
  return stack.channel.execute(
    node.ListRunnersCommand(workspaceId: stack.homeWorkspaceId),
  );
}

Future<bool> _isRunningLocallyOnline(RealStack stack) async {
  final node.RunnerView? runner = await findNodeRunner(
    stack: stack,
    deviceName: appDeviceName,
  );
  final node.RunnersView runners = await _listNodeRunners(stack);
  final bool isLocal =
      runners.thisDeviceSettings?.sandbox is node.LocalProcessSandbox;
  return runner != null && runner.runner.online && isLocal;
}

Future<bool> _isBlockedInContainer(RealStack stack) async {
  final node.RunnersView runners = await _listNodeRunners(stack);
  final bool isContainer =
      runners.thisDeviceSettings?.sandbox is node.ContainerSandbox;
  return isContainer && runners.thisDeviceProblem != null;
}

AgentPlace _shownPlace(WidgetTester tester) {
  return tester
      .widget<ChoiceListField<AgentPlace>>(
        find.byType(ChoiceListField<AgentPlace>),
      )
      .selected;
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_runner_place_property_the_tab_and_page_follow_the_choice',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openAsRunner(
        tester,
        runner: _blockedContainerRunner(),
      );
      await openSettingsTab(
        tester,
        tabLabel: 'Runners',
        expected: find.byType(RunnersSettingsTab),
      );
      await waitUntilShown(tester, _findInRunnersTab(runnerProblemTitle));
      final node.RunnersView blocked = await askNode(
        tester,
        () => _listNodeRunners(stack),
      );
      expect(blocked.thisDeviceProblem, isNotNull);
      expect(_findInRunnersTab(blocked.thisDeviceProblem!), findsOneWidget);
      expect(_findInRunnersTab('No runners yet'), findsNothing);

      await tapWhenShown(tester, _findInRunnersTab(runLocallyLabel));
      await waitUntilNodeAgrees(
        tester,
        description: 'this computer running agents locally',
        check: () => _isRunningLocallyOnline(stack),
      );
      await waitUntilShown(tester, _findInRunnersTab(appDeviceName));
      await waitUntilGone(tester, _findInRunnersTab(runnerProblemTitle));

      await tapAndWait(
        tester,
        _findInRunnersTab(appDeviceName),
        expected: findPageTitle(appDeviceName),
      );
      await waitUntilGone(tester, find.byType(RunnersSettingsTab));
      expect(_shownPlace(tester), AgentPlace.localProcess);

      await tapWhenShown(
        tester,
        find.text(describeAgentPlaceTitle(AgentPlace.container)),
      );
      await waitUntilShown(tester, find.text(runnerProblemTitle));
      await waitUntilNodeAgrees(
        tester,
        description: 'this computer blocked in a container',
        check: () => _isBlockedInContainer(stack),
      );
      expect(_shownPlace(tester), AgentPlace.container);

      await tapWhenShown(tester, find.text(runLocallyLabel));
      await waitUntilGone(tester, find.text(runnerProblemTitle));
      expect(_shownPlace(tester), AgentPlace.localProcess);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
