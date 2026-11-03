import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

import 'support/real_stack.dart';
import 'support/runner_device.dart';
import 'support/stack_navigation.dart';
import 'support/stack_waiting.dart';
import 'support/task_steps.dart';

const String _dockerTitle = 'Build the docs in a container';
const String _ranInDockerFileName = 'ran-in-docker';
const Duration _waitingPeriod = Duration(seconds: 12);
const List<String> _bothOffers = <String>['local_process', 'container'];

Future<void> _startDockerTask(WidgetTester tester) async {
  await openNewTaskForm(tester);
  await fillTaskForm(tester, title: _dockerTitle, details: 'Use Docker.');
  final Finder placeField = find.byType(SelectField<AgentPlace>);
  tester
      .widget<SelectField<AgentPlace>>(placeField)
      .onChanged(AgentPlace.container);
  await tester.pump();
  await tapAndWait(
    tester,
    find.text('Start now'),
    expected: findPageTitle(describeFirstRunTitle(_dockerTitle)),
  );
}

Future<void> _offerDockerToo(WidgetTester tester, RunnerDevice runner) {
  return askNode(
    tester,
    () => runner.node.run(<String, Object?>{
      'command': 'choose_agent_offers',
      'offers': _bothOffers,
    }),
  );
}

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_task_place_property_a_docker_task_waits_for_a_docker_runner',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final RunnerDevice runner = await pairRunnerWithProject(
        tester,
        stack: stack,
        agentAccess: node.AgentAccess.readOnly,
      );
      final String missingTitle = describeMissingPlaceTitle(
        AgentPlace.container,
      );

      await _startDockerTask(tester);
      await waitUntilShown(tester, find.text(missingTitle));
      await tester.runAsync(() => Future<void>.delayed(_waitingPeriod));
      final node.Run waiting = await askNode(
        tester,
        () => readLatestNodeRun(stack, _dockerTitle),
      );
      expect(waiting.status, node.RunStatus.queued);
      expect(waiting.steps.single.runner, isNull);
      expect(runner.hasRecord(_ranInDockerFileName), isFalse);

      await _offerDockerToo(tester, runner);
      await waitUntilRunStatus(
        tester,
        stack: stack,
        title: _dockerTitle,
        status: node.RunStatus.done,
      );
      await waitUntilGone(tester, find.text(missingTitle));

      expect(runner.hasRecord(_ranInDockerFileName), isTrue);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
