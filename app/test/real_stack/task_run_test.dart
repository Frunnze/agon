import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/run_chat_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;

import 'support/real_stack.dart';
import 'support/runner_device.dart';
import 'support/stack_navigation.dart';
import 'support/stack_waiting.dart';
import 'support/task_steps.dart';

const String _blockedTitle = 'Wait for release before the build';
const String _failingTitle = 'Fail once then fix the build';
const String _retryLabel = 'Retry $agentStepName';
const String _readableLogTitle = 'Show a readable log of the tests';
const String _ranTestsLine = 'Ran npm test';
const String _testsErrorLine = 'npm ERR! missing script: test';
const String _saidLine = 'Said: $agentFinishedReply';
const String _finishedLine = 'Finished';
const String _rawStreamMarker = '"type"';

void main() {
  final bool isStackMissing = findRealStackSkipReason() != null;

  testWidgets(
    'test_task_run_property_cancel_run_stops_the_running_agent',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      final RunnerDevice runner = await pairRunnerWithProject(
        tester,
        stack: stack,
        agentAccess: node.AgentAccess.readOnly,
      );

      await startNewTaskNow(
        tester,
        title: _blockedTitle,
        details: 'Hold until told.',
      );
      await waitUntilTrue(
        tester,
        description: 'the agent to start on the runner',
        isReached: () => runner.hasRecord(agentStartedFileName),
      );
      await waitUntilShown(tester, find.text('Running'));
      await tapWhenShown(tester, find.text('Cancel run'));
      await waitUntilShown(tester, find.text(_retryLabel));
      await waitUntilRunStatus(
        tester,
        stack: stack,
        title: _blockedTitle,
        status: node.RunStatus.cancelled,
      );
      final node.Run cancelled = await askNode(
        tester,
        () => readLatestNodeRun(stack, _blockedTitle),
      );

      expect(find.text('Cancel run'), findsNothing);
      expect(find.text('Skipped'), findsOneWidget);
      expect(find.textContaining('stopped at'), findsOneWidget);
      expect(cancelled.finishedAt, isNotNull);
      expect(cancelled.steps.single.status, node.StepStatus.skipped);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_task_run_failed_property_retry_after_a_failure_finishes_the_run',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      await pairRunnerWithProject(
        tester,
        stack: stack,
        agentAccess: node.AgentAccess.readOnly,
      );

      await startNewTaskNow(
        tester,
        title: _failingTitle,
        details: 'The first try breaks.',
      );
      await waitUntilRunStatus(
        tester,
        stack: stack,
        title: _failingTitle,
        status: node.RunStatus.failed,
      );
      await waitUntilShown(
        tester,
        find.text('$agentStepName failed on $runnerDeviceName'),
      );
      final node.Run failed = await askNode(
        tester,
        () => readLatestNodeRun(stack, _failingTitle),
      );
      final node.RunFailure? failure = failed.failure;
      if (failure == null) {
        throw TestFailure('The failed run has no failure on the node');
      }
      expect(find.text(failure.reason), findsOneWidget);
      expect(failure.stepName, agentStepName);

      await tapWhenShown(tester, find.text(_retryLabel));
      await waitUntilRunStatus(
        tester,
        stack: stack,
        title: _failingTitle,
        status: node.RunStatus.done,
      );
      await waitUntilShown(tester, find.text('Ask the agent'));
      final node.Run retried = await askNode(
        tester,
        () => readLatestNodeRun(stack, _failingTitle),
      );

      expect(find.text(_retryLabel), findsNothing);
      expect(
        find.text('$agentStepName failed on $runnerDeviceName'),
        findsNothing,
      );
      expect(findPageTitle(describeFirstRunTitle(_failingTitle)), findsOne);
      expect(retried.id, failed.id);
      expect(retried.failure, isNull);
      expect(retried.steps.single.result, agentFinishedReply);
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );

  testWidgets(
    'test_task_run_property_log_shows_readable_lines_never_stream_json',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      await pairRunnerWithProject(
        tester,
        stack: stack,
        agentAccess: node.AgentAccess.readOnly,
      );

      await startNewTaskNow(
        tester,
        title: _readableLogTitle,
        details: 'The test script is missing.',
      );
      await waitUntilRunStatus(
        tester,
        stack: stack,
        title: _readableLogTitle,
        status: node.RunStatus.done,
      );
      await waitUntilShown(tester, find.textContaining(_saidLine));
      final node.Run finished = await askNode(
        tester,
        () => readLatestNodeRun(stack, _readableLogTitle),
      );
      final List<String> errorTexts = <String>[
        for (final node.LogLine line in finished.log)
          if (line.isError) line.text,
      ];
      final List<String> logTexts = <String>[
        for (final node.LogLine line in finished.log) line.text,
      ];

      expect(find.textContaining(_ranTestsLine), findsOneWidget);
      expect(find.textContaining(_testsErrorLine), findsOneWidget);
      expect(find.textContaining(_rawStreamMarker), findsNothing);
      expect(errorTexts, <String>[_testsErrorLine]);
      expect(logTexts, contains(_ranTestsLine));
      expect(logTexts, contains(_saidLine));
      expect(logTexts.last, _finishedLine);
      for (final String logText in logTexts) {
        expect(logText.contains(_rawStreamMarker), isFalse);
      }
      await stack.close(tester);
    },
    skip: isStackMissing,
    timeout: realStackTimeout,
  );
}
